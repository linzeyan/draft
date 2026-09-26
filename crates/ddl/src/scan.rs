//! Lexical scanning that keeps byte offsets into the original SQL valid.
//!
//! Everything here works on the *blanked* buffer produced by [`blank_comments`]
//! but reports offsets that are equally valid in the original source, because
//! blanking a comment never changes the length of the text. That equality is
//! the whole reason two-way editing can be a byte splice instead of a
//! regeneration.
//!
//! Ported from sqltoerdiagram's `src/parser.js` (MIT) — see NOTICE. The port
//! works on bytes rather than UTF-16 code units, drops the regular expressions
//! in favour of the token stream, and handles doubled-delimiter escapes.

use crate::Span;

/// A slice of source text together with its absolute byte offset.
#[derive(Clone, Copy, Debug)]
pub(crate) struct Chunk<'a> {
    pub text: &'a str,
    pub start: usize,
}

/// A lexical token. `text` borrows the blanked buffer; the offsets address the
/// original SQL just as well.
#[derive(Clone, Copy, Debug)]
pub(crate) struct Token<'a> {
    pub text: &'a str,
    pub start: usize,
    pub end: usize,
}

impl<'a> Token<'a> {
    /// Case-insensitive keyword test. SQL keywords are ASCII, so
    /// `eq_ignore_ascii_case` is both correct and allocation-free.
    pub fn is(&self, word: &str) -> bool {
        self.text.eq_ignore_ascii_case(word)
    }

    pub fn is_group(&self) -> bool {
        self.text.starts_with('(')
    }

    /// Inner text of a `( … )` group plus the absolute offset of that text.
    pub fn group_inner(&self) -> (&'a str, usize) {
        let inner = self.text.strip_prefix('(').unwrap_or(self.text);
        let inner = inner.strip_suffix(')').unwrap_or(inner);
        (inner, self.start + 1)
    }

    /// Span of the bare identifier this token holds: the part after the last
    /// dot, with one matched pair of wrapping delimiters removed. This is the
    /// span a rename splices, so it must exclude the quotes and the schema
    /// qualifier — replacing those would corrupt the statement.
    pub fn bare_span(&self) -> Span {
        let (mut lo, mut hi) = (0, self.text.len());
        if unwrap_delims(self.text).is_none()
            && let Some(dot) = last_qualifier_dot(self.text)
        {
            lo = dot + 1;
        }
        if unwrap_delims(&self.text[lo..hi]).is_some() {
            lo += 1;
            hi -= 1; // delimiters are ASCII, so one byte each
        }
        Span::new(self.start + lo, self.start + hi)
    }

    /// The token's identifier text, unqualified and unquoted.
    pub fn bare_name(&self) -> &'a str {
        bare_name(self.text)
    }
}

/// Strip one *matched* wrapping delimiter pair: `` `id` ``, `"id"`, `[id]`.
///
/// "Matched" is load-bearing in both directions. Stripping the sides
/// independently would mangle the type `TEXT[]` (no leading `[`) into `TEXT[`
/// by dropping the trailing `]`; accepting any delimiter at each end would
/// mangle the *qualified* name `"public"."users"` into `public"."users`. So the
/// opening delimiter's own partner has to be the final byte.
fn unwrap_delims(id: &str) -> Option<&str> {
    let b = id.as_bytes();
    if b.len() < 2 {
        return None;
    }
    let close = match b[0] {
        b'`' => b'`',
        b'"' => b'"',
        b'[' => b']',
        _ => return None,
    };
    (b[b.len() - 1] == close && skip_quoted(b, 0) == b.len()).then(|| &id[1..id.len() - 1])
}

/// The last dot that separates a qualifier from a name — dots inside a quoted
/// identifier belong to the name itself.
fn last_qualifier_dot(id: &str) -> Option<usize> {
    let b = id.as_bytes();
    let (mut i, mut last) = (0, None);
    while i < b.len() {
        match b[i] {
            b'`' | b'"' | b'[' | b'\'' => {
                i = skip_quoted(b, i);
                continue;
            }
            b'.' => last = Some(i),
            _ => {}
        }
        i += 1;
    }
    last
}

