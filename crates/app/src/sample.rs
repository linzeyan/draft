//! The schemas the Sample button offers: one per dialect.
//!
//! Written out rather than pulled from `fixtures/`, because they have a job the
//! fixtures do not. A fixture is deliberately awkward — it carries a dangling
//! foreign key, a reserved word, a truncated statement — because that is what
//! it is there to prove. A sample is the opposite: it is the first thing a
//! visitor sees, so it has to be small enough to read, shaped enough to show
//! what the layout does with hubs and chains, and clean enough that the status
//! bar has nothing to complain about.
//!
//! Each is written in its dialect's own idiom rather than in portable SQL that
//! has been relabelled — backticks and `ENGINE=` for MySQL, bracketed types and
//! `IDENTITY` for SQL Server, lowercase three-part names for Snowflake. That is
//! what makes them worth having as separate samples at all, and it means
//! `draft_ddl::detect` identifies each one without being told: the samples
//! are a live demonstration of the dialect label, not a hard-coded claim.
//!
//! They live beside this file rather than inside it so the landing pages can
//! draw the same schema the application opens with. A visitor who clicks
//! through from the picture should arrive at the picture — which is also why the
//! default keeps the plain `sample.sql` name that `web/site.mjs` reads.

use draft_ddl::Dialect;

/// One schema, ready to open.
#[derive(Clone, Copy)]
pub struct Sample {
    /// What it is written in. Not passed to the parser — there are no dialect
    /// modes — and not pinned when the sample is opened either: detection gets
    /// to answer for itself, and a sample it cannot place is a bug worth seeing.
    pub dialect: Dialect,
    /// What the status bar calls it.
    pub name: &'static str,
    pub sql: &'static str,
}

const POSTGRES: Sample = Sample {
    dialect: Dialect::Postgres,
    name: "sample.sql",
    sql: include_str!("sample.sql"),
};

const MYSQL: Sample = Sample {
    dialect: Dialect::MySql,
    name: "sample-mysql.sql",
    sql: include_str!("sample-mysql.sql"),
};

const SQLITE: Sample = Sample {
    dialect: Dialect::Sqlite,
    name: "sample-sqlite.sql",
    sql: include_str!("sample-sqlite.sql"),
};

const SQLSERVER: Sample = Sample {
    dialect: Dialect::SqlServer,
    name: "sample-sqlserver.sql",
    sql: include_str!("sample-sqlserver.sql"),
};

const SNOWFLAKE: Sample = Sample {
    dialect: Dialect::Snowflake,
    name: "sample-snowflake.sql",
    sql: include_str!("sample-snowflake.sql"),
};

/// Every sample, in the order the menu lists them, which is the order
/// [`Dialect::ALL`] declares.
pub const ALL: [Sample; 5] = [POSTGRES, MYSQL, SQLITE, SQLSERVER, SNOWFLAKE];

/// The schema a first visit opens with, and the one the landing page draws.
pub const DEFAULT: Sample = POSTGRES;
