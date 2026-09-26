//! Which dialect a script looks like.
//!
//! Advisory, and deliberately kept out of [`crate::parse`]. The parser has no
//! dialect modes and is not getting any — see docs/architecture.md D1 — so this
//! answers a different question: not "how do I read this", which is settled, but
//! "what is the person looking at". It changes nothing downstream. In particular
//! it does *not* feed the type suggestions, which still come from the types the
//! script already uses rather than from a per-dialect list (D12).
//!
//! ## How it decides
//!
//! Each dialect has a handful of markers that only it produces: backticks and
//! `ENGINE=` are MySQL and nothing else, `jsonb` and `OWNER TO` are Postgres,
//! bracketed identifiers and `IDENTITY(` are SQL Server. A marker scores once
//! however often it appears, so one stray `jsonb` in a large MySQL dump cannot
//! outvote the backtick on every identifier in it, and the highest total wins.
//!
//! Two honest limits. Comments are blanked first, so the `-- MySQL dump` header
//! every mysqldump carries is *not* what identifies it — the backticks and
//! `ENGINE=` in the statements are. String literals are not blanked, because
//! the parser needs them intact, so a marker quoted inside a default value does
//! count; a schema that defaults a column to the text `'ENGINE=InnoDB'` is a
//! price worth paying for not maintaining a second scanner.

/// A SQL dialect this project recognises on sight.
///
/// No serde derive, on purpose: this crate has no dependencies and that is
/// worth keeping. A project file stores [`Self::label`] and reads it back with
/// [`Self::from_label`] — see `crates/app/src/project.rs`.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Dialect {
    Postgres,
    MySql,
    Sqlite,
    SqlServer,
    Snowflake,
}

impl Dialect {
    /// Every dialect, in the order a menu should list them.
    pub const ALL: [Self; 5] = [
        Self::Postgres,
        Self::MySql,
        Self::Sqlite,
        Self::SqlServer,
        Self::Snowflake,
    ];

    /// What the vendor calls itself, which is what a status bar should say.
    pub fn label(self) -> &'static str {
        match self {
            Self::Postgres => "PostgreSQL",
            Self::MySql => "MySQL",
            Self::Sqlite => "SQLite",
            Self::SqlServer => "SQL Server",
            Self::Snowflake => "Snowflake",
        }
    }

    /// The inverse of [`Self::label`], so a dialect can be stored as the name a
    /// person would recognise and read back.
    ///
    /// Case-insensitive and `None` for anything unrecognised: the only caller
    /// is a project file, which is text somebody may have typed into by hand.
    pub fn from_label(label: &str) -> Option<Self> {
        Self::ALL
            .into_iter()
            .find(|d| d.label().eq_ignore_ascii_case(label.trim()))
    }
}

/// Markers, lowercase, with what each is worth.
///
/// A 3 is a construct no other dialect in this list emits. A 2 is strongly
/// suggestive but imaginable elsewhere. A 1 is shared with at least one other
/// dialect and is only ever a tie-breaker.
type Markers = &'static [(&'static str, u32)];

const POSTGRES: Markers = &[
    ("jsonb", 3),
    ("character varying", 3),
    ("without time zone", 3),
    ("timestamptz", 3),
    ("bigserial", 3),
    ("smallserial", 3),
    ("nextval", 3),
    ("owner to", 3),
    ("client_encoding", 3),
    ("with time zone", 2),
    ("tsvector", 2),
    ("using btree", 2),
    ("text[]", 2),
    // Snowflake casts this way too, so it can only break a tie.
    ("::", 1),
];

const MYSQL: Markers = &[
    ("`", 3),
    ("engine=", 3),
    ("auto_increment", 3),
    ("charset=", 2),
    ("collate=", 2),
    ("utf8mb4", 2),
    ("unsigned", 2),
    ("tinyint", 2),
    ("fulltext", 2),
];

const SQLITE: Markers = &[
    // Snowflake spells it this way as well, but pairs it with markers of its
    // own that Postgres and SQLite have no answer to.
    ("autoincrement", 3),
    ("without rowid", 3),
    ("pragma ", 3),
    ("strftime", 2),
    ("integer primary key", 2),
];

const SQLSERVER: Markers = &[
    ("identity(", 3),
    ("nvarchar", 3),
    ("clustered", 3),
    ("[dbo]", 3),
    ("uniqueidentifier", 2),
    ("datetime2", 2),
    // A bracketed name followed by a bracketed type. `text[]` cannot produce
    // it, which a bare `[` could not distinguish.
    ("] [", 2),
    ("\ngo\n", 2),
];

const SNOWFLAKE: Markers = &[
    ("transient table", 3),
    ("timestamp_ntz", 3),
    ("timestamp_ltz", 3),
    ("timestamp_tz", 3),
    ("variant", 2),
    ("number(38", 2),
    ("cluster by", 2),
    // Postgres replaces views and functions this way, so on its own it means
    // very little.
    ("create or replace", 1),
];

