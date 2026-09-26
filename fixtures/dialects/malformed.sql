-- Deliberately broken input: the shapes that arrive when a schema is pasted
-- out of a chat window. None of them may stop the rest of the file parsing,
-- and none of them may produce an empty result.

CREATE TABLE good_one (
  id int PRIMARY KEY,
  name text
);

CREATE TABLE ;

ALTER TABLE ADD CONSTRAINT;

)));

CREATE TABLE dup (a int);
CREATE TABLE dup (b int);

CREATE TABLE truncated (
  id int,
  name text
