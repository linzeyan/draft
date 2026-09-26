//! Classifying SQL for an editor, using the parser's own lexical rules.
//!
//! This exists here rather than in the application for one reason: the editor
//! and the diagram must never disagree about where a string ends. A second
//! tokenizer — hand-written or from `syntect` — would drift, and would be wrong
//! about exactly the constructs that are hard: doubled quote escapes, MySQL
//! backslashes, PostgreSQL dollar-quoted function bodies. Those are already
//! solved in [`crate::scan`], so highlighting reuses them instead of guessing.
//!
//! `syntect` was the alternative. It is a large dependency, a second grammar to
//! keep in step, and it would be answering a question we can already answer.

use crate::Span;
use crate::scan::{skip_dollar_quoted, skip_quoted};

/// What a run of source text is.
///
/// Deliberately coarse: this drives colours, not semantics. The parser's own
/// output is what knows whether an identifier names a table.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Token {
    /// An identifier, or any word that is neither a keyword nor a type name.
    Plain,
    Keyword,
    /// A word that names a type: `bigint`, `varchar`, `timestamptz`.
    Type,
    /// A string literal, including a dollar-quoted body.
    Literal,
    /// A delimited identifier: `"id"`, `` `id` ``, `[id]`.
    Quoted,
    Comment,
    Number,
    /// Operators and separators. Whitespace is [`Token::Plain`].
    Punct,
}

/// Words that shape a statement. Not the full SQL vocabulary — a keyword list
/// that tries to be exhaustive ends up colouring column names, which is worse
/// than leaving a rare keyword plain.
const KEYWORDS: &[&str] = &[
    "add",
    "alter",
    "always",
    "as",
    "asc",
    "auto_increment",
    "begin",
    "by",
    "cascade",
    "check",
    "collate",
    "column",
    "comment",
    "constraint",
    "create",
    "cluster",
    "database",
    "default",
    "deferrable",
    "delete",
    "delimiter",
    "desc",
    "distinct",
    "drop",
    "end",
    "engine",
    "exists",
    "foreign",
    "from",
    "fulltext",
    "generated",
    "group",
    "identity",
    "if",
    "index",
    "inherits",
    "insert",
    "into",
    "join",
    "key",
    "like",
    "not",
    "null",
    "on",
    "only",
    "or",
    "order",
    "primary",
    "references",
    "replace",
    "restrict",
    "returns",
    "schema",
    "select",
    "sequence",
    "set",
    "spatial",
    "stored",
    "table",
    "temp",
    "temporary",
    "transient",
    "trigger",
    "unique",
    "unlogged",
    "unsigned",
    "update",
    "using",
    "values",
    "view",
    "virtual",
    "where",
    "with",
    "without",
];

const TYPES: &[&str] = &[
    "array",
    "bigint",
    "bigserial",
    "binary",
    "bit",
    "blob",
    "bool",
    "boolean",
    "bytea",
    "char",
    "character",
    "clob",
    "date",
    "datetime",
    "datetime2",
    "decimal",
    "double",
    "enum",
    "float",
    "geography",
    "geometry",
    "inet",
    "int",
    "int2",
    "int4",
    "int8",
    "integer",
    "interval",
    "json",
    "jsonb",
    "longblob",
    "longtext",
    "mediumint",
    "mediumtext",
    "money",
    "nchar",
    "numeric",
    "nvarchar",
    "precision",
    "real",
    "serial",
    "set",
    "smallint",
    "smallserial",
    "text",
    "time",
    "timestamp",
    "timestamptz",
    "tinyint",
    "tinytext",
    "uuid",
    "varbinary",
    "varchar",
    "varying",
    "xml",
    "year",
];

/// Classify `sql` into runs.
///
/// The runs are contiguous and cover every byte, so a caller building a styled
/// text layout can append them one after another without tracking gaps. They
/// are also always at a character boundary, because every branch here either
/// consumes whole multi-byte characters or stops at an ASCII delimiter.
pub fn highlight(sql: &str) -> Vec<(Span, Token)> {
    highlight_until(sql, sql.len())
}

