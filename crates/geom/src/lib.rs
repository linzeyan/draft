//! How big a table box is, what goes in its rows, and where the edges between
//! boxes run.
//!
//! Split out of `view` for [D19](../../../docs/architecture.md#d19--the-dom-front-end-is-the-plan):
//! the diagram's arithmetic has to be callable by two renderers that measure
//! text with different engines — epaint for the GUI and the CLI, the browser's
//! own `measureText` for the DOM front end — and the only way both can agree to
//! within a tenth of a pixel is for the arithmetic to exist once.
//!
//! So text measurement is *injected* here rather than performed. [`Measure`]
//! takes widths and answers with a size; it never asks what font anything is in.
//! That is also what lets the typefaces stay out of the front end's wasm.

use draft_ddl::{Cardinality, Column, Index, Table};
use draft_layout::{Rect, Size};

/// Table box metrics, in points. These match sqltoerdiagram's `measureTable()`
/// so the fixtures generated against it stay comparable — the Phase 0 layout
/// numbers in `docs/measurements.md` were taken with exactly these.
pub const PAD_X: f32 = 12.0;
pub const GAP: f32 = 14.0;
pub const BADGE_W: f32 = 30.0;
pub const MIN_W: f32 = 140.0;
pub const MAX_W: f32 = 360.0;
pub const ROW_H: f32 = 26.0;
pub const HEADER_H: f32 = 34.0;

/// One index row, and the rule above the first of them. Shorter than a column
/// row on purpose: an index is secondary information, and a table with six of
/// them should not double in height because of it.
pub const INDEX_H: f32 = 19.0;
pub const INDEX_SEP: f32 = 6.0;

/// How much of a table to draw.
///
/// A legibility feature before it is a performance one: below a certain zoom
/// the column text is a grey smear, and a header or a solid block says more.
/// That it also collapses a thousand tables into a thousand rectangles — or a
/// thousand `<rect>`s — is the second reason, not the first.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Lod {
    /// Name, columns, types and badges.
    Full,
    /// Name only.
    Header,
    /// A solid rectangle.
    Block,
}

impl Lod {
    /// The detail worth drawing at this zoom. The thresholds are where the text
    /// stops being readable, not where the frame budget runs out.
    pub fn for_zoom(zoom: f32) -> Self {
        match zoom {
            z if z >= 0.45 => Self::Full,
            z if z >= 0.18 => Self::Header,
            _ => Self::Block,
        }
    }

    /// The name the DOM front end knows this by, which is also its CSS class.
    pub fn name(self) -> &'static str {
        match self {
            Self::Full => "full",
            Self::Header => "header",
            Self::Block => "block",
        }
    }
}

/// A table box being sized, one measured row at a time.
///
/// A builder rather than a struct of vectors because the caller that matters is
/// a re-parse of a 300-table script, and two allocations per table to hand over
/// numbers that are consumed immediately would be a cost with nothing to show
/// for it. Both renderers drive it in the same order, which is what makes them
/// comparable.
pub struct Measure {
    width: f32,
    columns: usize,
    indexes: usize,
}

impl Measure {
    /// Start from the table's name: it is the one row that is always there.
    pub fn table(header: f32) -> Self {
        Self {
            width: PAD_X * 2.0 + header,
            columns: 0,
            indexes: 0,
        }
    }

    /// A column row: the name on the left, the type on the right, and the
    /// fixed-width badge column beyond it.
    pub fn column(&mut self, name: f32, ty: f32) -> &mut Self {
        self.width = self.width.max(PAD_X * 2.0 + name + GAP + ty + BADGE_W);
        self.columns += 1;
        self
    }

    /// An index row, whose two halves come from [`index_row`].
    pub fn index(&mut self, left: f32, right: f32) -> &mut Self {
        self.width = self.width.max(PAD_X * 2.0 + left + GAP + right + BADGE_W);
        self.indexes += 1;
        self
    }

    /// The box, clamped: a one-column table still has to look like a table, and
    /// a `varchar(255) NOT NULL DEFAULT …` must not be allowed to stretch one
    /// box across the diagram. What overflows is elided by whoever draws it.
    pub fn size(&self) -> Size {
        Size {
            w: self.width.clamp(MIN_W, MAX_W),
            h: HEADER_H + ROW_H * self.columns as f32 + self.index_block(),
        }
    }

    /// How much taller the box is for having indexes. Zero for the majority
    /// that declare none, which is why the separator is inside the measurement
    /// rather than always present.
    fn index_block(&self) -> f32 {
        if self.indexes == 0 {
            0.0
        } else {
            INDEX_SEP + INDEX_H * self.indexes as f32
        }
    }
}

