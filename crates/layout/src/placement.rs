//! Where each table sits, which is not the same question as where the layout
//! engine would put it.
//!
//! `draft_layout::layout` is a pure function of the schema, so a re-parse
//! moves everything: insert a table halfway down the script and every box below
//! it slides. A diagram that rearranges itself while you type is unreadable, and
//! any table you dragged somewhere deliberate would not survive the next
//! keystroke.
//!
//! So the engine *seeds* positions and this owns them. A table keeps its place
//! for as long as it exists, a genuinely new one is placed beside whatever it
//! references, and re-running the engine is an explicit command — see
//! docs/architecture.md D11.
//!
//! This sits beside the engine rather than in a front end because both front
//! ends need it and neither may own it: the canvas build proved it in Phase 4,
//! and the DOM front end acquired the same problem the moment its SQL pane
//! became editable (Phase 8.4 stage c). A second copy of these three passes
//! would be a second answer to "did that table move".

use std::collections::HashMap;

use draft_ddl::Schema;

use crate::{Layout, Options, Rect, Size};

/// Space left between a newly placed table and its neighbours.
const GAP: f32 = 56.0;

/// A point, in the same units as [`Rect`].
///
/// Ours rather than a geometry crate's because this crate is below every
/// renderer: `draft-geom` holds the shared point type but depends on *this*
/// one, so taking it from there would be a cycle.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
#[cfg_attr(feature = "serde", derive(serde::Serialize, serde::Deserialize))]
pub struct Pos {
    pub x: f32,
    pub y: f32,
}

impl Pos {
    pub fn new(x: f32, y: f32) -> Self {
        Self { x, y }
    }
}

// `Default` for `serde(default)`, which is what lets a field be added to a
// stored project without invalidating the ones already on disk.
#[derive(Clone, Default, PartialEq)]
#[cfg_attr(feature = "serde", derive(serde::Serialize, serde::Deserialize))]
#[cfg_attr(feature = "serde", serde(default))]
struct Placed {
    name: String,
    at: Pos,
    /// Put here by hand rather than by the engine.
    ///
    /// Carried across re-parses with the position it belongs to, because that
    /// is what makes Arrange able to say how much work it is about to undo.
    /// Stored, so opening a project knows which positions were deliberate.
    moved: bool,
}

// `PartialEq` so the undo history can tell one state of the diagram from
// another without keeping a second copy of the positions itself.
#[derive(Clone, Default, PartialEq)]
#[cfg_attr(feature = "serde", derive(serde::Serialize, serde::Deserialize))]
pub struct Placement {
    /// The previous schema's tables, in script order, with where they ended up.
    ///
    /// Order is load-bearing: matching by name alone cannot tell a rename from
    /// a deletion plus an insertion, and every keystroke inside a table name is
    /// a rename. Script order is what distinguishes them.
    prev: Vec<Placed>,
}

