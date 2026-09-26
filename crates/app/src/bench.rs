//! The frame-cost gates, run against the shipping renderer.
//!
//! Phase 0 measured a spike; these measure the product. Two runs, because the
//! two budgets are about different work:
//!
//! - `canvas` sweeps the camera deterministically from "reading one table" to
//!   "the whole schema framed", so every zoom level and every LOD bucket is
//!   visited exactly once and the worst case is reached rather than hoped for.
//! - `type` types into the editor, which is dominated by egui laying out the
//!   whole document and by the debounced re-parse behind it.
//!
//! Native: `draft-app --bench canvas 1000 600`
//! Web:    `index.html#bench=canvas,1000,600` — the result goes to the console
//!         with a `RESULT ` prefix, which is what `web/bench.mjs` scrapes.

use egui::Rect;

use crate::app::MIRROR_DELAY;
use crate::camera::{Camera, MAX_ZOOM, MIN_ZOOM};
use crate::canvas::Counts;
use crate::document::Cost;
use crate::stats::Stats;

pub struct CanvasBench {
    tables: usize,
    total: usize,
    left: usize,
    stats: Stats,
    peak_visible: usize,
    peak_shapes: usize,
    pub finished: Option<String>,
}

impl CanvasBench {
    pub fn new(tables: usize, frames: usize) -> Self {
        let frames = frames.max(1);
        Self {
            tables,
            total: frames,
            left: frames,
            // A generous window: the run is a few hundred frames and every one
            // of them belongs in the percentiles.
            stats: Stats::new(frames, 30),
            peak_visible: 0,
            peak_shapes: 0,
            finished: None,
        }
    }

    /// Advance one frame. `cpu_ms` is the *previous* frame's cost, which is the
    /// only honest number available: it includes tessellation, and unlike
    /// wall-clock frame time it does not count waiting for vsync.
    pub fn tick(
        &mut self,
        camera: &mut Camera,
        view: Rect,
        world: Rect,
        cpu_ms: Option<f32>,
        counts: Counts,
    ) {
        if self.finished.is_some() {
            return;
        }
        if let Some(ms) = cpu_ms {
            self.stats.push(ms);
        }
        self.peak_visible = self.peak_visible.max(counts.visible);
        self.peak_shapes = self.peak_shapes.max(counts.shapes);

        let progress = 1.0 - self.left as f32 / self.total as f32;
        let fit = (view.width() / world.width().max(1.0))
            .min(view.height() / world.height().max(1.0))
            * 0.98;
        camera.zoom = (1.2 * (1.0 - progress) + fit * progress).clamp(MIN_ZOOM, MAX_ZOOM);
        // Orbit around the middle so the framing stays centred as the zoom
        // pulls back, and so panning is exercised alongside zooming.
        let t = progress * 12.0;
        let drift = egui::Vec2::new(
            t.sin() * world.width() * 0.10,
            (t * 0.8).cos() * world.height() * 0.10,
        );
        camera.look_at(world.center() + drift, view);

        self.left = self.left.saturating_sub(1);
        if self.left == 0 {
            self.finished = Some(format!(
                "canvas {:>5} tables  view {:.0}x{:.0}  peak visible {:>5}  peak shapes {:>6}  {}",
                self.tables,
                view.width(),
                view.height(),
                self.peak_visible,
                self.peak_shapes,
                self.stats.summary(),
            ));
        }
    }
}

/// Keystrokes in one burst, and how long the pause after it lasts.
///
/// A keystroke on every frame is the worst case for the editor, and it is what
/// S2 measured — but on its own it never lets the debounce fire, so it would
/// report that typing is cheap while hiding the re-parse entirely. Half a
/// second of typing and then a pause long enough for the debounce to land
/// exercises both, and is roughly what typing actually looks like.
const BURST: usize = 30;
/// The pause has to outlast the longest thing that hangs off it, or that thing
/// never happens during a run and the report says it costs nothing. That used to
/// be the re-parse debounce; it is now the page's text mirror, two frames of
/// margin past its deadline.
const PAUSE: f64 = MIRROR_DELAY + 2.0 / 60.0;