/// Classify `sql`, starting no new run at or past `to`.
///
/// The lexer has to start at the beginning — a string or a block comment opened
/// earlier decides how everything after it reads — but it does not have to
/// finish. A caller colouring the part of a document that is on screen pays for
/// the prefix it cannot skip and nothing for the rest, which is what keeps the
/// cost of a keystroke off the size of the file below the caret. A run that
/// begins before `to` is still emitted whole, so the last one may overhang.
pub fn highlight_until(sql: &str, to: usize) -> Vec<(Span, Token)> {
    let b = sql.as_bytes();
    let n = b.len();
    let stop = to.min(n);
    // Roughly one run per four bytes on real DDL; over-reserving a little is
    // cheaper than growing while the user is typing.
    let mut out: Vec<(Span, Token)> = Vec::with_capacity(stop / 4 + 8);
    let mut i = 0;

    while i < stop {
        let start = i;
        let c = b[i];

        // Comments, in all three spellings the parser accepts.
        if (c == b'-' && b.get(i + 1) == Some(&b'-')) || c == b'#' {
            while i < n && b[i] != b'\n' {
                i += 1;
            }
            push(&mut out, start, i, Token::Comment);
            continue;
        }
        if c == b'/' && b.get(i + 1) == Some(&b'*') {
            i += 2;
            while i + 1 < n && !(b[i] == b'*' && b[i + 1] == b'/') {
                i += 1;
            }
            i = (i + 2).min(n);
            push(&mut out, start, i, Token::Comment);
            continue;
        }

        // Strings and delimited identifiers, via the parser's own skipper, so an
        // escaped or doubled delimiter ends the run in exactly the same place
        // the parse does.
        if matches!(c, b'\'' | b'"' | b'`' | b'[') {
            i = skip_quoted(b, i);
            let kind = if c == b'\'' {
                Token::Literal
            } else {
                Token::Quoted
            };
            push(&mut out, start, i, kind);
            continue;
        }
        if c == b'$'
            && let Some(end) = skip_dollar_quoted(b, i)
        {
            i = end;
            push(&mut out, start, i, Token::Literal);
            continue;
        }

        if c.is_ascii_digit() {
            while i < n && (b[i].is_ascii_digit() || b[i] == b'.') {
                i += 1;
            }
            push(&mut out, start, i, Token::Number);
            continue;
        }

        if c.is_ascii_alphabetic() || c == b'_' || c >= 0x80 {
            while i < n && (b[i].is_ascii_alphanumeric() || b[i] == b'_' || b[i] >= 0x80) {
                i += 1;
            }
            push(&mut out, start, i, classify(&sql[start..i]));
            continue;
        }

        // Whitespace and punctuation, each coalesced into a run so the editor
        // gets a handful of sections per line rather than one per character.
        let punct = !c.is_ascii_whitespace();
        while i < n {
            let c = b[i];
            let same_kind = c.is_ascii_whitespace() != punct;
            if !same_kind
                || c.is_ascii_alphanumeric()
                || c == b'_'
                || c >= 0x80
                || matches!(c, b'\'' | b'"' | b'`' | b'[' | b'#' | b'$')
                || (c == b'-' && b.get(i + 1) == Some(&b'-'))
                || (c == b'/' && b.get(i + 1) == Some(&b'*'))
            {
                break;
            }
            i += 1;
        }
        if i == start {
            // Never stall, whatever the input.
            i += 1;
        }
        push(
            &mut out,
            start,
            i,
            if punct { Token::Punct } else { Token::Plain },
        );
    }
    out
}

fn push(out: &mut Vec<(Span, Token)>, start: usize, end: usize, token: Token) {
    // Merging adjacent runs of the same kind matters more than it looks: each
    // run becomes a section in a text layout, and sections are what the layout
    // cost scales with.
    if let Some((span, last)) = out.last_mut()
        && *last == token
        && span.end == start
    {
        span.end = end;
        return;
    }
    out.push((Span::new(start, end), token));
}

