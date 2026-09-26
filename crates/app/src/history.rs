//! Undo and redo, as whole-document snapshots.
//!
//! Snapshots rather than a log of reversible commands, for the same reason the
//! diagram is rebuilt rather than patched (docs/architecture.md D2): the
//! document is a string plus a handful of small maps, and an inverse for every
//! gesture — a rename that is a byte splice, a re-arrange that discards every
//! hand-placed position, a note deleted from the middle of a list — is far more
//! code to write and to keep correct than copying the document is to run.
//!
//! The stack holds *states*, including the one on screen, with a cursor into
//! it. That is what makes [`History::commit`] safe to call after anything: a
//! commit that finds nothing changed does nothing, so restoring a state and
//! then committing it — which is exactly what an undo followed by the next
//! frame's settle looks like — cannot destroy the redo half of the stack.

use draft_ddl::Dialect;
use draft_layout::Placement;

use crate::annotate::Annotations;
use crate::app::{Dir, Gap};
use crate::document::Document;

/// How much SQL the whole history may hold.
///
/// A number of states would be the wrong unit: 64 states of a 300 KB dump is
/// 19 MB of a wasm heap, and 64 states of a hand-written schema is 200 KB.
/// Trimming by size keeps the ceiling flat and leaves ordinary documents with a
/// history nobody reaches the end of.
const BUDGET: usize = 4 << 20;

/// …and never fewer than this many states, whatever they cost. A history one
/// step deep is not a history.
const FLOOR: usize = 8;

/// Everything a gesture can change, and nothing derived from it.
///
/// The layout direction and spacing are in here; the theme and the pane
/// visibility are not. Those two describe the arrangement of the diagram —
/// Arrange is the one gesture that throws away hand-placed tables, and the
/// direction that produced the arrangement has to come back with them — while
/// dark mode and a hidden SQL pane are how you are looking at it, which is not
/// something anybody expects Ctrl+Z to touch.
#[derive(Clone, PartialEq)]
pub struct Snapshot {
    pub name: String,
    pub sql: String,
    pub placement: Placement,
    pub annotations: Annotations,
    pub dialect_pin: Option<Dialect>,
    pub direction: Dir,
    pub spacing: Gap,
}

impl Snapshot {
    /// The document as it now stands.
    ///
    /// The layout options are passed in rather than read out of the document,
    /// because that is where they live: they are a preference that outlives any
    /// one schema, and are captured here only because undoing an Arrange
    /// without them would leave the menus describing a diagram that is no
    /// longer on screen.
    pub fn of(doc: &Document, direction: Dir, spacing: Gap) -> Self {
        Self {
            name: doc.name.clone(),
            sql: doc.sql.clone(),
            placement: doc.placement.clone(),
            annotations: doc.annotations.clone(),
            dialect_pin: doc.dialect_pin,
            direction,
            spacing,
        }
    }
}

pub struct History {
    /// Every state, oldest first, including the one on screen.
    states: Vec<Snapshot>,
    /// Which of them is on screen.
    at: usize,
}

impl History {
    pub fn new(opening: Snapshot) -> Self {
        Self {
            states: vec![opening],
            at: 0,
        }
    }

    /// Record the document as it now stands.
    ///
    /// Called *after* a change rather than before it, so a gesture only has to
    /// say "done" — and a gesture that turned out to change nothing, such as a
    /// drag that ended where it started, records nothing.
    pub fn commit(&mut self, now: Snapshot) {
        if self.states[self.at] == now {
            return;
        }
        // Anything ahead of the cursor was a future that has now not happened.
        self.states.truncate(self.at + 1);
        self.states.push(now);
        self.at = self.states.len() - 1;
        self.trim();
    }

    pub fn can_undo(&self) -> bool {
        self.at > 0
    }

    pub fn can_redo(&self) -> bool {
        self.at + 1 < self.states.len()
    }

    /// The state before this one, which becomes the state on screen.
    ///
    /// Cloned rather than borrowed: the caller rebuilds the whole document from
    /// it, which means holding `&mut` on everything including this.
    pub fn undo(&mut self) -> Option<Snapshot> {
        if !self.can_undo() {
            return None;
        }
        self.at -= 1;
        Some(self.states[self.at].clone())
    }

    pub fn redo(&mut self) -> Option<Snapshot> {
        if !self.can_redo() {
            return None;
        }
        self.at += 1;
        Some(self.states[self.at].clone())
    }

    /// Drop the oldest states until the history fits in its budget.
    fn trim(&mut self) {
        while self.states.len() > FLOOR && self.bytes() > BUDGET {
            self.states.remove(0);
            self.at = self.at.saturating_sub(1);
        }
    }

