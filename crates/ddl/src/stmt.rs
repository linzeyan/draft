//! Statement-level parsing, driven entirely by the token stream.
//!
//! The reference implementation matches statements with regular expressions;
//! this port scans tokens instead. That is not a stylistic choice: `regex`
//! would be one of the largest single contributors to the wasm payload we are
//! budgeting in R1, and the token stream already carries the spans we need.

use std::collections::HashMap;

use crate::scan::{
    Chunk, Token, bare_name, blank_comments, pretty_type, split_statements, split_top_commas,
    tokenize,
};
use crate::{Cardinality, ColRef, Column, Index, Relation, Schema, Span, Table, Warning};

/// Words permitted between `CREATE` and `TABLE`. Anything else means this is a
/// `CREATE INDEX` / `VIEW` / `FUNCTION` and we must not touch it.
const CREATE_MODIFIERS: &[&str] = &[
    "or",
    "replace",
    "temporary",
    "temp",
    "global",
    "local",
    "unlogged",
    "transient",
    "volatile",
    "hybrid",
    "iceberg",
    "dynamic",
    "external",
    "virtual",
];

/// Index clauses. They constrain nothing, but their column lists still have to
/// move when a column is renamed — leaving `KEY idx (old_name)` behind makes
/// the script invalid.
const INDEX_HEADS: &[&str] = &["key", "index", "fulltext", "spatial"];

/// Every word that can head a key clause, including the two that are not
/// indexes. Used to tell `KEY idx (a)` from `KEY (a)`: if the word before the
/// column list is one of these, the clause named nothing.
const KEY_HEADS: &[&str] = &[
    "key",
    "index",
    "fulltext",
    "spatial",
    "unique",
    "primary",
    "clustered",
    "nonclustered",
];

/// Words between `CREATE` and `INDEX` that describe the index rather than
/// changing what the statement is.
const INDEX_MODIFIERS: &[&str] = &[
    "clustered",
    "nonclustered",
    "fulltext",
    "spatial",
    "bitmap",
    "columnstore",
];

/// Clause heads that introduce something other than a column and carry no
/// column list we can follow.
const NON_COLUMN_HEADS: &[&str] = &["check", "exclude", "period", "like", "inherits"];

/// Words that cannot begin a type, so a column starting with one is typeless
/// (`CREATE TABLE t (id, name)` is legal SQLite).
const NON_TYPE_WORDS: &[&str] = &[
    "primary",
    "not",
    "null",
    "unique",
    "references",
    "default",
    "check",
    "constraint",
    "generated",
    "collate",
    "auto_increment",
    "comment",
    "as",
];

/// Type words that continue a multi-word type. `pg_dump` emits `character
/// varying(255)` and `timestamp without time zone` constantly; showing those as
/// `character` and `timestamp` would be wrong on the most important input we
/// have.
const TYPE_CONTINUATIONS: &[&str] = &["varying", "precision", "unsigned", "signed", "zerofill"];

#[derive(Clone, Copy)]
enum KeyKind {
    Pk,
    Unique,
    /// Records the column references without constraining anything.
    Index,
}

/// A `CREATE INDEX` before its table is known to exist. Schemas do arrive with
/// the indexes in a block at the end, but nothing stops them arriving first.
struct RawIndex {
    table: String,
    index: Index,
    /// The index's own column list, so a column rename splices it.
    col_refs: Vec<ColRef>,
}

/// A relation before the target table is known to exist.
struct RawRelation {
    from_table: String,
    from_cols: Vec<String>,
    to_table: String,
    to_cols: Vec<String>,
    ref_span: Option<Span>,
    /// Occurrences of the *target* table's column names inside this clause.
    /// Renaming `users.id` has to update `REFERENCES users(id)` everywhere.
    to_col_refs: Vec<ColRef>,
}

pub(crate) struct Builder<'a> {
    src: &'a str,
    tables: Vec<Table>,
    by_key: HashMap<String, usize>,
    relations: Vec<RawRelation>,
    warnings: Vec<Warning>,
    /// `ALTER TABLE <here>` targets, keyed by lowercased table name. Resolved
    /// in `finish` rather than inline, so an ALTER that precedes its CREATE
    /// still contributes its span — schemas do arrive in that order.
    pending_name_refs: Vec<(String, Span)>,
    /// `CREATE INDEX` statements, resolved in `finish` for the same reason.
    pending_indexes: Vec<RawIndex>,
}