/// The dialect this script looks most like, or `None` when nothing in it
/// commits to one.
///
/// `None` is a real answer, not a failure: `CREATE TABLE t (id int);` is valid
/// in all five and claiming otherwise would be worse than saying nothing.
pub fn detect(sql: &str) -> Option<Dialect> {
    let code = crate::scan::blank_comments(sql).to_ascii_lowercase();
    let mut best: Option<(Dialect, u32)> = None;
    for (dialect, markers) in [
        (Dialect::Postgres, POSTGRES),
        (Dialect::MySql, MYSQL),
        (Dialect::Sqlite, SQLITE),
        (Dialect::SqlServer, SQLSERVER),
        (Dialect::Snowflake, SNOWFLAKE),
    ] {
        let score: u32 = markers
            .iter()
            .filter(|(marker, _)| code.contains(marker))
            .map(|(_, weight)| weight)
            .sum();
        // Strictly greater, so the declaration order above breaks a tie rather
        // than the iteration order of anything.
        if score > best.map_or(0, |(_, s)| s) {
            best = Some((dialect, score));
        }
    }
    // One weight-1 marker is a coincidence, not an identification.
    best.filter(|&(_, score)| score >= 2).map(|(d, _)| d)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The plainest schema there is parses in all five dialects, and saying
    /// "PostgreSQL" about it would be inventing information.
    #[test]
    fn a_script_that_commits_to_nothing_is_not_guessed_at() {
        assert_eq!(
            detect("CREATE TABLE t (id int PRIMARY KEY, name text);"),
            None
        );
        assert_eq!(detect(""), None);
        assert_eq!(detect("-- jsonb ENGINE= IDENTITY( nvarchar"), None);
    }

    /// The header of a real dump names its vendor in a comment, and leaning on
    /// that would be reading the label rather than the bottle: a schema pasted
    /// out of a chat window arrives with no header at all, and a file copied
    /// from one database to another arrives with the wrong one.
    #[test]
    fn a_comment_naming_a_vendor_does_not_decide_it() {
        let mysql_header_postgres_body = "\
            -- MySQL dump 10.13  Distrib 8.0.36\n\
            CREATE TABLE users (id bigserial PRIMARY KEY, at timestamptz);\n";
        assert_eq!(detect(mysql_header_postgres_body), Some(Dialect::Postgres));
    }

    /// A marker that appears everywhere must not be outvoted by one that
    /// appears once. This is the case the scoring exists for.
    #[test]
    fn one_stray_marker_does_not_outvote_a_dialect_written_throughout() {
        let mysql = "\
            CREATE TABLE `event` (\n\
              `id` bigint unsigned NOT NULL AUTO_INCREMENT,\n\
              `payload` json DEFAULT NULL,\n\
              PRIMARY KEY (`id`)\n\
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;\n\
            -- migrated from a jsonb column\n";
        assert_eq!(detect(mysql), Some(Dialect::MySql));
    }

    /// Each dialect's own markers, with nothing else in the script, so a
    /// reordering or a typo in the tables above fails here rather than on a
    /// fixture where several markers cover for each other.
    #[test]
    fn each_dialect_is_identified_by_its_own_markers() {
        for (sql, expected) in [
            (
                "CREATE TABLE t (a character varying(8));",
                Dialect::Postgres,
            ),
            ("CREATE TABLE `t` (a int);", Dialect::MySql),
            (
                "CREATE TABLE t (id INTEGER PRIMARY KEY AUTOINCREMENT);",
                Dialect::Sqlite,
            ),
            ("CREATE TABLE t ([a] [nvarchar](8));", Dialect::SqlServer),
            (
                "CREATE TRANSIENT TABLE t (a timestamp_ntz(9));",
                Dialect::Snowflake,
            ),
        ] {
            assert_eq!(detect(sql), Some(expected), "{sql}");
        }
    }

    /// A stored dialect is a label in a JSON file somebody can edit, so the
    /// round trip has to hold for every variant and the unrecognised case has
    /// to come back as "no opinion" rather than as a wrong one.
    #[test]
    fn a_label_survives_being_stored_and_read_back() {
        for dialect in Dialect::ALL {
            assert_eq!(Dialect::from_label(dialect.label()), Some(dialect));
        }
        assert_eq!(Dialect::from_label("  mysql "), Some(Dialect::MySql));
        assert_eq!(Dialect::from_label("Oracle"), None);
        assert_eq!(Dialect::from_label(""), None);
    }

    /// Detection must not depend on how the author cased their keywords —
    /// Snowflake's own tooling emits lowercase, everyone else's emits upper.
    #[test]
    fn case_does_not_matter() {
        let lower = "create table t (id integer primary key autoincrement);";
        let upper = lower.to_ascii_uppercase();
        assert_eq!(detect(lower), Some(Dialect::Sqlite));
        assert_eq!(detect(&upper), Some(Dialect::Sqlite));
    }
}