/// What a frame was asked to do, for attributing its cost.
///
/// `cpu_usage` reports the *previous* frame, and a keystroke injected at the
/// end of frame N is not laid out until frame N + 1 — so the attribution runs
/// two frames behind the decision and has to be pipelined, or the burst
/// boundaries get credited to the wrong bucket.
#[derive(Clone, Copy)]
enum Attr {
    Idle,
    Typing,
    /// A re-parse, re-measure and re-layout all landed on this frame.
    Settle,
}

pub struct TypingBench {
    kb: usize,
    left: usize,
    /// Cost of the frames that laid out a keystroke.
    typing: Stats,
    /// Cost of the frames the debounce fired on. Kept apart because one in
    /// thirty frames being expensive is a different fact from every frame
    /// being expensive, and averaging them together hides both.
    settle: Stats,
    /// The three stages inside a settle frame, so the report says which one to
    /// go and fix rather than only that one of them is slow.
    parse: Stats,
    remeasure: Stats,
    relayout: Stats,
    /// Writing the schema into the page, which is deliberately *not* on a
    /// settle frame and so would otherwise be measured by nothing: its frames
    /// are idle ones, and idle frames are not attributed to any bucket.
    mirror: Stats,
    /// Attribution of the frame `cpu_ms` is reporting, and of the one being
    /// drawn right now.
    reported: Attr,
    drawing: Attr,
    typed: usize,
    paused_since: Option<f64>,
    /// Alternate insert and remove so the document length — and therefore the
    /// cost of laying it out — stays constant over a long run.
    inserted: bool,
    at: usize,
    pub finished: Option<String>,
}

impl TypingBench {
    pub fn new(kb: usize, frames: usize) -> Self {
        let frames = frames.max(1);
        Self {
            kb,
            left: frames,
            typing: Stats::new(frames, 20),
            // The first settle also builds every shape cache from nothing,
            // which is a load, not a keystroke.
            settle: Stats::new(frames, 1),
            parse: Stats::new(frames, 1),
            remeasure: Stats::new(frames, 1),
            relayout: Stats::new(frames, 1),
            mirror: Stats::new(frames, 1),
            reported: Attr::Idle,
            drawing: Attr::Idle,
            typed: 0,
            paused_since: None,
            inserted: false,
            at: 0,
            finished: None,
        }
    }

    /// Advance one frame. Returns true if a keystroke was injected, which the
    /// caller turns into the same "the text changed" signal a real one would.
    ///
    /// `settled` is the re-parse the debounce fired during *this* frame, which
    /// the caller knows and this does not: the pause is timed to make it
    /// happen, but nothing here forces it. If the debounce were broken the
    /// settle bucket would come back empty rather than come back wrong.
    pub fn tick(
        &mut self,
        sql: &mut String,
        now: f64,
        cpu_ms: Option<f32>,
        settled: Option<Cost>,
        mirrored: Option<f32>,
    ) -> bool {
        if self.finished.is_some() {
            return false;
        }
        if let Some(ms) = mirrored {
            self.mirror.push(ms);
        }
        if let Some(cost) = settled {
            self.drawing = Attr::Settle;
            self.parse.push(cost.parse);
            self.remeasure.push(cost.measure);
            self.relayout.push(cost.layout);
        }
        if let Some(ms) = cpu_ms {
            match self.reported {
                Attr::Settle => self.settle.push(ms),
                Attr::Typing => self.typing.push(ms),
                Attr::Idle => {}
            }
        }

        let typing = match self.paused_since {
            Some(at) if now - at < PAUSE => false,
            Some(_) => {
                self.paused_since = None;
                self.typed = 0;
                true
            }
            None => true,
        };
        if typing {
            self.keystroke(sql);
            self.typed += 1;
            if self.typed >= BURST {
                self.paused_since = Some(now);
            }
        }

        self.reported = self.drawing;
        self.drawing = if typing { Attr::Typing } else { Attr::Idle };

        self.left = self.left.saturating_sub(1);
        if self.left == 0 {
            self.finished = Some(format!(
                "editor {:>4} KB  typing {}  settle n={} p50={:.2}ms max={:.2}ms \
                 [parse {:.2} measure {:.2} layout {:.2}]  mirror n={} p50={:.2}ms max={:.2}ms",
                self.kb,
                self.typing.summary(),
                self.settle.len(),
                self.settle.percentile(0.50),
                self.settle.percentile(1.00),
                self.parse.percentile(0.50),
                self.remeasure.percentile(0.50),
                self.relayout.percentile(0.50),
                self.mirror.len(),
                self.mirror.percentile(0.50),
                self.mirror.percentile(1.00),
            ));
        }
        typing
    }

