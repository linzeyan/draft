//! Find a table, in a diagram too big to read by panning.
//!
//! This takes Ctrl/Cmd+F rather than inventing a shortcut of its own, because
//! the browser's own find bar is already useless here: everything on screen is
//! painted into a canvas, so there is no text in the page for it to find.
//! `crates/app/index.html` suppresses the browser's bar on the same key for the
//! same reason — two find bars, one of which can never find anything, is worse
//! than one.

use draft_ddl::Schema;
use egui::{Key, Modifiers, RichText};

/// How many matches are offered at once.
///
/// Enough to see that a guess was too broad, few enough to read at a glance: a
/// list you have to scroll is a list you have to search.
const LIMIT: usize = 12;

const WIDTH: f32 = 260.0;

/// Distance from the corner of the canvas, so the box reads as floating over
/// the diagram rather than as part of the toolbar above it.
const MARGIN: f32 = 12.0;

#[derive(Default)]
pub struct Find {
    open: bool,
    query: String,
    /// Which match the keyboard is on, as an index into this frame's list.
    selected: usize,
    /// Set on the frame the box opens, so the field takes the keyboard once
    /// rather than stealing it back on every frame afterwards.
    focus: bool,
}

/// A table worth offering, and what in it matched.
#[derive(Debug, PartialEq, Eq)]
struct Match {
    table: usize,
    /// The column whose name matched, when the table's own name did not.
    column: Option<usize>,
}

impl Find {
    pub fn open(&mut self) {
        self.open = true;
        self.focus = true;
        // The query survives, the cursor into the list does not: the list is
        // rebuilt against whatever the schema now says.
        self.selected = 0;
    }

    pub fn close(&mut self) {
        self.open = false;
    }

    /// Draw the box, if it is open. Returns the table to go to, once one has
    /// been chosen.
    pub fn show(
        &mut self,
        ctx: &egui::Context,
        schema: &Schema,
        view: egui::Rect,
    ) -> Option<usize> {
        if !self.open {
            return None;
        }
        let found = matches(schema, &self.query);

        // The list owns Enter, the arrows and Escape, and takes them before the
        // field is drawn: a `TextEdit` handed Enter surrenders its focus and
        // handed an arrow moves its caret, and either would leave the list
        // unreachable from the keyboard. Taking Escape here is also what makes
        // one press cancel one thing — the box before the pin behind it.
        let (go, down, up, escape) = ctx.input_mut(|i| {
            (
                i.consume_key(Modifiers::NONE, Key::Enter),
                i.consume_key(Modifiers::NONE, Key::ArrowDown),
                i.consume_key(Modifiers::NONE, Key::ArrowUp),
                i.consume_key(Modifiers::NONE, Key::Escape),
            )
        });
        if escape {
            self.close();
            return None;
        }
        if down {
            self.selected += 1;
        }
        if up {
            self.selected = self.selected.saturating_sub(1);
        }
        self.selected = self.selected.min(found.len().saturating_sub(1));

        let mut chosen = if go {
            found.get(self.selected).map(|m| m.table)
        } else {
            None
        };
        let mut moved_focus = false;
        let at = egui::pos2(view.right() - WIDTH - MARGIN, view.top() + MARGIN);
        egui::Area::new(egui::Id::new("find"))
            .order(egui::Order::Foreground)
            .fixed_pos(at)
            .show(ctx, |ui| {
                egui::Frame::popup(ui.style()).show(ui, |ui| {
                    ui.set_width(WIDTH);
                    let field = ui.add(
                        egui::TextEdit::singleline(&mut self.query)
                            .hint_text("Find a table")
                            .desired_width(f32::INFINITY),
                    );
                    if std::mem::take(&mut self.focus) {
                        field.request_focus();
                    }
                    for (i, hit) in found.iter().enumerate() {
                        let table = &schema.tables[hit.table];
                        let label = match hit.column.map(|c| &table.columns[c].name) {
                            Some(column) => format!("{} · {column}", table.name),
                            None => table.name.clone(),
                        };
                        if ui.selectable_label(i == self.selected, label).clicked() {
                            chosen = Some(hit.table);
                            moved_focus = true;
                        }
                    }
                    if found.is_empty() {
                        ui.label(RichText::new("no table of that name").weak());
                    }
                    // Clicking into the diagram or the SQL pane is how people
                    // say they are done with a find bar. Read after the rows,
                    // because clicking a row also takes the focus away.
                    if field.lost_focus() && !moved_focus {
                        self.open = false;
                    }
                });
            });

        if chosen.is_some() {
            self.close();
        }
        chosen
    }
}

