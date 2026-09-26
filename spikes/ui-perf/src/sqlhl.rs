//! Minimal SQL highlighter.
//!
//! A preview of the real lexer: one linear pass, no regex, no backtracking. In
//! the shipped app this is the *same* tokenizer that feeds the parser, so the
//! editor and the diagram can never disagree about where a string literal ends.
//! Pulling in `syntect` instead would mean a second tokenizer to keep in sync
//! and a large wasm dependency for the privilege.

use egui::text::{LayoutJob, TextFormat};
use egui::{Color32, FontId};

#[derive(Clone, Copy, PartialEq)]
enum Tok {
    Plain,
    Keyword,
    Type,
    Str,
    Comment,
    Number,
    Punct,
}

const KEYWORDS: &[&str] = &[
    "create", "table", "alter", "add", "constraint", "primary", "key", "foreign",
    "references", "not", "null", "unique", "default", "if", "exists", "or",
    "replace", "temporary", "temp", "transient", "index", "on", "only", "check",
    "cascade", "delete", "update", "set", "with", "as", "select", "from", "join",
    "where", "generated", "always", "identity", "collate", "using", "public",
];

const TYPES: &[&str] = &[
    "int", "integer", "bigint", "smallint", "tinyint", "serial", "bigserial",
    "text", "varchar", "char", "nvarchar", "nchar", "boolean", "bool", "date",
    "time", "timestamp", "timestamptz", "datetime", "datetime2", "numeric",
    "decimal", "real", "float", "double", "precision", "json", "jsonb", "uuid",
    "bytea", "blob", "binary", "varbinary", "inet", "money", "enum", "array",
];

fn colour(tok: Tok) -> Color32 {
    // Dark-theme palette, roughly matching the reference tool so a side-by-side
    // comparison is about performance rather than taste.
    match tok {
        Tok::Plain => Color32::from_rgb(0xc4, 0xcc, 0xd6),
        Tok::Keyword => Color32::from_rgb(0x5a, 0xa7, 0xff),
        Tok::Type => Color32::from_rgb(0x7d, 0xd3, 0xa0),
        Tok::Str => Color32::from_rgb(0xe5, 0xa0, 0x6b),
        Tok::Comment => Color32::from_rgb(0x6f, 0x7b, 0x8a),
        Tok::Number => Color32::from_rgb(0xf5, 0xc4, 0x51),
        Tok::Punct => Color32::from_rgb(0x8a, 0x95, 0xa3),
    }
}

/// Classify `sql` into (byte_range, kind) runs.
///
/// Returned runs are contiguous and cover the whole input, so the caller can
/// append them to a `LayoutJob` without tracking gaps.
fn scan(sql: &str) -> Vec<(usize, usize, Tok)> {
    let bytes = sql.as_bytes();
    let n = bytes.len();
    let mut out: Vec<(usize, usize, Tok)> = Vec::with_capacity(n / 8);
    let mut i = 0;

    while i < n {
        let c = bytes[i];
        let start = i;

        // Line comment: -- or #
        if (c == b'-' && i + 1 < n && bytes[i + 1] == b'-') || c == b'#' {
            while i < n && bytes[i] != b'\n' {
                i += 1;
            }
            out.push((start, i, Tok::Comment));
            continue;
        }

        // Block comment
        if c == b'/' && i + 1 < n && bytes[i + 1] == b'*' {
            i += 2;
            while i + 1 < n && !(bytes[i] == b'*' && bytes[i + 1] == b'/') {
                i += 1;
            }
            i = (i + 2).min(n);
            out.push((start, i, Tok::Comment));
            continue;
        }

        // Quoted: '…' is a literal; "…", `…`, [.…] are identifiers, but for
        // highlighting they read the same.
        if c == b'\'' || c == b'"' || c == b'`' || c == b'[' {
            let close = match c {
                b'[' => b']',
                other => other,
            };
            i += 1;
            while i < n {
                if bytes[i] == close && (i == 0 || bytes[i - 1] != b'\\') {
                    i += 1;
                    break;
                }
                i += 1;
            }
            out.push((start, i, Tok::Str));
            continue;
        }

        if c.is_ascii_digit() {
            while i < n && (bytes[i].is_ascii_digit() || bytes[i] == b'.') {
                i += 1;
            }
            out.push((start, i, Tok::Number));
            continue;
        }

        if c.is_ascii_alphabetic() || c == b'_' {
            while i < n && (bytes[i].is_ascii_alphanumeric() || bytes[i] == b'_') {
                i += 1;
            }
            // ASCII-only lowercase compare avoids allocating a String per word,
            // which at ~15k words per repaint is the difference between a
            // linear pass and a garbage storm.
            let word = &sql[start..i];
            let kind = if KEYWORDS.iter().any(|k| k.eq_ignore_ascii_case(word)) {
                Tok::Keyword
            } else if TYPES.iter().any(|t| t.eq_ignore_ascii_case(word)) {
                Tok::Type
            } else {
                Tok::Plain
            };
            out.push((start, i, kind));
            continue;
        }

        // Everything else, coalesced into runs so we emit fewer job sections.
        while i < n {
            let b = bytes[i];
            if b.is_ascii_alphanumeric()
                || b == b'_'
                || b == b'\''
                || b == b'"'
                || b == b'`'
                || b == b'['
                || b == b'#'
                || (b == b'-' && i + 1 < n && bytes[i + 1] == b'-')
                || (b == b'/' && i + 1 < n && bytes[i + 1] == b'*')
            {
                break;
            }
            i += 1;
        }
        if i == start {
            i += 1; // never stall, whatever the input
        }
        let kind = if sql[start..i].trim().is_empty() { Tok::Plain } else { Tok::Punct };
        out.push((start, i, kind));
    }
    out
}

pub fn highlight(sql: &str, font: FontId) -> LayoutJob {
    let mut job = LayoutJob::default();
    for (a, b, tok) in scan(sql) {
        job.append(
            &sql[a..b],
            0.0,
            TextFormat { font_id: font.clone(), color: colour(tok), ..Default::default() },
        );
    }
    job
}