impl<'a> Builder<'a> {
    pub(crate) fn run(sql: &'a str) -> Schema {
        let blanked = blank_comments(sql);
        let mut b = Builder {
            src: sql,
            tables: Vec::new(),
            by_key: HashMap::new(),
            relations: Vec::new(),
            warnings: Vec::new(),
            pending_name_refs: Vec::new(),
            pending_indexes: Vec::new(),
        };
        for st in split_statements(&blanked) {
            let toks = tokenize(st.text, st.start);
            if b.create_table(&st, &toks) || b.create_index(&toks) {
                continue;
            }
            b.alter_table(&toks);
        }
        b.finish()
    }

    fn warn(&mut self, message: String, span: Option<Span>) {
        self.warnings.push(Warning { message, span });
    }

    fn ensure_table(&mut self, name: &str, name_span: Option<Span>) -> usize {
        let key = name.to_lowercase();
        if let Some(&i) = self.by_key.get(&key) {
            if self.tables[i].name_span.is_none() {
                self.tables[i].name_span = name_span;
            }
            return i;
        }
        let i = self.tables.len();
        self.tables.push(Table {
            name: name.to_owned(),
            key: key.clone(),
            columns: Vec::new(),
            name_span,
            body_span: None,
            stmt_span: None,
            name_refs: Vec::new(),
            col_refs: Vec::new(),
            indexes: Vec::new(),
        });
        self.by_key.insert(key, i);
        i
    }