pub(crate) fn clean(id: &str) -> &str {
    let id = id.trim();
    unwrap_delims(id).unwrap_or(id)
}

/// The unqualified, unquoted form of a possibly `schema.qualified` identifier.
pub(crate) fn bare_name(id: &str) -> &str {
    let id = id.trim();
    // A fully wrapped identifier may legitimately contain a dot ("my.table"),
    // so unwrap before considering the qualifier, not after.
    if let Some(inner) = unwrap_delims(id) {
        return inner;
    }
    match last_qualifier_dot(id) {
        Some(dot) => clean(&id[dot + 1..]),
        None => id,
    }
}

/// Index just past the string or quoted identifier opening at `i`, or the end
/// of input if it is unterminated. Handles both escape conventions we meet in
/// the wild: a doubled delimiter (`''`, SQL standard) and a backslash (MySQL).
pub(crate) fn skip_quoted(s: &[u8], i: usize) -> usize {
    let open = s[i];
    let close = if open == b'[' { b']' } else { open };
    let mut j = i + 1;
    while j < s.len() {
        if s[j] == b'\\' && open == b'\'' && j + 1 < s.len() {
            j += 2;
            continue;
        }
        if s[j] == close {
            if s.get(j + 1) == Some(&close) {
                j += 2;
                continue;
            }
            return j + 1;
        }
        j += 1;
    }
    s.len()
}

/// Index just past a PostgreSQL dollar-quoted string starting at `i`, or
/// `None` if one does not start there.
///
/// These wrap function bodies, and a function body is arbitrary text: `;`,
/// unbalanced parentheses, apostrophes and whole `CREATE TABLE` statements that
/// are emphatically not part of the schema. Skipping the region wholesale is
/// what keeps a `pg_dump` full of plpgsql from derailing the parse — real dumps
/// found this, `fixtures/real/pagila-pg_dump.sql` keeps it found.
pub(crate) fn skip_dollar_quoted(s: &[u8], i: usize) -> Option<usize> {
    if s[i] != b'$' {
        return None;
    }
    // `a$b` is one identifier, not an identifier and a quote.
    if i > 0 && (s[i - 1].is_ascii_alphanumeric() || s[i - 1] == b'_') {
        return None;
    }
    let mut tag_end = i + 1;
    while tag_end < s.len() && (s[tag_end].is_ascii_alphanumeric() || s[tag_end] == b'_') {
        tag_end += 1;
    }
    if s.get(tag_end) != Some(&b'$') {
        return None;
    }
    let tag = &s[i..=tag_end];
    // A tag is an identifier, so `$1$` is two positional parameters rather than
    // an opener.
    if tag.len() > 2 && tag[1].is_ascii_digit() {
        return None;
    }
    let body = tag_end + 1;
    Some(
        s[body..]
            .windows(tag.len())
            .position(|w| w == tag)
            .map_or(s.len(), |p| body + p + tag.len()),
    )
}

/// Replace comments with same-length whitespace, preserving newlines so line
/// numbers survive. Every byte offset into the result maps 1:1 to the original.
pub(crate) fn blank_comments(sql: &str) -> String {
    let s = sql.as_bytes();
    let mut out = Vec::with_capacity(s.len());
    let mut i = 0;
    while i < s.len() {
        match (s[i], s.get(i + 1)) {
            (b'-', Some(b'-')) | (b'#', _) => {
                while i < s.len() && s[i] != b'\n' {
                    out.push(b' ');
                    i += 1;
                }
            }
            (b'/', Some(b'*')) => {
                let start = i;
                i += 2;
                while i < s.len() && !(s[i] == b'*' && s.get(i + 1) == Some(&b'/')) {
                    i += 1;
                }
                i = (i + 2).min(s.len());
                out.extend(
                    s[start..i]
                        .iter()
                        .map(|&c| if c == b'\n' { b'\n' } else { b' ' }),
                );
            }
            (b'\'' | b'"' | b'`', _) => {
                let end = skip_quoted(s, i);
                out.extend_from_slice(&s[i..end]);
                i = end;
            }
            (b'$', _) if skip_dollar_quoted(s, i).is_some() => {
                let end = skip_dollar_quoted(s, i).unwrap_or(i + 1);
                out.extend_from_slice(&s[i..end]);
                i = end;
            }
            _ => {
                out.push(s[i]);
                i += 1;
            }
        }
    }
    debug_assert_eq!(out.len(), s.len(), "blanking must preserve byte offsets");
    // Comment bytes are replaced whole-sequence-at-a-time, so the result is
    // always valid UTF-8; the fallback exists only so a bug here degrades the
    // parse instead of panicking.
    String::from_utf8(out).unwrap_or_else(|_| sql.to_owned())
}