    /// Edit near the top of the document: everything after the caret may have
    /// to move, so it is the worst case for both the layout and the parser.
    fn keystroke(&mut self, sql: &mut String) {
        if self.at == 0 || self.at >= sql.len() {
            self.at = floor_char_boundary(sql, sql.len().min(200));
        }
        if self.inserted {
            sql.remove(self.at);
        } else {
            sql.insert(self.at, 'x');
        }
        self.inserted = !self.inserted;
    }
}

/// `String::insert` and `remove` panic on a non-boundary index, and nothing
/// guarantees an arbitrary offset into a schema is one.
fn floor_char_boundary(s: &str, mut i: usize) -> usize {
    while i > 0 && !s.is_char_boundary(i) {
        i -= 1;
    }
    i
}

/// A schema of roughly `kb` kilobytes, for measuring the editor rather than the
/// canvas.
///
/// Measure the generator rather than assume a bytes-per-table constant: the
/// column count is random, so the constant would drift with any change to the
/// generator and quietly stop measuring the size it claims to.
pub fn synthetic_sql_of_size(kb: usize) -> String {
    const PROBE: usize = 64;
    let per_table = (synthetic_sql(PROBE).len() / PROBE).max(1);
    synthetic_sql((kb * 1024 / per_table).max(1))
}

/// A schema of `tables` tables, generated rather than embedded.
///
/// Embedding the 106 KB and 396 KB fixtures would put them in the shipped wasm
/// payload, which is the one number this application is not allowed to spend
/// freely. Generating costs a few hundred bytes of code and still feeds the
/// real parser, the real layout and the real renderer.
pub fn synthetic_sql(tables: usize) -> String {
    const TYPES: [&str; 6] = [
        "bigint",
        "text",
        "varchar(255)",
        "timestamptz",
        "boolean",
        "numeric(12,2)",
    ];
    let mut seed = 0x2545_F491_4F6C_DD1Du64;
    let mut rand = move || {
        seed ^= seed << 13;
        seed ^= seed >> 7;
        seed ^= seed << 17;
        (seed >> 11) as f32 / (1u64 << 53) as f32
    };

    let mut sql = String::with_capacity(tables * 220);
    for i in 0..tables {
        sql.push_str(&format!(
            "CREATE TABLE table_{i} (\n  id bigint PRIMARY KEY"
        ));
        let columns = 3 + (rand() * 11.0) as usize;
        for c in 0..columns {
            let ty = TYPES[(rand() * TYPES.len() as f32) as usize % TYPES.len()];
            sql.push_str(&format!(",\n  column_name_{c} {ty}"));
        }
        // Reference an earlier table so the layered layout has ranks to build,
        // and give the low-numbered tables more of the references so the result
        // has hubs like a real schema does.
        if i > 0 {
            let target = (rand().powi(3) * i as f32) as usize;
            sql.push_str(&format!(
                ",\n  table_{target}_id bigint REFERENCES table_{target}(id)"
            ));
        }
        sql.push_str("\n);\n\n");
    }
    sql
}

#[cfg(test)]
mod tests {
    use super::*;
    // Only the harness needs it now that the pause is timed off the mirror.
    use crate::editor::DEBOUNCE;

