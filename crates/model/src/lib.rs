//! Edits to a SQL script, expressed as byte splices.
//!
//! This is the crate that makes the product's one promise keepable: editing a
//! table on the canvas changes exactly the bytes that had to change, and every
//! other byte of the user's script — comments, indentation, vendor clauses the
//! parser never understood — comes out identical.
//!
//! The mechanism is deliberately dull. [`draft_ddl`] records where every
//! identifier is; an operation here turns "rename this table" into the set of
//! [`Splice`]s that covers every one of those places; [`apply`] performs them.
//! Nothing regenerates SQL from a model, because a regenerated script is a
//! different script.
//!
//! ```
//! let sql = "CREATE TABLE users (id int);  -- keep me\n";
//! let schema = draft_ddl::parse(sql);
//! let edit = draft_model::rename_table(&schema, "users", "people").unwrap();
//! assert_eq!(
//!     draft_model::apply(sql, &edit.splices).unwrap(),
//!     "CREATE TABLE people (id int);  -- keep me\n"
//! );
//! ```

use std::fmt;
use std::ops::Range;

use draft_ddl::{Schema, Span};

/// Replace `range` with `text`.
///
/// Ranges address the *original* script. That is only sound because an [`Edit`]
/// is applied as a set rather than one at a time — see [`apply`].
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Splice {
    pub range: Range<usize>,
    pub text: String,
}

impl Splice {
    pub fn new(span: Span, text: impl Into<String>) -> Self {
        Self {
            range: span.range(),
            text: text.into(),
        }
    }
}

/// One user-level change and the splices that carry it out.
#[derive(Clone, Debug)]
pub struct Edit {
    /// Human-readable, for undo history and CLI output.
    pub summary: String,
    pub splices: Vec<Splice>,
}

impl Edit {
    fn new(summary: String, mut splices: Vec<Splice>) -> Self {
        splices.sort_unstable_by_key(|s| (s.range.start, s.range.end));
        // The same identifier can be reached by two routes — a foreign key
        // declared inline and repeated in an ALTER, say. Identical splices are
        // the same edit, not a conflict.
        splices.dedup_by(|a, b| a.range == b.range && a.text == b.text);
        Self { summary, splices }
    }

    pub fn is_empty(&self) -> bool {
        self.splices.is_empty()
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum EditError {
    NoSuchTable(String),
    NoSuchColumn {
        table: String,
        column: String,
    },
    /// The replacement would need quoting to survive as an identifier. Splicing
    /// it in raw would produce a script that no longer parses, which is exactly
    /// the failure this crate exists to prevent.
    UnsafeIdentifier(String),
    DuplicateColumn {
        table: String,
        column: String,
    },
    /// A `CREATE TABLE` whose body the parser never found, so there is nowhere
    /// to put anything. Refusing beats guessing at an offset.
    NoBody(String),
}

impl fmt::Display for EditError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::NoSuchTable(t) => write!(f, "no table named {t:?}"),
            Self::NoSuchColumn { table, column } => {
                write!(f, "no column named {column:?} in table {table:?}")
            }
            Self::UnsafeIdentifier(s) => {
                write!(f, "{s:?} is not a bare identifier and would need quoting")
            }
            Self::DuplicateColumn { table, column } => {
                write!(f, "table {table:?} already has a column named {column:?}")
            }
            Self::NoBody(t) => write!(f, "table {t:?} has no readable body to add to"),
        }
    }
}

impl std::error::Error for EditError {}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SpliceError {
    OutOfBounds {
        range: Range<usize>,
        len: usize,
    },
    NotACharBoundary {
        at: usize,
    },
    Overlap {
        first: Range<usize>,
        second: Range<usize>,
    },
}

impl fmt::Display for SpliceError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::OutOfBounds { range, len } => {
                write!(
                    f,
                    "splice {}..{} is outside a {len}-byte script",
                    range.start, range.end
                )
            }
            Self::NotACharBoundary { at } => write!(f, "byte {at} is inside a character"),
            Self::Overlap { first, second } => write!(
                f,
                "splices {}..{} and {}..{} overlap",
                first.start, first.end, second.start, second.end
            ),
        }
    }
}

impl std::error::Error for SpliceError {}