/// Split into statements, ignoring terminators inside parens, strings and
/// function bodies.
///
/// Honours `DELIMITER`, which `mysqldump` wraps around every stored routine.
/// Without it the routine body is split into statements of its own and any
/// `CREATE TEMPORARY TABLE` inside leaks into the schema as a real table —
/// `fixtures/real/sakila-mysqldump.sql` is the case that proved it.
pub(crate) fn split_statements<'a>(s: &'a str) -> Vec<Chunk<'a>> {
    const DIRECTIVE: &[u8] = b"delimiter";
    let b = s.as_bytes();
    let mut out = Vec::new();
    let mut terminator: &str = ";";
    let (mut depth, mut start, mut i) = (0i32, 0usize, 0usize);

    let push = |out: &mut Vec<Chunk<'a>>, from: usize, to: usize| {
        if !s[from..to].trim().is_empty() {
            out.push(Chunk {
                text: &s[from..to],
                start: from,
            });
        }
    };

    while i < b.len() {
        // Screen on the first byte before the nine-byte comparison; this loop
        // visits every byte of the script.
        if (b[i] | 0x20) == b'd'
            && (i == 0 || b[i - 1] == b'\n')
            && b.len() - i > DIRECTIVE.len()
            && b[i..i + DIRECTIVE.len()].eq_ignore_ascii_case(DIRECTIVE)
            && b[i + DIRECTIVE.len()].is_ascii_whitespace()
        {
            let eol = b[i..]
                .iter()
                .position(|&c| c == b'\n')
                .map_or(b.len(), |p| i + p);
            let arg = s[i + DIRECTIVE.len()..eol].trim();
            if !arg.is_empty() {
                terminator = arg;
                push(&mut out, start, i);
                start = (eol + 1).min(b.len());
                i = start;
                continue;
            }
        }
        // A one-byte terminator is the overwhelmingly common case.
        let term = terminator.as_bytes();
        let at_terminator = match term {
            [only] => b[i] == *only,
            _ => b[i..].starts_with(term),
        };
        if depth <= 0 && at_terminator {
            push(&mut out, start, i);
            start = i + terminator.len();
            i = start;
            continue;
        }
        match b[i] {
            b'\'' | b'"' | b'`' => {
                i = skip_quoted(b, i);
                continue;
            }
            b'$' => {
                if let Some(end) = skip_dollar_quoted(b, i) {
                    i = end;
                    continue;
                }
            }
            b'(' => depth += 1,
            b')' => depth -= 1,
            _ => {}
        }
        i += 1;
    }
    push(&mut out, start, b.len());
    out
}

/// Split a parenthesised body on top-level commas. `base` is the absolute
/// offset of `body` in the source.
pub(crate) fn split_top_commas(body: &str, base: usize) -> Vec<Chunk<'_>> {
    let mut parts = split_on(body, base, b',');
    // `split_on` drops a blank trailing remainder, which is right for
    // statements but would silently lose an empty final column definition.
    if parts.is_empty() {
        parts.push(Chunk {
            text: body,
            start: base,
        });
    }
    parts
}

