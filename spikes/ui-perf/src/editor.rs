//! Phase 0 spike S2 -- SQL editor latency.
//!
//! Answers one question: does egui's `TextEdit` stay under 8ms p95 per keystroke
//! on our 106 KB / 300-table fixture?
//!
//! egui does no viewport culling in text layout (egui#3086), so a `TextEdit`
//! lays out the whole document. Reports exist of >1s per keystroke at 15M
//! characters. 106 KB is far below that, but "far below a pathological case" is
//! not a number, and the answer decides whether Phase 3 is an S or Phase 3a is
//! an L.

use std::sync::Arc;

use egui::text::LayoutJob;
use egui::{FontFamily, FontId, Galley, TextBuffer, Ui};

use crate::sqlhl;
use crate::stats::Stats;

/// Wall-clock split of one cache miss.
///
/// The p95 sits right on the 8ms gate in the browser, and the fix depends
/// entirely on which half is responsible: our tokenizer is ours to make
/// incremental, while egui's whole-document galley layout can only be avoided
/// by virtualising the editor -- a much larger piece of work. Guessing which
/// one to attack would be expensive.
#[derive(Default, Clone, Copy)]
pub struct Split {
    pub highlight_ms: f32,
    pub layout_ms: f32,
}

/// Memoised highlighter.
///
/// egui calls the layouter at least once per frame. Without this cache we would
/// be measuring our own tokenizer running 60 times a second on unchanged text,
/// which is a self-inflicted wound rather than a property of `TextEdit`.
#[derive(Default)]
struct HighlightCache {
    key: Option<(u64, u32)>,
    galley: Option<Arc<Galley>>,
    /// Times the cache actually recomputed. If this does not track the keystroke
    /// count, the measurement is not testing what it claims to.
    pub misses: u64,
    pub last_split: Split,
}

#[cfg(not(target_arch = "wasm32"))]
fn wrap_enabled() -> bool {
    std::env::var("DRAFT_WRAP").is_ok()
}

#[cfg(target_arch = "wasm32")]
fn wrap_enabled() -> bool {
    web_sys::window()
        .and_then(|w| w.location().hash().ok())
        .is_some_and(|h| h.contains("wrap"))
}

fn hash(s: &str) -> u64 {
    use std::hash::{Hash as _, Hasher as _};
    let mut h = std::collections::hash_map::DefaultHasher::new();
    s.hash(&mut h);
    h.finish()
}

impl HighlightCache {
    fn layout(&mut self, ui: &Ui, text: &str, wrap_width: f32, font: FontId) -> Arc<Galley> {
        let key = (hash(text), wrap_width.to_bits());
        if self.key == Some(key) {
            if let Some(g) = &self.galley {
                return g.clone();
            }
        }
        self.misses += 1;
        // web_time::Instant, because std::time::Instant panics on
        // wasm32-unknown-unknown and this has to measure the same thing on both
        // targets.
        let t0 = web_time::Instant::now();
        let mut job: LayoutJob = sqlhl::highlight(text, font);
        // A SQL editor should not soft-wrap: long lines scroll horizontally, as
        // in every code editor. Disabling wrapping also removes egui's
        // line-breaking pass, which is part of the galley cost dominating this
        // measurement. Set DRAFT_WRAP=1 to measure the wrapping variant.
        job.wrap.max_width = if wrap_enabled() { wrap_width } else { f32::INFINITY };
        let t1 = web_time::Instant::now();
        let galley = ui.ctx().fonts_mut(|f| f.layout_job(job));
        let t2 = web_time::Instant::now();
        self.last_split = Split {
            highlight_ms: (t1 - t0).as_secs_f32() * 1000.0,
            layout_ms: (t2 - t1).as_secs_f32() * 1000.0,
        };
        self.key = Some(key);
        self.galley = Some(galley.clone());
        galley
    }
}

/// Where the synthetic keystroke lands.
///
/// Editing near the top is the worst case: everything after the caret may need
/// repositioning. Measuring only at the end would flatter the result, and users
/// edit in the middle of their schema all the time.
#[derive(Clone, Copy, PartialEq)]
pub enum Caret {
    Top,
    Middle,
    End,
}

