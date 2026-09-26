//! Golden AST tests over the dialect corpus, plus the invariants that have to
//! hold for *any* input, including input that is not valid SQL.
//!
//! Regenerate the goldens with `UPDATE_GOLDEN=1 cargo test -p draft-ddl`,
//! then read the diff — that diff is the review.

use std::fmt::Write as _;
use std::path::{Path, PathBuf};
use std::time::Instant;

use draft_ddl::{Cardinality, Column, Schema, Span, parse};

fn fixtures() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../fixtures")
}

fn read(rel: &str) -> String {
    let path = fixtures().join(rel);
    std::fs::read_to_string(&path).unwrap_or_else(|e| panic!("reading {}: {e}", path.display()))
}

// --- golden corpus ----------------------------------------------------------

#[test]
fn postgres() {
    golden("postgres");
}

#[test]
fn mysql() {
    golden("mysql");
}

#[test]
fn sqlite() {
    golden("sqlite");
}

#[test]
fn sqlserver() {
    golden("sqlserver");
}

#[test]
fn snowflake() {
    golden("snowflake");
}

/// Indexes, which arrive in more shapes than anything else in a schema: inside
/// the body, after the table, before the table, named, unnamed, and with a
/// method or a predicate wrapped around the column list.
#[test]
fn an_index_is_read_wherever_the_script_declares_one() {
    const SQL: &str = "\
CREATE INDEX early_idx ON orders (placed_at);
CREATE TABLE orders (
    id bigint PRIMARY KEY,
    user_id bigint NOT NULL,
    placed_at timestamptz NOT NULL,
    email text,
    KEY (user_id),
    UNIQUE (email),
    CONSTRAINT uq_orders_email UNIQUE (email),
    UNIQUE KEY uq_orders_user (user_id),
    FULLTEXT KEY ft_orders (email)
);
CREATE UNIQUE INDEX uq_late ON orders USING btree (id, user_id);
CREATE INDEX partial_idx ON orders (placed_at) WHERE email IS NOT NULL;
CREATE INDEX nowhere_idx ON a_table_this_script_never_defines (x);
";
    let schema = parse(SQL);
    let orders = schema.table("orders").expect("orders");
    let found: Vec<_> = orders
        .indexes
        .iter()
        .map(|x| (x.name.as_deref(), x.columns.join(","), x.unique))
        .collect();

    assert_eq!(
        found,
        vec![
            // Body clauses first, in the order the body declares them. The
            // anonymous `UNIQUE (email)` is absent on purpose: it names
            // nothing, and `email` already carries the badge.
            (None, "user_id".to_owned(), false),
            (Some("uq_orders_email"), "email".to_owned(), true),
            (Some("uq_orders_user"), "user_id".to_owned(), true),
            (Some("ft_orders"), "email".to_owned(), false),
            // Then the standalone statements, including the one that precedes
            // the table it indexes.
            (Some("early_idx"), "placed_at".to_owned(), false),
            (Some("uq_late"), "id,user_id".to_owned(), true),
            (Some("partial_idx"), "placed_at".to_owned(), false),
        ],
        "indexes read as {found:#?}"
    );

    assert_eq!(
        schema.tables.len(),
        1,
        "an index on an undefined table must not invent the table"
    );

    // The other half of parsing them: a rename has to reach the column list of
    // a `CREATE INDEX`, which is only possible if the spans were recorded.
    let refs: Vec<&str> = orders
        .col_refs
        .iter()
        .map(|r| r.span.text(SQL))
        .filter(|s| *s == "placed_at")
        .collect();
    assert_eq!(
        refs.len(),
        2,
        "both index clauses naming placed_at have to be spliceable: {:?}",
        orders.col_refs
    );
    assert_eq!(
        orders
            .name_refs
            .iter()
            .filter(|s| s.text(SQL) == "orders")
            .count(),
        3,
        "each of the three `ON orders` has to move when the table is renamed"
    );
}

