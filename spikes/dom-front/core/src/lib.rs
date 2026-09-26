//! Spike S5a — how big is the wasm a DOM front end would need?
//!
//! The question behind the strategic fork in
//! [architecture.md](../../../docs/architecture.md): 76% of the shipped 1266 K
//! payload is the egui runtime plus two typefaces, and only ~300 K is this
//! project. If the UI were HTML and the diagram were SVG, the wasm would carry
//! the parser, the layout engine and the splice logic and nothing else. This
//! measures that floor.
//!
//! It is a *bridge*, not a toy: every call a DOM front end would actually make
//! is here, because a measurement of half the surface would flatter the answer.
//! Two design points come out of writing it, and they are the reason it is
//! worth committing rather than deleting:
//!
//! 1. **Nothing needs a JSON parser in wasm.** Widths arrive as a `Float32Array`
//!    and positions go back as one; only the schema goes out as JSON, and
//!    writing JSON is thirty lines. A `serde`/`serde_json` pair on this side of
//!    the wall would be pure weight.
//! 2. **The session holds the parse.** The front end sends text once and then
//!    asks questions about it, exactly as `Document` does today, so re-parsing
//!    per call never happens.
//!
//! What is deliberately absent is any text measurement: the browser measures,
//! which is the whole reason the typefaces can leave the wasm. Whether that is
//! *safe* is the other half of this spike — see `../metrics`.

use draft_ddl::{Cardinality, Schema};
use draft_layout::{Direction, Options, Size, Spacing};
use wasm_bindgen::prelude::*;

/// One script, parsed once, asked about many times.
#[wasm_bindgen]
pub struct Session {
    sql: String,
    schema: Schema,
}

#[wasm_bindgen]
impl Session {
    #[wasm_bindgen(constructor)]
    pub fn new(sql: String) -> Self {
        let schema = draft_ddl::parse(&sql);
        Self { sql, schema }
    }

    /// Everything the DOM needs to build the boxes, as JSON.
    pub fn schema_json(&self) -> String {
        let mut out = String::with_capacity(self.sql.len());
        out.push_str("{\"tables\":[");
        for (i, table) in self.schema.tables.iter().enumerate() {
            if i > 0 {
                out.push(',');
            }
            out.push_str("{\"name\":");
            quote(&table.name, &mut out);
            out.push_str(",\"columns\":[");
            for (j, column) in table.columns.iter().enumerate() {
                if j > 0 {
                    out.push(',');
                }
                out.push_str("{\"name\":");
                quote(&column.name, &mut out);
                out.push_str(",\"type\":");
                quote(&column.ty, &mut out);
                out.push_str(",\"flags\":");
                // A bitfield rather than four booleans: the front end is going
                // to turn these into class names anyway.
                let flags = u32::from(column.pk)
                    | u32::from(column.not_null) << 1
                    | u32::from(column.unique) << 2
                    | u32::from(column.fk) << 3;
                out.push_str(&flags.to_string());
                out.push_str(",\"def\":");
                quote(column.def_span.text(&self.sql).trim(), &mut out);
                out.push('}');
            }
            out.push_str("],\"indexes\":[");
            for (j, index) in table.indexes.iter().enumerate() {
                if j > 0 {
                    out.push(',');
                }
                out.push_str("{\"name\":");
                quote(index.name.as_deref().unwrap_or(""), &mut out);
                out.push_str(",\"unique\":");
                out.push_str(if index.unique { "true" } else { "false" });
                out.push_str(",\"columns\":[");
                for (k, column) in index.columns.iter().enumerate() {
                    if k > 0 {
                        out.push(',');
                    }
                    quote(column, &mut out);
                }
                out.push_str("]}");
            }
            out.push_str("]}");
        }
        out.push_str("],\"relations\":[");
        for (i, relation) in self.schema.relations.iter().enumerate() {
            if i > 0 {
                out.push(',');
            }
            out.push_str("{\"from\":");
            quote(&relation.from_table, &mut out);
            out.push_str(",\"to\":");
            quote(&relation.to_table, &mut out);
            out.push_str(",\"fromCols\":[");
            for (j, column) in relation.from_cols.iter().enumerate() {
                if j > 0 {
                    out.push(',');
                }
                quote(column, &mut out);
            }
            out.push_str("],\"toCols\":[");
            for (j, column) in relation.to_cols.iter().enumerate() {
                if j > 0 {
                    out.push(',');
                }
                quote(column, &mut out);
            }
            out.push_str("],\"one\":");
            out.push_str(match relation.cardinality {
                Cardinality::OneToOne => "true",
                Cardinality::OneToMany => "false",
            });
            out.push_str(",\"missing\":");
            out.push_str(if relation.to_missing { "true" } else { "false" });
            out.push('}');
        }
        out.push_str("],\"warnings\":[");
        for (i, warning) in self.schema.warnings.iter().enumerate() {
            if i > 0 {
                out.push(',');
            }
            out.push_str("{\"message\":");
            quote(&warning.message, &mut out);
            out.push_str(",\"at\":");
            out.push_str(&warning.span.map_or(-1, |s| s.start as i64).to_string());
            out.push('}');
        }
        out.push_str("]}");
        out
    }

    /// Place the tables, given the widths and heights the browser measured.
    ///
    /// `sizes` is `[w0, h0, w1, h1, …]` and the answer is `[x0, y0, x1, y1, …]`
    /// — typed arrays both ways, so neither side parses anything.
    pub fn layout(&self, sizes: &[f32], vertical: bool, spacing: u8) -> Vec<f32> {
        let sizes: Vec<Size> = sizes
            .chunks_exact(2)
            .map(|wh| Size { w: wh[0], h: wh[1] })
            .collect();
        let options = Options {
            direction: if vertical {
                Direction::Vertical
            } else {
                Direction::Horizontal
            },
            spacing: match spacing {
                0 => Spacing::Compact,
                2 => Spacing::Spacious,
                _ => Spacing::Comfortable,
            },
        };
        let placed = draft_layout::layout(&self.schema, &sizes, &options);
        placed.nodes.iter().flat_map(|n| [n.x, n.y]).collect()
    }

    /// Syntax highlighting for the editor pane, as `[start, end, token, …]`.
    pub fn highlight(&self) -> Vec<u32> {
        draft_ddl::highlight(&self.sql)
            .into_iter()
            .flat_map(|(span, token)| [span.start as u32, span.end as u32, token as u32])
            .collect()
    }

    pub fn dialect(&self) -> String {
        draft_ddl::detect(&self.sql)
            .map(|d| d.label().to_owned())
            .unwrap_or_default()
    }

    /// The splice path, which is the product's whole point: rename a column and
    /// get the rewritten script back.
    pub fn rename_column(&self, table: &str, column: &str, to: &str) -> Option<String> {
        let edit = draft_model::rename_column(&self.schema, table, column, to).ok()?;
        draft_model::apply(&self.sql, &edit.splices).ok()
    }
}

/// A JSON string literal. Enough of the escape rules for identifiers and
/// messages, which is all that crosses this wall.
fn quote(text: &str, out: &mut String) {
    out.push('"');
    for c in text.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
}