impl Caret {
    fn label(self) -> &'static str {
        match self {
            Self::Top => "top",
            Self::Middle => "middle",
            Self::End => "end",
        }
    }
}

pub struct EditorSpike {
    sql: String,
    cache: HighlightCache,
    stats: Stats,
    caret: Caret,
    /// Alternates insert/remove so the document length stays constant over a
    /// long run while every frame still dirties the cache.
    inserted: bool,
    insert_at: usize,
    pub frames_left: Option<usize>,
    pub finished: Option<String>,
    view: egui::Vec2,
    hl_total: f32,
    layout_total: f32,
    split_n: u32,
}

impl EditorSpike {
    pub fn new(sql: String, caret: Caret, frames: Option<usize>) -> Self {
        let insert_at = match caret {
            Caret::Top => floor_char_boundary(&sql, sql.len().min(200)),
            Caret::Middle => floor_char_boundary(&sql, sql.len() / 2),
            Caret::End => sql.len(),
        };
        Self {
            sql,
            cache: HighlightCache::default(),
            stats: Stats::new(30),
            caret,
            inserted: false,
            insert_at,
            frames_left: frames,
            finished: None,
            view: egui::Vec2::ZERO,
            hl_total: 0.0,
            layout_total: 0.0,
            split_n: 0,
        }
    }

    fn tick_keystroke(&mut self) {
        if self.inserted {
            self.sql.remove(self.insert_at);
        } else {
            self.sql.insert(self.insert_at, 'x');
        }
        self.inserted = !self.inserted;
    }

    pub fn ui(&mut self, ui: &mut Ui, cpu_ms: Option<f32>) {
        if let Some(ms) = cpu_ms {
            self.stats.push(ms);
        }

        self.view = ui.available_size();

        // One synthetic keystroke per frame, so every frame is a cache miss and
        // the percentile is over keystrokes rather than idle repaints.
        self.tick_keystroke();

        ui.horizontal(|ui| {
            ui.label(format!(
                "S2 editor · {} KB · caret {} · misses {} · {}",
                self.sql.len() / 1024,
                self.caret.label(),
                self.cache.misses,
                self.stats.summary(),
            ));
        });

        let font = FontId::new(13.0, FontFamily::Monospace);
        let cache = &mut self.cache;
        let mut layouter = |ui: &Ui, buf: &dyn TextBuffer, wrap: f32| {
            cache.layout(ui, buf.as_str(), wrap, font.clone())
        };

        egui::ScrollArea::both().show(ui, |ui| {
            ui.add(
                egui::TextEdit::multiline(&mut self.sql)
                    .code_editor()
                    .desired_width(f32::INFINITY)
                    .layouter(&mut layouter),
            );
        });

        let split = self.cache.last_split;
        self.hl_total += split.highlight_ms;
        self.layout_total += split.layout_ms;
        self.split_n += 1;

        if let Some(left) = &mut self.frames_left {
            *left = left.saturating_sub(1);
            if *left == 0 && self.finished.is_none() {
                self.finished = Some(format!(
                    "S2 editor  {:>6} KB  caret {:<6} view {:.0}x{:.0}  {}  [tokenize {:.2}ms + galley {:.2}ms]",
                    self.sql.len() / 1024,
                    self.caret.label(),
                    self.view.x,
                    self.view.y,
                    self.stats.summary(),
                    self.hl_total / self.split_n.max(1) as f32,
                    self.layout_total / self.split_n.max(1) as f32,
                ));
            }
        }
        ui.ctx().request_repaint();
    }
}

/// `String::insert`/`remove` panic on a non-boundary index, and the fixture is
/// not guaranteed to be ASCII at an arbitrary offset.
fn floor_char_boundary(s: &str, mut i: usize) -> usize {
    while i > 0 && !s.is_char_boundary(i) {
        i -= 1;
    }
    i
}
