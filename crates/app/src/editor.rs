//! The SQL pane.
//!
//! Two things here are not optional, and Phase 0's S2 spike is why: the
//! layouter's output is memoised on `(text_hash, wrap_width)`, and highlighting
//! comes from the parser's own lexer. Without the cache we would re-highlight
//! and re-lay-out an unchanged document sixty times a second; with a second
//! tokenizer the colours and the diagram would eventually disagree.
//!
//! S2 also measured where the time goes: at 106 KB in a browser, 0.97 ms is
//! ours and 6.48 ms is egui laying out every glyph in the document. So there is
//! nothing to win by making the tokenizer incremental, and the ceiling is
//! egui's — see docs/measurements.md S2 for the trigger that would make
//! virtualising the editor worth its cost.

use std::sync::Arc;

use draft_view::Syntax;
use egui::text::{LayoutJob, TextFormat};
use egui::{FontFamily, FontId, Galley, TextBuffer, Ui};

/// How long after the last keystroke the schema is re-parsed.
///
/// Long enough that a burst of typing costs one re-layout rather than thirty,
/// short enough that it reads as "while I type" rather than "when I stop".
pub const DEBOUNCE: f64 = 0.18;

pub struct Editor {
    cache: Cache,
    /// When the text was last touched, in `Context::input(|i| i.time)`.
    /// `None` means everything derived from it is up to date.
    dirty_since: Option<f64>,
    font: FontId,
}

impl Default for Editor {
    fn default() -> Self {
        Self {
            cache: Cache::default(),
            dirty_since: None,
            font: FontId::new(12.5, FontFamily::Monospace),
        }
    }
}

#[derive(Default)]
struct Cache {
    key: Option<(u64, u32, u8)>,
    galley: Option<Arc<Galley>>,
}

fn hash(s: &str) -> u64 {
    use std::hash::{Hash as _, Hasher as _};
    let mut h = std::collections::hash_map::DefaultHasher::new();
    s.hash(&mut h);
    h.finish()
}

impl Cache {
    fn layout(
        &mut self,
        ui: &Ui,
        text: &str,
        wrap_width: f32,
        font: &FontId,
        syntax: &Syntax,
        theme_key: u8,
    ) -> Arc<Galley> {
        let key = (hash(text), wrap_width.to_bits(), theme_key);
        if self.key == Some(key)
            && let Some(galley) = &self.galley
        {
            return galley.clone();
        }

        let mut job = LayoutJob::default();
        for (span, token) in draft_ddl::highlight(text) {
            job.append(
                span.text(text),
                0.0,
                TextFormat {
                    font_id: font.clone(),
                    color: syntax.of(token),
                    ..Default::default()
                },
            );
        }
        // A SQL editor does not soft-wrap: long lines scroll sideways, as in
        // every code editor. S2 measured this as performance-neutral (2.12 ms
        // vs 2.10 ms), so it is a behaviour choice, not an optimisation.
        job.wrap.max_width = f32::INFINITY;

        let galley = ui.ctx().fonts_mut(|fonts| fonts.layout_job(job));
        self.key = Some(key);
        self.galley = Some(galley.clone());
        galley
    }
}

impl Editor {
    /// Draw the pane. `sql` is edited in place; the caller decides when to act
    /// on the change.
    pub fn show(&mut self, ui: &mut egui::Ui, sql: &mut String, syntax: &Syntax, dark: bool) {
        let font = self.font.clone();
        let theme_key = u8::from(dark);
        let cache = &mut self.cache;
        let mut layouter = |ui: &Ui, buffer: &dyn TextBuffer, wrap_width: f32| {
            cache.layout(ui, buffer.as_str(), wrap_width, &font, syntax, theme_key)
        };

        let response = egui::ScrollArea::both()
            .auto_shrink([false, false])
            .show(ui, |ui| {
                ui.add(
                    egui::TextEdit::multiline(sql)
                        .code_editor()
                        // The panel already paints the background; a second
                        // frame inside it would draw a box around the text.
                        .frame(egui::Frame::NONE)
                        .desired_width(f32::INFINITY)
                        .desired_rows(1)
                        .layouter(&mut layouter),
                )
            })
            .inner;

        if response.changed() {
            self.dirty_since = Some(ui.ctx().input(|i| i.time));
        }
    }

    /// True once the text has settled for [`DEBOUNCE`]. Clears the flag, so a
    /// caller that asks is expected to act.
    pub fn take_settled(&mut self, now: f64) -> bool {
        match self.dirty_since {
            Some(at) if now - at >= DEBOUNCE => {
                self.dirty_since = None;
                true
            }
            _ => false,
        }
    }

    /// Whether a re-parse is still owed, so the app can keep asking for frames
    /// rather than waiting for the next stray input event.
    pub fn is_pending(&self) -> bool {
        self.dirty_since.is_some()
    }

    /// Report a change made to the text from outside the `TextEdit`. The
    /// measurement run types without a keyboard, and the debounce has to treat
    /// that exactly as it treats a real keystroke or it would be measuring a
    /// different code path than the one that ships.
    pub fn mark_dirty(&mut self, now: f64) {
        self.dirty_since = Some(now);
    }

    /// Forget any cached galley. The text is unchanged, but its colours are not.
    pub fn invalidate(&mut self) {
        self.cache.key = None;
        self.cache.galley = None;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A burst of typing must cost one re-parse, not one per keystroke, and the
    /// re-parse must actually arrive once the burst ends.
    #[test]
    fn the_debounce_fires_once_after_typing_stops() {
        let mut editor = Editor::default();
        let mut now = 100.0;

        for _ in 0..20 {
            editor.dirty_since = Some(now);
            now += 0.03;
            assert!(!editor.take_settled(now), "fired mid-burst at {now}");
        }
        assert!(editor.is_pending());

        now += DEBOUNCE;
        assert!(editor.take_settled(now), "never fired after the burst");
        assert!(!editor.is_pending());
        assert!(
            !editor.take_settled(now + 10.0),
            "fired twice for one burst"
        );
    }
}