/// Apply a set of splices to a script.
///
/// The splices are sorted and applied in one forward pass, which is the same
/// result as applying them right-to-left in place and costs one allocation
/// instead of one per splice. Either way the point is that no splice ever sees
/// offsets shifted by another: they all address the original text.
///
/// Overlapping splices are rejected rather than resolved. Two edits that both
/// claim the same bytes have no correct combined meaning, and guessing one
/// would corrupt the script silently.
pub fn apply(src: &str, splices: &[Splice]) -> Result<String, SpliceError> {
    let mut order: Vec<&Splice> = splices.iter().collect();
    order.sort_by_key(|s| (s.range.start, s.range.end));

    let mut out = String::with_capacity(src.len());
    let mut cursor = 0usize;
    let mut previous: Option<Range<usize>> = None;

    for splice in order {
        let Range { start, end } = splice.range.clone();
        if start > end || end > src.len() {
            return Err(SpliceError::OutOfBounds {
                range: splice.range.clone(),
                len: src.len(),
            });
        }
        for at in [start, end] {
            if !src.is_char_boundary(at) {
                return Err(SpliceError::NotACharBoundary { at });
            }
        }
        if start < cursor {
            return Err(SpliceError::Overlap {
                first: previous.unwrap_or(0..cursor),
                second: splice.range.clone(),
            });
        }
        out.push_str(&src[cursor..start]);
        out.push_str(&splice.text);
        cursor = end;
        previous = Some(splice.range.clone());
    }
    out.push_str(&src[cursor..]);
    Ok(out)
}

/// Whether `name` can be spliced in as-is, without acquiring quotes it does not
/// have. Deliberately conservative: this is the gate on writing to a file the
/// user cannot get back.
pub fn is_bare_identifier(name: &str) -> bool {
    let mut chars = name.chars();
    chars
        .next()
        .is_some_and(|c| c.is_ascii_alphabetic() || c == '_')
        && chars.all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '$')
}

fn check_identifier(name: &str) -> Result<(), EditError> {
    if is_bare_identifier(name) {
        Ok(())
    } else {
        Err(EditError::UnsafeIdentifier(name.to_owned()))
    }
}

/// Rename a table, and with it every `REFERENCES` and `ALTER TABLE` that names
/// it.
///
/// Existing delimiters are preserved for free: the recorded span sits *inside*
/// the quotes, so renaming `` `old` `` yields `` `new` `` and renaming `old`
/// yields `new`.
///
/// Statements the parser skips — `CREATE INDEX`, triggers, views — are out of
/// reach and keep the old name. That is a property of span-based editing, and
/// it is why those statements are worth parsing eventually.
pub fn rename_table(schema: &Schema, table: &str, new_name: &str) -> Result<Edit, EditError> {
    check_identifier(new_name)?;
    let t = schema
        .table(table)
        .ok_or_else(|| EditError::NoSuchTable(table.to_owned()))?;
    let splices = t
        .name_span
        .iter()
        .chain(t.name_refs.iter())
        .map(|s| Splice::new(*s, new_name))
        .collect();
    Ok(Edit::new(
        format!("rename table {} to {new_name}", t.name),
        splices,
    ))
}

/// Rename a column, and with it every key, index and foreign-key clause that
/// lists it — including incoming `REFERENCES other(col)` from other tables.
pub fn rename_column(
    schema: &Schema,
    table: &str,
    column: &str,
    new_name: &str,
) -> Result<Edit, EditError> {
    check_identifier(new_name)?;
    let t = schema
        .table(table)
        .ok_or_else(|| EditError::NoSuchTable(table.to_owned()))?;
    let col = t.column(column).ok_or_else(|| EditError::NoSuchColumn {
        table: t.name.clone(),
        column: column.to_owned(),
    })?;
    let key = col.name.to_lowercase();
    let splices = std::iter::once(Splice::new(col.name_span, new_name))
        .chain(
            t.col_refs
                .iter()
                .filter(|r| r.name == key)
                .map(|r| Splice::new(r.span, new_name)),
        )
        .collect();
    Ok(Edit::new(
        format!("rename column {}.{} to {new_name}", t.name, col.name),
        splices,
    ))
}

