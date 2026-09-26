//! A JSON view of the parsed schema, for scripting and for seeing exactly what
//! the parser made of a file.
//!
//! Hand-written rather than derived. `draft-ddl` is a wasm dependency under
//! a payload budget (docs/risks.md R1), and putting serde in it to serve a
//! native-only flag would be the wrong trade — the shape below is small and it
//! is the CLI's own output format, not the core's.

use std::fmt::Write as _;

use draft_ddl::{Schema, Span};

pub fn schema(schema: &Schema) -> String {
    let mut out = String::with_capacity(4096);
    out.push_str("{\n  \"tables\": [");
    for (i, table) in schema.tables.iter().enumerate() {
        out.push_str(if i == 0 { "\n" } else { ",\n" });
        let _ = write!(
            out,
            "    {{ \"name\": {}, \"name_span\": {}, \"columns\": [",
            string(&table.name),
            span(table.name_span)
        );
        for (j, column) in table.columns.iter().enumerate() {
            out.push_str(if j == 0 { "\n" } else { ",\n" });
            let _ = write!(
                out,
                "      {{ \"name\": {}, \"type\": {}, \"pk\": {}, \"not_null\": {}, \
                 \"unique\": {}, \"fk\": {}, \"name_span\": {}, \"type_span\": {} }}",
                string(&column.name),
                string(&column.ty),
                column.pk,
                column.not_null,
                column.unique,
                column.fk,
                span(Some(column.name_span)),
                span(column.ty_span)
            );
        }
        out.push_str(if table.columns.is_empty() {
            "] }"
        } else {
            "\n    ] }"
        });
    }
    out.push_str(if schema.tables.is_empty() {
        "],\n"
    } else {
        "\n  ],\n"
    });

    out.push_str("  \"relations\": [");
    for (i, relation) in schema.relations.iter().enumerate() {
        out.push_str(if i == 0 { "\n" } else { ",\n" });
        let _ = write!(
            out,
            "    {{ \"from\": {}, \"from_columns\": {}, \"to\": {}, \"to_columns\": {}, \
             \"to_missing\": {} }}",
            string(&relation.from_table),
            strings(&relation.from_cols),
            string(&relation.to_table),
            strings(&relation.to_cols),
            relation.to_missing
        );
    }
    out.push_str(if schema.relations.is_empty() {
        "],\n"
    } else {
        "\n  ],\n"
    });

    out.push_str("  \"warnings\": [");
    for (i, warning) in schema.warnings.iter().enumerate() {
        out.push_str(if i == 0 { "\n" } else { ",\n" });
        let _ = write!(
            out,
            "    {{ \"message\": {}, \"span\": {} }}",
            string(&warning.message),
            span(warning.span)
        );
    }
    out.push_str(if schema.warnings.is_empty() {
        "]\n}\n"
    } else {
        "\n  ]\n}\n"
    });
    out
}

fn span(span: Option<Span>) -> String {
    match span {
        Some(s) => format!("[{}, {}]", s.start, s.end),
        None => "null".to_owned(),
    }
}

fn strings(values: &[String]) -> String {
    let items: Vec<String> = values.iter().map(|v| string(v)).collect();
    format!("[{}]", items.join(", "))
}

fn string(value: &str) -> String {
    let mut out = String::with_capacity(value.len() + 2);
    out.push('"');
    for c in value.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => {
                let _ = write!(out, "\\u{:04x}", c as u32);
            }
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn control_characters_and_quotes_cannot_break_the_document() {
        assert_eq!(string("a\"b\\c\nd\u{1}"), "\"a\\\"b\\\\c\\nd\\u0001\"");
    }

    /// An empty schema still has to produce parseable JSON, not `[,]`.
    #[test]
    fn an_empty_schema_is_still_valid_json() {
        let out = schema(&draft_ddl::parse(""));
        assert_eq!(
            out.trim(),
            "{\n  \"tables\": [],\n  \"relations\": [],\n  \"warnings\": []\n}"
        );
    }

    #[test]
    fn braces_and_brackets_balance_on_a_real_schema() {
        let out = schema(&draft_ddl::parse(
            "CREATE TABLE a (id int PRIMARY KEY);
             CREATE TABLE b (a_id int REFERENCES a(id));
             CREATE TABLE ;",
        ));
        assert_eq!(out.matches('{').count(), out.matches('}').count(), "{out}");
        assert_eq!(out.matches('[').count(), out.matches(']').count(), "{out}");
        assert!(out.contains("\"to_missing\": false"));
        assert!(out.contains("\"warnings\": [\n"));
        assert!(!out.contains(",\n  ]"), "a trailing comma crept in");
    }
}