    /// Returns whether this statement was a `CREATE TABLE`, consumed or not.
    fn create_table(&mut self, st: &Chunk<'_>, toks: &[Token<'_>]) -> bool {
        if !toks.first().is_some_and(|t| t.is("create")) {
            return false;
        }
        let mut i = 1;
        while toks
            .get(i)
            .is_some_and(|t| CREATE_MODIFIERS.iter().any(|m| t.is(m)))
        {
            i += 1;
        }
        if !toks.get(i).is_some_and(|t| t.is("table")) {
            return false;
        }
        i += 1;
        if ["if", "not", "exists"]
            .iter()
            .enumerate()
            .all(|(n, w)| toks.get(i + n).is_some_and(|t| t.is(w)))
        {
            i += 3;
        }
        let Some(name_tok) = toks.get(i) else {
            self.warn(
                "CREATE TABLE without a table name".into(),
                Some(Span::new(toks[0].start, toks[0].end)),
            );
            return true;
        };
        // The body must be the token right after the name. Scanning further
        // would find the first paren of a `CREATE TABLE … AS SELECT …`, which
        // has no column definitions to take.
        let Some(body_tok) = toks.get(i + 1).filter(|t| t.is_group()) else {
            return true;
        };

        let name = name_tok.bare_name().to_owned();
        let name_span = name_tok.bare_span();
        let already_defined = self.by_key.contains_key(&name.to_lowercase());
        let idx = self.ensure_table(&name, Some(name_span));
        // A second CREATE for the same table still spells the name out, and a
        // rename that skipped it would split one table into two.
        if self.tables[idx].name_span != Some(name_span) {
            self.tables[idx].name_refs.push(name_span);
        }
        if already_defined && self.tables[idx].body_span.is_some() {
            self.warn(
                format!("table \"{name}\" is created more than once; definitions are merged"),
                Some(name_span),
            );
        }
        if !body_tok.text.ends_with(')') {
            self.warn(
                format!("unbalanced parentheses in table \"{name}\""),
                Some(name_span),
            );
        }

        let (inner, inner_base) = body_tok.group_inner();
        self.tables[idx].body_span = Some(Span::new(inner_base, inner_base + inner.len()));
        self.tables[idx].stmt_span = Some(Span::new(
            toks[0].start,
            st.start + st.text.trim_end().len(),
        ));
        self.table_body(idx, inner, inner_base);
        true
    }

    /// `CREATE [UNIQUE] INDEX [IF NOT EXISTS] name ON t [USING m] (cols)`.
    ///
    /// Parsed for two reasons. The obvious one is that an index is worth
    /// showing. The other is that a rename has to reach it: leaving
    /// `CREATE INDEX i ON old (old_col)` behind after renaming either the table
    /// or the column produces a script that no longer runs, and until this
    /// statement was parsed that is exactly what happened.
    ///
    /// Returns whether the statement was a `CREATE INDEX` — including the
    /// unreadable ones, which are still not something else.
    fn create_index(&mut self, toks: &[Token<'_>]) -> bool {
        if !toks.first().is_some_and(|t| t.is("create")) {
            return false;
        }
        let mut i = 1;
        let unique = toks.get(i).is_some_and(|t| t.is("unique"));
        if unique {
            i += 1;
        }
        while toks
            .get(i)
            .is_some_and(|t| INDEX_MODIFIERS.iter().any(|m| t.is(m)))
        {
            i += 1;
        }
        if !toks.get(i).is_some_and(|t| t.is("index")) {
            return false;
        }
        i += 1;
        if ["if", "not", "exists"]
            .iter()
            .enumerate()
            .all(|(n, w)| toks.get(i + n).is_some_and(|t| t.is(w)))
        {
            i += 3;
        }
        // The name is optional: Postgres lets the server invent one, and then
        // `ON` follows immediately.
        let mut name = None;
        if toks.get(i).is_some_and(|t| !t.is("on")) {
            name = Some(toks[i].bare_name().to_owned());
            i += 1;
        }
        if !toks.get(i).is_some_and(|t| t.is("on")) {
            return true;
        }
        i += 1;
        let Some(table_tok) = toks.get(i) else {
            return true;
        };
        i += 1;
        // `USING btree`, `USING gin` — the method sits between the table and
        // the columns.
        if toks.get(i).is_some_and(|t| t.is("using")) {
            i += 2;
        }
        let Some(group) = toks.get(i).filter(|t| t.is_group()) else {
            return true;
        };

        let table = table_tok.bare_name().to_lowercase();
        self.pending_name_refs
            .push((table.clone(), table_tok.bare_span()));
        let cols = column_list(group);
        self.pending_indexes.push(RawIndex {
            table,
            index: Index {
                name,
                columns: cols.iter().map(|t| t.bare_name().to_owned()).collect(),
                unique,
            },
            col_refs: cols
                .iter()
                .map(|t| ColRef {
                    name: t.bare_name().to_lowercase(),
                    span: t.bare_span(),
                })
                .collect(),
        });
        true
    }

    /// `ALTER TABLE [ONLY] t ADD …` — `ONLY` matters because `pg_dump` emits
    /// it, and `pg_dump` puts every primary and foreign key here rather than in
    /// the `CREATE TABLE`.
    fn alter_table(&mut self, toks: &[Token<'_>]) {
        if !(toks.first().is_some_and(|t| t.is("alter"))
            && toks.get(1).is_some_and(|t| t.is("table")))
        {
            return;
        }
        let mut i = 2;
        if toks.get(i).is_some_and(|t| t.is("only")) {
            i += 1;
        }
        let Some(name_tok) = toks.get(i) else { return };
        let table = name_tok.bare_name().to_owned();
        let idx = self.by_key.get(&table.to_lowercase()).copied();
        self.pending_name_refs
            .push((table.to_lowercase(), name_tok.bare_span()));

        // One statement may carry several ADDs; the tokenizer drops the commas
        // between them, so slice on the ADDs themselves.
        let adds: Vec<usize> = toks
            .iter()
            .enumerate()
            .skip(i)
            .filter(|(_, t)| t.is("add"))
            .map(|(n, _)| n)
            .collect();
        for (n, &a) in adds.iter().enumerate() {
            let end = adds.get(n + 1).copied().unwrap_or(toks.len());
            self.constraint(idx, &table, &toks[a + 1..end]);
        }
    }

    fn table_body(&mut self, idx: usize, body: &str, base: usize) {
        let table = self.tables[idx].name.clone();
        for part in split_top_commas(body, base) {
            if part.text.trim().is_empty() {
                continue;
            }
            let toks = tokenize(part.text, part.start);
            let Some(head) = toks.first() else { continue };

            if ["primary", "unique", "foreign", "constraint"]
                .iter()
                .any(|w| head.is(w))
            {
                self.constraint(Some(idx), &table, &toks);
                continue;
            }
            if INDEX_HEADS.iter().any(|w| head.is(w)) {
                self.mark_key(Some(idx), &toks, KeyKind::Index);
                self.body_index(idx, &toks, None, false);
                continue;
            }
            if NON_COLUMN_HEADS.iter().any(|w| head.is(w)) {
                continue;
            }
            self.column(idx, &table, &part, &toks);
        }
    }

    /// A constraint clause, with or without a leading `CONSTRAINT <name>`.
    /// Shared by table bodies and `ALTER TABLE … ADD` tails, which is why the
    /// table index is optional: an `ALTER` may name a table we never saw.
    fn constraint(&mut self, idx: Option<usize>, table: &str, toks: &[Token<'_>]) {
        // The constraint's own name, which is also the name of the index a
        // `UNIQUE` constraint creates — and the only place that name appears.
        let named = match toks.first() {
            Some(t) if t.is("constraint") && toks.len() > 2 => Some(toks[1].bare_name().to_owned()),
            _ => None,
        };
        let toks = match toks.first() {
            Some(t) if t.is("constraint") && toks.len() > 2 => &toks[2..],
            _ => toks,
        };
        match toks.first() {
            Some(t) if t.is("primary") => self.mark_key(idx, toks, KeyKind::Pk),
            Some(t) if t.is("unique") => {
                self.mark_key(idx, toks, KeyKind::Unique);
                if let Some(idx) = idx {
                    self.body_index(idx, toks, named, true);
                }
            }
            Some(t) if t.is("foreign") => self.foreign_key(idx, table, toks),
            _ => {}
        }
    }

    /// The index a key clause inside a table body declares.
    ///
    /// `KEY idx (a, b)`, `UNIQUE KEY uq (a)`, `CONSTRAINT uq UNIQUE (a)`. An
    /// anonymous `UNIQUE (a)` is skipped: it names nothing this script
    /// contains, and the column already carries the badge that says it is
    /// unique. An anonymous `KEY (a)` is kept, because there the column list is
    /// the only thing that was said at all.
    fn body_index(&mut self, idx: usize, toks: &[Token<'_>], named: Option<String>, unique: bool) {
        let Some(at) = toks.iter().position(|t| t.is_group()) else {
            return;
        };
        let name = named.or_else(|| {
            let prev = toks[..at].last()?;
            let is_head = prev.is_group() || KEY_HEADS.iter().any(|w| prev.is(w));
            (!is_head).then(|| prev.bare_name().to_owned())
        });
        if unique && name.is_none() {
            return;
        }
        self.tables[idx].indexes.push(Index {
            name,
            columns: column_list(&toks[at])
                .iter()
                .map(|t| t.bare_name().to_owned())
                .collect(),
            unique,
        });
    }

    fn mark_key(&mut self, idx: Option<usize>, toks: &[Token<'_>], kind: KeyKind) {
        let (Some(idx), Some(grp)) = (idx, toks.iter().find(|t| t.is_group())) else {
            return;
        };
        let cols = column_list(grp);
        let single = cols.len() == 1;
        for col_tok in cols {
            let name = col_tok.bare_name().to_lowercase();
            if let Some(col) = self.tables[idx].column_mut(&name) {
                match kind {
                    KeyKind::Pk => col.pk = true,
                    // Only when the key is this column alone. `UNIQUE (a, b)`
                    // makes the *pair* unique and neither column unique, and a
                    // badge on both would claim something the schema does not
                    // allow — as would a one-to-one edge drawn from a foreign
                    // key on just one of them.
                    KeyKind::Unique if single => col.unique = true,
                    KeyKind::Unique | KeyKind::Index => {}
                }
            }
            self.tables[idx].col_refs.push(ColRef {
                name,
                span: col_tok.bare_span(),
            });
        }
    }

    /// `FOREIGN KEY (a, b) REFERENCES other (c, d)`.
    fn foreign_key(&mut self, idx: Option<usize>, table: &str, toks: &[Token<'_>]) {
        if !toks.get(1).is_some_and(|t| t.is("key")) {
            return;
        }
        let Some(local) = toks.get(2).filter(|t| t.is_group()) else {
            return;
        };
        let Some(r) = toks.iter().position(|t| t.is("references")) else {
            return;
        };

        let local_cols = column_list(local);
        if let Some(idx) = idx {
            for t in &local_cols {
                self.tables[idx].col_refs.push(ColRef {
                    name: t.bare_name().to_lowercase(),
                    span: t.bare_span(),
                });
            }
        }
        self.reference(
            table,
            local_cols
                .iter()
                .map(|t| t.bare_name().to_owned())
                .collect(),
            toks,
            r,
        );
    }

    /// Record `REFERENCES target (cols)` starting at token `r`.
    fn reference(
        &mut self,
        from_table: &str,
        from_cols: Vec<String>,
        toks: &[Token<'_>],
        r: usize,
    ) {
        let Some(to_tok) = toks.get(r + 1) else {
            return;
        };
        let to_group = toks.get(r + 2).filter(|t| t.is_group());
        let to_cols = to_group.map(|g| column_list(g)).unwrap_or_default();
        self.relations.push(RawRelation {
            from_table: from_table.to_owned(),
            from_cols,
            to_table: to_tok.bare_name().to_owned(),
            to_cols: to_cols.iter().map(|t| t.bare_name().to_owned()).collect(),
            ref_span: Some(to_tok.bare_span()),
            to_col_refs: to_cols
                .iter()
                .map(|t| ColRef {
                    name: t.bare_name().to_lowercase(),
                    span: t.bare_span(),
                })
                .collect(),
        });
    }

    fn column(&mut self, idx: usize, table: &str, part: &Chunk<'_>, toks: &[Token<'_>]) {
        let name_tok = toks[0];
        let name = name_tok.bare_name();
        if name.is_empty() {
            return;
        }
        let name = name.to_owned();

        let ty_span = self.type_span(toks);
        let ty_raw = ty_span
            .map(|s| s.text(self.src))
            .unwrap_or_default()
            .to_owned();

        let has_pair = |a: &str, b: &str| toks.windows(2).any(|w| w[0].is(a) && w[1].is(b));
        let inline_ref = toks.iter().position(|t| t.is("references"));

        self.tables[idx].columns.push(Column {
            ty: pretty_type(&ty_raw),
            ty_raw,
            pk: has_pair("primary", "key"),
            not_null: has_pair("not", "null"),
            // Skip the name token so a column called `unique` is not flagged by
            // its own name.
            unique: toks.iter().skip(1).any(|t| t.is("unique")),
            fk: inline_ref.is_some(),
            name_span: name_tok.bare_span(),
            ty_span,
            def_span: Span::new(part.start, part.start + part.text.len()),
            name: name.clone(),
        });

        if let Some(r) = inline_ref {
            self.reference(table, vec![name], toks, r);
        }
    }

    /// Span of the column's type: the token after the name, plus any
    /// parenthesised argument and multi-word continuation.
    fn type_span(&self, toks: &[Token<'_>]) -> Option<Span> {
        let first = toks.get(1)?;
        if first.is_group() || NON_TYPE_WORDS.iter().any(|w| first.is(w)) {
            return None;
        }
        let mut end = first.end;
        let mut j = 2;
        while let Some(t) = toks.get(j) {
            if t.is_group() || TYPE_CONTINUATIONS.iter().any(|w| t.is(w)) {
                end = t.end;
                j += 1;
            } else if (t.is("with") || t.is("without"))
                && toks.get(j + 1).is_some_and(|t| t.is("time"))
                && toks.get(j + 2).is_some_and(|t| t.is("zone"))
            {
                end = toks[j + 2].end;
                j += 3;
            } else {
                break;
            }
        }
        Some(Span::new(first.start, end))
    }

    fn finish(mut self) -> Schema {
        // Before the relations, because a relation's cardinality is decided by
        // whether a unique index covers its columns.
        //
        // An index on a table this script never defines has nothing to hang
        // off, exactly like a relation whose owner is missing.
        for raw in std::mem::take(&mut self.pending_indexes) {
            if let Some(&i) = self.by_key.get(&raw.table) {
                self.tables[i].col_refs.extend(raw.col_refs);
                self.tables[i].indexes.push(raw.index);
            }
        }

        let raw = std::mem::take(&mut self.relations);
        let mut relations = Vec::with_capacity(raw.len());
        for r in raw {
            // A relation whose owner we never saw has nothing to hang off.
            let Some(&from) = self.by_key.get(&r.from_table.to_lowercase()) else {
                continue;
            };
            for c in &r.from_cols {
                if let Some(col) = self.tables[from].column_mut(c) {
                    col.fk = true;
                }
            }
            let to = self.by_key.get(&r.to_table.to_lowercase()).copied();
            let to_table = match to {
                Some(i) => {
                    self.tables[i].col_refs.extend(r.to_col_refs);
                    self.tables[i].name_refs.extend(r.ref_span);
                    self.tables[i].name.clone()
                }
                None => r.to_table,
            };
            let cardinality = cardinality(&self.tables[from], &r.from_cols);
            relations.push(Relation {
                from_table: self.tables[from].name.clone(),
                from_cols: r.from_cols,
                to_table,
                to_cols: r.to_cols,
                cardinality,
                to_missing: to.is_none(),
                ref_span: r.ref_span,
            });
        }
        for (key, span) in std::mem::take(&mut self.pending_name_refs) {
            if let Some(&i) = self.by_key.get(&key) {
                self.tables[i].name_refs.push(span);
            }
        }
        // Sorting makes the reference lists independent of the order the
        // parser happened to discover them in, which keeps goldens stable and
        // makes an edit's splice list read top-to-bottom like the script does.
        for t in &mut self.tables {
            t.name_refs.sort_unstable_by_key(|s| s.start);
            t.col_refs.sort_unstable_by_key(|r| r.span.start);
        }

        Schema {
            tables: self.tables,
            relations,
            warnings: self.warnings,
            by_key: self.by_key,
        }
    }
}

/// Whether the child's own key covers the foreign key's columns, which is the
/// whole question behind [`Cardinality`].
///
/// `PRIMARY KEY (a, b)` with `FOREIGN KEY (a, b)` is one-to-one. The same
/// foreign key in a table whose primary key is `(a, b, c)` is not: two child
/// rows can still share `(a, b)`.
fn cardinality(table: &Table, cols: &[String]) -> Cardinality {
    let fk: Vec<String> = cols.iter().map(|c| c.to_lowercase()).collect();
    if fk.is_empty() {
        return Cardinality::OneToMany;
    }
    let covers = |key: &[String]| key.len() == fk.len() && fk.iter().all(|c| key.contains(c));

    let pk: Vec<String> = table
        .columns
        .iter()
        .filter(|c| c.pk)
        .map(|c| c.name.to_lowercase())
        .collect();
    let unique_index = table.indexes.iter().filter(|x| x.unique).any(|x| {
        let cols: Vec<String> = x.columns.iter().map(|c| c.to_lowercase()).collect();
        covers(&cols)
    });
    let unique_column = fk.len() == 1
        && table
            .columns
            .iter()
            .any(|c| c.unique && c.name.to_lowercase() == fk[0]);

    if covers(&pk) || unique_index || unique_column {
        Cardinality::OneToOne
    } else {
        Cardinality::OneToMany
    }
}

/// The leading identifier of each entry in a `(a, b(10), c DESC)` clause.
fn column_list<'t>(group: &Token<'t>) -> Vec<Token<'t>> {
    let (inner, base) = group.group_inner();
    split_top_commas(inner, base)
        .into_iter()
        .filter_map(|seg| tokenize(seg.text, seg.start).into_iter().next())
        // A parenthesised entry is a functional index, `KEY idx ((a + b))`.
        // Following that would need expression parsing, so it names no column.
        .filter(|t| !t.is_group() && !bare_name(t.text).is_empty())
        .collect()
}
