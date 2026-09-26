//! Phase 0 spike S4 -- layout engine evaluation.
//!
//! Throwaway. Decides which Rust layered-layout crate the `layout` crate wraps.
//! Runs each candidate on identical pre-measured graphs (fixtures/*.graph.json)
//! and reports time plus the quality metrics that actually matter for an ER
//! diagram, rather than a generic graph benchmark.
//!
//! Gate (docs/roadmap.md#s4): under 500ms on the 300-table fixture, with no
//! pathological output.

use std::collections::HashMap;
use std::time::Instant;

use serde::Deserialize;

#[derive(Deserialize)]
struct GraphSpec {
    nodes: Vec<NodeSpec>,
    edges: Vec<EdgeSpec>,
}

#[derive(Deserialize, Clone)]
struct NodeSpec {
    id: String,
    w: f64,
    h: f64,
}

#[derive(Deserialize)]
struct EdgeSpec {
    from: String,
    to: String,
}

/// A laid-out table. `x`/`y` are top-left, matching what the renderer wants;
/// engines that return centre coordinates are converted on the way out so the
/// metrics below compare like with like.
#[derive(Clone, Debug)]
struct Placed {
    x: f64,
    y: f64,
    w: f64,
    h: f64,
}

// Spacing preset ported from sqltoerdiagram's layout.js "comfortable". Using
// its numbers keeps the visual comparison against the reference tool honest.
const NODESEP: f64 = 36.0;
const RANKSEP: f64 = 130.0;
const EDGESEP: f64 = 24.0;

/// Hub-aware edge weighting, ported from sqltoerdiagram's layout.js.
///
/// Edges touching a high-degree table are weighted up so its spokes stay in the
/// adjacent rank instead of scattering. This is most of what makes a layered
/// layout read as an ER diagram rather than a hairball, so every engine is
/// given the same weights -- otherwise we would be benchmarking our own tuning
/// rather than the engines.
fn degrees(edges: &[EdgeSpec]) -> HashMap<&str, usize> {
    let mut d: HashMap<&str, usize> = HashMap::new();
    for e in edges {
        if e.from != e.to {
            *d.entry(e.from.as_str()).or_default() += 1;
            *d.entry(e.to.as_str()).or_default() += 1;
        }
    }
    d
}

fn edge_weight(d: &HashMap<&str, usize>, from: &str, to: &str) -> i32 {
    let hubness = d
        .get(from)
        .copied()
        .unwrap_or(0)
        .max(d.get(to).copied().unwrap_or(0));
    1 + hubness.min(12) as i32
}

// ---------------------------------------------------------------- metrics

#[derive(Debug)]
struct Metrics {
    placed: usize,
    width: f64,
    height: f64,
    aspect: f64,
    overlaps: usize,
    /// Fraction of the bounding box actually covered by tables. Low values mean
    /// a sprawling layout that forces the user to zoom out past legibility.
    density: f64,
    /// Mean centre-to-centre edge length. Long edges are hard to follow.
    mean_edge: f64,
}

