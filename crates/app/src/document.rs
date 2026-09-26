//! One schema on screen: the SQL text, and everything derived from it.
//!
//! Parsing and layout are rebuilt rather than patched: keeping spans and
//! positions incrementally correct costs more to maintain than either stage
//! costs to redo — see docs/architecture.md D2.
//!
//! Measuring is the exception, because it is a pure function of a table's own
//! text and so needs no invalidation logic to be correct. It was a third of the
//! re-parse before [`draft_view::Sizes`] existed; see D10.

use draft_ddl::{Dialect, Schema};
use draft_layout::{Layout, Options, Placement, Size};
use draft_view::{Sizes, TextStyles};
use egui::epaint::FontsView;
use egui::{Pos2, Rect, Vec2};
use web_time::Instant;

use crate::annotate::Annotations;

/// Where the time went re-deriving the diagram, in milliseconds.
///
/// The debounced re-parse is the one frame in a burst of typing that can miss
/// its deadline, and a single total for it would not say which of three stages
/// to go and fix. Reported by the `type` measurement run.
#[derive(Clone, Copy, Default)]
pub struct Cost {
    pub parse: f32,
    pub measure: f32,
    pub layout: f32,
}

fn ms(since: Instant) -> f32 {
    since.elapsed().as_secs_f32() * 1000.0
}

pub struct Document {
    /// What this schema is called in the status bar: a file name, or where the
    /// text came from.
    pub name: String,
    pub sql: String,
    pub schema: Schema,
    pub sizes: Vec<Size>,
    /// The measurement cache behind `sizes`. Carried on the document because
    /// it is only useful across re-parses of the same document.
    measurer: Sizes,
    pub layout: Layout,
    /// Where the tables actually are, which outlives any one parse of the SQL.
    pub placement: Placement,
    /// Sticky notes and group boxes. Part of the diagram, no part of the
    /// schema — the SQL never knows they exist.
    pub annotations: Annotations,
    /// The diagram no longer matches the text, because the text currently
    /// parses to nothing and the last good diagram was kept instead.
    pub stale: bool,
    /// What the script looks like, re-derived with every parse this shows.
    /// `None` when the text commits to no dialect.
    detected_dialect: Option<Dialect>,
    /// What someone said it actually is, overriding the guess. Carried by the
    /// project, because the guess is derived from the SQL and a correction is
    /// the only part of the answer that would otherwise be lost.
    pub dialect_pin: Option<Dialect>,
}

impl Document {
    /// Parse, and nothing more.
    ///
    /// Measuring needs fonts, and fonts do not exist until egui has run a pass,
    /// so a document created during start-up has no geometry yet. Laying out
    /// with fallback sizes to fill the gap would cost a full layout of a
    /// diagram nobody will ever see; an empty one is honest and free.
    pub fn new(name: impl Into<String>, sql: impl Into<String>) -> Self {
        let sql = sql.into();
        let schema = draft_ddl::parse(&sql);
        let detected_dialect = draft_ddl::detect(&sql);
        Self {
            name: name.into(),
            sql,
            schema,
            sizes: Vec::new(),
            measurer: Sizes::default(),
            placement: Placement::default(),
            annotations: Annotations::default(),
            layout: Layout {
                nodes: Vec::new(),
                size: Size { w: 0.0, h: 0.0 },
            },
            stale: false,
            detected_dialect,
            dialect_pin: None,
        }
    }

    /// Which dialect this is, as far as anyone knows: what somebody pinned, or
    /// failing that what the script looks like.
    pub fn dialect(&self) -> Option<Dialect> {
        self.dialect_pin.or(self.detected_dialect)
    }

    /// What the script looks like, whatever is pinned over it. The status bar
    /// needs both to be able to say "pinned, and it looks like something else".
    pub fn detected_dialect(&self) -> Option<Dialect> {
        self.detected_dialect
    }

    /// Measure every table and place it. Must run before the first draw.
    pub fn measure(
        &mut self,
        fonts: &mut FontsView<'_>,
        styles: &TextStyles,
        options: &Options,
    ) -> Cost {
        let started = Instant::now();
        self.sizes = self.measurer.measure(&self.schema, fonts, styles);
        let measure = ms(started);
        let placing = Instant::now();
        self.layout = self.placement.arrange(&self.schema, &self.sizes, options);
        Cost {
            parse: 0.0,
            measure,
            layout: ms(placing),
        }
    }

