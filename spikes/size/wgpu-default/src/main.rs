// The smallest app that still exercises a window, a frame loop and text
// rendering. Measuring a truly empty binary would flatter the result, because
// the font atlas and the tessellator are what a real app pays for.
use eframe::egui;

#[derive(Default)]
struct App;

impl eframe::App for App {
    // egui 0.36 replaced `update(&Context, ..)` with `ui(&mut Ui, ..)`; the Ui
    // handed over has no margin or background of its own.
    fn ui(&mut self, ui: &mut egui::Ui, _frame: &mut eframe::Frame) {
        ui.heading("size probe");
        ui.label("one label, one button");
        let _ = ui.button("click");
    }
}

fn main() {
    use eframe::wasm_bindgen::JsCast as _;
    let options = eframe::WebOptions::default();
    wasm_bindgen_futures::spawn_local(async {
        let canvas = web_sys::window()
            .unwrap()
            .document()
            .unwrap()
            .get_element_by_id("canvas")
            .unwrap()
            .dyn_into::<web_sys::HtmlCanvasElement>()
            .unwrap();
        eframe::WebRunner::new()
            .start(canvas, options, Box::new(|_cc| Ok(Box::new(App))))
            .await
            .expect("failed to start eframe");
    });
}