impl Placement {
    /// Position every table in `schema`, keeping whatever we can.
    ///
    /// The layout engine runs only when there is a table nothing else can
    /// account for, which is why typing is cheap: renaming a column touches no
    /// name at all, so this is a map lookup per table and nothing more.
    pub fn arrange(&mut self, schema: &Schema, sizes: &[Size], options: &Options) -> Layout {
        if self.prev.is_empty() {
            let engine = crate::layout(schema, sizes, options);
            let by_hand = vec![false; engine.nodes.len()];
            return self.adopt(engine, schema, &by_hand);
        }

        let mut by_name: HashMap<&str, usize> = HashMap::with_capacity(self.prev.len());
        for (i, placed) in self.prev.iter().enumerate() {
            by_name.insert(placed.name.as_str(), i);
        }

        // Pass one: anything whose name still exists stays exactly where it is.
        // The position and "was it put there by hand" travel together: they are
        // one fact about one table, and splitting them is how the flag ends up
        // on the wrong box after a rename.
        let mut claimed = vec![false; self.prev.len()];
        let mut kept: Vec<Option<(Pos, bool)>> = schema
            .tables
            .iter()
            .map(|table| {
                let i = *by_name.get(table.name.as_str())?;
                claimed[i] = true;
                Some((self.prev[i].at, self.prev[i].moved))
            })
            .collect();

        // Pass two: pair what is left, in script order, oldest to newest. One
        // table gone and one appeared at the same point in the script is a
        // rename, and a renamed table should not move.
        let mut orphans = self
            .prev
            .iter()
            .zip(&claimed)
            .filter_map(|(placed, taken)| (!taken).then_some((placed.at, placed.moved)));
        for slot in kept.iter_mut().filter(|s| s.is_none()) {
            *slot = orphans.next();
        }

        let mut at: Vec<Option<Pos>> = kept.iter().map(|k| k.map(|(p, _)| p)).collect();
        let by_hand: Vec<bool> = kept.iter().map(|k| k.is_some_and(|(_, m)| m)).collect();

        // Pass three: whatever is still unplaced is genuinely new, and nobody
        // has had the chance to place it.
        for i in 0..at.len() {
            if at[i].is_none() {
                at[i] = Some(self.somewhere_free(i, schema, sizes, &at));
            }
        }

        let nodes: Vec<Rect> = at
            .iter()
            .enumerate()
            .map(|(i, p)| rect_at(p.unwrap_or_default(), size_of(sizes, i)))
            .collect();
        let size = Size {
            w: nodes.iter().map(|r| r.right()).fold(0.0, f32::max),
            h: nodes.iter().map(|r| r.bottom()).fold(0.0, f32::max),
        };
        self.adopt(Layout { nodes, size }, schema, &by_hand)
    }

    /// Move one table, and remember it there.
    pub fn set(&mut self, index: usize, at: Pos) {
        if let Some(placed) = self.prev.get_mut(index) {
            placed.at = at;
            placed.moved = true;
        }
    }

    /// How many tables sit where somebody put them rather than where the engine
    /// would. Exactly what Arrange is about to throw away, which is why it is
    /// worth counting rather than inferring from "has anything been dragged".
    pub fn moved(&self) -> usize {
        self.prev.iter().filter(|placed| placed.moved).count()
    }

    /// Forget every position, so the next arrange is the engine's alone. This
    /// is what the Arrange button means, and what changing direction or spacing
    /// has to do — those options describe an arrangement, and keeping the old
    /// positions would make them do nothing.
    pub fn reset(&mut self) {
        self.prev.clear();
    }

    /// Record the result, so the next re-parse has something to keep.
    fn adopt(&mut self, layout: Layout, schema: &Schema, by_hand: &[bool]) -> Layout {
        self.prev = schema
            .tables
            .iter()
            .zip(&layout.nodes)
            .enumerate()
            .map(|(i, (table, node))| Placed {
                name: table.name.clone(),
                at: Pos::new(node.x, node.y),
                moved: by_hand.get(i).copied().unwrap_or(false),
            })
            .collect();
        layout
    }

    /// A home for a table that has never been seen before: beside whatever it
    /// is connected to, and out of everything else's way.
    ///
    /// Placing it where the engine would is not an option — the engine places
    /// the whole diagram at once, and its answer for one table only makes sense
    /// alongside its answer for all the others.
    fn somewhere_free(
        &self,
        index: usize,
        schema: &Schema,
        sizes: &[Size],
        at: &[Option<Pos>],
    ) -> Pos {
        let size = size_of(sizes, index);
        let taken: Vec<Rect> = at
            .iter()
            .enumerate()
            .filter(|&(i, _)| i != index)
            .filter_map(|(i, p)| Some(rect_at((*p)?, size_of(sizes, i))))
            .collect();

        let mut start = match self.beside_neighbours(index, schema, sizes, at) {
            Some(pos) => pos,
            // Nothing to sit beside, so sit after everything. An unconnected
            // table appended to the script belongs at the end of the diagram.
            None => Pos::new(
                taken.iter().map(Rect::right).fold(0.0, f32::max) + GAP,
                taken.first().map_or(0.0, |r| r.y),
            ),
        };

        // Slide down past anything in the way. Down rather than out, because
        // the layout engine builds columns and a new table joining one reads as
        // belonging there.
        let mut guard = 0;
        while let Some(hit) = taken.iter().find(|r| overlaps(r, &rect_at(start, size))) {
            start.y = hit.bottom() + GAP;
            guard += 1;
            if guard > taken.len() {
                break;
            }
        }
        start
    }