    /// Re-derive the diagram from the current SQL. `None` when the text
    /// currently says nothing and the last good diagram was kept instead.
    pub fn reparse(
        &mut self,
        fonts: &mut FontsView<'_>,
        styles: &TextStyles,
        options: &Options,
    ) -> Option<Cost> {
        let started = Instant::now();
        let schema = draft_ddl::parse(&self.sql);
        let parse = ms(started);
        if !worth_showing(&schema, &self.schema) {
            self.stale = true;
            return None;
        }
        self.schema = schema;
        self.stale = false;
        // Re-derived only when the fresh parse is the one being shown, for the
        // same reason the diagram is: halfway through typing a statement the
        // text says less than it did, and a label that blinked out and back on
        // every keystroke would be worse than a label that lags one edit.
        self.detected_dialect = draft_ddl::detect(&self.sql);
        Some(Cost {
            parse,
            ..self.measure(fonts, styles, options)
        })
    }

    /// Hand the diagram back to the layout engine, discarding every position
    /// anyone has chosen. What the Arrange button means, and what changing the
    /// direction or spacing has to do — those options describe an arrangement,
    /// and honouring them while keeping the old positions would make them do
    /// nothing. Measurements do not depend on layout options, so they are kept.
    pub fn relayout(&mut self, options: &Options) {
        self.placement.reset();
        self.layout = self.placement.arrange(&self.schema, &self.sizes, options);
    }

    /// Move one table, and remember it there.
    pub fn move_table(&mut self, index: usize, to: Pos2) {
        if let Some(node) = self.layout.nodes.get_mut(index) {
            node.x = to.x;
            node.y = to.y;
        }
        self.placement
            .set(index, draft_layout::Pos::new(to.x, to.y));
    }

    /// The whole diagram, annotations included. The union of the boxes rather
    /// than the engine's reported size, because a dragged table can sit
    /// anywhere — including at negative coordinates, where an origin-anchored
    /// box would not find it.
    pub fn bounds(&self) -> Rect {
        let mut bounds: Option<Rect> = self.annotations.bounds();
        for i in 0..self.layout.nodes.len() {
            if let Some(rect) = self.table_rect(i) {
                bounds = Some(bounds.map_or(rect, |b: Rect| b.union(rect)));
            }
        }
        bounds.unwrap_or_else(|| Rect::from_min_size(Pos2::ZERO, Vec2::ZERO))
    }

    pub fn table_rect(&self, index: usize) -> Option<Rect> {
        self.layout
            .nodes
            .get(index)
            .map(|r| Rect::from_min_size(Pos2::new(r.x, r.y), Vec2::new(r.w, r.h)))
    }

    pub fn dangling(&self) -> usize {
        self.schema
            .relations
            .iter()
            .filter(|r| r.to_missing)
            .count()
    }
}

/// Whether a fresh parse is worth putting on screen.
///
/// Halfway through deleting or typing a statement the text defines no table,
/// and replacing a diagram with an empty canvas on the way to a valid edit is
/// the single most irritating thing a live editor can do. The text stays the
/// source of truth; the diagram is simply its last projection that said
/// anything.
///
/// Deliberately not "did it parse cleanly": this parser is tolerant and reports
/// warnings rather than failing, so "has at least one table" is the only signal
/// that distinguishes a schema mid-edit from a schema that is genuinely gone.
fn worth_showing(fresh: &Schema, current: &Schema) -> bool {
    !fresh.tables.is_empty() || current.tables.is_empty()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Every intermediate state of typing or deleting a statement must keep the
    /// last good diagram. This walks real prefixes through the real parser
    /// rather than asserting on a hand-picked one, because the states that
    /// blank a diagram are exactly the ones nobody thinks to pick.
    #[test]
    fn no_prefix_of_an_edit_ever_blanks_a_good_diagram() {
        const TEXT: &str = "CREATE TABLE orders (\n  id bigint PRIMARY KEY,\n  \
                            customer_id bigint REFERENCES customers(id)\n);\n";
        let good = draft_ddl::parse(
            "CREATE TABLE customers (id bigint PRIMARY KEY);\n\
             CREATE TABLE orders (id bigint PRIMARY KEY);\n",
        );
        assert_eq!(good.tables.len(), 2);

        for cut in 0..=TEXT.len() {
            let fresh = draft_ddl::parse(&TEXT[..cut]);
            assert_eq!(
                worth_showing(&fresh, &good),
                !fresh.tables.is_empty(),
                "at byte {cut} the diagram would have been replaced by {} tables",
                fresh.tables.len()
            );
        }
    }

    /// The converse, and the reason the rule is not simply "never show an empty
    /// schema": an empty document on a fresh start has to be allowed through,
    /// or the application opens permanently stale.
    #[test]
    fn an_empty_document_is_showable_when_there_is_nothing_to_keep() {
        let nothing = draft_ddl::parse("");
        assert!(worth_showing(&nothing, &nothing));
    }
}