    #[test]
    fn the_generated_schema_is_what_it_claims_to_be() {
        let schema = draft_ddl::parse(&synthetic_sql(200));
        assert_eq!(schema.tables.len(), 200);
        assert!(schema.warnings.is_empty(), "{:?}", schema.warnings);
        assert_eq!(schema.relations.len(), 199);
        assert_eq!(
            schema.relations.iter().filter(|r| r.to_missing).count(),
            0,
            "a generated reference pointed at a table that does not exist"
        );
    }

    #[test]
    fn a_bench_run_ends_and_reports() {
        let view = Rect::from_min_size(egui::Pos2::ZERO, egui::Vec2::new(1400.0, 900.0));
        let world = Rect::from_min_size(egui::Pos2::ZERO, egui::Vec2::new(20_000.0, 8_000.0));
        let mut bench = CanvasBench::new(1000, 50);
        let mut camera = Camera::default();
        for _ in 0..50 {
            bench.tick(&mut camera, view, world, Some(4.0), Counts::default());
        }
        let line = bench.finished.expect("the run should have finished");
        assert!(line.contains("1000 tables"), "{line}");
        assert!(line.contains("p95=4.00ms"), "{line}");
        assert!(
            camera.zoom < 0.12,
            "the sweep must end with the whole diagram framed, got {}",
            camera.zoom
        );
    }

    #[test]
    fn the_editor_fixture_is_the_size_it_says_it_is() {
        let sql = synthetic_sql_of_size(106);
        let kb = sql.len() as f32 / 1024.0;
        assert!(
            (100.0..112.0).contains(&kb),
            "asked for 106 KB, generated {kb:.1} KB"
        );
        assert!(draft_ddl::parse(&sql).warnings.is_empty());
    }

    /// The whole point of the typing run is that it measures two different
    /// things: the per-keystroke cost, and the re-parse the debounce defers. A
    /// run that reported one number for both would pass the gate by averaging
    /// a spike away.
    #[test]
    fn typing_and_settling_are_measured_separately() {
        let mut sql = synthetic_sql(20);
        let length = sql.len();
        let mut bench = TypingBench::new(1, 400);

        // 60 fps, and a re-parse on the first frame after each pause has run
        // longer than the debounce — which is what the real app does.
        let mut now = 0.0_f64;
        let mut idle_since: Option<f64> = None;
        // `cpu_usage` reports the frame before, so the harness has to hand back
        // the previous frame's cost — feeding it the current one would let a
        // broken pipeline pass.
        let mut previous = 2.0;
        for frame in 0..400 {
            let reparsed = idle_since.is_some_and(|at| now - at >= DEBOUNCE);
            if reparsed {
                idle_since = None;
            }
            let settled = reparsed.then_some(Cost {
                parse: 1.0,
                measure: 2.0,
                layout: 3.0,
            });
            // Two mirror writes, on idle frames, as the debounce arranges: the
            // bucket exists precisely because no other bucket would have taken
            // them. The first is deliberately absurd, because the first write
            // of the run is a cold one — an empty element and a cold allocator
            // — and is dropped as warm-up like every other stage's.
            let mirrored = match frame {
                100 => Some(99.0),
                200 => Some(12.5),
                _ => None,
            };
            let typed = bench.tick(&mut sql, now, Some(previous), settled, mirrored);
            if typed {
                idle_since = Some(now);
            }
            // Settling is the expensive frame; typing is the cheap one.
            previous = if reparsed { 9.0 } else { 2.0 };
            now += 1.0 / 60.0;
        }

        let line = bench.finished.expect("the run should have finished");
        assert!(line.contains("p95=2.00ms"), "typing cost polluted: {line}");
        assert!(
            !line.contains("settle n=0"),
            "the pause never let the debounce fire: {line}"
        );
        assert!(line.contains("max=9.00ms"), "settle cost lost: {line}");
        assert!(
            line.contains("mirror n=1 p50=12.50ms"),
            "the page's text mirror went unmeasured: {line}"
        );
        assert!(
            !line.contains("99.00"),
            "the cold first write was counted: {line}"
        );
        assert!(
            sql.len().abs_diff(length) <= 1,
            "the document grew from {length} to {} — the run would end up measuring a much \
             longer document than it started with",
            sql.len()
        );
    }
}