    fn bytes(&self) -> usize {
        self.states.iter().map(|s| s.sql.len()).sum()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn snap(sql: &str) -> Snapshot {
        Snapshot {
            name: "t.sql".to_owned(),
            sql: sql.to_owned(),
            placement: Placement::default(),
            annotations: Annotations::default(),
            dialect_pin: None,
            direction: Dir::Horizontal,
            spacing: Gap::Comfortable,
        }
    }

    /// The shape of the thing: three edits, three steps back, three forward.
    #[test]
    fn undo_walks_back_through_the_states_and_redo_walks_forward() {
        let mut history = History::new(snap("a"));
        for sql in ["b", "c", "d"] {
            history.commit(snap(sql));
        }

        assert_eq!(history.undo().map(|s| s.sql).as_deref(), Some("c"));
        assert_eq!(history.undo().map(|s| s.sql).as_deref(), Some("b"));
        assert_eq!(history.undo().map(|s| s.sql).as_deref(), Some("a"));
        assert!(!history.can_undo(), "walked back past the first state");
        assert!(history.undo().is_none());

        assert_eq!(history.redo().map(|s| s.sql).as_deref(), Some("b"));
        assert_eq!(history.redo().map(|s| s.sql).as_deref(), Some("c"));
        assert_eq!(history.redo().map(|s| s.sql).as_deref(), Some("d"));
        assert!(!history.can_redo());
        assert!(history.redo().is_none());
    }

    /// The invariant the whole design rests on. An undo hands a state back to
    /// the application, which puts it on screen and then commits it like any
    /// other document that has just landed — and if that commit counted as an
    /// edit it would delete the redo stack, so an undo could never be followed
    /// by a redo.
    #[test]
    fn re_committing_a_restored_state_is_not_an_edit() {
        let mut history = History::new(snap("a"));
        history.commit(snap("b"));

        let back = history.undo().expect("a state to go back to");
        history.commit(back);

        assert!(history.can_redo(), "the redo was thrown away");
        assert_eq!(history.redo().map(|s| s.sql).as_deref(), Some("b"));
    }

    /// Editing after an undo is a new branch: the future that was undone is
    /// gone, and offering a redo into it would put text on screen that nobody
    /// typed.
    #[test]
    fn an_edit_after_an_undo_drops_what_was_undone() {
        let mut history = History::new(snap("a"));
        history.commit(snap("b"));
        history.undo();
        history.commit(snap("c"));

        assert!(!history.can_redo());
        assert_eq!(history.undo().map(|s| s.sql).as_deref(), Some("a"));
    }

    /// A drag reports a position every frame, and a debounced re-parse can land
    /// on text byte-identical to what was already recorded. Neither is an edit.
    #[test]
    fn nothing_is_recorded_when_nothing_changed() {
        let mut history = History::new(snap("a"));
        for _ in 0..50 {
            history.commit(snap("a"));
        }
        assert!(!history.can_undo());
    }

    /// The layout options travel with the positions, because undoing the
    /// Arrange that a direction change asked for has to put the direction back
    /// too — otherwise the menus describe a diagram that is no longer there.
    #[test]
    fn the_layout_options_are_part_of_the_state() {
        let mut history = History::new(snap("a"));
        history.commit(Snapshot {
            direction: Dir::Vertical,
            ..snap("a")
        });

        let back = history.undo().expect("a state to go back to");
        assert_eq!(back.direction, Dir::Horizontal);
    }

    /// A long session with a big schema must not grow without bound, and a
    /// session with a small one must not be trimmed at all.
    #[test]
    fn the_history_stops_growing_at_its_budget() {
        // Sixteen of these fit, so the seventeenth edit has to push the oldest
        // state out and every edit after it has to keep doing so.
        let each = "x".repeat(BUDGET / 16);
        let mut history = History::new(snap(&each));
        for i in 0..40 {
            history.commit(snap(&format!("{each}{i}")));
        }
        assert!(
            history.bytes() <= BUDGET + each.len(),
            "{} bytes held",
            history.bytes()
        );
        assert!(history.can_undo(), "trimmed away the whole history");

        // A schema so big that the budget cannot hold even the floor keeps the
        // floor regardless: being able to undo is worth more than the memory.
        let huge = "x".repeat(BUDGET / 4);
        let mut history = History::new(snap(&huge));
        for i in 0..20 {
            history.commit(snap(&format!("{huge}{i}")));
        }
        assert_eq!(history.states.len(), FLOOR);

        let mut small = History::new(snap("a"));
        for i in 0..200 {
            small.commit(snap(&i.to_string()));
        }
        assert_eq!(small.states.len(), 201, "a small history is never trimmed");
    }
}