fn split_on(s: &str, base: usize, sep: u8) -> Vec<Chunk<'_>> {
    let b = s.as_bytes();
    let mut out = Vec::new();
    let (mut depth, mut start, mut i) = (0i32, 0usize, 0usize);
    while i < b.len() {
        match b[i] {
            b'\'' | b'"' | b'`' => {
                i = skip_quoted(b, i);
                continue;
            }
            b'$' if skip_dollar_quoted(b, i).is_some() => {
                i = skip_dollar_quoted(b, i).unwrap_or(i + 1);
                continue;
            }
            b'(' => depth += 1,
            b')' => depth -= 1,
            c if c == sep && depth <= 0 => {
                out.push(Chunk {
                    text: &s[start..i],
                    start: base + start,
                });
                start = i + 1;
            }
            _ => {}
        }
        i += 1;
    }
    if !s[start..].trim().is_empty() {
        out.push(Chunk {
            text: &s[start..],
            start: base + start,
        });
    }
    out
}

/// Tokenise a definition. Parenthesised runs and quoted identifiers each
/// collapse into a single token, commas are dropped, and every token carries
/// its absolute span.
pub(crate) fn tokenize(def: &str, base: usize) -> Vec<Token<'_>> {
    let b = def.as_bytes();
    let mut tokens = Vec::new();
    let mut i = 0;
    while i < b.len() {
        match b[i] {
            c if c.is_ascii_whitespace() => i += 1,
            b',' => i += 1,
            b'(' => {
                let start = i;
                let mut depth = 0i32;
                while i < b.len() {
                    match b[i] {
                        b'\'' | b'"' | b'`' => {
                            i = skip_quoted(b, i);
                            continue;
                        }
                        b'(' => depth += 1,
                        b')' => {
                            depth -= 1;
                            if depth == 0 {
                                i += 1;
                                break;
                            }
                        }
                        _ => {}
                    }
                    i += 1;
                }
                tokens.push(Token {
                    text: &def[start..i],
                    start: base + start,
                    end: base + i,
                });
            }
            // One token per identifier or literal, quoted parts included. A
            // qualified name like `"public"."users"` has to stay whole: the
            // pieces are what a rename must avoid splicing.
            _ => {
                let start = i;
                loop {
                    match b.get(i) {
                        Some(b'`' | b'"' | b'[' | b'\'') => i = skip_quoted(b, i),
                        Some(b'$') if skip_dollar_quoted(b, i).is_some() => {
                            i = skip_dollar_quoted(b, i).unwrap_or(i + 1);
                        }
                        Some(&c) if !matches!(c, b'(' | b',') && !c.is_ascii_whitespace() => i += 1,
                        _ => break,
                    }
                }
                tokens.push(Token {
                    text: &def[start..i],
                    start: base + start,
                    end: base + i,
                });
            }
        }
    }
    tokens
}