    /// Level with the tables this one is connected to, and clear of the
    /// rightmost of them so the edge has somewhere to run.
    fn beside_neighbours(
        &self,
        index: usize,
        schema: &Schema,
        sizes: &[Size],
        at: &[Option<Pos>],
    ) -> Option<Pos> {
        let key = &schema.tables.get(index)?.key;
        let mut sum_y = 0.0;
        let mut n = 0;
        let mut right = f32::NEG_INFINITY;
        for relation in &schema.relations {
            let other = if relation.from_table.eq_ignore_ascii_case(key) {
                &relation.to_table
            } else if relation.to_table.eq_ignore_ascii_case(key) {
                &relation.from_table
            } else {
                continue;
            };
            let Some(i) = schema.index_of(other) else {
                continue;
            };
            let Some(Some(pos)) = at.get(i) else { continue };
            sum_y += pos.y;
            n += 1;
            right = right.max(pos.x + size_of(sizes, i).w);
        }
        (n > 0).then(|| Pos::new(right + GAP, sum_y / n as f32))
    }
}

fn size_of(sizes: &[Size], i: usize) -> Size {
    sizes.get(i).copied().unwrap_or(Size { w: 200.0, h: 80.0 })
}

fn rect_at(at: Pos, size: Size) -> Rect {
    Rect {
        x: at.x,
        y: at.y,
        w: size.w,
        h: size.h,
    }
}