/// The two halves of an index row: what it is called, and what it covers.
///
/// An unnamed `KEY (a, b)` has only one thing to say, so its columns move into
/// the name's place rather than leaving a blank where a name would be.
pub fn index_row(index: &Index) -> (String, String) {
    let columns = format!("({})", index.columns.join(", "));
    match &index.name {
        Some(name) => (name.clone(), columns),
        None => (columns, String::new()),
    }
}

/// The badge for a column: at most one, in order of how much it tells you.
pub fn badge(column: &Column) -> Option<&'static str> {
    match () {
        _ if column.pk => Some("PK"),
        _ if column.fk => Some("FK"),
        _ if column.unique => Some("UQ"),
        _ => None,
    }
}

/// How far from a table a relationship's cardinality marker sits, and how far
/// it reaches across the edge.
pub const MARK_LEN: f32 = 9.0;
pub const MARK_HALF: f32 = 4.5;

/// How far a reference to a table that is not on the diagram reaches before it
/// stops. Long enough to read as an edge going somewhere, short enough that it
/// cannot be mistaken for one that arrives.
pub const STUB_LEN: f32 = 28.0;

/// A point in world space.
///
/// Its own type because this crate has no epaint in it, and not a `(f32, f32)`
/// because these come in fours and a tuple would not say which one is which.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Pos {
    pub x: f32,
    pub y: f32,
}

impl Pos {
    pub fn new(x: f32, y: f32) -> Self {
        Self { x, y }
    }
}

/// The cardinality mark at one end of an edge: one segment or two.
///
/// A fixed array and a length rather than a `Vec`, because the caller that
/// matters rebuilds every edge when a box moves, and two marks per edge is not
/// worth an allocation.
#[derive(Clone, Copy, Debug)]
pub struct Marks {
    segments: [[Pos; 2]; 2],
    len: usize,
}

impl Marks {
    pub fn segments(&self) -> &[[Pos; 2]] {
        &self.segments[..self.len]
    }
}

/// The line an edge follows.
#[derive(Clone, Copy, Debug)]
pub enum Path {
    /// Both ends are on the diagram: a cubic leaving each box sideways, so the
    /// edge meets the boxes at a right angle and bends in between.
    Curve([Pos; 4]),
    /// The far end is not on the diagram, so there is nothing to bend towards.
    Stub([Pos; 2]),
}

/// One relationship, routed.
#[derive(Clone, Copy, Debug)]
pub struct Route {
    pub path: Path,
    /// The mark at the referencing end, which says how many rows.
    pub start: Marks,
    /// The mark at the referenced end. Absent exactly when [`Path::Stub`] is,
    /// because a stub has no far end to mark.
    pub end: Option<Marks>,
}

/// Where an edge should meet a table: the row of the named column, or the
/// header if the reference does not name one.
pub fn anchor_y(table: &Table, rect: Rect, column: Option<&String>) -> f32 {
    let row = column.and_then(|c| {
        table
            .columns
            .iter()
            .position(|x| x.name.eq_ignore_ascii_case(c))
    });
    match row {
        Some(i) => rect.y + HEADER_H + ROW_H * (i as f32 + 0.5),
        None => rect.y + HEADER_H / 2.0,
    }
}

/// Route one relationship between two placed boxes, or off the side of one.
///
/// Points only: the caller decides what a line is made of. That is the whole
/// reason this is here rather than in `view` — the GUI turns these into epaint
/// `Shape`s and the DOM front end into an SVG `path`, and an edge that curved
/// differently in the two would be a different diagram.
pub fn route(from: Rect, from_y: f32, to: Option<(Rect, f32)>, cardinality: Cardinality) -> Route {
    let Some((target, to_y)) = to else {
        // A dangling reference still deserves to be visible: a short stub off
        // the side of the table says "this points somewhere we cannot see",
        // which an omitted edge does not.
        let start = Pos::new(from.right(), from_y);
        return Route {
            path: Path::Stub([start, Pos::new(start.x + STUB_LEN, start.y)]),
            start: marks(start, 1.0, cardinality),
            end: None,
        };
    };

    // Leave from the side that faces the other table, so edges do not cut back
    // across the box they started in.
    let from_right = centre_x(target) >= centre_x(from);
    let start = Pos::new(if from_right { from.right() } else { from.x }, from_y);
    let end = Pos::new(if from_right { target.x } else { target.right() }, to_y);
    let reach = ((end.x - start.x).abs() * 0.45).clamp(24.0, 140.0);
    let bend = if from_right { reach } else { -reach };
    let out_dir = if from_right { 1.0 } else { -1.0 };

    Route {
        path: Path::Curve([
            start,
            Pos::new(start.x + bend, start.y),
            Pos::new(end.x - bend, end.y),
            end,
        ]),
        start: marks(start, out_dir, cardinality),
        // The child end says how many; the parent end is always one row,
        // because that is what a foreign key points at.
        end: Some(marks(end, -out_dir, Cardinality::OneToOne)),
    }
}

