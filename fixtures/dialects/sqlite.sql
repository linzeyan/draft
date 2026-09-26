-- SQLite: double-quoted identifiers, inline REFERENCES, and the typeless
-- column form that is legal here and nowhere else.

CREATE TABLE IF NOT EXISTS "notebook" (
  "id"      INTEGER PRIMARY KEY,
  "title"   TEXT NOT NULL UNIQUE,
  "created" INTEGER DEFAULT (strftime('%s','now'))
);

CREATE TABLE IF NOT EXISTS "note" (
  "id"          INTEGER PRIMARY KEY AUTOINCREMENT,
  "notebook_id" INTEGER REFERENCES "notebook"("id") ON DELETE CASCADE,
  "body"        TEXT NOT NULL,
  "pinned"      BOOLEAN DEFAULT 0
);

CREATE TABLE tagless (a, b, c);

CREATE INDEX note_notebook ON note(notebook_id);