fn measure(placed: &HashMap<String, Placed>, edges: &[EdgeSpec]) -> Metrics {
    if placed.is_empty() {
        return Metrics {
            placed: 0,
            width: 0.0,
            height: 0.0,
            aspect: 0.0,
            overlaps: 0,
            density: 0.0,
            mean_edge: 0.0,
        };
    }
    let (mut min_x, mut min_y) = (f64::MAX, f64::MAX);
    let (mut max_x, mut max_y) = (f64::MIN, f64::MIN);
    let mut area = 0.0;
    for p in placed.values() {
        min_x = min_x.min(p.x);
        min_y = min_y.min(p.y);
        max_x = max_x.max(p.x + p.w);
        max_y = max_y.max(p.y + p.h);
        area += p.w * p.h;
    }
    let width = max_x - min_x;
    let height = max_y - min_y;

    // O(n^2), but this is a spike on 300-1000 nodes and correctness beats
    // cleverness here.
    let list: Vec<&Placed> = placed.values().collect();
    let mut overlaps = 0;
    for i in 0..list.len() {
        for j in (i + 1)..list.len() {
            let (a, b) = (list[i], list[j]);
            let ox = (a.x + a.w).min(b.x + b.w) - a.x.max(b.x);
            let oy = (a.y + a.h).min(b.y + b.h) - a.y.max(b.y);
            if ox > 0.0 && oy > 0.0 {
                overlaps += 1;
            }
        }
    }

    let mut total = 0.0;
    let mut counted = 0;
    for e in edges {
        if let (Some(a), Some(b)) = (placed.get(&e.from), placed.get(&e.to)) {
            let dx = (a.x + a.w / 2.0) - (b.x + b.w / 2.0);
            let dy = (a.y + a.h / 2.0) - (b.y + b.h / 2.0);
            total += (dx * dx + dy * dy).sqrt();
            counted += 1;
        }
    }

    Metrics {
        placed: placed.len(),
        width,
        height,
        aspect: if height > 0.0 { width / height } else { 0.0 },
        overlaps,
        density: if width * height > 0.0 {
            area / (width * height)
        } else {
            0.0
        },
        mean_edge: if counted > 0 {
            total / counted as f64
        } else {
            0.0
        },
    }
}

// ---------------------------------------------------------------- engines

type Placement = HashMap<String, Placed>;

fn run_dagre(spec: &GraphSpec) -> Option<Placement> {
    use dagre::{EdgeLabel, LayoutOptions, NodeLabel, RankDir};

    let d = degrees(&spec.edges);
    // Multigraph, because two tables can legitimately be joined by more than one
    // foreign key and collapsing those loses a relationship.
    let mut g: dagre::graph::Graph<NodeLabel, EdgeLabel> =
        dagre::graph::Graph::with_options(dagre::graph::GraphOptions {
            directed: true,
            multigraph: true,
            compound: false,
        });
    for n in &spec.nodes {
        g.set_node(
            n.id.clone(),
            Some(NodeLabel {
                width: n.w,
                height: n.h,
                ..Default::default()
            }),
        );
    }
    for (i, e) in spec.edges.iter().enumerate() {
        if e.from == e.to {
            continue;
        }
        g.set_edge(
            e.from.clone(),
            e.to.clone(),
            Some(EdgeLabel {
                weight: edge_weight(&d, &e.from, &e.to),
                minlen: 1,
                ..Default::default()
            }),
            Some(&format!("e{i}")),
        );
    }

    dagre::layout(
        &mut g,
        Some(LayoutOptions {
            rankdir: RankDir::LR,
            nodesep: NODESEP,
            ranksep: RANKSEP,
            edgesep: EDGESEP,
            ..Default::default()
        }),
    );

    let mut out = Placement::new();
    for n in &spec.nodes {
        if let Some(label) = g.node(&n.id)
            && let (Some(x), Some(y)) = (label.x, label.y)
        {
            // dagre reports centres; the renderer wants top-left.
            out.insert(
                n.id.clone(),
                Placed {
                    x: x - n.w / 2.0,
                    y: y - n.h / 2.0,
                    w: n.w,
                    h: n.h,
                },
            );
        }
    }
    Some(out)
}