/// Normalise a raw type for display: lowercase, with whitespace collapsed and
/// removed around punctuation. `CHARACTER  VARYING (255)` → `character varying(255)`.
pub(crate) fn pretty_type(raw: &str) -> String {
    let raw = raw.trim();
    // SQL Server writes types as delimited identifiers: `[nvarchar](70)`.
    let unwrapped;
    let raw = match raw.as_bytes().first() {
        Some(b'[' | b'"' | b'`') => {
            let head = skip_quoted(raw.as_bytes(), 0);
            match unwrap_delims(&raw[..head]) {
                Some(inner) => {
                    unwrapped = format!("{inner}{}", &raw[head..]);
                    unwrapped.as_str()
                }
                None => raw,
            }
        }
        _ => raw,
    };

    let b = raw.as_bytes();
    let mut out = String::with_capacity(raw.len());
    let mut pending_space = false;
    let mut i = 0;
    while i < b.len() {
        // A quoted literal inside a type — `enum('G','PG-13')` — is data, not a
        // keyword. Neither its case nor its spacing is ours to normalise.
        if b[i] == b'\'' {
            let end = skip_quoted(b, i);
            if pending_space && !out.ends_with(['(', ',']) {
                out.push(' ');
            }
            out.push_str(&raw[i..end]);
            pending_space = false;
            i = end;
            continue;
        }
        let Some(c) = raw[i..].chars().next() else {
            break;
        };
        i += c.len_utf8();
        if c.is_whitespace() {
            pending_space = !out.is_empty();
            continue;
        }
        if pending_space && !matches!(c, '(' | ')' | ',') && !out.ends_with(['(', ',']) {
            out.push(' ');
        }
        pending_space = false;
        out.extend(c.to_lowercase());
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The load-bearing property: blanking is length-preserving, so a span
    /// found in the blanked text addresses the same bytes in the original.
    #[test]
    fn blanking_preserves_every_offset() {
        for sql in [
            "create table a (b int); -- trailing\n",
            "/* multi\nline */ create table a (b int);",
            "create table a (b int); # mysql comment\n",
            "insert into a values ('-- not a comment');",
            "select '\\'' , \"quo\"\"ted\";",
            "create table \u{5ba2}\u{6236} (\u{540d} text); -- \u{4e2d}\u{6587}\u{8a3b}\u{89e3}\n",
        ] {
            let blanked = blank_comments(sql);
            assert_eq!(blanked.len(), sql.len(), "length changed for {sql:?}");
            assert_eq!(
                blanked.lines().count(),
                sql.lines().count(),
                "newline count changed for {sql:?}"
            );
        }
    }

    #[test]
    fn comment_markers_inside_strings_survive() {
        let sql = "insert into t values ('a -- b', 'c /* d */ e');";
        assert_eq!(blank_comments(sql), sql);
    }

    #[test]
    fn statements_split_at_top_level_only() {
        let sql = "create table a (b int); insert into c values (';');";
        let stmts = split_statements(sql);
        assert_eq!(stmts.len(), 2);
        assert_eq!(stmts[0].start, 0);
        assert_eq!(stmts[1].text.trim(), "insert into c values (';')");
    }

    #[test]
    fn tokens_group_parens_and_quotes() {
        let toks = tokenize("`id` decimal (10, 2) not null default 'a, b'", 100);
        let texts: Vec<_> = toks.iter().map(|t| t.text).collect();
        assert_eq!(
            texts,
            [
                "`id`", "decimal", "(10, 2)", "not", "null", "default", "'a, b'"
            ]
        );
        assert_eq!(toks[0].start, 100);
        assert_eq!(toks[0].bare_span(), Span::new(101, 103)); // inside the backticks
    }

    #[test]
    fn bare_span_skips_schema_and_quotes() {
        let span = |src: &str| tokenize(src, 0)[0].bare_span();
        assert_eq!(span("users"), Span::new(0, 5));
        assert_eq!(span("public.users"), Span::new(7, 12));
        assert_eq!(span("\"public\".\"users\""), Span::new(10, 15));
        assert_eq!(span("[dbo].[users]"), Span::new(7, 12));
        assert_eq!(span("\"my.table\""), Span::new(1, 9)); // dot is part of the name
    }

    #[test]
    fn array_types_keep_their_brackets() {
        assert_eq!(clean("text[]"), "text[]");
        assert_eq!(bare_name("[dbo].[users]"), "users");
    }

    #[test]
    fn pretty_type_collapses_around_punctuation() {
        assert_eq!(
            pretty_type("CHARACTER  VARYING (255)"),
            "character varying(255)"
        );
        assert_eq!(
            pretty_type("timestamp WITHOUT TIME ZONE"),
            "timestamp without time zone"
        );
        assert_eq!(pretty_type("NUMERIC(10, 2)"), "numeric(10,2)");
        assert_eq!(pretty_type("int"), "int");
        // Enum members are values, so their case and spacing must survive.
        assert_eq!(
            pretty_type("ENUM('G','PG', 'PG-13', 'Deleted Scenes')"),
            "enum('G','PG','PG-13','Deleted Scenes')"
        );
    }
}
