//! Phase 0 spikes S2 (editor latency), S3 (canvas scale) and S5 (web parity).
//!
//! Throwaway. Both spikes run for a fixed number of frames, then emit a
//! percentile summary and stop, so results are reproducible instead of
//! eyeballed.
//!
//! Native is the iteration target because the build loop is seconds rather than
//! minutes. Native numbers are a *lower bound* for wasm -- the same code in a
//! browser is typically slower -- so a native failure is decisive, while a
//! native pass still has to be confirmed in a browser. Both targets build the
//! spike through the same `build_spike`, so the two cannot drift into measuring
//! different things.
//!
//! Native:  ui-perf editor [top|middle|end] [frames]
//!          ui-perf canvas [table-count] [frames]
//! Web:     index.html#editor,top,400   /  index.html#canvas,1000,600

mod canvas;
mod editor;
mod sqlhl;
mod stats;

use canvas::CanvasSpike;
use editor::{Caret, EditorSpike};

/// Fixtures embedded so the wasm build has them too.
///
/// Two sizes, because the browser result sits on the gate and the useful
/// question is no longer pass/fail but "at what document size does this start
/// dropping frames?".
const FIXTURE_106K: &str = include_str!("../../../fixtures/synthetic_300.sql");
const FIXTURE_396K: &str = include_str!("../../../fixtures/synthetic_1000.sql");

enum Spike {
    Editor(Box<EditorSpike>),
    Canvas(Box<CanvasSpike>),
}

struct App {
    spike: Spike,
    reported: bool,
}

/// Build the requested spike from `[mode, arg1, arg2]`.
fn build_spike(args: &[String]) -> Spike {
    let mode = args.first().map(String::as_str).unwrap_or("editor");
    match mode {
        "canvas" => {
            let count = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(1000);
            let frames = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(600);
            Spike::Canvas(Box::new(CanvasSpike::new(count, Some(frames))))
        }
        _ => {
            let caret = match args.get(1).map(String::as_str) {
                Some("middle") => Caret::Middle,
                Some("end") => Caret::End,
                _ => Caret::Top,
            };
            let frames = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(400);
            // Optional 4th argument selects the document size in KB.
            let sql = match args.get(3).map(String::as_str) {
                Some("396") => FIXTURE_396K,
                Some("212") => &FIXTURE_106K.repeat(2),
                _ => FIXTURE_106K,
            };
            Spike::Editor(Box::new(EditorSpike::new(sql.to_string(), caret, Some(frames))))
        }
    }
}

impl eframe::App for App {
    fn ui(&mut self, ui: &mut egui::Ui, frame: &mut eframe::Frame) {
        // cpu_usage is the previous frame's CPU seconds including tessellation,
        // which is the number a user actually feels. Wall-clock frame time would
        // also count vsync waiting and flatter us.
        let cpu_ms = frame.info().cpu_usage.map(|s| s * 1000.0);

        let finished = match &mut self.spike {
            Spike::Editor(s) => {
                s.ui(ui, cpu_ms);
                s.finished.clone()
            }
            Spike::Canvas(s) => {
                s.ui(ui, cpu_ms);
                s.finished.clone()
            }
        };

        if let Some(line) = finished {
            if !self.reported {
                self.reported = true;
                report(&line);
                #[cfg(not(target_arch = "wasm32"))]
                ui.ctx().send_viewport_cmd(egui::ViewportCommand::Close);
            }
        }
    }
}

/// Emit the result where the harness for this target can read it.
#[cfg(not(target_arch = "wasm32"))]
fn report(line: &str) {
    println!("{line}");
}

#[cfg(target_arch = "wasm32")]
fn report(line: &str) {
    // The headless-browser driver scrapes console output for this prefix.
    web_sys::console::log_1(&format!("RESULT {line}").into());
}

#[cfg(not(target_arch = "wasm32"))]
fn main() -> eframe::Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let spike = build_spike(&args);

    eframe::run_native(
        "ui-perf",
        eframe::NativeOptions {
            viewport: egui::ViewportBuilder::default().with_inner_size([1400.0, 900.0]),
            ..Default::default()
        },
        Box::new(|_cc| Ok(Box::new(App { spike, reported: false }))),
    )
}

#[cfg(target_arch = "wasm32")]
fn main() {
    use eframe::wasm_bindgen::JsCast as _;

    // Arguments ride in the URL fragment, e.g. #canvas,1000,600 -- the fragment
    // is never sent to a server, which also happens to be how the real app will
    // carry share links.
    let hash = web_sys::window()
        .and_then(|w| w.location().hash().ok())
        .unwrap_or_default();
    let args: Vec<String> = hash
        .trim_start_matches('#')
        .split(',')
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .collect();

    let spike = build_spike(&args);
    wasm_bindgen_futures::spawn_local(async move {
        let canvas = web_sys::window()
            .unwrap()
            .document()
            .unwrap()
            .get_element_by_id("canvas")
            .unwrap()
            .dyn_into::<web_sys::HtmlCanvasElement>()
            .unwrap();
        eframe::WebRunner::new()
            .start(
                canvas,
                eframe::WebOptions::default(),
                Box::new(|_cc| Ok(Box::new(App { spike, reported: false }))),
            )
            .await
            .expect("failed to start eframe");
    });
}