/// Change a column's declared type. A column with no type at all — legal in
/// SQLite — gains one after its name rather than being rewritten.
pub fn set_column_type(
    schema: &Schema,
    table: &str,
    column: &str,
    new_type: &str,
) -> Result<Edit, EditError> {
    let t = schema
        .table(table)
        .ok_or_else(|| EditError::NoSuchTable(table.to_owned()))?;
    let col = t.column(column).ok_or_else(|| EditError::NoSuchColumn {
        table: t.name.clone(),
        column: column.to_owned(),
    })?;
    let splice = match col.ty_span {
        Some(span) => Splice::new(span, new_type),
        None => Splice {
            range: col.name_span.end..col.name_span.end,
            text: format!(" {new_type}"),
        },
    };
    Ok(Edit::new(
        format!("set type of {}.{} to {new_type}", t.name, col.name),
        vec![splice],
    ))
}

/// Append a column to a table.
///
/// Placed after the last column rather than at the end of the body, because the
/// body ends after a newline and often after a trailing table constraint: an
/// insertion there lands below `PRIMARY KEY (...)` and turns a valid script
/// into one that no longer parses.
///
/// Indentation is copied from the line the last column sits on, so a script
/// indented with four spaces, or a tab, or not at all, stays that way. That is
/// the same promise as [`Splice`] itself, applied to the bytes we are adding
/// rather than the ones we are leaving alone.
pub fn add_column(
    src: &str,
    schema: &Schema,
    table: &str,
    name: &str,
    ty: &str,
) -> Result<Edit, EditError> {
    check_identifier(name)?;
    let t = schema
        .table(table)
        .ok_or_else(|| EditError::NoSuchTable(table.to_owned()))?;
    if t.column(name).is_some() {
        return Err(EditError::DuplicateColumn {
            table: t.name.clone(),
            column: name.to_owned(),
        });
    }

    let splice = match t.columns.last() {
        Some(last) => Splice {
            range: last.def_span.end..last.def_span.end,
            text: format!(",\n{}{name} {ty}", indent_of(src, last.def_span.start)),
        },
        // A table with no columns at all. Legal, and the only place left to put
        // one is between the parentheses.
        None => {
            let span = t
                .body_span
                .ok_or_else(|| EditError::NoBody(t.name.clone()))?;
            Splice {
                range: span.start..span.end,
                text: format!("\n  {name} {ty}\n"),
            }
        }
    };
    Ok(Edit::new(
        format!("add column {}.{name} {ty}", t.name),
        vec![splice],
    ))
}

/// The whitespace that starts the line `at` sits on.
fn indent_of(src: &str, at: usize) -> &str {
    let line = src[..at].rfind('\n').map_or(0, |i| i + 1);
    let end = src[line..at]
        .find(|c: char| !c.is_whitespace())
        .map_or(at - line, |i| i);
    &src[line..line + end]
}

