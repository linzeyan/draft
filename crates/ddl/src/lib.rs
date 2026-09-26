//! Tolerant, span-preserving SQL DDL parser.
//!
//! Extracts tables, columns and foreign keys from `CREATE TABLE` / `ALTER
//! TABLE` statements across PostgreSQL, MySQL, SQLite, SQL Server and
//! Snowflake dialects. Two properties matter more than coverage:
//!
//! 1. **It never refuses a script.** An unfamiliar statement is skipped, a
//!    broken one becomes a [`Warning`]. There is no parse failure mode, only a
//!    less complete [`Schema`].
//! 2. **Every identifier carries its byte [`Span`]** in the original source, so
//!    renaming a table on a canvas is a byte splice rather than a regeneration.
//!    Comments, formatting and clauses this parser does not understand survive
//!    untouched. Comments are blanked to equal-length whitespace rather than
//!    removed, which is what keeps the offsets valid.
//!
//! ```
//! let schema = draft_ddl::parse("CREATE TABLE users (id int PRIMARY KEY);");
//! assert_eq!(schema.tables[0].name, "users");
//! assert!(schema.tables[0].columns[0].pk);
//! ```

use std::collections::HashMap;

mod dialect;
mod highlight;
mod scan;
mod stmt;

pub use dialect::{Dialect, detect};
pub use highlight::{Token, highlight, highlight_until};

/// A byte range in the original SQL. Half-open: `[start, end)`.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Span {
    pub start: usize,
    pub end: usize,
}

impl Span {
    pub fn new(start: usize, end: usize) -> Self {
        Self { start, end }
    }

    pub fn len(&self) -> usize {
        self.end.saturating_sub(self.start)
    }

    pub fn is_empty(&self) -> bool {
        self.end <= self.start
    }

    pub fn range(&self) -> std::ops::Range<usize> {
        self.start..self.end
    }

    /// The text this span covers, or `""` if it does not address a valid slice
    /// of `src`. Never panics: a parser that cannot fail must not have
    /// accessors that can.
    pub fn text<'a>(&self, src: &'a str) -> &'a str {
        src.get(self.range()).unwrap_or("")
    }
}

/// A parsed schema. Always returned, however malformed the input.
#[derive(Debug, Default)]
pub struct Schema {
    pub tables: Vec<Table>,
    pub relations: Vec<Relation>,
    /// Non-blocking notes about what could not be understood.
    pub warnings: Vec<Warning>,
    by_key: HashMap<String, usize>,
}

impl Schema {
    pub fn table(&self, name: &str) -> Option<&Table> {
        self.index_of(name).map(|i| &self.tables[i])
    }

    /// Position of a table in [`Schema::tables`], looked up case-insensitively.
    /// Layout and rendering resolve every relation through this, so it is a map
    /// rather than a scan.
    pub fn index_of(&self, name: &str) -> Option<usize> {
        self.by_key.get(&name.to_lowercase()).copied()
    }
}

#[derive(Debug)]
pub struct Table {
    /// As written in the source, unqualified and unquoted.
    pub name: String,
    /// Lowercased `name`; the identity used for lookup.
    pub key: String,
    pub columns: Vec<Column>,
    /// The bare table name in `CREATE TABLE …`, excluding schema and quotes.
    pub name_span: Option<Span>,
    /// Between the body parentheses, exclusive.
    pub body_span: Option<Span>,
    /// The whole `CREATE TABLE …` statement, excluding the `;`.
    pub stmt_span: Option<Span>,
    /// Every place this table's *name* appears outside its `CREATE TABLE`: the
    /// target of an `ALTER TABLE`, and every incoming `REFERENCES`. A table
    /// rename must splice all of these, or the script stops being valid SQL.
    ///
    /// `CREATE INDEX … ON t` is in here, because indexes are parsed. Triggers,
    /// views and functions are not and cannot be, so a rename does not reach
    /// them. That is a known limit of span-based editing, not an oversight.
    pub name_refs: Vec<Span>,
    /// Every place one of this table's column names appears *outside* its own
    /// definition: `PRIMARY KEY (…)`, `UNIQUE (…)`, `FOREIGN KEY (…)` and
    /// incoming `REFERENCES t(col)`. A column rename must splice all of these
    /// too, or the script stops being valid SQL.
    pub col_refs: Vec<ColRef>,
    /// The indexes this table's script declares, in the order it declares them.
    pub indexes: Vec<Index>,
}