/// Cardinality is inferred, so the interesting cases are the ones where the
/// evidence is partial: one column of a composite key, a unique index declared
/// after the table, a `UNIQUE` that covers a pair rather than a column.
#[test]
fn cardinality_follows_the_childs_own_key() {
    const SQL: &str = "\
CREATE TABLE users (id bigint PRIMARY KEY);
CREATE TABLE profiles (
    user_id bigint PRIMARY KEY REFERENCES users(id)
);
CREATE TABLE orders (
    id bigint PRIMARY KEY,
    user_id bigint REFERENCES users(id)
);
CREATE TABLE settings (
    user_id bigint UNIQUE REFERENCES users(id)
);
CREATE TABLE memberships (
    user_id bigint REFERENCES users(id),
    team_id bigint,
    PRIMARY KEY (user_id, team_id)
);
CREATE TABLE seats (
    user_id bigint REFERENCES users(id),
    row_no int,
    UNIQUE (user_id, row_no)
);
CREATE TABLE badges (user_id bigint REFERENCES users(id));
CREATE UNIQUE INDEX uq_badges_user ON badges (user_id);
";
    let schema = parse(SQL);
    let of = |table: &str| {
        schema
            .relations
            .iter()
            .find(|r| r.from_table == table)
            .unwrap_or_else(|| panic!("no relation from {table}"))
            .cardinality
    };

    assert_eq!(
        of("profiles"),
        Cardinality::OneToOne,
        "the FK is the whole PK"
    );
    assert_eq!(of("settings"), Cardinality::OneToOne, "the FK is unique");
    assert_eq!(
        of("badges"),
        Cardinality::OneToOne,
        "a unique index declared after the table still covers the FK"
    );

    assert_eq!(of("orders"), Cardinality::OneToMany, "an ordinary FK");
    assert_eq!(
        of("memberships"),
        Cardinality::OneToMany,
        "one column of a composite primary key is not unique on its own"
    );
    assert_eq!(
        of("seats"),
        Cardinality::OneToMany,
        "one column of a composite UNIQUE is not unique on its own"
    );
    assert!(
        !schema
            .table("seats")
            .unwrap()
            .column("user_id")
            .unwrap()
            .unique,
        "a composite UNIQUE must not badge its columns as individually unique"
    );
}

/// The acceptance gate for tolerance: broken input yields a partial schema and
/// warnings, never an empty result and never a panic.
#[test]
fn malformed_still_yields_tables_and_warnings() {
    let sql = read("dialects/malformed.sql");
    let schema = parse(&sql);
    assert!(
        !schema.tables.is_empty(),
        "a broken script must still produce tables"
    );
    assert!(
        !schema.warnings.is_empty(),
        "a broken script must explain itself"
    );
    assert!(
        schema
            .table("truncated")
            .is_some_and(|t| t.columns.len() == 2),
        "columns before the missing paren must survive"
    );
    golden("malformed");
}

/// Two dumps written by `pg_dump` and `mysqldump` for somebody else's purposes,
/// years before this tool existed. Fixtures we write ourselves can only confirm
/// what we already believe; these are the ones that tell us we are wrong.
///
/// Both landed two real defects on first contact — routine bodies leaking
/// `CREATE TEMPORARY TABLE` into the schema, through PostgreSQL dollar quoting
/// in one and MySQL's `DELIMITER` in the other. The counts below are what
/// `pg_dump` and `mysqldump` actually declare.
#[test]
fn real_dumps_parse_completely_and_without_complaint() {
    let pagila = read("real/pagila-pg_dump.sql");
    let schema = parse(&pagila);
    check_span_invariants(&schema, &pagila);
    assert_eq!(schema.tables.len(), 71, "pagila declares 71 tables");
    assert!(
        schema.warnings.is_empty(),
        "unexpected warnings: {:?}",
        schema.warnings
    );
    assert!(
        schema.relations.iter().all(|r| !r.to_missing),
        "a self-contained dump should have no dangling references"
    );
    assert!(
        schema.table("tmpCustomer").is_none(),
        "a temp table inside a dollar-quoted function body is not part of the schema"
    );
    let film = schema.table("film").expect("film");
    assert_eq!(film.column("special_features").unwrap().ty, "text[]");
    assert_eq!(film.column("rating").unwrap().ty, "public.mpaa_rating");
    assert_eq!(
        film.column("last_update").unwrap().ty,
        "timestamp with time zone"
    );
    assert!(
        film.column("film_id").unwrap().pk,
        "pg_dump declares keys via ALTER TABLE"
    );

    let sakila = read("real/sakila-mysqldump.sql");
    let schema = parse(&sakila);
    check_span_invariants(&schema, &sakila);
    assert_eq!(schema.tables.len(), 16, "sakila declares 16 tables");
    assert!(
        schema.warnings.is_empty(),
        "unexpected warnings: {:?}",
        schema.warnings
    );
    assert!(
        schema.table("tmpCustomer").is_none(),
        "a temp table inside a DELIMITER-wrapped routine is not part of the schema"
    );
    let film = schema.table("film").expect("film");
    assert_eq!(
        film.column("rating").unwrap().ty,
        "enum('G','PG','PG-13','R','NC-17')"
    );
    assert_eq!(
        film.column("rental_duration").unwrap().ty,
        "tinyint unsigned"
    );
    assert!(film.column("film_id").unwrap().pk);
    assert!(film.column("language_id").unwrap().fk);
}