/// The types this script already uses, most used first.
///
/// Deliberately not a table of types per dialect. The script in front of us is
/// the only authority on its own dialect that cannot be wrong: a file full of
/// `bigserial` and `timestamptz` will suggest those, one full of `AUTO_INCREMENT`
/// and `datetime` will suggest *those*, and a dialect nobody thought to enumerate
/// works on the first try. It also puts this schema's own conventions first,
/// which is what someone adding a column to it actually wants.
pub fn types_in_use(schema: &Schema) -> Vec<String> {
    let mut counts: Vec<(String, usize)> = Vec::new();
    for column in schema.tables.iter().flat_map(|t| &t.columns) {
        if column.ty.is_empty() {
            continue;
        }
        match counts.iter_mut().find(|(ty, _)| *ty == column.ty) {
            Some((_, n)) => *n += 1,
            None => counts.push((column.ty.clone(), 1)),
        }
    }
    // Ties broken by name so the list does not reshuffle between keystrokes.
    counts.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
    counts.into_iter().map(|(ty, _)| ty).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn splice(range: Range<usize>, text: &str) -> Splice {
        Splice {
            range,
            text: text.to_owned(),
        }
    }

    #[test]
    fn splices_address_the_original_text_regardless_of_order() {
        let src = "abcdef";
        let out = apply(src, &[splice(4..6, "YZ"), splice(0..2, "WX")]).unwrap();
        assert_eq!(out, "WXcdYZ");
    }

    #[test]
    fn replacement_length_does_not_shift_later_splices() {
        let src = "aa.bb.cc";
        let out = apply(
            src,
            &[splice(0..2, "LONGER"), splice(3..5, "x"), splice(6..8, "")],
        )
        .unwrap();
        assert_eq!(out, "LONGER.x.");
    }

    #[test]
    fn overlapping_splices_are_refused_rather_than_guessed() {
        let err = apply("abcdef", &[splice(0..3, "x"), splice(2..4, "y")]).unwrap_err();
        assert_eq!(
            err,
            SpliceError::Overlap {
                first: 0..3,
                second: 2..4
            }
        );
    }

    #[test]
    fn adjacent_and_empty_splices_are_fine() {
        assert_eq!(
            apply("abcd", &[splice(0..2, "X"), splice(2..4, "Y")]).unwrap(),
            "XY"
        );
        assert_eq!(
            apply("abcd", &[splice(2..2, "-"), splice(2..2, "+")]).unwrap(),
            "ab-+cd"
        );
    }

    #[test]
    fn a_split_character_is_an_error_not_a_panic() {
        let src = "\u{5ba2}\u{6236}"; // three bytes per char
        assert_eq!(
            apply(src, &[splice(1..3, "x")]).unwrap_err(),
            SpliceError::NotACharBoundary { at: 1 }
        );
        assert_eq!(
            apply(src, &[splice(0..99, "x")]).unwrap_err(),
            SpliceError::OutOfBounds {
                range: 0..99,
                len: 6
            }
        );
    }

    #[test]
    fn no_splices_is_the_identity() {
        assert_eq!(apply("anything at all", &[]).unwrap(), "anything at all");
    }

    #[test]
    fn identifiers_that_would_need_quoting_are_rejected() {
        for ok in ["users", "_x", "t1", "camelCase", "a$b"] {
            assert!(is_bare_identifier(ok), "{ok} should be safe");
        }
        for bad in [
            "",
            "1st",
            "two words",
            "drop;table",
            "quo\"ted",
            "\u{5ba2}\u{6236}",
        ] {
            assert!(!is_bare_identifier(bad), "{bad} should be rejected");
        }

        let schema = draft_ddl::parse("CREATE TABLE t (a int);");
        assert_eq!(
            rename_table(&schema, "t", "two words").unwrap_err(),
            EditError::UnsafeIdentifier("two words".into())
        );
    }

    #[test]
    fn missing_targets_are_reported_not_ignored() {
        let schema = draft_ddl::parse("CREATE TABLE t (a int);");
        assert_eq!(
            rename_table(&schema, "nope", "x").unwrap_err(),
            EditError::NoSuchTable("nope".into())
        );
        assert_eq!(
            rename_column(&schema, "t", "nope", "x").unwrap_err(),
            EditError::NoSuchColumn {
                table: "t".into(),
                column: "nope".into()
            }
        );
    }

    #[test]
    fn renaming_preserves_whatever_quoting_the_source_used() {
        let sql = "CREATE TABLE `old` (`c` int);\nALTER TABLE `old` ADD CONSTRAINT x \
                   FOREIGN KEY (`c`) REFERENCES `old` (`c`);";
        let schema = draft_ddl::parse(sql);
        let edit = rename_table(&schema, "old", "new").unwrap();
        let out = apply(sql, &edit.splices).unwrap();
        assert_eq!(
            out,
            "CREATE TABLE `new` (`c` int);\nALTER TABLE `new` ADD CONSTRAINT x \
             FOREIGN KEY (`c`) REFERENCES `new` (`c`);"
        );
    }

    #[test]
    fn a_typeless_column_gains_a_type_instead_of_losing_its_name() {
        let sql = "CREATE TABLE t (a, b);";
        let schema = draft_ddl::parse(sql);
        let edit = set_column_type(&schema, "t", "a", "INTEGER").unwrap();
        assert_eq!(
            apply(sql, &edit.splices).unwrap(),
            "CREATE TABLE t (a INTEGER, b);"
        );
    }
}
