//! Editing the schema through the diagram.
//!
//! The differentiating feature, and the reason `draft_model` exists: double
//! -click a name on the canvas, type a new one, and the *script* changes —
//! exactly the bytes that had to, with every comment and every vendor clause
//! the parser never understood still in place.
//!
//! Nothing here edits a model and regenerates SQL. The text is the document;
//! the diagram is a view of it, and an edit made on the diagram is a splice
//! into the text like any other.

use draft_ddl::Schema;
use draft_model::{Edit, EditError};
use draft_view::Hit;
use egui::{Align2, Color32, Rect, RichText};

/// What is being edited, named rather than indexed.
///
/// A re-parse can fire from the debounce while a field is open, and indices do
/// not survive one. A name that no longer exists fails the edit loudly instead
/// of renaming whatever landed at index 3.
#[derive(Clone, Debug, PartialEq)]
enum What {
    Table,
    ColumnName(String),
    ColumnType(String),
}

struct Active {
    table: String,
    what: What,
    hit: Hit,
    text: String,
    /// Set on the frame the field opens, to hand it the keyboard.
    fresh: bool,
    error: Option<String>,
}

#[derive(Default)]
pub struct Inline {
    active: Option<Active>,
}

/// What the caller should do with the schema text, once a field is committed.
pub enum Outcome {
    /// Nothing happened, or the field is still open.
    Pending,
    Apply(Edit),
    Cancelled,
}

impl Inline {
    pub fn is_open(&self) -> bool {
        self.active.is_some()
    }

    /// Open a field over `hit` in `table`. Ignored if the target does not
    /// resolve — a stale double-click after a re-parse, say.
    pub fn open(&mut self, schema: &Schema, table: usize, hit: Hit) {
        let Some(t) = schema.tables.get(table) else {
            return;
        };
        let (what, text) = match hit {
            Hit::Header => (What::Table, t.name.clone()),
            Hit::ColumnName(i) => match t.columns.get(i) {
                Some(c) => (What::ColumnName(c.name.clone()), c.name.clone()),
                None => return,
            },
            Hit::ColumnType(i) => match t.columns.get(i) {
                Some(c) => (What::ColumnType(c.name.clone()), c.ty_raw.clone()),
                None => return,
            },
        };
        self.active = Some(Active {
            table: t.name.clone(),
            what,
            hit,
            text,
            fresh: true,
            error: None,
        });
    }

    pub fn close(&mut self) {
        self.active = None;
    }

    /// Draw the field, if one is open. `at` is where it goes on screen.
    ///
    /// Drawn in an `Area` above the canvas rather than painted into it: this is
    /// a real `TextEdit`, with a caret, selection and an IME, and reimplementing
    /// those over a painter would be a worse version of what egui already has.
    pub fn show(&mut self, ctx: &egui::Context, at: Rect, schema: &Schema, sql: &str) -> Outcome {
        let Some(active) = &mut self.active else {
            return Outcome::Pending;
        };

        let mut commit = false;
        let mut cancel = false;
        let id = egui::Id::new("inline-edit");
        egui::Area::new(id)
            .order(egui::Order::Foreground)
            .fixed_pos(at.min)
            .show(ctx, |ui| {
                ui.set_min_size(at.size());
                egui::Frame::popup(ui.style()).show(ui, |ui| {
                    ui.vertical(|ui| {
                        let field = ui.add(
                            egui::TextEdit::singleline(&mut active.text)
                                .desired_width(at.width().max(120.0))
                                .hint_text(active.what.hint()),
                        );
                        if active.fresh {
                            active.fresh = false;
                            field.request_focus();
                        }
                        commit =
                            field.lost_focus() && ui.input(|i| i.key_pressed(egui::Key::Enter));
                        cancel = ui.input(|i| i.key_pressed(egui::Key::Escape))
                            || (field.lost_focus() && !commit);

                        if let What::ColumnType(_) = active.what {
                            suggestions(ui, schema, &mut active.text, &mut commit);
                        }
                        if let Some(message) = &active.error {
                            ui.label(
                                RichText::new(message).color(Color32::from_rgb(0xd0, 0x6b, 0x6b)),
                            );
                        }
                    });
                });
            });

        if cancel {
            self.active = None;
            return Outcome::Cancelled;
        }
        if !commit {
            return Outcome::Pending;
        }
        match self.build(schema, sql) {
            Ok(edit) => {
                self.active = None;
                Outcome::Apply(edit)
            }
            Err(e) => {
                // Keep the field open with the message attached: closing it
                // would throw away what was typed and say nothing about why.
                if let Some(active) = &mut self.active {
                    active.error = Some(e.to_string());
                    active.fresh = true;
                }
                Outcome::Pending
            }
        }
    }