/// An index the script spells out.
///
/// An index constrains nothing the diagram draws, but it is half of why a
/// schema performs the way it does, and a viewer that silently drops the
/// `CREATE INDEX` statements is hiding something the script says out loud.
///
/// A `PRIMARY KEY` is not in here: every database indexes it, nobody writes it
/// for the index, and the column already carries a `PK` badge. An anonymous
/// `UNIQUE (a, b)` is not in here either — there is nothing to show but the
/// columns, and the badge already shows those.
#[derive(Debug)]
pub struct Index {
    /// `None` for MySQL's unnamed `KEY (col)`, where the server invents a name
    /// this script does not contain.
    pub name: Option<String>,
    /// As written, in index order, which is the order that decides what the
    /// index can be used for.
    pub columns: Vec<String>,
    pub unique: bool,
}

impl Table {
    pub fn column(&self, name: &str) -> Option<&Column> {
        let name = name.to_lowercase();
        self.columns.iter().find(|c| c.name.to_lowercase() == name)
    }

    fn column_mut(&mut self, name: &str) -> Option<&mut Column> {
        let name = name.to_lowercase();
        self.columns
            .iter_mut()
            .find(|c| c.name.to_lowercase() == name)
    }
}

#[derive(Debug)]
pub struct Column {
    pub name: String,
    /// Normalised for display: `character varying(255)`, `numeric(10,2)`.
    pub ty: String,
    /// Exactly as written, for splicing decisions.
    pub ty_raw: String,
    pub pk: bool,
    pub not_null: bool,
    pub unique: bool,
    pub fk: bool,
    /// The bare column name, excluding quotes.
    pub name_span: Span,
    pub ty_span: Option<Span>,
    /// The whole `name type …` segment between commas.
    pub def_span: Span,
}

/// An occurrence of a column name in a key or reference clause.
#[derive(Debug)]
pub struct ColRef {
    /// Lowercased, to match against [`Column::name`].
    pub name: String,
    pub span: Span,
}

/// How many rows each end of a relationship can have.
///
/// Inferred from the constraints rather than declared: a foreign key always
/// points at one row of the parent, so the only question is whether the child
/// can have more than one row pointing back, and that is answered by whether
/// the child's own key covers the foreign key's columns.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Cardinality {
    /// One parent row, many child rows. The overwhelmingly common case.
    OneToMany,
    /// The child's foreign key is itself unique, so at most one child row.
    OneToOne,
}

#[derive(Debug)]
pub struct Relation {
    pub from_table: String,
    pub from_cols: Vec<String>,
    pub to_table: String,
    pub to_cols: Vec<String>,
    /// What the child's constraints make of it. A composite `UNIQUE (a, b)`
    /// with no name is not detected — see [`Index`] for why it is not recorded
    /// — so such a relationship reads as one-to-many. Erring towards many is
    /// the safe direction: it claims less.
    pub cardinality: Cardinality,
    /// The referenced table is not defined anywhere in this script. Drawn as a
    /// dangling edge rather than dropped, because a schema split across files
    /// is normal.
    pub to_missing: bool,
    /// The bare table name inside `REFERENCES …`, for rename propagation.
    pub ref_span: Option<Span>,
}

#[derive(Debug)]
pub struct Warning {
    pub message: String,
    pub span: Option<Span>,
}

/// Parse a SQL script. Never fails and never panics.
pub fn parse(sql: &str) -> Schema {
    stmt::Builder::run(sql)
}