fn golden(name: &str) {
    let sql = read(&format!("dialects/{name}.sql"));
    let schema = parse(&sql);
    check_span_invariants(&schema, &sql);

    let actual = render(&schema);
    let path = fixtures().join(format!("dialects/{name}.golden"));
    if std::env::var_os("UPDATE_GOLDEN").is_some() {
        std::fs::write(&path, &actual).unwrap();
        return;
    }
    let expected = std::fs::read_to_string(&path).unwrap_or_default();
    assert_eq!(
        actual, expected,
        "golden mismatch for {name}; UPDATE_GOLDEN=1 to accept"
    );
}

// --- invariants -------------------------------------------------------------

/// Every span must address exactly the identifier it belongs to. This is the
/// property the whole product rests on: if a span drifts by one byte, a rename
/// corrupts the user's script instead of editing it.
fn check_span_invariants(schema: &Schema, sql: &str) {
    for t in &schema.tables {
        if let Some(s) = t.name_span {
            assert_eq!(s.text(sql), t.name, "table name span for {}", t.name);
        }
        if let Some(s) = t.body_span {
            assert!(
                s.end <= sql.len() && s.start <= s.end,
                "body span of {}",
                t.name
            );
        }
        for c in &t.columns {
            assert_eq!(
                c.name_span.text(sql),
                c.name,
                "name span of {}.{}",
                t.name,
                c.name
            );
            if let Some(s) = c.ty_span {
                assert_eq!(s.text(sql), c.ty_raw, "type span of {}.{}", t.name, c.name);
            }
            assert!(
                c.def_span.start <= c.name_span.start && c.name_span.end <= c.def_span.end,
                "{}.{} name span escapes its definition",
                t.name,
                c.name
            );
        }
        for s in &t.name_refs {
            assert_eq!(
                s.text(sql).to_lowercase(),
                t.key,
                "self reference span of {}",
                t.name
            );
        }
        for r in &t.col_refs {
            assert_eq!(
                r.span.text(sql).to_lowercase(),
                r.name,
                "column reference span in {}",
                t.name
            );
        }
    }
    for r in &schema.relations {
        if let Some(s) = r.ref_span {
            assert_eq!(
                s.text(sql).to_lowercase(),
                r.to_table.to_lowercase(),
                "reference span of {} -> {}",
                r.from_table,
                r.to_table
            );
        }
    }
}

/// Truncation is the cheapest source of syntax nobody wrote on purpose: every
/// prefix of every fixture is a script with a half-open construct somewhere.
/// All of them must parse without panicking, and all of them must keep the span
/// invariants — a span into text that no longer exists is the dangerous case.
#[test]
fn every_prefix_parses_without_panicking() {
    for name in [
        "small_20.sql",
        "dialects/postgres.sql",
        "dialects/mysql.sql",
        "dialects/sqlserver.sql",
        "dialects/malformed.sql",
        "real/sakila-mysqldump.sql",
    ] {
        let sql = read(name);
        let mut cut = 0;
        while cut < sql.len() {
            let prefix = &sql[..cut];
            check_span_invariants(&parse(prefix), prefix);
            cut += 7;
            while cut < sql.len() && !sql.is_char_boundary(cut) {
                cut += 1;
            }
        }
    }
}

#[test]
fn empty_and_garbage_input_are_not_special_cases() {
    for sql in [
        "",
        "   ",
        ";;;",
        "\u{0}\u{1}\u{2}",
        "CREATE",
        "((((",
        "'unterminated",
        "\u{5ba2}\u{6236}",
        "-- just a comment",
    ] {
        let schema = parse(sql);
        check_span_invariants(&schema, sql);
        assert!(
            schema.relations.is_empty(),
            "{sql:?} should not invent relations"
        );
    }
}

