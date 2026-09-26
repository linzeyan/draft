//! The invariant the whole product rests on: an edit changes the bytes it
//! claims and not one byte more.
//!
//! The test is a round trip rather than a comparison against an expected
//! output, because a round trip cannot be satisfied by a plausible-looking
//! answer. Rename every table and every column, apply, rename them all back,
//! and require the result to be byte-identical to the file we started with. A
//! span that is off by one, a reference that was missed, a comment that moved —
//! each shows up as a difference.

use std::collections::HashMap;
use std::path::Path;

use draft_ddl::{Schema, parse};
use draft_model::{
    Splice, add_column, apply, is_bare_identifier, rename_column, rename_table, types_in_use,
};

const CORPUS: &[&str] = &[
    "small_20.sql",
    "synthetic_300.sql",
    "dialects/postgres.sql",
    "dialects/mysql.sql",
    "dialects/sqlite.sql",
    "dialects/sqlserver.sql",
    "dialects/snowflake.sql",
    "dialects/malformed.sql",
    // Written by pg_dump and mysqldump, not by us. If a rename survives these
    // byte-for-byte, it survives anything in the fixture corpus.
    "real/pagila-pg_dump.sql",
    "real/sakila-mysqldump.sql",
];

fn read(rel: &str) -> String {
    let path = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../fixtures")
        .join(rel);
    std::fs::read_to_string(&path).unwrap_or_else(|e| panic!("reading {}: {e}", path.display()))
}

/// Every rename this corpus admits, as one batch of splices. Returns the
/// splices and the mapping needed to undo them.
fn rename_everything(schema: &Schema, prefix: &str) -> (Vec<Splice>, HashMap<String, String>) {
    let mut splices = Vec::new();
    let mut back = HashMap::new();

    for (ti, table) in schema.tables.iter().enumerate() {
        // A name that needs quoting cannot be spliced in bare, so it is not
        // part of the round trip — but it must still come out untouched.
        if is_bare_identifier(&table.name) {
            let new = format!("{prefix}t{ti}");
            splices.extend(rename_table(schema, &table.name, &new).unwrap().splices);
            back.insert(new, table.name.clone());
        }

        let mut seen = Vec::new();
        for (ci, column) in table.columns.iter().enumerate() {
            let key = column.name.to_lowercase();
            // Duplicate column names in one table are malformed input; both
            // would claim the same reference spans and collide.
            if !is_bare_identifier(&column.name) || seen.contains(&key) {
                continue;
            }
            seen.push(key);
            let new = format!("{prefix}c{ti}_{ci}");
            splices.extend(
                rename_column(schema, &table.name, &column.name, &new)
                    .unwrap()
                    .splices,
            );
            back.insert(new, column.name.clone());
        }
    }
    (splices, back)
}

/// Per-table column counts, and one entry per relation: the target's position,
/// and how many columns each end names.
type Shape = (Vec<usize>, Vec<(Option<usize>, usize, usize)>);

/// Structure, independent of naming: which table points at which, and with how
/// many columns. Renaming must not change any of it.
fn shape(schema: &Schema) -> Shape {
    let mut edges: Vec<_> = schema
        .relations
        .iter()
        .map(|r| {
            (
                schema.index_of(&r.to_table),
                r.from_cols.len(),
                r.to_cols.len(),
            )
        })
        .collect();
    edges.sort();
    (
        schema.tables.iter().map(|t| t.columns.len()).collect(),
        edges,
    )
}

#[test]
fn renaming_everything_and_back_is_the_identity() {
    for name in CORPUS {
        let original = read(name);
        let before = parse(&original);

        let (splices, back) = rename_everything(&before, "zz_");
        let renamed = apply(&original, &splices)
            .unwrap_or_else(|e| panic!("{name}: forward rename produced conflicting splices: {e}"));
        assert_ne!(
            renamed, original,
            "{name}: the corpus must actually contain identifiers"
        );

        // The renamed script has to still be the same schema, or the round trip
        // below would be proving something about mush.
        let after = parse(&renamed);
        assert_eq!(
            shape(&before),
            shape(&after),
            "{name}: renaming changed the schema's shape"
        );
        assert_eq!(
            before.warnings.len(),
            after.warnings.len(),
            "{name}: renaming introduced or hid a parse warning"
        );

        let reverse: Vec<Splice> = after
            .tables
            .iter()
            .flat_map(|t| {
                let table_splices = back
                    .get(&t.name)
                    .map(|old| rename_table(&after, &t.name, old).unwrap().splices)
                    .unwrap_or_default();
                let column_splices = t.columns.iter().flat_map(|c| {
                    back.get(&c.name)
                        .map(|old| {
                            rename_column(&after, &t.name, &c.name, old)
                                .unwrap()
                                .splices
                        })
                        .unwrap_or_default()
                });
                table_splices.into_iter().chain(column_splices)
            })
            .collect();

        let restored = apply(&renamed, &reverse)
            .unwrap_or_else(|e| panic!("{name}: reverse rename produced conflicting splices: {e}"));
        assert_eq!(restored, original, "{name}: round trip lost or moved bytes");
    }
}