/// The tables worth offering for a query, best first.
///
/// An empty query offers the schema itself, which is what makes this box double
/// as the table list this application otherwise does not have.
fn matches(schema: &Schema, query: &str) -> Vec<Match> {
    let needle = query.trim().to_lowercase();
    if needle.is_empty() {
        return (0..schema.tables.len())
            .take(LIMIT)
            .map(|table| Match {
                table,
                column: None,
            })
            .collect();
    }

    let mut found: Vec<(u8, Match)> = Vec::new();
    for (i, table) in schema.tables.iter().enumerate() {
        if let Some(at) = table.name.to_lowercase().find(&needle) {
            // Somebody typing a name is aiming at its start, so `orders` has to
            // come before `line_orders` however the script happens to order
            // them.
            found.push((
                u8::from(at > 0),
                Match {
                    table: i,
                    column: None,
                },
            ));
            continue;
        }
        // Falling back to the columns answers the other half of the question —
        // "which table holds this field?" — and ranks below every name match,
        // because a table that is called what you typed is a better answer than
        // one that merely contains it.
        if let Some(c) = table
            .columns
            .iter()
            .position(|c| c.name.to_lowercase().contains(&needle))
        {
            found.push((
                2,
                Match {
                    table: i,
                    column: Some(c),
                },
            ));
        }
    }
    // Stable, so equally good matches stay in script order.
    found.sort_by_key(|(rank, _)| *rank);
    found.into_iter().map(|(_, m)| m).take(LIMIT).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    const SQL: &str = "\
        CREATE TABLE order_customers (id int PRIMARY KEY, note text);\n\
        CREATE TABLE customers (id int PRIMARY KEY, email text);\n\
        CREATE TABLE payments (id int PRIMARY KEY, customer_id int);\n";

    fn schema() -> Schema {
        draft_ddl::parse(SQL)
    }

    /// The table you typed the name of has to be the first thing offered, or
    /// Enter jumps somewhere you did not ask for — which is worse than no
    /// keyboard at all.
    #[test]
    fn the_table_whose_name_starts_with_the_query_comes_first() {
        let schema = schema();
        let found = matches(&schema, "cust");
        assert_eq!(
            found,
            vec![
                Match {
                    table: 1,
                    column: None
                },
                Match {
                    table: 0,
                    column: None
                },
                Match {
                    table: 2,
                    column: Some(1)
                },
            ],
            "expected customers, then order_customers, then the column match"
        );
    }

    /// Identifiers are typed in whatever case is to hand, and a search that
    /// respects case is a search that fails silently.
    #[test]
    fn case_is_not_part_of_the_question() {
        let schema = schema();
        assert_eq!(matches(&schema, "CUSTOMERS")[0].table, 1);
        assert_eq!(matches(&schema, "EmAiL")[0].table, 1);
    }

    /// "Which table holds this column?" is the other reason to open this box.
    #[test]
    fn a_column_name_finds_the_table_that_holds_it() {
        let schema = schema();
        assert_eq!(
            matches(&schema, "email"),
            vec![Match {
                table: 1,
                column: Some(1)
            }]
        );
    }

    /// With nothing typed the box is the table list, which is how somebody
    /// discovers it does anything at all.
    #[test]
    fn an_empty_query_offers_the_tables_themselves() {
        let schema = schema();
        let found = matches(&schema, "");
        assert_eq!(found.len(), 3);
        assert_eq!(found[0].table, 0);
        assert!(found.iter().all(|m| m.column.is_none()));
    }

    /// A query that matches everything must not turn the box into a wall.
    #[test]
    fn the_list_is_capped() {
        let sql: String = (0..40)
            .map(|i| format!("CREATE TABLE t{i} (id int);\n"))
            .collect();
        let schema = draft_ddl::parse(&sql);
        assert_eq!(matches(&schema, "t").len(), LIMIT);
        assert_eq!(matches(&schema, "").len(), LIMIT);
    }
}