fn centre_x(rect: Rect) -> f32 {
    (rect.x + rect.right()) / 2.0
}

/// A crow's foot for many, a single bar for one.
///
/// `out` is +1 or -1 — which way is *away* from the box this end touches. The
/// classic notation, because it is the one an ER diagram is read with: the
/// prongs of the foot sit against the box and converge onto the line, and the
/// bar crosses the line a little clear of the box.
fn marks(at: Pos, out: f32, cardinality: Cardinality) -> Marks {
    let apex = Pos::new(at.x + out * MARK_LEN, at.y);
    match cardinality {
        Cardinality::OneToMany => Marks {
            segments: [
                [Pos::new(at.x, at.y - MARK_HALF), apex],
                [Pos::new(at.x, at.y + MARK_HALF), apex],
            ],
            len: 2,
        },
        Cardinality::OneToOne => Marks {
            segments: [
                [
                    Pos::new(apex.x, apex.y - MARK_HALF),
                    Pos::new(apex.x, apex.y + MARK_HALF),
                ],
                [apex, apex],
            ],
            len: 1,
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The clamps are what stop one long type from stretching a box across the
    /// diagram, and what stop a one-column table from looking like a label.
    #[test]
    fn a_box_is_never_narrower_or_wider_than_the_diagram_can_use() {
        assert_eq!(Measure::table(0.0).size().w, MIN_W);
        assert_eq!(Measure::table(10_000.0).size().w, MAX_W);
    }

    /// Height is the one dimension nothing measures: it comes from how many
    /// rows there are, and an index block only exists when there are indexes.
    #[test]
    fn height_counts_rows_and_only_pays_for_an_index_block_when_there_is_one() {
        let mut plain = Measure::table(40.0);
        plain.column(30.0, 20.0).column(30.0, 20.0);
        assert_eq!(plain.size().h, HEADER_H + ROW_H * 2.0);

        let mut indexed = Measure::table(40.0);
        indexed.column(30.0, 20.0).column(30.0, 20.0);
        indexed.index(50.0, 60.0);
        assert_eq!(
            indexed.size().h,
            HEADER_H + ROW_H * 2.0 + INDEX_SEP + INDEX_H,
            "the separator belongs to the block, not to the box"
        );
    }

    /// The widest row decides the box, whichever kind of row it is — an index
    /// covering six columns is routinely wider than anything else in the table.
    #[test]
    fn the_widest_row_decides_the_width() {
        let mut from_column = Measure::table(10.0);
        from_column.column(100.0, 60.0);
        assert_eq!(
            from_column.size().w,
            PAD_X * 2.0 + 100.0 + GAP + 60.0 + BADGE_W
        );

        let mut from_index = Measure::table(10.0);
        from_index.column(10.0, 10.0);
        from_index.index(100.0, 60.0);
        assert_eq!(
            from_index.size().w,
            PAD_X * 2.0 + 100.0 + GAP + 60.0 + BADGE_W
        );
    }

    /// An unnamed `KEY` has one thing to say and says it in the name's place,
    /// rather than drawing a row that begins with a blank.
    #[test]
    fn an_unnamed_index_puts_its_columns_where_the_name_would_be() {
        let schema =
            draft_ddl::parse("CREATE TABLE t (a int, b int, KEY (a, b), UNIQUE KEY named (b));");
        let indexes = &schema.tables[0].indexes;
        assert_eq!(index_row(&indexes[0]), ("(a, b)".to_owned(), String::new()));
        assert_eq!(
            index_row(&indexes[1]),
            ("named".to_owned(), "(b)".to_owned())
        );
    }

    /// One badge per row, and the order is how much it tells you: a primary key
    /// is also unique, and saying `UQ` there would waste the only badge slot on
    /// the weaker fact.
    #[test]
    fn a_column_shows_the_most_informative_badge_it_has_earned() {
        let schema = draft_ddl::parse(
            "CREATE TABLE p (id int PRIMARY KEY);\n\
             CREATE TABLE c (id int PRIMARY KEY, p_id int UNIQUE REFERENCES p(id), \
             e text UNIQUE, plain text);",
        );
        let columns = &schema.tables[1].columns;
        assert_eq!(badge(&columns[0]), Some("PK"));
        assert_eq!(badge(&columns[1]), Some("FK"), "a key beats being unique");
        assert_eq!(badge(&columns[2]), Some("UQ"));
        assert_eq!(badge(&columns[3]), None);
    }

    fn two_tables() -> draft_ddl::Schema {
        draft_ddl::parse(
            "CREATE TABLE p (id int PRIMARY KEY, name text);\n\
             CREATE TABLE c (id int PRIMARY KEY, p_id int REFERENCES p(id));",
        )
    }

    /// An edge points at the row it is about. Anchoring a foreign key to the
    /// header would say the reference is to the table rather than to a column,
    /// which is the one thing a reader is reading the edge to find out.
    #[test]
    fn an_edge_meets_the_row_it_names_and_the_header_when_it_names_none() {
        let schema = two_tables();
        let rect = Rect {
            x: 0.0,
            y: 100.0,
            w: 200.0,
            h: 90.0,
        };
        let table = &schema.tables[0];
        let name = "name".to_owned();
        assert_eq!(
            anchor_y(table, rect, Some(&name)),
            100.0 + HEADER_H + ROW_H * 1.5,
            "the second row's middle"
        );
        assert_eq!(anchor_y(table, rect, None), 100.0 + HEADER_H / 2.0);
    }

    /// Edges leave from the side that faces the other box. The alternative is
    /// an edge that sets off in the wrong direction and crosses back over the
    /// table it came from, which reads as a relationship to itself.
    #[test]
    fn an_edge_leaves_from_the_side_that_faces_the_other_table() {
        let left = Rect {
            x: 0.0,
            y: 0.0,
            w: 100.0,
            h: 60.0,
        };
        let right = Rect {
            x: 400.0,
            y: 0.0,
            w: 100.0,
            h: 60.0,
        };

        let Path::Curve(forward) =
            route(left, 10.0, Some((right, 20.0)), Cardinality::OneToMany).path
        else {
            panic!("two placed boxes are joined by a curve");
        };
        assert_eq!(forward[0], Pos::new(left.right(), 10.0));
        assert_eq!(forward[3], Pos::new(right.x, 20.0));

        let Path::Curve(back) = route(right, 20.0, Some((left, 10.0)), Cardinality::OneToMany).path
        else {
            panic!("two placed boxes are joined by a curve");
        };
        assert_eq!(back[0], Pos::new(right.x, 20.0));
        assert_eq!(back[3], Pos::new(left.right(), 10.0));
    }

    /// A reference to a table that was never declared is a fact about the
    /// script, and the diagram is the place it becomes visible.
    #[test]
    fn a_reference_to_nothing_is_drawn_as_a_stub_with_one_mark() {
        let from = Rect {
            x: 0.0,
            y: 0.0,
            w: 100.0,
            h: 60.0,
        };
        let routed = route(from, 10.0, None, Cardinality::OneToMany);
        let Path::Stub([a, b]) = routed.path else {
            panic!("an unplaceable target has nothing to curve towards");
        };
        assert_eq!(a, Pos::new(100.0, 10.0));
        assert_eq!(b, Pos::new(100.0 + STUB_LEN, 10.0));
        assert!(
            routed.end.is_none(),
            "there is no far end to mark: {routed:?}"
        );
    }

    /// The two ends say different things: many rows here, one row there. Both
    /// ends drawn the same way would leave the direction of the relationship
    /// unreadable.
    #[test]
    fn the_child_end_is_a_crows_foot_and_the_parent_end_a_single_bar() {
        let a = Rect {
            x: 0.0,
            y: 0.0,
            w: 100.0,
            h: 60.0,
        };
        let b = Rect {
            x: 400.0,
            y: 0.0,
            w: 100.0,
            h: 60.0,
        };
        let many = route(a, 10.0, Some((b, 10.0)), Cardinality::OneToMany);
        assert_eq!(many.start.segments().len(), 2);
        assert_eq!(many.end.expect("placed").segments().len(), 1);

        let one = route(a, 10.0, Some((b, 10.0)), Cardinality::OneToOne);
        assert_eq!(one.start.segments().len(), 1);
    }
}