fn run_sugiyama(spec: &GraphSpec) -> Option<Placement> {
    use rust_sugiyama::configure::Config;

    // rust-sugiyama is index-based, so ids are mapped to u32 and back.
    let index: HashMap<&str, u32> = spec
        .nodes
        .iter()
        .enumerate()
        .map(|(i, n)| (n.id.as_str(), i as u32))
        .collect();
    let vertices: Vec<(u32, (f64, f64))> = spec
        .nodes
        .iter()
        .enumerate()
        .map(|(i, n)| (i as u32, (n.w, n.h)))
        .collect();
    let edges: Vec<(u32, u32)> = spec
        .edges
        .iter()
        .filter(|e| e.from != e.to)
        .filter_map(|e| Some((*index.get(e.from.as_str())?, *index.get(e.to.as_str())?)))
        .collect();

    let cfg = Config {
        vertex_spacing: NODESEP,
        ..Config::default()
    };

    let layouts = rust_sugiyama::from_vertices_and_edges(&vertices, &edges, &cfg);

    // Disjoint subgraphs come back separately, each with its own origin. Packing
    // them into one row is the crudest possible arrangement -- good enough to
    // judge the engine, and not how the real orphan packer will work.
    let mut out = Placement::new();
    let by_index: HashMap<u32, &NodeSpec> = spec
        .nodes
        .iter()
        .enumerate()
        .map(|(i, n)| (i as u32, n))
        .collect();
    let mut offset_x = 0.0;
    for (layout, w, _h) in layouts {
        for (id, (x, y)) in layout {
            if let Some(n) = by_index.get(&(id as u32)) {
                out.insert(
                    n.id.clone(),
                    Placed {
                        x: x + offset_x - n.w / 2.0,
                        y: y - n.h / 2.0,
                        w: n.w,
                        h: n.h,
                    },
                );
            }
        }
        offset_x += w + 200.0;
    }
    Some(out)
}

fn run_dugong(spec: &GraphSpec) -> Option<Placement> {
    use dugong::graphlib::{Graph, GraphOptions};
    use dugong::{EdgeLabel, GraphLabel, NodeLabel, RankDir};

    let d = degrees(&spec.edges);
    let opts = GraphOptions {
        multigraph: true,
        directed: true,
        ..GraphOptions::default()
    };
    let mut g: Graph<NodeLabel, EdgeLabel, GraphLabel> = Graph::new(opts);
    g.set_graph(GraphLabel {
        rankdir: RankDir::LR,
        nodesep: NODESEP,
        ranksep: RANKSEP,
        edgesep: EDGESEP,
        ..Default::default()
    });

    for n in &spec.nodes {
        g.set_node(
            n.id.clone(),
            NodeLabel {
                width: n.w,
                height: n.h,
                ..Default::default()
            },
        );
    }
    for (i, e) in spec.edges.iter().enumerate() {
        if e.from == e.to {
            continue;
        }
        g.set_edge_named(
            e.from.as_str(),
            e.to.as_str(),
            Some(format!("e{i}")),
            Some(EdgeLabel {
                weight: edge_weight(&d, &e.from, &e.to) as f64,
                minlen: 1,
                ..Default::default()
            }),
        );
    }

    dugong::layout(&mut g).ok()?;

    let mut out = Placement::new();
    for n in &spec.nodes {
        if let Some(label) = g.node(&n.id)
            && let (Some(x), Some(y)) = (label.x, label.y)
        {
            out.insert(
                n.id.clone(),
                Placed {
                    x: x - n.w / 2.0,
                    y: y - n.h / 2.0,
                    w: n.w,
                    h: n.h,
                },
            );
        }
    }
    Some(out)
}

// ---------------------------------------------------------------- driver

fn bench(name: &str, spec: &GraphSpec, f: impl Fn(&GraphSpec) -> Option<Placement>) {
    // One warm-up to fault in allocations, then best-of-3. Best-of rather than
    // mean because we want the engine's cost, not the machine's noise.
    let _ = f(spec);
    let mut best = f64::MAX;
    let mut result = None;
    for _ in 0..3 {
        let t = Instant::now();
        let r = f(spec);
        let ms = t.elapsed().as_secs_f64() * 1000.0;
        if ms < best {
            best = ms;
        }
        result = r;
    }

    match result {
        None => println!("{name:<16} FAILED (engine returned no layout)"),
        Some(p) => {
            let m = measure(&p, &spec.edges);
            let missing = spec.nodes.len() - m.placed;
            println!(
                "{name:<16} {best:>8.1}ms  placed {}/{}{}  bbox {:.0}x{:.0} (aspect {:.2})  \
                 overlaps {}  density {:.3}  mean edge {:.0}px",
                m.placed,
                spec.nodes.len(),
                if missing > 0 {
                    format!(" [{missing} MISSING]")
                } else {
                    String::new()
                },
                m.width,
                m.height,
                m.aspect,
                m.overlaps,
                m.density,
                m.mean_edge,
            );
        }
    }
}

