//! draft — read a SQL schema, draw the diagram.
//!
//! One binary, two entry points. Everything above them is the same code: the
//! browser and the desktop differ only in how the window is obtained and where
//! start-up arguments come from.

mod annotate;
mod app;
mod bench;
mod camera;
mod canvas;
mod document;
mod editor;
mod find;
mod history;
mod inline;
mod mirror;
mod platform;
mod project;
mod sample;
mod share;
mod stats;

use app::App;
use platform::Startup;

#[cfg(not(target_arch = "wasm32"))]
fn main() -> eframe::Result<()> {
    let startup = Startup::from_args(&std::env::args().skip(1).collect::<Vec<_>>());
    eframe::run_native(
        "draft",
        eframe::NativeOptions {
            viewport: egui::ViewportBuilder::default()
                .with_title("draft")
                .with_inner_size([1400.0, 900.0])
                .with_min_inner_size([640.0, 400.0])
                .with_drag_and_drop(true),
            ..Default::default()
        },
        Box::new(|cc| Ok(Box::new(App::new(cc, startup)))),
    )
}

#[cfg(target_arch = "wasm32")]
fn main() {
    use wasm_bindgen::JsCast as _;

    // Start-up arguments ride in the URL fragment, which is never sent to a
    // server — the same property that will let a share link carry a whole
    // schema in Phase 6.
    let fragment = web_sys::window()
        .and_then(|w| w.location().hash().ok())
        .unwrap_or_default();
    let startup = Startup::from_fragment(&fragment);

    wasm_bindgen_futures::spawn_local(async move {
        let Some(canvas) = web_sys::window()
            .and_then(|w| w.document())
            .and_then(|d| d.get_element_by_id("canvas"))
            .and_then(|e| e.dyn_into::<web_sys::HtmlCanvasElement>().ok())
        else {
            web_sys::console::error_1(&"draft: no <canvas id=\"canvas\"> to draw on".into());
            return;
        };
        let result = eframe::WebRunner::new()
            .start(
                canvas,
                eframe::WebOptions::default(),
                Box::new(|cc| Ok(Box::new(App::new(cc, startup)))),
            )
            .await;
        if let Err(e) = result {
            web_sys::console::error_1(&format!("draft: failed to start: {e:?}").into());
        }
        // The loading text in index.html is only there to be replaced; leaving
        // it behind would print "Loading…" over a working application.
        if let Some(element) = web_sys::window()
            .and_then(|w| w.document())
            .and_then(|d| d.get_element_by_id("loading"))
        {
            element.remove();
        }
    });
}
