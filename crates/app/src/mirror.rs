//! The schema as text in the page, for the readers a canvas has none of.
//!
//! A `<canvas>` contains no text. A screen reader finds nothing to read in this
//! application, a translator nothing to translate, and `document.body.innerText`
//! is empty. This writes the facts the diagram draws — tables, columns, types,
//! keys, indexes, relations, notes — into a visually hidden element on every
//! re-parse, so at least the *content* is in the accessibility tree even while
//! the *interaction* is not.
//!
//! Two things it deliberately is not. It is not a fix for
//! [the accessibility gap](../../../docs/spec.md): nothing here gives a keyboard
//! user a way to move the camera, and describing it as accessible support would
//! be a lie of omission. And it is not a second model of the schema — it is a
//! projection of `Document`, built fresh each time, exactly like the diagram.
//!
//! It is also step 0 of D19: writing the schema from wasm into the DOM is the
//! path the DOM front end needs, arriving early where it is cheap.

use crate::annotate::Kind;
use crate::document::Document;
use draft_ddl::Cardinality;

/// The whole summary, as HTML. Pure, so what it says can be tested without a
/// browser — which is the only place it can ever be read.
pub fn html(doc: &Document) -> String {
    let schema = &doc.schema;
    // Roughly what a medium schema needs, to save the first dozen reallocations
    // on the 300-table fixture.
    let mut out = String::with_capacity(512 + schema.tables.len() * 256);

    out.push_str("<h2>");
    escape(&doc.name, &mut out);
    out.push_str("</h2>\n<p>");
    out.push_str(&plural(schema.tables.len(), "table"));
    out.push_str(", ");
    out.push_str(&plural(schema.relations.len(), "relation"));
    if let Some(dialect) = doc.dialect() {
        out.push_str(", ");
        escape(dialect.label(), &mut out);
    }
    out.push_str(".</p>\n");

    for table in &schema.tables {
        out.push_str("<h3>");
        escape(&table.name, &mut out);
        out.push_str("</h3>\n<ul>\n");
        for column in &table.columns {
            out.push_str("<li>");
            escape(&column.name, &mut out);
            out.push_str(": ");
            escape(&column.ty, &mut out);
            // Only what the box marks, in the order the badges read. Nullable
            // rather than "not null" for the same reason the canvas dims it:
            // `NOT NULL` is the normal case, and naming the normal case on
            // every row is noise a screen reader has to listen through.
            let mut marks = Vec::new();
            if column.pk {
                marks.push("primary key");
            }
            if column.fk {
                marks.push("foreign key");
            }
            if column.unique {
                marks.push("unique");
            }
            if !column.not_null && !column.pk {
                marks.push("nullable");
            }
            if !marks.is_empty() {
                out.push_str(" — ");
                out.push_str(&marks.join(", "));
            }
            out.push_str("</li>\n");
        }
        out.push_str("</ul>\n");

        if !table.indexes.is_empty() {
            out.push_str("<p>Indexes:</p>\n<ul>\n");
            for index in &table.indexes {
                out.push_str("<li>");
                // MySQL's unnamed `KEY (col)` has no name in the script; the
                // columns are what it is, so they are what it is called here.
                match &index.name {
                    Some(name) => escape(name, &mut out),
                    None => out.push_str("unnamed"),
                }
                out.push_str(" (");
                for (i, column) in index.columns.iter().enumerate() {
                    if i > 0 {
                        out.push_str(", ");
                    }
                    escape(column, &mut out);
                }
                out.push(')');
                if index.unique {
                    out.push_str(" — unique");
                }
                out.push_str("</li>\n");
            }
            out.push_str("</ul>\n");
        }
    }

    if !schema.relations.is_empty() {
        out.push_str("<h3>Relations</h3>\n<ul>\n");
        for relation in &schema.relations {
            out.push_str("<li>");
            columns_of(&relation.from_table, &relation.from_cols, &mut out);
            out.push_str(" references ");
            columns_of(&relation.to_table, &relation.to_cols, &mut out);
            out.push_str(match relation.cardinality {
                Cardinality::OneToMany => " — one to many",
                Cardinality::OneToOne => " — one to one",
            });
            if relation.to_missing {
                out.push_str(", which this script does not define");
            }
            out.push_str("</li>\n");
        }
        out.push_str("</ul>\n");
    }

    if !doc.annotations.is_empty() {
        out.push_str("<h3>Notes</h3>\n<ul>\n");
        for annotation in doc.annotations.iter() {
            out.push_str("<li>");
            out.push_str(match annotation.kind {
                Kind::Note => "Note: ",
                Kind::Group => "Group: ",
            });
            escape(&annotation.text, &mut out);
            out.push_str("</li>\n");
        }
        out.push_str("</ul>\n");
    }

    out
}