    fn build(&self, schema: &Schema, sql: &str) -> Result<Edit, EditError> {
        let active = self.active.as_ref().expect("only called with a field open");
        let text = active.text.trim();
        match &active.what {
            What::Table => draft_model::rename_table(schema, &active.table, text),
            What::ColumnName(col) => draft_model::rename_column(schema, &active.table, col, text),
            What::ColumnType(col) => draft_model::set_column_type(schema, &active.table, col, text),
        }
        .map(|edit| {
            // An unchanged value is not an error and not an edit. Returning an
            // empty one lets the caller skip the re-parse entirely.
            if edit.splices.iter().all(|s| sql[s.range.clone()] == s.text) {
                Edit {
                    summary: edit.summary,
                    splices: Vec::new(),
                }
            } else {
                edit
            }
        })
    }

    /// The table and row a field is open over, for the caller to position it.
    pub fn target(&self, schema: &Schema) -> Option<(usize, Hit)> {
        let active = self.active.as_ref()?;
        Some((schema.index_of(&active.table)?, active.hit))
    }
}

impl What {
    fn hint(&self) -> &'static str {
        match self {
            Self::Table => "table name",
            Self::ColumnName(_) => "column name",
            Self::ColumnType(_) => "type",
        }
    }
}

/// The types this script already uses. See `model::types_in_use` for why this
/// is not a list of types per dialect.
fn suggestions(ui: &mut egui::Ui, schema: &Schema, text: &mut String, commit: &mut bool) {
    let typed = text.trim().to_lowercase();
    let matches: Vec<String> = draft_model::types_in_use(schema)
        .into_iter()
        .filter(|t| typed.is_empty() || t.to_lowercase().contains(&typed))
        .take(6)
        .collect();
    if matches.is_empty() {
        return;
    }
    ui.separator();
    for ty in matches {
        if ui.selectable_label(false, &ty).clicked() {
            *text = ty;
            *commit = true;
        }
    }
}

/// Where to put the field on screen, given the camera.
pub fn field_rect(table: Rect, size: draft_layout::Size, hit: Hit, zoom: f32) -> Rect {
    let local = draft_view::hit_rect(size, hit);
    Align2::LEFT_TOP.align_size_within_rect(
        egui::Vec2::new(local.width() * zoom, local.height() * zoom),
        Rect::from_min_size(
            table.min + local.min.to_vec2() * zoom,
            egui::Vec2::new(local.width() * zoom, local.height() * zoom),
        ),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    const SQL: &str = "CREATE TABLE orders (\n  id bigint PRIMARY KEY,\n  \
                       total_cents integer NOT NULL\n);\n";

    /// Opening a field must show what is already there, or the first keystroke
    /// looks like it wiped the value.
    #[test]
    fn a_field_opens_with_the_current_value() {
        let schema = draft_ddl::parse(SQL);
        let mut inline = Inline::default();

        inline.open(&schema, 0, Hit::Header);
        assert_eq!(inline.active.as_ref().unwrap().text, "orders");

        inline.open(&schema, 0, Hit::ColumnName(1));
        assert_eq!(inline.active.as_ref().unwrap().text, "total_cents");

        inline.open(&schema, 0, Hit::ColumnType(1));
        assert_eq!(
            inline.active.as_ref().unwrap().text,
            "integer",
            "the type field must offer what was written, not the normalised form"
        );
    }

    /// Committing an unchanged value must not touch the script. Otherwise
    /// double-clicking a name and pressing Enter would mark the document dirty
    /// and re-lay it out for nothing.
    #[test]
    fn committing_an_unchanged_value_is_not_an_edit() {
        let schema = draft_ddl::parse(SQL);
        let mut inline = Inline::default();
        inline.open(&schema, 0, Hit::Header);
        assert!(inline.build(&schema, SQL).unwrap().is_empty());

        inline.active.as_mut().unwrap().text = "invoices".to_owned();
        let edit = inline.build(&schema, SQL).unwrap();
        assert_eq!(edit.splices.len(), 1);
        assert_eq!(
            draft_model::apply(SQL, &edit.splices).unwrap(),
            SQL.replace("orders", "invoices")
        );
    }

    /// A name that would need quoting must be refused, not spliced in raw. The
    /// script on disk is the thing this application cannot be allowed to break.
    #[test]
    fn a_name_that_would_break_the_script_is_refused() {
        let schema = draft_ddl::parse(SQL);
        let mut inline = Inline::default();
        inline.open(&schema, 0, Hit::Header);
        inline.active.as_mut().unwrap().text = "orders; DROP TABLE users".to_owned();
        assert!(matches!(
            inline.build(&schema, SQL),
            Err(EditError::UnsafeIdentifier(_))
        ));
    }

    /// The field is addressed by name, so a re-parse that renumbers the tables
    /// cannot make it edit a different one.
    #[test]
    fn a_target_follows_its_table_through_a_reparse() {
        let schema = draft_ddl::parse(SQL);
        let mut inline = Inline::default();
        inline.open(&schema, 0, Hit::ColumnName(0));

        let moved = draft_ddl::parse(&format!("CREATE TABLE first (id int);\n{SQL}"));
        assert_eq!(
            inline.target(&moved),
            Some((1, Hit::ColumnName(0))),
            "the field should have followed `orders` to its new index"
        );
    }
}
