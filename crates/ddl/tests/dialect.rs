//! What `detect` makes of the corpus.
//!
//! The same files the golden AST tests parse, asserted on from the other end:
//! every one of them was written to be characteristic of its vendor, so a
//! detector that cannot tell them apart is not worth shipping. The two real
//! dumps are the ones that matter most — a hand-written fixture can be made to
//! carry any marker, and `pagila` and `sakila` were not written by us.

use std::path::{Path, PathBuf};
use std::time::Instant;

use draft_ddl::{Dialect, detect};

fn fixtures() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../fixtures")
}

fn read(rel: &str) -> String {
    let path = fixtures().join(rel);
    std::fs::read_to_string(&path).unwrap_or_else(|e| panic!("reading {}: {e}", path.display()))
}

#[test]
fn every_dialect_fixture_is_identified() {
    for (file, expected) in [
        ("dialects/postgres.sql", Dialect::Postgres),
        ("dialects/mysql.sql", Dialect::MySql),
        ("dialects/sqlite.sql", Dialect::Sqlite),
        ("dialects/sqlserver.sql", Dialect::SqlServer),
        ("dialects/snowflake.sql", Dialect::Snowflake),
    ] {
        assert_eq!(detect(&read(file)), Some(expected), "{file}");
    }
}

/// Dumps nobody here wrote, from the tools people actually use. If detection
/// only works on our own fixtures it only works on our own fixtures.
#[test]
fn the_real_dumps_are_identified() {
    assert_eq!(
        detect(&read("real/pagila-pg_dump.sql")),
        Some(Dialect::Postgres)
    );
    assert_eq!(
        detect(&read("real/sakila-mysqldump.sql")),
        Some(Dialect::MySql)
    );
}

/// The tolerance rule applies here too: input that is not valid SQL must
/// produce an answer, not a panic. It commits to no dialect, so the honest
/// answer is that there is nothing to report.
#[test]
fn broken_input_is_answered_rather_than_guessed_at() {
    assert_eq!(detect(&read("dialects/malformed.sql")), None);
}

/// The generator emits Postgres types — `jsonb`, `timestamptz`, `inet` — so
/// Postgres is the right answer for its output. Asserted because the generated
/// corpus is the largest script in the tree and the one most likely to expose
/// a marker that matches far more loosely than it was meant to.
#[test]
fn the_synthetic_corpus_reads_as_what_the_generator_emits() {
    assert_eq!(
        detect(&read("synthetic_300.sql")),
        Some(Dialect::Postgres),
        "the generator emits Postgres types; see fixtures/gen/gen.mjs"
    );
}

/// Detection runs beside every re-parse, so it has to be small against the
/// parse it accompanies rather than merely "fast enough" on its own. The parse
/// budget for this file is 50 ms; a tenth of that is the most a status-bar
/// label is worth.
#[test]
fn detect_stays_within_the_time_budget() {
    let sql = read("synthetic_300.sql");
    let mut best = f64::INFINITY;
    for _ in 0..5 {
        let start = Instant::now();
        let found = detect(&sql);
        best = best.min(start.elapsed().as_secs_f64() * 1000.0);
        assert_eq!(found, Some(Dialect::Postgres));
    }

    let budget = if cfg!(debug_assertions) { 60.0 } else { 5.0 };
    assert!(
        best < budget,
        "detected {} KB in {best:.1} ms, budget {budget} ms",
        sql.len() / 1024
    );
    eprintln!("detect: {best:.2} ms for {} KB", sql.len() / 1024);
}