/// Two boxes sharing any area. Touching edges do not count: the layout engine
/// packs unconnected tables edge to edge, and treating that as a collision
/// would push every one of them down a row.
fn overlaps(a: &Rect, b: &Rect) -> bool {
    a.x < b.right() && b.x < a.right() && a.y < b.bottom() && b.y < a.bottom()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Not `draft_view`'s, because this crate is below it: a header band and
    /// a row are 28 and 22 points there, and what these tests need is boxes of
    /// a plausible size rather than boxes of the right size.
    const HEADER_H: f32 = 28.0;
    const ROW_H: f32 = 22.0;

    fn schema(sql: &str) -> Schema {
        draft_ddl::parse(sql)
    }

    /// Sizes good enough to place with. Measuring needs fonts; placement does
    /// not care what is written in a box, only how big it is.
    fn sizes(schema: &Schema) -> Vec<Size> {
        schema
            .tables
            .iter()
            .map(|t| Size {
                w: 180.0,
                h: HEADER_H + ROW_H * t.columns.len() as f32,
            })
            .collect()
    }

    fn arrange(p: &mut Placement, sql: &str) -> (Schema, Layout) {
        let schema = schema(sql);
        let sizes = sizes(&schema);
        let layout = p.arrange(&schema, &sizes, &Options::default());
        (schema, layout)
    }

    fn at(schema: &Schema, layout: &Layout, name: &str) -> Pos {
        let i = schema.index_of(name).expect("table should exist");
        Pos::new(layout.nodes[i].x, layout.nodes[i].y)
    }

    const BASE: &str = "CREATE TABLE customers (id bigint PRIMARY KEY, email text);\n\
                        CREATE TABLE orders (id bigint PRIMARY KEY, \
                          customer_id bigint REFERENCES customers(id));\n\
                        CREATE TABLE payments (id bigint PRIMARY KEY, \
                          order_id bigint REFERENCES orders(id));\n";

    /// Phase 4's acceptance criterion, stated as a test: adding a table in the
    /// middle of the script must not move the tables that were already there.
    #[test]
    fn a_table_added_mid_script_moves_nothing_else() {
        let mut p = Placement::default();
        let (before, first) = arrange(&mut p, BASE);
        let kept: Vec<Pos> = ["customers", "orders", "payments"]
            .iter()
            .map(|n| at(&before, &first, n))
            .collect();

        let edited = BASE.replace(
            "CREATE TABLE payments",
            "CREATE TABLE addresses (id bigint PRIMARY KEY, \
               customer_id bigint REFERENCES customers(id));\n\
             CREATE TABLE payments",
        );
        let (after, second) = arrange(&mut p, &edited);

        for (name, was) in ["customers", "orders", "payments"].iter().zip(&kept) {
            assert_eq!(at(&after, &second, name), *was, "{name} moved");
        }
        assert_eq!(after.tables.len(), 4);
    }

    /// A new table must land somewhere usable, not on top of an existing one.
    #[test]
    fn a_new_table_does_not_land_on_another() {
        let mut p = Placement::default();
        arrange(&mut p, BASE);
        let extra: String = (0..6)
            .map(|i| {
                format!(
                    "CREATE TABLE extra{i} (id bigint PRIMARY KEY, \
                     order_id bigint REFERENCES orders(id));\n"
                )
            })
            .collect();
        let (schema, layout) = arrange(&mut p, &format!("{BASE}{extra}"));

        let boxes: &[Rect] = &layout.nodes;
        for (i, a) in boxes.iter().enumerate() {
            for (j, b) in boxes.iter().enumerate().skip(i + 1) {
                assert!(
                    !overlaps(a, b),
                    "{} overlaps {}",
                    schema.tables[i].name,
                    schema.tables[j].name
                );
            }
        }
    }

    /// Every keystroke inside a table name is a rename. If a rename were a
    /// deletion plus an insertion the table would jump across the canvas once
    /// per character typed.
    #[test]
    fn renaming_a_table_leaves_it_where_it_was() {
        let mut p = Placement::default();
        let (before, first) = arrange(&mut p, BASE);
        let was = at(&before, &first, "orders");

        for renamed in ["order", "orde", "orde_v2", "orders_v2"] {
            let sql = BASE.replacen(
                "CREATE TABLE orders ",
                &format!("CREATE TABLE {renamed} "),
                1,
            );
            let (schema, layout) = arrange(&mut p, &sql);
            assert_eq!(
                at(&schema, &layout, renamed),
                was,
                "moved on rename to {renamed}"
            );
        }
    }

    /// A dragged table is the strongest statement of intent there is, and it
    /// has to outlive the re-parse that follows the next keystroke.
    #[test]
    fn a_dragged_table_survives_a_reparse() {
        let mut p = Placement::default();
        let (schema, _) = arrange(&mut p, BASE);
        let moved = Pos::new(-400.0, 900.0);
        p.set(schema.index_of("orders").unwrap(), moved);

        let edited = BASE.replace("email text", "email_address text");
        let (schema, layout) = arrange(&mut p, &edited);
        assert_eq!(at(&schema, &layout, "orders"), moved);
    }

    /// The count Arrange asks about. It has to survive the re-parses that
    /// follow every keystroke, or the confirmation would stop appearing the
    /// moment you typed a character after dragging something.
    #[test]
    fn a_hand_placed_table_is_counted_until_the_engine_takes_over_again() {
        let mut p = Placement::default();
        let (schema, _) = arrange(&mut p, BASE);
        assert_eq!(p.moved(), 0, "the engine placed all of these");

        p.set(schema.index_of("orders").unwrap(), Pos::new(-400.0, 900.0));
        assert_eq!(p.moved(), 1);

        // A rename is what the flag is most likely to be lost by: pass two
        // pairs the old entry with the new name, and the flag has to go with
        // the position it belongs to.
        let renamed = BASE.replacen("CREATE TABLE orders ", "CREATE TABLE sales ", 1);
        arrange(&mut p, &renamed);
        assert_eq!(p.moved(), 1, "the flag was dropped by a rename");

        // An added table is nobody's decision, so it must not inflate the count
        // the confirmation reports.
        arrange(
            &mut p,
            &format!("{renamed}CREATE TABLE refunds (id bigint PRIMARY KEY);\n"),
        );
        assert_eq!(p.moved(), 1, "a new table was counted as hand-placed");

        p.reset();
        arrange(&mut p, &renamed);
        assert_eq!(p.moved(), 0, "Arrange did not hand everything back");
    }

    /// Arranging is a command, and a command that did nothing when you had
    /// moved something would be worse than no command at all.
    #[test]
    fn reset_hands_the_diagram_back_to_the_engine() {
        let mut p = Placement::default();
        let (schema, first) = arrange(&mut p, BASE);
        p.set(schema.index_of("orders").unwrap(), Pos::new(-999.0, 999.0));
        p.reset();
        let (schema, again) = arrange(&mut p, BASE);
        assert_eq!(at(&schema, &again, "orders"), at(&schema, &first, "orders"));
    }
}