/// The generator knows exactly what it emitted, so these counts are a golden
/// test over 106 KB of SQL without a 106 KB golden file.
#[test]
fn synthetic_corpus_round_trips_its_own_counts() {
    for (file, tables, columns, relations) in [
        ("small_20.sql", 20, 154, 40),
        ("synthetic_300.sql", 300, 2076, 600),
    ] {
        let sql = read(file);
        let schema = parse(&sql);
        check_span_invariants(&schema, &sql);
        assert_eq!(schema.tables.len(), tables, "table count in {file}");
        assert_eq!(
            schema.tables.iter().map(|t| t.columns.len()).sum::<usize>(),
            columns,
            "column count in {file}"
        );
        assert_eq!(
            schema.relations.len(),
            relations,
            "relation count in {file}"
        );
        assert!(
            schema.relations.iter().all(|r| !r.to_missing),
            "every generated relation targets a generated table"
        );
    }
}

/// NFR: parse the 106 KB fixture in under 50 ms.
///
/// Best of several runs, because `cargo test` runs tests in parallel and a
/// single timing taken while the rest of the suite competes for the CPU reads
/// three to four times slower than the same code measured alone. The fastest
/// run is the one least contaminated by that; it is a budget check, not a
/// benchmark. Only the release number is the real gate.
#[test]
fn parse_stays_within_the_time_budget() {
    let sql = read("synthetic_300.sql");
    let mut best = f64::INFINITY;
    for _ in 0..5 {
        let start = Instant::now();
        let schema = parse(&sql);
        best = best.min(start.elapsed().as_secs_f64() * 1000.0);
        assert_eq!(schema.tables.len(), 300);
    }

    let budget = if cfg!(debug_assertions) { 600.0 } else { 50.0 };
    assert!(
        best < budget,
        "parsed {} KB in {best:.1} ms, budget {budget} ms",
        sql.len() / 1024
    );
    eprintln!(
        "parse: {best:.2} ms for {} KB / 300 tables",
        sql.len() / 1024
    );
}

// --- rendering --------------------------------------------------------------

fn render(schema: &Schema) -> String {
    let mut out = String::new();
    for t in &schema.tables {
        let _ = writeln!(
            out,
            "TABLE {}  name@{}  body@{}",
            t.name,
            opt_span(t.name_span),
            opt_span(t.body_span)
        );
        for c in &t.columns {
            let ty = if c.ty.is_empty() { "-" } else { c.ty.as_str() };
            let _ = writeln!(
                out,
                "  COL {:<14} {:<28} {:<12} name@{}  type@{}",
                c.name,
                ty,
                flags(c),
                span(c.name_span),
                opt_span(c.ty_span)
            );
        }
        for x in &t.indexes {
            let _ = writeln!(
                out,
                "  IDX {:<14} {:<8} ({})",
                x.name.as_deref().unwrap_or("-"),
                if x.unique { "unique" } else { "-" },
                x.columns.join(",")
            );
        }
        for s in &t.name_refs {
            let _ = writeln!(out, "  SELF {:<13} @{}", t.key, span(*s));
        }
        for r in &t.col_refs {
            let _ = writeln!(out, "  REF {:<14} @{}", r.name, span(r.span));
        }
    }
    for r in &schema.relations {
        let _ = writeln!(
            out,
            "REL {}({}) -> {}({})  {}{}",
            r.from_table,
            r.from_cols.join(","),
            r.to_table,
            r.to_cols.join(","),
            match r.cardinality {
                Cardinality::OneToOne => "1:1",
                Cardinality::OneToMany => "1:n",
            },
            if r.to_missing {
                "  [undefined target]"
            } else {
                ""
            }
        );
    }
    for w in &schema.warnings {
        let _ = writeln!(out, "WARN @{}  {}", opt_span(w.span), w.message);
    }
    out
}

fn flags(c: &Column) -> String {
    let set = [
        (c.pk, "pk"),
        (c.not_null, "nn"),
        (c.unique, "uq"),
        (c.fk, "fk"),
    ];
    let joined = set
        .iter()
        .filter(|(on, _)| *on)
        .map(|(_, n)| *n)
        .collect::<Vec<_>>()
        .join(",");
    if joined.is_empty() {
        "-".into()
    } else {
        joined
    }
}

fn span(s: Span) -> String {
    format!("{}..{}", s.start, s.end)
}

fn opt_span(s: Option<Span>) -> String {
    s.map_or_else(|| "-".to_owned(), span)
}