/// `table.column`, or `table.(a, b)` for a composite key.
fn columns_of(table: &str, columns: &[String], out: &mut String) {
    escape(table, out);
    match columns {
        [] => {}
        [one] => {
            out.push('.');
            escape(one, out);
        }
        many => {
            out.push_str(".(");
            for (i, column) in many.iter().enumerate() {
                if i > 0 {
                    out.push_str(", ");
                }
                escape(column, out);
            }
            out.push(')');
        }
    }
}

/// Escape for a text node. Only the three that can end one: nothing here is
/// ever written into an attribute, and a quoted identifier is a normal thing
/// for a schema to contain.
fn escape(text: &str, out: &mut String) {
    for ch in text.chars() {
        match ch {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            _ => out.push(ch),
        }
    }
}

fn plural(n: usize, noun: &str) -> String {
    if n == 1 {
        format!("{n} {noun}")
    } else {
        format!("{n} {noun}s")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// `Document::new` parses and nothing else, which is exactly what this
    /// needs: the summary is a function of the schema, not of the geometry, so
    /// it is testable without fonts.
    fn document(sql: &str) -> Document {
        Document::new("test.sql", sql)
    }

    /// The point of the whole file: the names a reader would ask for are in the
    /// page as text, not only as pixels.
    #[test]
    fn every_table_and_column_is_in_the_page() {
        let doc = document(
            "CREATE TABLE customers (id bigserial PRIMARY KEY, email text NOT NULL UNIQUE);\n\
             CREATE TABLE orders (id bigserial PRIMARY KEY, customer_id bigint REFERENCES customers(id));\n",
        );
        let html = html(&doc);

        assert!(html.contains("<h3>customers</h3>"), "{html}");
        assert!(html.contains("<h3>orders</h3>"), "{html}");
        assert!(html.contains("email: text — unique"), "{html}");
        assert!(html.contains("id: bigserial — primary key"), "{html}");
        // A nullable column says so; a NOT NULL one does not say the opposite.
        assert!(
            html.contains("customer_id: bigint — foreign key, nullable"),
            "{html}"
        );
        assert!(
            html.contains("orders.customer_id references customers.id — one to many"),
            "{html}"
        );
    }

    /// A schema is somebody else's text, and it goes into the page as HTML. A
    /// table called `<script>` must not become one.
    #[test]
    fn a_schema_cannot_write_markup_into_the_page() {
        let mut doc = document("CREATE TABLE t (id int);\n");
        doc.schema.tables[0].name = "<script>alert('x')</script>".to_owned();
        doc.schema.tables[0].columns[0].name = "a & b".to_owned();

        let html = html(&doc);
        assert!(!html.contains("<script>"), "{html}");
        assert!(html.contains("&lt;script&gt;"), "{html}");
        assert!(html.contains("a &amp; b"), "{html}");
    }

    /// An index block appears only when the script declares one, exactly as the
    /// table box shows it.
    #[test]
    fn indexes_and_notes_appear_only_when_there_are_some() {
        let plain = document("CREATE TABLE t (id int PRIMARY KEY);\n");
        assert!(!html(&plain).contains("Indexes"), "{}", html(&plain));
        assert!(!html(&plain).contains("Notes"));

        let mut doc = document(
            "CREATE TABLE t (id int PRIMARY KEY, email text);\n\
             CREATE UNIQUE INDEX ix_t_email ON t (email);\n",
        );
        let note = doc.annotations.add(Kind::Note, egui::Pos2::ZERO);
        *doc.annotations.text_mut(note).expect("just added") =
            "ask finance about this one".to_owned();

        let html = html(&doc);
        assert!(html.contains("ix_t_email (email) — unique"), "{html}");
        assert!(html.contains("Note: ask finance about this one"), "{html}");
    }
}