/// The reason any of this matters: what survives is not just the SQL but
/// everything around it that a regenerating tool would throw away.
#[test]
fn comments_and_formatting_are_untouched_by_a_rename() {
    let original = read("dialects/mysql.sql");
    let schema = parse(&original);
    let edit = rename_table(&schema, "customer", "client").unwrap();
    let renamed = apply(&original, &edit.splices).unwrap();

    for line in original.lines().filter(|l| {
        let t = l.trim_start();
        t.starts_with("--") || t.starts_with("/*")
    }) {
        assert!(renamed.contains(line), "comment lost: {line}");
    }
    assert!(
        renamed.contains(
            "`notes` text COMMENT 'free text, may contain ; and -- and even ) characters'"
        ),
        "a string literal that looks like syntax was rewritten"
    );
    assert_eq!(
        original.lines().count(),
        renamed.lines().count(),
        "line count changed"
    );
}

/// Every byte outside the spliced ranges is identical — stated directly, in the
/// words of the acceptance criterion, over the largest fixture we have.
#[test]
fn bytes_outside_the_spliced_ranges_are_unchanged() {
    let original = read("synthetic_300.sql");
    let schema = parse(&original);
    let (mut splices, _) = rename_everything(&schema, "zz_");
    splices.sort_by_key(|s| s.range.start);
    let renamed = apply(&original, &splices).unwrap();

    let (mut old_cursor, mut new_cursor) = (0usize, 0usize);
    for s in &splices {
        let gap = s.range.start - old_cursor;
        assert_eq!(
            original[old_cursor..s.range.start],
            renamed[new_cursor..new_cursor + gap],
            "bytes {old_cursor}..{} were rewritten and should not have been",
            s.range.start
        );
        old_cursor = s.range.end;
        new_cursor += gap + s.text.len();
    }
    assert_eq!(
        original[old_cursor..],
        renamed[new_cursor..],
        "the tail was rewritten"
    );
    assert!(
        splices.len() > 2000,
        "expected thousands of splices, got {}",
        splices.len()
    );
}

/// Adding a column has to be as safe as renaming one: the script must still
/// parse, gain exactly the column asked for, and lose nothing.
///
/// Run over the whole corpus rather than a hand-written table, because the
/// interesting cases are the ones nobody would write on purpose — a trailing
/// table constraint after the last column, a comment between the last column
/// and the closing paren, a body indented with tabs.
#[test]
fn adding_a_column_to_every_table_keeps_the_script_parsing() {
    for name in CORPUS {
        let original = read(name);
        let before = parse(&original);

        let splices: Vec<Splice> = before
            .tables
            .iter()
            .filter(|t| is_bare_identifier(&t.name))
            .filter_map(|t| {
                add_column(&original, &before, &t.name, "zz_added", "integer")
                    .ok()
                    .map(|e| e.splices)
            })
            .flatten()
            .collect();
        if splices.is_empty() {
            continue;
        }

        let edited = apply(&original, &splices)
            .unwrap_or_else(|e| panic!("{name}: adding columns produced conflicting splices: {e}"));
        let after = parse(&edited);

        assert_eq!(
            before.tables.len(),
            after.tables.len(),
            "{name}: adding a column changed how many tables there are"
        );
        assert_eq!(
            before.warnings.len(),
            after.warnings.len(),
            "{name}: adding a column introduced or hid a parse warning"
        );
        for (was, now) in before.tables.iter().zip(&after.tables) {
            let added = is_bare_identifier(&was.name);
            assert_eq!(
                now.columns.len(),
                was.columns.len() + usize::from(added),
                "{name}: table {} gained {} columns",
                was.name,
                now.columns.len() as isize - was.columns.len() as isize
            );
            if added {
                let last = now.columns.last().expect("a table we just added to");
                assert_eq!(last.name, "zz_added", "{name}: in table {}", was.name);
                assert_eq!(last.ty, "integer", "{name}: in table {}", was.name);
            }
        }
        // Relationships are declared on columns; adding one must not disturb
        // any of them.
        assert_eq!(
            before.relations.len(),
            after.relations.len(),
            "{name}: adding a column changed the relationships"
        );
    }
}

/// A script's own types are the only authority on its dialect that cannot be
/// wrong, so the suggestion list has to actually come from the script.
#[test]
fn type_suggestions_come_from_the_script_in_front_of_us() {
    let mysql = types_in_use(&parse(&read("dialects/mysql.sql")));
    let postgres = types_in_use(&parse(&read("dialects/postgres.sql")));

    assert!(!mysql.is_empty() && !postgres.is_empty());
    assert!(
        postgres
            .iter()
            .any(|t| t.contains("timestamp with time zone")),
        "postgres suggestions missing its own types: {postgres:?}"
    );
    assert!(
        !postgres.iter().any(|t| t.eq_ignore_ascii_case("datetime")),
        "postgres suggestions leaked a type the script never uses: {postgres:?}"
    );
    assert!(
        mysql != postgres,
        "two dialects produced the same suggestions"
    );
}