/// Do two engines agree on placement, or only on summary statistics?
///
/// Matching bbox and density could easily be coincidence. If the per-node
/// positions match too, both are faithful dagre ports and the faster one can be
/// chosen on speed alone with no quality risk.
fn compare(a: &Placement, b: &Placement) -> Option<f64> {
    let mut worst: f64 = 0.0;
    for (id, pa) in a {
        let pb = b.get(id)?;
        worst = worst.max((pa.x - pb.x).abs()).max((pa.y - pb.y).abs());
    }
    Some(worst)
}

/// Connected component sizes.
///
/// The layered layouts all produce a pathological aspect ratio on this graph.
/// If it decomposes into many components, laying each out separately and bin-
/// packing them to a target aspect ratio fixes it. If it is one giant
/// component, packing cannot help and the fix has to be elsewhere.
fn components(spec: &GraphSpec) -> Vec<usize> {
    let index: HashMap<&str, usize> = spec
        .nodes
        .iter()
        .enumerate()
        .map(|(i, n)| (n.id.as_str(), i))
        .collect();
    let mut parent: Vec<usize> = (0..spec.nodes.len()).collect();
    fn find(parent: &mut [usize], mut x: usize) -> usize {
        while parent[x] != x {
            parent[x] = parent[parent[x]];
            x = parent[x];
        }
        x
    }
    for e in &spec.edges {
        if let (Some(&a), Some(&b)) = (index.get(e.from.as_str()), index.get(e.to.as_str())) {
            let (ra, rb) = (find(&mut parent, a), find(&mut parent, b));
            if ra != rb {
                parent[ra] = rb;
            }
        }
    }
    let mut sizes: HashMap<usize, usize> = HashMap::new();
    for i in 0..spec.nodes.len() {
        let r = find(&mut parent, i);
        *sizes.entry(r).or_default() += 1;
    }
    let mut v: Vec<usize> = sizes.into_values().collect();
    v.sort_unstable_by(|a, b| b.cmp(a));
    v
}

fn main() {
    for fixture in [
        "fixtures/synthetic_300.graph.json",
        "fixtures/synthetic_1000.graph.json",
    ] {
        let raw = match std::fs::read_to_string(fixture) {
            Ok(s) => s,
            Err(e) => {
                eprintln!("skip {fixture}: {e} (run `make fixtures`)");
                continue;
            }
        };
        let spec: GraphSpec = serde_json::from_str(&raw).expect("valid graph json");
        println!(
            "\n=== {fixture}  ({} nodes, {} edges) ===",
            spec.nodes.len(),
            spec.edges.len()
        );
        bench("dagre", &spec, run_dagre);
        bench("dugong", &spec, run_dugong);
        bench("rust-sugiyama", &spec, run_sugiyama);

        match (run_dagre(&spec), run_dugong(&spec)) {
            (Some(a), Some(b)) => match compare(&a, &b) {
                Some(delta) => println!("  dagre vs dugong: max position delta {delta:.3}px"),
                None => println!("  dagre vs dugong: node sets differ"),
            },
            _ => println!("  dagre vs dugong: one engine failed"),
        }

        let comps = components(&spec);
        let singletons = comps.iter().filter(|&&s| s == 1).count();
        println!(
            "  components: {} total, largest {}, singletons {}, top5 {:?}",
            comps.len(),
            comps.first().copied().unwrap_or(0),
            singletons,
            &comps[..comps.len().min(5)],
        );
    }
}
