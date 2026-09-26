-- A reading list, in SQLite's own idiom: `INTEGER PRIMARY KEY` rowid aliases,
-- `AUTOINCREMENT`, quoted identifiers and inline `REFERENCES`. Paste your own
-- schema over it, or drop a .sql file anywhere on this window.

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS "shelf" (
  "id"       INTEGER PRIMARY KEY AUTOINCREMENT,
  "name"     TEXT NOT NULL UNIQUE,
  "created"  INTEGER NOT NULL DEFAULT (strftime('%s','now'))
);

CREATE TABLE IF NOT EXISTS "author" (
  "id"       INTEGER PRIMARY KEY AUTOINCREMENT,
  "name"     TEXT NOT NULL,
  "country"  TEXT
);

CREATE TABLE IF NOT EXISTS "book" (
  "id"        INTEGER PRIMARY KEY AUTOINCREMENT,
  "shelf_id"  INTEGER REFERENCES "shelf"("id") ON DELETE SET NULL,
  "isbn"      TEXT UNIQUE,
  "title"     TEXT NOT NULL,
  "pages"     INTEGER,
  "finished"  INTEGER NOT NULL DEFAULT 0
);

-- A pure join table, so there is no rowid worth storing.
CREATE TABLE IF NOT EXISTS "book_author" (
  "book_id"    INTEGER NOT NULL REFERENCES "book"("id") ON DELETE CASCADE,
  "author_id"  INTEGER NOT NULL REFERENCES "author"("id"),
  "billed"     INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY ("book_id", "author_id")
) WITHOUT ROWID;

CREATE TABLE IF NOT EXISTS "reading_session" (
  "id"        INTEGER PRIMARY KEY AUTOINCREMENT,
  "book_id"   INTEGER NOT NULL REFERENCES "book"("id") ON DELETE CASCADE,
  "started"   INTEGER NOT NULL,
  "ended"     INTEGER,
  "last_page" INTEGER
);

CREATE TABLE IF NOT EXISTS "highlight" (
  "id"       INTEGER PRIMARY KEY AUTOINCREMENT,
  "book_id"  INTEGER NOT NULL REFERENCES "book"("id") ON DELETE CASCADE,
  "page"     INTEGER NOT NULL,
  "quote"    TEXT NOT NULL,
  "colour"   TEXT NOT NULL DEFAULT 'yellow'
);

CREATE TABLE IF NOT EXISTS "note" (
  "id"            INTEGER PRIMARY KEY AUTOINCREMENT,
  "book_id"       INTEGER NOT NULL REFERENCES "book"("id") ON DELETE CASCADE,
  "highlight_id"  INTEGER REFERENCES "highlight"("id") ON DELETE CASCADE,
  "body"          TEXT NOT NULL,
  "written"       INTEGER NOT NULL DEFAULT (strftime('%s','now'))
);

CREATE TABLE IF NOT EXISTS "tag" (
  "id"     INTEGER PRIMARY KEY AUTOINCREMENT,
  "label"  TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS "book_tag" (
  "book_id"  INTEGER NOT NULL REFERENCES "book"("id") ON DELETE CASCADE,
  "tag_id"   INTEGER NOT NULL REFERENCES "tag"("id") ON DELETE CASCADE,
  PRIMARY KEY ("book_id", "tag_id")
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS "idx_highlight_book" ON "highlight"("book_id");