/// ASCII-only comparison against the two word lists, with no allocation: at
/// ~15,000 words per rehighlight, lowercasing each one would be a garbage storm
/// rather than a lookup.
fn classify(word: &str) -> Token {
    if KEYWORDS.iter().any(|k| k.eq_ignore_ascii_case(word)) {
        Token::Keyword
    } else if TYPES.iter().any(|t| t.eq_ignore_ascii_case(word)) {
        Token::Type
    } else {
        Token::Plain
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn runs(sql: &str) -> Vec<(&str, Token)> {
        highlight(sql)
            .into_iter()
            .map(|(span, token)| (span.text(sql), token))
            .collect()
    }

    /// The property every caller depends on: append the runs in order and you
    /// get the input back. A gap or an overlap would silently drop or duplicate
    /// the user's text on screen.
    #[test]
    fn runs_tile_the_input_exactly() {
        for sql in [
            "",
            "CREATE TABLE t (id int);",
            "-- just a comment",
            "/* unterminated",
            "'unterminated",
            "select '\\'' , \"quo\"\"ted\", `back`, [bracket];",
            "create table \u{5ba2}\u{6236} (\u{540d} text); -- \u{4e2d}\u{6587}\n",
            include_str!("../../../fixtures/dialects/malformed.sql"),
            include_str!("../../../fixtures/real/sakila-mysqldump.sql"),
        ] {
            let runs = highlight(sql);
            let mut at = 0;
            let mut rebuilt = String::with_capacity(sql.len());
            for (span, _) in &runs {
                assert_eq!(
                    span.start,
                    at,
                    "gap or overlap in {:?}",
                    &sql[..40.min(sql.len())]
                );
                assert!(span.end > span.start, "empty run");
                rebuilt.push_str(span.text(sql));
                at = span.end;
            }
            assert_eq!(at, sql.len(), "runs stopped short");
            assert_eq!(rebuilt, sql);
        }
    }

    /// Stopping early must mean *fewer* runs, never different ones. The prefix
    /// of a document decides how the rest of it reads — an unterminated comment
    /// swallows everything after it — so the lexer starts at the beginning
    /// whether or not it is asked to finish. The only licensed difference is
    /// that the last run may be cut short of where the full pass merged it to.
    #[test]
    fn stopping_early_gives_a_prefix_of_the_same_runs() {
        let flat = |runs: Vec<(Span, Token)>| {
            runs.into_iter()
                .map(|(s, t)| (s.start, s.end, t))
                .collect::<Vec<_>>()
        };
        for sql in [
            "CREATE TABLE t (/* c */ id int, name text); -- tail\n",
            "/* everything after here is a comment\nCREATE TABLE t (id int);",
            "select 'a string with ; and -- in it', \"quo\"\"ted\";",
        ] {
            let all = flat(highlight(sql));
            for to in 0..=sql.len() {
                let part = flat(highlight_until(sql, to));
                let expected = all.iter().take_while(|(start, ..)| *start < to).count();
                assert_eq!(part.len(), expected, "at {to} in {sql:?}");
                if let Some(((start, end, token), rest)) = part.split_last() {
                    assert_eq!(rest, &all[..rest.len()], "at {to} in {sql:?}");
                    let (was_start, was_end, was_token) = all[rest.len()];
                    assert_eq!((*start, *token), (was_start, was_token), "at {to}");
                    assert!(*end <= was_end, "the last run grew past the full pass");
                }
            }
        }
    }

    /// Identifiers and the whitespace around them share a colour, so they also
    /// share a run — one section instead of three, on every word in the file.
    #[test]
    fn words_are_sorted_into_keywords_types_and_everything_else() {
        assert_eq!(
            runs("CREATE TABLE orders (id BIGINT)"),
            [
                ("CREATE", Token::Keyword),
                (" ", Token::Plain),
                ("TABLE", Token::Keyword),
                (" orders ", Token::Plain),
                ("(", Token::Punct),
                ("id ", Token::Plain),
                ("BIGINT", Token::Type),
                (")", Token::Punct),
            ]
        );
    }

    /// The whole reason this lives in the parser's crate: a comment marker
    /// inside a literal is not a comment, and the editor must agree with the
    /// parse about that or the colours will say one thing and the diagram
    /// another.
    #[test]
    fn a_comment_marker_inside_a_literal_is_not_a_comment() {
        assert_eq!(
            runs("default '-- not a comment'"),
            [
                ("default", Token::Keyword),
                (" ", Token::Plain),
                ("'-- not a comment'", Token::Literal),
            ]
        );
        assert_eq!(
            runs("'it''s -- fine'"),
            [("'it''s -- fine'", Token::Literal)]
        );
    }

    /// A `pg_dump` is mostly function bodies. Colouring their contents as SQL
    /// keywords would be noise, and — worse — would disagree with a parser that
    /// skips the whole region.
    #[test]
    fn a_dollar_quoted_body_is_one_literal() {
        let sql = "CREATE FUNCTION f() RETURNS int AS $$ SELECT 1; -- x\n$$;";
        let runs = runs(sql);
        assert!(
            runs.iter()
                .any(|(text, token)| *token == Token::Literal && text.starts_with("$$")),
            "{runs:?}"
        );
    }

    /// Each run becomes a section in a text layout, and layout cost scales with
    /// sections, so merging is a performance property rather than a tidiness
    /// one.
    #[test]
    fn adjacent_runs_of_one_kind_are_merged() {
        assert_eq!(
            runs("a ==> b"),
            [
                ("a ", Token::Plain),
                ("==>", Token::Punct),
                (" b", Token::Plain)
            ]
        );
        // The claim that matters is about real input, where most bytes belong
        // to a neighbour of the same kind.
        let dump = include_str!("../../../fixtures/real/pagila-pg_dump.sql");
        let runs = highlight(dump).len();
        assert!(
            runs * 3 < dump.len(),
            "{runs} sections for {} bytes is too many to lay out per keystroke",
            dump.len()
        );
    }
}
