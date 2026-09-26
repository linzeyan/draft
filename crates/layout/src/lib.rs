//! Layered graph layout for schema diagrams.
//!
//! A thin, deliberate wrapper around [`dugong`]. Thin because the engine was
//! chosen by measurement — it matches dagre.js's output and is 25–53x faster
//! (see `docs/measurements.md`) — and deliberate because the whole visual
//! quality of the product sits on one small crate, so the seam where it could
//! be swapped is kept narrow on purpose.
//!
//! Two things here are ours rather than the engine's, and both are what make a
//! layered layout read as an ER diagram instead of a hairball:
//!
//! * **Hub-aware edge weighting**, ported from sqltoerdiagram's `layout.js`
//!   (MIT). Edges touching a high-degree table are weighted up so its spokes
//!   stay in the adjacent rank instead of scattering.
//! * **Unconnected tables are packed into a grid beside the graph** rather than
//!   handed to the engine, which would spread them across a rank each.

use draft_ddl::Schema;

mod placement;

pub use placement::{Placement, Pos};

/// Base separations, in points, at [`Spacing::Comfortable`].
const NODESEP: f64 = 36.0;
const RANKSEP: f64 = 130.0;
const EDGESEP: f64 = 24.0;

/// Used when a caller supplies no measurement for a table.
const DEFAULT_SIZE: Size = Size { w: 180.0, h: 80.0 };

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Size {
    pub w: f32,
    pub h: f32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Rect {
    pub x: f32,
    pub y: f32,
    pub w: f32,
    pub h: f32,
}

impl Rect {
    pub fn right(&self) -> f32 {
        self.x + self.w
    }

    pub fn bottom(&self) -> f32 {
        self.y + self.h
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum Direction {
    /// Ranks run left to right; the diagram grows sideways.
    #[default]
    Horizontal,
    Vertical,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum Spacing {
    Compact,
    #[default]
    Comfortable,
    Spacious,
}

impl Spacing {
    fn factor(self) -> f64 {
        match self {
            Self::Compact => 0.65,
            Self::Comfortable => 1.0,
            Self::Spacious => 1.6,
        }
    }
}

// `PartialEq` because a caller holding positions has to know when the options
// stopped describing the arrangement they came from (see [`Placement`]).
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Options {
    pub direction: Direction,
    pub spacing: Spacing,
}

/// Where every table ended up. Indices match [`Schema::tables`].
#[derive(Clone, Debug)]
pub struct Layout {
    pub nodes: Vec<Rect>,
    /// Bounding box of the whole diagram, with the top-left at the origin.
    pub size: Size,
}

/// Place every table in `schema`. `sizes` is indexed like `schema.tables`;
/// short or missing entries fall back to a default box, so a caller that has
/// not measured yet still gets a usable diagram.
pub fn layout(schema: &Schema, sizes: &[Size], options: &Options) -> Layout {
    let size_of = |i: usize| sizes.get(i).copied().unwrap_or(DEFAULT_SIZE);
    let gap = (NODESEP * options.spacing.factor()) as f32;

    let degree = degrees(schema);
    let connected: Vec<usize> = (0..schema.tables.len())
        .filter(|i| degree[*i] > 0)
        .collect();

    let mut nodes = vec![
        Rect {
            x: 0.0,
            y: 0.0,
            w: 0.0,
            h: 0.0
        };
        schema.tables.len()
    ];
    for (i, node) in nodes.iter_mut().enumerate() {
        let s = size_of(i);
        node.w = s.w;
        node.h = s.h;
    }

    let mut graph_box = run_engine(schema, &connected, &degree, options, &mut nodes);
    if let Some(b) = graph_box {
        graph_box = Some(wrap_ranks(&connected, b, options, gap, &mut nodes));
    }
    let loose: Vec<usize> = (0..schema.tables.len())
        .filter(|i| degree[*i] == 0)
        .collect();
    pack_beside(&loose, graph_box, options.direction, gap, &mut nodes);

    normalise(&mut nodes)
}

/// The shape we wrap towards. Not a hard constraint — a diagram is allowed to
/// be wider or taller than this — but it is the ratio a screen has, and a
/// diagram that fits one reads far better than a ribbon.
const TARGET_ASPECT: f32 = 16.0 / 9.0;

/// Fold over-long ranks into several columns each.
///
/// Every layered engine, including the dagre.js the reference tool uses,
/// answers a real ER schema with a ribbon: hundreds of tables share a handful
/// of ranks, so one axis grows without limit while the other stays put. Phase 0
/// measured aspect 0.15–0.17 and 6% ink on a 300-table schema, and confirmed
/// that packing disconnected components cannot help, because 285 of those 300
/// tables are one component.
///
/// So the fix is inside the ranks rather than between them. Rank order is what
/// carries the meaning — referenced tables upstream of referencing ones — and
/// wrapping preserves it: a rank becomes several adjacent columns, read
/// top-to-bottom then left-to-right, exactly like text. Relative order within a
/// rank survives too, so the engine's crossing-minimisation work is not thrown
/// away.
///
/// How long a column may get before the next node starts a new one.
///
/// Deriving this rather than guessing it matters, because the obvious guess is
/// wrong: the engine's bounding box is 94% empty on a real schema, so treating
/// wrapping as an area-preserving trade between the two axes just squeezes out
/// the whitespace and leaves the ribbon nearly as long as it was. Measured on
/// the 300-table fixture, that guess reached aspect 0.60 against a target of
/// 1.78.
///
/// What actually constrains the result is the ink. With `s` the total length of
/// all nodes plus their gaps, `t` the mean rank thickness and `r` the total
/// rank separation, wrapping to a column length `x` produces roughly `s / x`
/// columns, so:
///
/// ```text
///   along ≈ (s / x) · t + r        and we want   along = x · aspect
/// ```
///
/// which rearranges to `aspect·x² − r·x − s·t = 0`, hence the quadratic below.
fn wrap_target(
    ranked: &[(f32, usize)],
    vertical: bool,
    gap: f32,
    ranksep: f32,
    nodes: &[Rect],
) -> f32 {
    let len_of = |i: usize| if vertical { nodes[i].w } else { nodes[i].h };
    let thick_of = |i: usize| if vertical { nodes[i].h } else { nodes[i].w };

    let s: f32 = ranked.iter().map(|&(_, i)| len_of(i) + gap).sum();
    let ranks = ranked.windows(2).filter(|w| w[0].0 != w[1].0).count() + 1;
    let r = ranks as f32 * ranksep;
    let t =
        ranked.iter().map(|&(_, i)| thick_of(i)).sum::<f32>() / ranked.len().max(1) as f32 + gap;

    let x = (r + (r * r + 4.0 * TARGET_ASPECT * s * t).sqrt()) / (2.0 * TARGET_ASPECT);
    // Never wrap tighter than the tallest single node, or a column holds one
    // node and the wrap has achieved nothing but scattering.
    x.max(ranked.iter().map(|&(_, i)| len_of(i)).fold(0.0, f32::max))
}

/// Returns the new bounding box.
fn wrap_ranks(
    connected: &[usize],
    bounds: Rect,
    options: &Options,
    gap: f32,
    nodes: &mut [Rect],
) -> Rect {
    let vertical = options.direction == Direction::Vertical;

    // Group by rank. Nodes in a rank share a centre on the rank axis, but their
    // differing sizes mean the *edges* do not line up, so group on the centre.
    let mut ranked: Vec<(f32, usize)> = connected
        .iter()
        .map(|&i| {
            let c = if vertical {
                nodes[i].y + nodes[i].h / 2.0
            } else {
                nodes[i].x + nodes[i].w / 2.0
            };
            ((c * 4.0).round() / 4.0, i)
        })
        .collect();
    ranked.sort_by(|a, b| {
        let cross_of = |i: usize| if vertical { nodes[i].x } else { nodes[i].y };
        a.0.total_cmp(&b.0)
            .then(cross_of(a.1).total_cmp(&cross_of(b.1)))
    });

    let ranksep = (RANKSEP * options.spacing.factor()) as f32;
    let target = wrap_target(&ranked, vertical, gap, ranksep, nodes);
    let cross = if vertical { bounds.w } else { bounds.h };
    if cross <= target * 1.2 {
        return bounds; // already a reasonable shape; leave the engine's work alone
    }
    let (mut cursor_along, mut max_cross) = (0.0f32, 0.0f32);
    let mut rank_start = 0;

    while rank_start < ranked.len() {
        let rank_at = ranked[rank_start].0;
        let mut rank_end = rank_start;
        while rank_end < ranked.len() && ranked[rank_end].0 == rank_at {
            rank_end += 1;
        }

        // Lay this rank out in columns, each at most `target` long.
        let (mut run, mut column_thickness) = (0.0f32, 0.0f32);
        for &(_, i) in &ranked[rank_start..rank_end] {
            let (len, thick) = if vertical {
                (nodes[i].w, nodes[i].h)
            } else {
                (nodes[i].h, nodes[i].w)
            };
            if run > 0.0 && run + len > target {
                cursor_along += column_thickness + gap;
                run = 0.0;
                column_thickness = 0.0;
            }
            if vertical {
                nodes[i].x = run;
                nodes[i].y = cursor_along;
            } else {
                nodes[i].x = cursor_along;
                nodes[i].y = run;
            }
            run += len + gap;
            column_thickness = column_thickness.max(thick);
            max_cross = max_cross.max(run - gap);
        }
        cursor_along += column_thickness + ranksep;
        rank_start = rank_end;
    }

    let along_total = (cursor_along - ranksep).max(0.0);
    if vertical {
        Rect {
            x: 0.0,
            y: 0.0,
            w: max_cross,
            h: along_total,
        }
    } else {
        Rect {
            x: 0.0,
            y: 0.0,
            w: along_total,
            h: max_cross,
        }
    }
}

/// Undirected degree per table, counting only edges the engine will see.
fn degrees(schema: &Schema) -> Vec<usize> {
    let mut degree = vec![0usize; schema.tables.len()];
    for (from, to) in edges(schema) {
        degree[from] += 1;
        degree[to] += 1;
    }
    degree
}

/// Resolved table-to-table edges. Self-references are dropped: the engine
/// cannot rank a node against itself, and the diagram draws those as a loop on
/// the table rather than as a relationship between two of them.
fn edges(schema: &Schema) -> impl Iterator<Item = (usize, usize)> + '_ {
    schema.relations.iter().filter_map(|r| {
        let from = schema.index_of(&r.from_table)?;
        let to = schema.index_of(&r.to_table)?;
        (from != to).then_some((from, to))
    })
}

/// Run dugong over the connected subgraph, writing positions into `nodes`.
/// Returns the bounding box of what it placed.
fn run_engine(
    schema: &Schema,
    connected: &[usize],
    degree: &[usize],
    options: &Options,
    nodes: &mut [Rect],
) -> Option<Rect> {
    use dugong::graphlib::{Graph, GraphOptions};
    use dugong::{EdgeLabel, GraphLabel, NodeLabel, RankDir};

    if connected.is_empty() {
        return None;
    }

    let factor = options.spacing.factor();
    let mut g: Graph<NodeLabel, EdgeLabel, GraphLabel> = Graph::new(GraphOptions {
        directed: true,
        // Two tables can be joined by more than one foreign key, and a simple
        // graph would silently collapse them into one edge.
        multigraph: true,
        compound: false,
    });
    g.set_graph(GraphLabel {
        rankdir: match options.direction {
            Direction::Horizontal => RankDir::LR,
            Direction::Vertical => RankDir::TB,
        },
        nodesep: NODESEP * factor,
        ranksep: RANKSEP * factor,
        edgesep: EDGESEP * factor,
        ..Default::default()
    });

    for &i in connected {
        g.set_node(
            id(i),
            NodeLabel {
                width: nodes[i].w as f64,
                height: nodes[i].h as f64,
                ..Default::default()
            },
        );
    }
    for (n, (child, parent)) in edges(schema).enumerate() {
        // Upstream is the *referenced* table. A layered engine puts the source
        // of an edge in the earlier rank, so this is what makes a hub sit at
        // the left with its spokes fanning out, rather than the reverse.
        g.set_edge_named(
            id(parent).as_str(),
            id(child).as_str(),
            Some(format!("e{n}")),
            Some(EdgeLabel {
                weight: f64::from(hub_weight(degree[child], degree[parent])),
                minlen: 1,
                ..Default::default()
            }),
        );
    }

    // A layout failure is not worth losing the diagram over: the grid packer
    // below will lay every table out instead.
    dugong::layout(&mut g).ok()?;

    let mut bounds: Option<Rect> = None;
    for &i in connected {
        let Some(label) = g.node(&id(i)) else {
            continue;
        };
        let (Some(x), Some(y)) = (label.x, label.y) else {
            continue;
        };
        // dugong reports centres; everything downstream works in top-left.
        nodes[i].x = x as f32 - nodes[i].w / 2.0;
        nodes[i].y = y as f32 - nodes[i].h / 2.0;
        bounds = Some(match bounds {
            None => nodes[i],
            Some(b) => union(b, nodes[i]),
        });
    }
    bounds
}

fn id(index: usize) -> String {
    format!("t{index}")
}

/// Ported from sqltoerdiagram's `layout.js`: weight an edge by how much of a
/// hub its busier end is, capped so one enormous table cannot dominate every
/// ranking decision in the diagram.
fn hub_weight(from: usize, to: usize) -> i32 {
    1 + from.max(to).min(12) as i32
}

/// Lay unconnected tables out in a grid next to the graph. They carry no
/// ranking information, so giving them to the engine only stretches the canvas.
fn pack_beside(
    loose: &[usize],
    graph_box: Option<Rect>,
    direction: Direction,
    gap: f32,
    nodes: &mut [Rect],
) {
    if loose.is_empty() {
        return;
    }
    let vertical = direction == Direction::Vertical;
    // Aim for a block roughly as long as the graph, so the two sit side by side
    // instead of one trailing off the canvas.
    let extent: f32 = loose.iter().map(|&i| span(nodes[i], vertical) + gap).sum();
    let thickness: f32 = loose
        .iter()
        .map(|&i| span(nodes[i], !vertical) + gap)
        .sum::<f32>()
        / loose.len() as f32;
    // Same reasoning as `wrap_target`: `extent / x` columns, each `thickness`
    // across, should come out `TARGET_ASPECT` times wider than `x` is long.
    let own = (extent * thickness / TARGET_ASPECT).sqrt();
    // Match the graph's length when the graph is the longer of the two, so the
    // block sits beside it rather than hanging off the bottom.
    let target = match graph_box {
        Some(b) => span_of(b, vertical).max(own),
        None => own,
    }
    .max(
        loose
            .iter()
            .map(|&i| span(nodes[i], vertical))
            .fold(0.0, f32::max),
    );

    let origin = match (graph_box, vertical) {
        (Some(b), false) => (b.right() + gap * 2.0, b.y),
        (Some(b), true) => (b.x, b.bottom() + gap * 2.0),
        (None, _) => (0.0, 0.0),
    };

    let (mut along, mut across, mut band) = (0.0f32, 0.0f32, 0.0f32);
    for &i in loose {
        let (len, thick) = (span(nodes[i], vertical), span(nodes[i], !vertical));
        if along > 0.0 && along + len > target {
            across += band + gap;
            along = 0.0;
            band = 0.0;
        }
        if vertical {
            nodes[i].x = origin.0 + along;
            nodes[i].y = origin.1 + across;
        } else {
            nodes[i].x = origin.0 + across;
            nodes[i].y = origin.1 + along;
        }
        along += len + gap;
        band = band.max(thick);
    }
}

/// The node's extent along the packing axis.
fn span(r: Rect, vertical: bool) -> f32 {
    if vertical { r.w } else { r.h }
}

fn span_of(r: Rect, vertical: bool) -> f32 {
    if vertical { r.w } else { r.h }
}

fn union(a: Rect, b: Rect) -> Rect {
    let x = a.x.min(b.x);
    let y = a.y.min(b.y);
    Rect {
        x,
        y,
        w: a.right().max(b.right()) - x,
        h: a.bottom().max(b.bottom()) - y,
    }
}

/// Move the whole diagram so its top-left corner is the origin, and report its
/// size. Callers get coordinates they can put straight into a viewport.
fn normalise(nodes: &mut [Rect]) -> Layout {
    let Some(mut bounds) = nodes.first().copied() else {
        return Layout {
            nodes: Vec::new(),
            size: Size { w: 0.0, h: 0.0 },
        };
    };
    for n in nodes.iter() {
        bounds = union(bounds, *n);
    }
    for n in nodes.iter_mut() {
        n.x -= bounds.x;
        n.y -= bounds.y;
    }
    Layout {
        nodes: nodes.to_vec(),
        size: Size {
            w: bounds.w,
            h: bounds.h,
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sized(schema: &Schema) -> Vec<Size> {
        vec![Size { w: 160.0, h: 90.0 }; schema.tables.len()]
    }

    fn overlaps(a: Rect, b: Rect) -> bool {
        a.x < b.right() && b.x < a.right() && a.y < b.bottom() && b.y < a.bottom()
    }

    fn assert_no_overlaps(l: &Layout) {
        for i in 0..l.nodes.len() {
            for j in i + 1..l.nodes.len() {
                assert!(
                    !overlaps(l.nodes[i], l.nodes[j]),
                    "nodes {i} and {j} overlap"
                );
            }
        }
    }

    fn read_fixture(name: &str) -> String {
        std::fs::read_to_string(
            std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
                .join("../../fixtures")
                .join(name),
        )
        .unwrap()
    }

    fn chain(n: usize) -> String {
        let mut sql = String::new();
        for i in 0..n {
            sql.push_str(&format!(
                "CREATE TABLE t{i} (id int PRIMARY KEY, parent int"
            ));
            if i > 0 {
                sql.push_str(&format!(" REFERENCES t{} (id)", i - 1));
            }
            sql.push_str(");\n");
        }
        sql
    }

    #[test]
    fn an_empty_schema_lays_out_to_nothing() {
        let schema = draft_ddl::parse("");
        let l = layout(&schema, &[], &Options::default());
        assert!(l.nodes.is_empty());
        assert_eq!(l.size, Size { w: 0.0, h: 0.0 });
    }

    #[test]
    fn the_diagram_starts_at_the_origin() {
        let schema = draft_ddl::parse(&chain(12));
        let l = layout(&schema, &sized(&schema), &Options::default());
        assert_eq!(l.nodes.len(), 12);
        assert!(
            l.nodes.iter().any(|n| n.x == 0.0),
            "nothing touches the left edge"
        );
        assert!(
            l.nodes.iter().any(|n| n.y == 0.0),
            "nothing touches the top edge"
        );
        assert!(
            l.nodes.iter().all(|n| n.x >= 0.0 && n.y >= 0.0),
            "a node is off-canvas"
        );
        assert_no_overlaps(&l);
    }

    /// A chain is the one shape with an unambiguous answer, so it is the one
    /// case where we can assert the engine did the *right* thing rather than
    /// merely a self-consistent thing.
    #[test]
    fn a_chain_lays_out_in_order_along_the_rank_axis() {
        let schema = draft_ddl::parse(&chain(8));
        let sizes = sized(&schema);

        let h = layout(
            &schema,
            &sizes,
            &Options {
                direction: Direction::Horizontal,
                ..Default::default()
            },
        );
        for i in 1..8 {
            assert!(
                h.nodes[i].x > h.nodes[i - 1].x,
                "t{i} is not right of t{}",
                i - 1
            );
        }

        let v = layout(
            &schema,
            &sizes,
            &Options {
                direction: Direction::Vertical,
                ..Default::default()
            },
        );
        for i in 1..8 {
            assert!(
                v.nodes[i].y > v.nodes[i - 1].y,
                "t{i} is not below t{}",
                i - 1
            );
        }
        assert!(
            v.size.h > h.size.h && h.size.w > v.size.w,
            "direction had no effect"
        );
    }

    #[test]
    fn unconnected_tables_are_packed_beside_the_graph_not_through_it() {
        let mut sql = chain(6);
        for i in 0..9 {
            sql.push_str(&format!("CREATE TABLE loose{i} (id int);\n"));
        }
        let schema = draft_ddl::parse(&sql);
        let l = layout(&schema, &sized(&schema), &Options::default());
        assert_no_overlaps(&l);

        let graph_right = l.nodes[..6]
            .iter()
            .map(|n| n.right())
            .fold(0.0f32, f32::max);
        assert!(
            l.nodes[6..].iter().all(|n| n.x >= graph_right),
            "a loose table landed inside the graph"
        );
    }

    #[test]
    fn spacing_changes_the_diagram_and_nothing_else() {
        let schema = draft_ddl::parse(&chain(10));
        let sizes = sized(&schema);
        let of = |s| {
            layout(
                &schema,
                &sizes,
                &Options {
                    spacing: s,
                    ..Default::default()
                },
            )
        };
        let (compact, comfortable, spacious) = (
            of(Spacing::Compact),
            of(Spacing::Comfortable),
            of(Spacing::Spacious),
        );
        assert!(compact.size.w < comfortable.size.w);
        assert!(comfortable.size.w < spacious.size.w);
        assert_eq!(compact.nodes.len(), spacious.nodes.len());
    }

    /// The defect Phase 0 found and this crate now corrects. A layered engine
    /// answers a real ER schema with a ribbon — measured aspect 0.18 on this
    /// fixture before wrapping — which is unreadable and unpannable. The bound
    /// is deliberately loose: the point is that the diagram has a shape a
    /// screen can hold, not that it hits a particular number.
    #[test]
    fn a_wide_schema_is_folded_into_something_screen_shaped() {
        let schema = draft_ddl::parse(&read_fixture("synthetic_300.sql"));
        let sizes = sized(&schema);
        let l = layout(&schema, &sizes, &Options::default());
        let aspect = l.size.w / l.size.h;
        assert!(
            (0.5..=6.0).contains(&aspect),
            "aspect {aspect:.2} ({} x {}) is still a ribbon",
            l.size.w,
            l.size.h
        );
        assert_no_overlaps(&l);
    }

    /// Wrapping must not scramble the reading order it is folding: within a
    /// rank, nodes keep the order the engine gave them, and ranks keep theirs.
    #[test]
    fn wrapping_preserves_rank_order() {
        let schema = draft_ddl::parse(&chain(40));
        let sizes = vec![Size { w: 160.0, h: 900.0 }; schema.tables.len()];
        let l = layout(&schema, &sizes, &Options::default());
        for i in 1..40 {
            assert!(
                l.nodes[i].x >= l.nodes[i - 1].x,
                "t{i} moved upstream of t{}",
                i - 1
            );
        }
        assert_no_overlaps(&l);
    }

    /// NFR: lay out 300 tables in under 500 ms.
    ///
    /// The engine runs on the UI thread whenever the schema changes, so this is
    /// a budget the user feels directly rather than a throughput figure. Best of
    /// several runs for the same reason the parser's budget test takes the best:
    /// `cargo test` runs in parallel, and a single timing taken while the rest
    /// of the suite competes for the CPU reads several times slower than the
    /// same code measured alone. Only the release number is the real gate.
    #[test]
    fn layout_stays_within_the_time_budget() {
        let schema = draft_ddl::parse(&read_fixture("synthetic_300.sql"));
        let sizes = sized(&schema);
        assert_eq!(schema.tables.len(), 300);

        let mut best = f64::INFINITY;
        for _ in 0..5 {
            let start = std::time::Instant::now();
            let l = layout(&schema, &sizes, &Options::default());
            best = best.min(start.elapsed().as_secs_f64() * 1000.0);
            assert_eq!(l.nodes.len(), 300);
        }

        let budget = if cfg!(debug_assertions) {
            6000.0
        } else {
            500.0
        };
        assert!(
            best < budget,
            "laid out 300 tables in {best:.1} ms, budget {budget} ms"
        );
        eprintln!("layout: {best:.2} ms for 300 tables");
    }

    /// Layout has to be a pure function of its input. A diagram that reshuffles
    /// itself between runs would make every golden test and every user's mental
    /// map worthless.
    #[test]
    fn layout_is_deterministic() {
        let schema = draft_ddl::parse(
            &std::fs::read_to_string(
                std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
                    .join("../../fixtures/small_20.sql"),
            )
            .unwrap(),
        );
        let sizes = sized(&schema);
        let first = layout(&schema, &sizes, &Options::default());
        for _ in 0..4 {
            assert_eq!(
                layout(&schema, &sizes, &Options::default()).nodes,
                first.nodes
            );
        }
        assert_no_overlaps(&first);
    }
}
