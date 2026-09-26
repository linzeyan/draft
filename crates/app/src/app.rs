//! The application: a toolbar, a canvas, a status bar, and the state behind
//! them.
//!
//! Phase 2 is a read-only viewer. The SQL editor, dragging, inline editing and
//! sharing are later phases, and the seams they will need — a generation
//! counter the cache is keyed on, a document that owns its own SQL — are here
//! already because retrofitting them would mean rewriting this file.

use draft_ddl::Dialect;
use draft_layout::{Direction, Options, Placement, Spacing};
use draft_view::{Lod, Syntax, TextStyles, Theme};
use egui::{Align, Layout as UiLayout, RichText};
use serde::{Deserialize, Serialize};

use crate::annotate::{Annotations, Kind};
use crate::bench::{self, CanvasBench, TypingBench};
use crate::camera::Camera;
use crate::canvas::{Act, Canvas, Params};
use crate::document::{Cost, Document};
use crate::editor::Editor;
use crate::find::Find;
use crate::history::{History, Snapshot};
use crate::inline::Inline;
use crate::mirror;
use crate::platform::{self, BenchKind, FilePicker, FontFetch, Startup};
use crate::project::{self, Project};
use crate::sample;
use crate::share;
use crate::stats::Stats;

/// Space left around the diagram when framing it.
const FIT_MARGIN: f32 = 40.0;

/// How long after the last change the page's text mirror is rewritten.
///
/// Measured, and the reason this is a debounce at all: on the 300-table fixture
/// the summary is 545 K of HTML and 11,019 list items, which costs about 5 ms to
/// build and 5–12 ms for the browser to parse. That is a dropped frame, and
/// putting it on the frame a keystroke re-parsed took the re-parse from 7.2 ms
/// to 17.0 ms — over budget, to serve a reader who is not reading mid-keystroke.
/// An order of magnitude longer than the editor's own debounce, for the same
/// reason: nothing is waiting on it.
pub const MIRROR_DELAY: f64 = 0.5;

/// The width below which the two-pane layout stops being a layout.
///
/// Measured, not guessed. At 390 px the toolbar is clipped after *Redo*, the SQL
/// pane is wider than the window — so the diagram is not on screen at all — and
/// the button that would close the pane is one of the ones clipped off. That is
/// a dead end rather than a degradation, and this is the width at which the full
/// bar and the split still both fit.
const NARROW: f32 = 900.0;

/// Space left around an exported diagram. Bigger than the on-screen margin: an
/// export is pasted into documents, where a diagram flush to the edge looks like
/// a crop.
const EXPORT_PAD: f32 = 32.0;

/// The UI's own vocabulary for the layout options.
///
/// Deliberately not `draft_layout`'s enums: those belong to the engine and
/// have no business carrying serde derives for the sake of this application's
/// preferences file.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum Dir {
    Horizontal,
    Vertical,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum Gap {
    Compact,
    Comfortable,
    Spacious,
}

impl Dir {
    const ALL: [Self; 2] = [Self::Horizontal, Self::Vertical];

    fn label(self) -> &'static str {
        match self {
            Self::Horizontal => "Horizontal",
            Self::Vertical => "Vertical",
        }
    }
}

impl Gap {
    const ALL: [Self; 3] = [Self::Compact, Self::Comfortable, Self::Spacious];

    fn label(self) -> &'static str {
        match self {
            Self::Compact => "Compact",
            Self::Comfortable => "Comfortable",
            Self::Spacious => "Spacious",
        }
    }
}

/// The UI's own state: small, copyable, and touched every frame.
#[derive(Clone, Copy, Serialize, Deserialize)]
#[serde(default)]
pub struct Settings {
    dark: bool,
    direction: Dir,
    spacing: Gap,
    show_stats: bool,
    show_editor: bool,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            dark: true,
            direction: Dir::Horizontal,
            spacing: Gap::Comfortable,
            show_stats: false,
            // The product is a SQL-first viewer. Hiding the SQL by default
            // would be hiding the point.
            show_editor: true,
        }
    }
}

impl Settings {
    fn options(&self) -> Options {
        Options {
            direction: match self.direction {
                Dir::Horizontal => Direction::Horizontal,
                Dir::Vertical => Direction::Vertical,
            },
            spacing: match self.spacing {
                Gap::Compact => Spacing::Compact,
                Gap::Comfortable => Spacing::Comfortable,
                Gap::Spacious => Spacing::Spacious,
            },
        }
    }

    fn theme(&self) -> Theme {
        if self.dark {
            Theme::dark()
        } else {
            Theme::light()
        }
    }

    fn syntax(&self) -> Syntax {
        if self.dark {
            Syntax::dark()
        } else {
            Syntax::light()
        }
    }
}

/// A re-arrange that has been asked for and not yet allowed.
#[derive(Clone, Copy)]
struct Arrange {
    options: Options,
    /// What the toolbar said before this was asked for, so Cancel leaves the
    /// menus describing the diagram that is actually on screen rather than the
    /// one that was declined.
    was: (Dir, Gap),
    /// How many tables it would move back, counted when the question was asked
    /// so the number cannot change while the dialog is open.
    moved: usize,
}

/// Where the lazily-registered CJK face has got to.
///
/// Three states rather than a `bool` because the middle one is real and
/// visible: on the web it is a 16.4 MB fetch, and asking for it twice would
/// download it twice.
#[derive(Clone, Copy, PartialEq, Eq)]
enum Cjk {
    /// Nothing on screen needs it, which is the usual answer.
    Unneeded,
    Waiting,
    Installed,
}

/// Which raster format an export is asked for.
#[derive(Clone, Copy)]
enum Raster {
    Png,
    Webp,
}

impl Raster {
    fn extension(self) -> &'static str {
        match self {
            Self::Png => "png",
            Self::Webp => "webp",
        }
    }

    fn mime(self) -> &'static str {
        match self {
            Self::Png => "image/png",
            Self::Webp => "image/webp",
        }
    }
}

/// A measurement run in progress. Not a trait: the two runs drive completely
/// different parts of the application and share nothing but a finish line.
enum Run {
    Canvas(CanvasBench),
    // Boxed: a `TypingBench` carries five sample rings, and `App` holds one
    // `Run` for the whole session whether or not a measurement is running.
    Typing(Box<TypingBench>),
}

pub struct App {
    settings: Settings,
    doc: Document,
    editor: Editor,
    inline: Inline,
    find: Find,
    history: History,
    /// A drag reports a new position every frame it moves, so the history entry
    /// for one waits for the frame the reports stop.
    moving: bool,
    camera: Camera,
    canvas: Canvas,
    styles: TextStyles,
    picker: FilePicker,
    stats: Stats,
    bench: Option<Run>,
    bench_reported: bool,
    cpu_ms: Option<f32>,
    /// Bumped whenever the drawn diagram changes, including its colours. The
    /// shape cache is keyed on it.
    generation: u64,
    /// How full the font atlas was last pass. See [`App::check_font_atlas`].
    atlas_fill: f32,
    /// The CJK face, which is fetched rather than shipped.
    font: FontFetch,
    cjk: Cjk,
    /// Set when every width on screen was measured with a font that is no
    /// longer the one drawing.
    remeasure: bool,
    /// Set when the document changed and the camera has not yet been framed on
    /// it. Consumed once the canvas rect is known.
    fit_pending: bool,
    /// Set when the document waiting to land brought a camera of its own.
    keep_camera: bool,
    /// The canvas rectangle, as of the last frame. The toolbar is drawn before
    /// the canvas and still has to be able to put a note in the middle of it.
    last_view: egui::Rect,
    /// A document waiting for fonts, which only exist once egui has run a pass.
    pending: Option<Document>,
    /// The annotation whose text is being edited.
    note_edit: Option<usize>,
    /// A re-arrange waiting on its confirmation.
    pending_arrange: Option<Arrange>,
    /// Why a URL this application was asked to open produced nothing.
    problem: Option<String>,
    /// The generation the page's text mirror was written from. `MAX` so the
    /// first frame writes it: nothing has been mirrored yet, and generation 0
    /// is a real state.
    mirrored: u64,
    /// When the mirror is due to be rewritten. `None` when it is up to date.
    mirror_due: Option<f64>,
    /// Whether the window was too narrow for the split layout last frame.
    /// `None` until a frame has reported a width, which is what makes a phone
    /// and a window somebody dragged narrow take the same path.
    narrow: Option<bool>,
}

impl App {
    pub fn new(cc: &eframe::CreationContext<'_>, startup: Startup) -> Self {
        install_fonts(&cc.egui_ctx);

        // The last session and a share link are the same shape, which is the
        // point of having one project format: a link simply wins, because
        // following one and being shown yesterday's work instead would be
        // indefensible.
        let mut prefs: Project = startup
            .project
            .as_deref()
            .and_then(share::decode)
            .as_deref()
            .and_then(Project::from_json)
            .or_else(|| {
                cc.storage
                    .and_then(|s| eframe::get_value(s, eframe::APP_KEY))
            })
            .unwrap_or_default();
        if prefs.sql.is_empty() {
            prefs.name = sample::DEFAULT.name.to_owned();
            prefs.sql = sample::DEFAULT.sql.to_owned();
        }

        // A measurement run must not inherit whatever the last session was
        // looking at, or the numbers mean nothing.
        let mut bench = None;
        match startup.bench {
            Some(BenchKind::Canvas { tables, frames }) => {
                prefs.name = format!("bench-{tables}");
                prefs.sql = bench::synthetic_sql(tables);
                prefs.camera = None;
                prefs.placement = Placement::default();
                prefs.annotations = Annotations::default();
                prefs.settings.show_stats = true;
                // Phase 2's budget is for a full-window diagram. Leaving the
                // editor open would shrink the canvas and quietly make every
                // later canvas number look better than the one it is compared
                // against.
                prefs.settings.show_editor = false;
                bench = Some(Run::Canvas(CanvasBench::new(tables, frames)));
            }
            Some(BenchKind::Typing { kb, frames }) => {
                prefs.name = format!("bench-{kb}kb");
                prefs.sql = bench::synthetic_sql_of_size(kb);
                prefs.camera = None;
                prefs.placement = Placement::default();
                prefs.annotations = Annotations::default();
                prefs.settings.show_stats = true;
                prefs.settings.show_editor = true;
                bench = Some(Run::Typing(Box::new(TypingBench::new(kb, frames))));
            }
            None => {
                if let Some(path) = startup.file {
                    match std::fs::read_to_string(&path) {
                        Ok(sql) => {
                            prefs.name = path.rsplit('/').next().unwrap_or(&path).to_owned();
                            prefs.sql = sql;
                            prefs.camera = None;
                            prefs.placement = Placement::default();
                            prefs.annotations = Annotations::default();
                        }
                        Err(e) => eprintln!("draft: cannot read {path}: {e}"),
                    }
                }
            }
        }

        apply_visuals(&cc.egui_ctx, prefs.settings.dark);
        let camera = prefs.camera.unwrap_or_default();
        let fit_pending = prefs.camera.is_none();

        // A `#u=` link asks for somebody else's schema. It arrives later, so
        // what is on screen until then is the sample or the last session —
        // which is also what stays there if the fetch fails.
        let picker = FilePicker::default();
        if let Some(url) = startup.url.filter(|_| startup.project.is_none()) {
            picker.fetch(&url);
        }

        let mut doc = Document::new(prefs.name, prefs.sql);
        doc.placement = prefs.placement;
        doc.annotations = prefs.annotations;
        doc.dialect_pin = prefs.dialect.as_deref().and_then(Dialect::from_label);

        Self {
            history: History::new(Snapshot::of(
                &doc,
                prefs.settings.direction,
                prefs.settings.spacing,
            )),
            doc,
            editor: Editor::default(),
            inline: Inline::default(),
            find: Find::default(),
            moving: false,
            camera,
            canvas: Canvas::default(),
            styles: TextStyles::default(),
            picker,
            // Roughly ten seconds of frames: enough for a percentile to mean
            // something, short enough to reflect what is happening now.
            stats: Stats::new(600, 10),
            bench,
            bench_reported: false,
            cpu_ms: None,
            generation: 0,
            atlas_fill: 0.0,
            font: FontFetch::default(),
            cjk: Cjk::Unneeded,
            remeasure: false,
            fit_pending,
            keep_camera: false,
            last_view: egui::Rect::ZERO,
            pending: None,
            note_edit: None,
            pending_arrange: None,
            problem: None,
            mirrored: u64::MAX,
            mirror_due: None,
            narrow: None,
            settings: prefs.settings,
        }
    }

    fn load(&mut self, name: impl Into<String>, sql: impl Into<String>) {
        self.pending = Some(Document::new(name, sql));
    }

    /// Open whatever a file dialog, a drop or a paste produced.
    ///
    /// A project and a schema arrive through the same door because they arrive
    /// the same way, and which one this is is decided by looking at the bytes.
    fn open(&mut self, ctx: &egui::Context, name: String, text: String) {
        if project::looks_like_json(&text)
            && let Some(project) = Project::from_json(&text)
        {
            let mut doc = Document::new(
                if project.name.is_empty() {
                    name
                } else {
                    project.name.clone()
                },
                project.sql,
            );
            doc.placement = project.placement;
            doc.annotations = project.annotations;
            doc.dialect_pin = project.dialect.as_deref().and_then(Dialect::from_label);
            self.settings = project.settings;
            apply_visuals(ctx, self.settings.dark);
            self.editor.invalidate();
            self.pending = Some(doc);
            // A project carries a camera, and honouring it is the difference
            // between opening someone's diagram and opening their schema.
            if let Some(camera) = project.camera {
                self.camera = camera;
                self.keep_camera = true;
            }
            return;
        }
        self.load(name, text);
    }

    /// The project as it stands, for a file or a link.
    fn project(&self) -> Project {
        Project {
            version: project::VERSION,
            name: self.doc.name.clone(),
            sql: self.doc.sql.clone(),
            settings: self.settings,
            camera: Some(self.camera),
            placement: self.doc.placement.clone(),
            annotations: self.doc.annotations.clone(),
            // Only a correction is worth storing. The guess is a function of
            // the SQL that travels with it, so writing it down would be storing
            // a cache and inviting it to go stale.
            dialect: self.doc.dialect_pin.map(|d| d.label().to_owned()),
        }
    }

    /// Measure and place whatever is waiting, now that there are fonts.
    fn settle(&mut self, ctx: &egui::Context) {
        let fresh = self.pending.take();
        let needs_measure = fresh.is_some()
            || std::mem::take(&mut self.remeasure)
            || self.doc.sizes.len() != self.doc.schema.tables.len();
        if !needs_measure {
            return;
        }
        if let Some(doc) = fresh {
            self.doc = doc;
            // A project brought its own camera. Framing the diagram anyway
            // would discard the view someone chose and saved.
            self.fit_pending = !std::mem::take(&mut self.keep_camera);
        }
        self.check_cjk();
        let (styles, options) = (self.styles.clone(), self.settings.options());
        ctx.fonts_mut(|fonts| self.doc.measure(fonts, &styles, &options));
        self.touch();
    }

    /// Ask for the CJK face if the text has turned out to need one.
    ///
    /// Called where the text changes rather than every frame: the answer is a
    /// function of the text and cannot change on its own.
    fn check_cjk(&mut self) {
        if self.cjk == Cjk::Unneeded && draft_view::fonts::needs_cjk(&self.doc.sql) {
            self.font.request();
            self.cjk = Cjk::Waiting;
        }
    }

    /// Register the CJK face once its bytes have arrived.
    ///
    /// Everything measured so far was measured against a font that is no longer
    /// the one drawing, so both text caches go and every table is measured
    /// again. That is the cost of not shipping 16.4 MB to the majority who
    /// never need it, and it is paid once.
    fn install_cjk(&mut self, ctx: &egui::Context) {
        if self.cjk != Cjk::Waiting {
            return;
        }
        let Some(bytes) = self.font.take() else {
            // A fetch in flight wakes nothing up by itself. Polling a slot four
            // times a second for the seconds it takes beats plumbing a waker
            // through the platform layer for one asset.
            ctx.request_repaint_after(std::time::Duration::from_millis(250));
            return;
        };
        let mut fonts = draft_view::fonts::definitions();
        draft_view::fonts::add_cjk(&mut fonts, bytes);
        ctx.set_fonts(fonts);
        self.cjk = Cjk::Installed;
        self.editor.invalidate();
        self.remeasure = true;
        self.touch();
    }

    /// Rebuild both text caches if epaint has thrown the font atlas away.
    ///
    /// A `Galley` addresses the atlas by texel, so every galley in hand becomes
    /// garbage the moment epaint rebuilds it — which it does at the start of any
    /// pass that begins with the atlas more than 80% full. Nothing here notices
    /// on its own: the editor's galley is keyed on the text and the table shapes
    /// on the generation, and neither of those changed. The symptom was that
    /// toggling the theme — the one gesture that re-lays out the whole document
    /// *and* every visible table in a single pass, and so the one most likely to
    /// tip the atlas over — left the SQL pane blank and the table text sampled
    /// from whatever now occupies those texels.
    ///
    /// The fill ratio only ever rises while an atlas lives, so a fall is the
    /// rebuild, and that is the entire signal.
    fn check_font_atlas(&mut self, ctx: &egui::Context) {
        let fill = ctx.fonts(|f| f.font_atlas_fill_ratio());
        if fill < self.atlas_fill {
            self.editor.invalidate();
            self.touch();
        }
        self.atlas_fill = fill;
    }

    /// Declare that what is on screen has changed.
    fn touch(&mut self) {
        self.generation += 1;
        self.canvas.clear();
    }

    /// Record the document as it now stands, so Ctrl+Z can come back to it.
    ///
    /// Called after each gesture that changes the document rather than before
    /// it — see `history.rs` for why that is the cheaper contract, and why
    /// calling it when nothing changed is free.
    fn record(&mut self) {
        let now = Snapshot::of(&self.doc, self.settings.direction, self.settings.spacing);
        self.history.commit(now);
    }

    /// Put a recorded state back on screen.
    ///
    /// Through `pending` and a fresh `Document`, exactly as opening a file
    /// does: the snapshot holds the text, and everything the diagram is made of
    /// is derived from it. The camera is kept, because an undo that also
    /// re-framed the view would move two things when it was asked to move one.
    fn restore(&mut self, snap: Snapshot) {
        self.settings.direction = snap.direction;
        self.settings.spacing = snap.spacing;
        let mut doc = Document::new(snap.name, snap.sql);
        doc.placement = snap.placement;
        doc.annotations = snap.annotations;
        doc.dialect_pin = snap.dialect_pin;
        // Both editors are open on things that may not survive the restore: a
        // field on a column that is about to stop existing, a note that is
        // about to come back. Closing them is the only honest answer.
        self.editor.invalidate();
        self.inline.close();
        self.note_edit = None;
        self.keep_camera = true;
        self.pending = Some(doc);
    }

    /// The shortcuts that have to be taken before anything is drawn.
    ///
    /// egui's `TextEdit` carries an undo history of its own, and the SQL pane
    /// is a `TextEdit`: leaving Ctrl+Z to it would give this application two
    /// undo stacks that disagree, one of them per-keystroke and blind to
    /// everything that is not text. A focused widget does not hide a keypress
    /// from anyone else (see [`App::shortcuts`]), so the only way to take a key
    /// away from one is to consume it before the widget runs.
    fn intercept(&mut self, ctx: &egui::Context) {
        use egui::{Key, KeyboardShortcut as Shortcut, Modifiers};

        // Redo is tested first because `matches_logically` ignores an extra
        // Shift, so Cmd+Z would otherwise answer for Cmd+Shift+Z as well. Both
        // spellings of redo are the ones egui's own text editor accepts, so the
        // SQL pane and the diagram answer to the same keys.
        const REDO_Z: Shortcut = Shortcut::new(Modifiers::COMMAND.plus(Modifiers::SHIFT), Key::Z);
        const REDO_Y: Shortcut = Shortcut::new(Modifiers::COMMAND, Key::Y);
        const UNDO: Shortcut = Shortcut::new(Modifiers::COMMAND, Key::Z);
        const FIND: Shortcut = Shortcut::new(Modifiers::COMMAND, Key::F);

        let (redo, undo, find) = ctx.input_mut(|i| {
            (
                i.consume_shortcut(&REDO_Z) || i.consume_shortcut(&REDO_Y),
                i.consume_shortcut(&UNDO),
                i.consume_shortcut(&FIND),
            )
        });
        let step = if redo {
            self.history.redo()
        } else if undo {
            self.history.undo()
        } else {
            None
        };
        if let Some(snap) = step {
            self.restore(snap);
        }
        if find {
            self.find.open();
        }
    }

    fn zoom_by(&mut self, factor: f32, view: egui::Rect) {
        self.camera.zoom_about(factor, view.center(), view);
    }
}

/// The two typefaces this application starts with, and no others.
///
/// The policy itself lives in `draft_view::fonts`, because the CLI has to
/// make the same choice and a diagram measured with different fonts in the two
/// is two different diagrams. A CJK face joins these later, if the text turns
/// out to need it — see [`App::install_cjk`].
fn install_fonts(ctx: &egui::Context) {
    ctx.set_fonts(draft_view::fonts::definitions());
}

fn apply_visuals(ctx: &egui::Context, dark: bool) {
    // Pin the preference before styling anything. egui otherwise follows the
    // host's colour scheme and re-derives its visuals every pass, which
    // silently threw away a `set_visuals` made before the browser had reported
    // its preference — the chrome stayed light around a dark canvas.
    let theme = if dark {
        egui::Theme::Dark
    } else {
        egui::Theme::Light
    };
    ctx.set_theme(theme);

    // The canvas paints its own background; the chrome around it should agree
    // with the diagram rather than with egui's defaults. A shade off the
    // canvas, not exactly it, so the toolbar still reads as chrome.
    let diagram = if dark { Theme::dark() } else { Theme::light() };
    let mut visuals = theme.default_visuals();
    visuals.panel_fill = diagram.table_fill;
    ctx.set_visuals_of(theme, visuals);
}

impl eframe::App for App {
    fn save(&mut self, storage: &mut dyn eframe::Storage) {
        eframe::set_value(storage, eframe::APP_KEY, &self.project());
    }

    #[cfg(target_arch = "wasm32")]
    fn as_any_mut(&mut self) -> Option<&mut dyn std::any::Any> {
        Some(&mut *self)
    }

    fn ui(&mut self, ui: &mut egui::Ui, frame: &mut eframe::Frame) {
        let ctx = ui.ctx().clone();
        // The previous frame's CPU seconds, tessellation included. Wall-clock
        // frame time would also count waiting for vsync and flatter us.
        self.cpu_ms = frame.info().cpu_usage.map(|s| s * 1000.0);
        if let Some(ms) = self.cpu_ms {
            self.stats.push(ms);
        }

        if let Some(loaded) = self.picker.take() {
            self.open(&ctx, loaded.name, loaded.text);
        }
        if let Some(problem) = self.picker.take_problem() {
            self.problem = Some(problem);
        }
        self.take_dropped_files(&ctx);
        self.install_cjk(&ctx);
        self.settle(&ctx);
        self.check_font_atlas(&ctx);
        self.intercept(&ctx);

        // One decision per frame, read by the toolbar, the status bar and the
        // SQL pane alike: how wide the window is belongs to the window, not to
        // any of the three.
        let narrow = self.reflow(ui.available_width());
        egui::Panel::top("toolbar").show(ui, |ui| self.toolbar(ui, narrow));
        egui::Panel::bottom("status").show(ui, |ui| self.status(ui, narrow));
        let settled = self.editor_pane(ui, narrow);

        let view = ui.available_rect_before_wrap();
        self.last_view = view;
        // Before the shortcuts, because the box takes the keys it needs off the
        // queue: one Escape has to cancel one thing, and an open Find box is
        // the innermost of them.
        self.find_table(&ctx, view);
        self.shortcuts(&ctx, view);
        if self.fit_pending && view.is_positive() {
            self.fit_pending = false;
            self.camera.fit(self.doc.bounds(), view, FIT_MARGIN);
        }
        let theme = self.settings.theme();
        let moved = self.canvas.show(
            ui,
            Params {
                doc: &self.doc,
                camera: &mut self.camera,
                theme: &theme,
                dark: self.settings.dark,
                styles: &self.styles,
                generation: self.generation,
            },
        );
        let dragging = matches!(moved, Some(Act::Moved(..) | Act::NoteMoved(..)));
        match moved {
            Some(Act::Moved(index, to)) => self.doc.move_table(index, to),
            Some(Act::Edit(table, hit)) => self.inline.open(&self.doc.schema, table, hit),
            Some(Act::ZoomTo(table)) => {
                if let Some(rect) = self.doc.table_rect(table) {
                    self.camera.zoom = 1.0;
                    self.camera.look_at(rect.center(), view);
                }
            }
            Some(Act::AddColumn(table)) => self.add_column(&ctx, table),
            // Annotations are not in the schema, so there is nothing to splice
            // and nothing to re-parse: they are edited where they are stored.
            Some(Act::NoteMoved(index, rect)) => self.doc.annotations.set_rect(index, rect),
            Some(Act::NoteEdit(index)) => self.note_edit = Some(index),
            Some(Act::NoteColour(index, colour)) => {
                self.doc.annotations.set_colour(index, colour);
                self.record();
            }
            Some(Act::NoteDelete(index)) => {
                self.doc.annotations.remove(index);
                self.note_edit = None;
                self.record();
            }
            None => {}
        }
        // A drag is one gesture however many frames it reports, and a history
        // with an entry per frame is a history you cannot get out of. The entry
        // is written on the first frame the reports stop.
        if self.moving && !dragging {
            self.record();
        }
        self.moving = dragging;
        self.inline_edit(&ctx, view);
        self.note_editor(&ctx, view);
        self.arrange_confirm(&ctx);
        self.problem_dialog(&ctx);

        // Before the bench, not after, so the frame's own cost can be handed to
        // it: the bench injects this frame's keystroke, which is next frame's
        // work anyway.
        let mirrored = self.mirror(&ctx);
        self.run_bench(&ctx, view, settled, mirrored);
    }
}

impl App {
    /// Decide whether this frame is drawn narrow, and close the split if the
    /// window has just become too small to hold one.
    ///
    /// Closing on the way in rather than defaulting the pane off at start-up is
    /// what makes a phone and a dragged-narrow desktop window behave the same.
    /// It is deliberately not reopened on the way out: *SQL* is one click, and
    /// being wrong in the other direction covers a diagram somebody asked to
    /// see with a text pane they did not.
    fn reflow(&mut self, width: f32) -> bool {
        let narrow = width < NARROW;
        if narrow && self.narrow != Some(true) {
            self.settings.show_editor = false;
        }
        self.narrow = Some(narrow);
        narrow
    }

    /// Rewrite the page's text mirror, once the document has stopped moving.
    ///
    /// Called last in the frame, so what goes into the page is the schema as it
    /// stands after everything this frame did to it — a re-parse, an undo, a
    /// splice. The generation is what says the diagram changed, so it is what
    /// says the text is stale; without that guard this would serialise the whole
    /// schema sixty times a second. [`MIRROR_DELAY`] is why it then waits.
    /// Returns how long the write took, in milliseconds, on the frame it
    /// happened — the typing bench reports it, so the cost of this stays a
    /// measured number rather than a claim.
    fn mirror(&mut self, ctx: &egui::Context) -> Option<f32> {
        let now = ctx.input(|i| i.time);
        if self.mirrored != self.generation {
            self.mirrored = self.generation;
            // Each change pushes the deadline out, so a burst of typing costs
            // one write rather than one per debounce.
            self.mirror_due = Some(now + MIRROR_DELAY);
        }
        let due = self.mirror_due?;
        if now < due {
            // Nothing else will wake us: the deadline is on a clock, not on an
            // event, exactly like the editor's re-parse.
            ctx.request_repaint_after(std::time::Duration::from_secs_f64(due - now));
            return None;
        }
        self.mirror_due = None;
        let started = web_time::Instant::now();
        platform::mirror_schema(&mirror::html(&self.doc));
        Some(started.elapsed().as_secs_f32() * 1000.0)
    }

    /// The SQL pane, and the debounced re-parse that follows it. Returns
    /// whether the re-parse happened on this frame.
    ///
    /// egui's panel owns its own width and remembers it, so the divider is
    /// draggable and persistent without any state here.
    fn editor_pane(&mut self, ui: &mut egui::Ui, narrow: bool) -> Option<Cost> {
        if !self.settings.show_editor {
            return None;
        }
        let syntax = self.settings.syntax();
        let dark = self.settings.dark;
        // Borrow the two fields separately: the layouter closure inside the
        // editor holds its cache while `doc.sql` is being edited.
        let App { editor, doc, .. } = self;
        if narrow {
            // A full-width overlay, because below `NARROW` there is no width to
            // split. An `Area` rather than a panel so the canvas keeps its own
            // rect: every camera calculation behind the pane stays the one that
            // runs when the pane is closed, and the diagram is where it was
            // when the pane is dismissed.
            let rect = ui.available_rect_before_wrap();
            egui::Area::new(egui::Id::new("editor-overlay"))
                .order(egui::Order::Foreground)
                .fixed_pos(rect.min)
                .show(ui.ctx(), |ui| {
                    ui.set_max_size(rect.size());
                    egui::Frame::new().fill(syntax.background).show(ui, |ui| {
                        ui.set_min_size(rect.size());
                        editor.show(ui, &mut doc.sql, &syntax, dark);
                    });
                });
        } else {
            egui::Panel::left("editor")
                .resizable(true)
                .default_size(420.0)
                .frame(egui::Frame::new().fill(syntax.background))
                .show(ui, |ui| editor.show(ui, &mut doc.sql, &syntax, dark));
        }

        let now = ui.ctx().input(|i| i.time);
        if self.editor.is_pending() {
            // Nothing else will wake us: the debounce is the only thing left to
            // happen, and it happens on a clock rather than on an event.
            ui.ctx()
                .request_repaint_after(std::time::Duration::from_secs_f64(crate::editor::DEBOUNCE));
        }
        if !self.editor.take_settled(now) {
            return None;
        }
        let (styles, options) = (self.styles.clone(), self.settings.options());
        let cost = ui
            .ctx()
            .fonts_mut(|fonts| self.doc.reparse(fonts, &styles, &options));
        // The debounce is also what coalesces the undo history: one entry per
        // pause in the typing, not per keystroke. Recorded whether or not the
        // fresh text parsed to a diagram — the text is the document, and half a
        // statement somebody is in the middle of writing is a state they are
        // entitled to get back to.
        self.record();
        if cost.is_some() {
            // Typing or pasting is the other way text arrives, and a schema
            // pasted into the pane is the most likely way a CJK one arrives at
            // all.
            self.check_cjk();
            self.touch();
        }
        cost
    }

    /// Append a column, then open a field on the name it was given.
    ///
    /// A placeholder name rather than a prompt first: the column exists, is
    /// visible, and is already selected for renaming, so the whole gesture is
    /// right-click, Add column, type, Enter. Asking for the name in a dialog
    /// before anything appears is one more thing to cancel out of.
    fn add_column(&mut self, ctx: &egui::Context, table: usize) {
        let Some(name) = self.doc.schema.tables.get(table).map(|t| t.name.clone()) else {
            return;
        };
        let ty = draft_model::types_in_use(&self.doc.schema)
            .first()
            .cloned()
            .unwrap_or_else(|| "text".to_owned());
        let placeholder = free_column_name(&self.doc.schema, table);
        let edit = match draft_model::add_column(
            &self.doc.sql,
            &self.doc.schema,
            &name,
            &placeholder,
            &ty,
        ) {
            Ok(edit) => edit,
            Err(e) => {
                eprintln!("draft: {e}");
                return;
            }
        };
        if !self.splice(ctx, &edit) {
            return;
        }
        // Open a field on it straight away. The index is found again rather
        // than assumed: the re-parse above rebuilt the whole schema.
        if let Some(i) = self.doc.schema.index_of(&name)
            && let Some(row) = self.doc.schema.tables[i]
                .columns
                .iter()
                .position(|c| c.name == placeholder)
        {
            self.inline
                .open(&self.doc.schema, i, draft_view::Hit::ColumnName(row));
        }
    }

    /// Apply an edit to the script and re-derive the diagram at once. Returns
    /// whether anything changed.
    ///
    /// Not through the debounce: this change came from a deliberate commit, not
    /// from typing, and watching the diagram catch up a fifth of a second later
    /// would look broken.
    fn splice(&mut self, ctx: &egui::Context, edit: &draft_model::Edit) -> bool {
        if edit.is_empty() {
            return false;
        }
        let sql = match draft_model::apply(&self.doc.sql, &edit.splices) {
            Ok(sql) => sql,
            // Unreachable in practice — the splices come from spans this parse
            // produced — but the alternative to saying so is a silent no-op on
            // the one operation that writes to someone's schema.
            Err(e) => {
                eprintln!("draft: {}: {e}", edit.summary);
                return false;
            }
        };
        self.doc.sql = sql;
        // The text is the document. Everything downstream — the highlighter's
        // cache, the diagram — has to be told it moved, exactly as if it had
        // been typed.
        self.editor.invalidate();
        let (styles, options) = (self.styles.clone(), self.settings.options());
        if ctx
            .fonts_mut(|fonts| self.doc.reparse(fonts, &styles, &options))
            .is_some()
        {
            self.touch();
        }
        // A deliberate commit is exactly one thing to undo, however many bytes
        // of the script it moved.
        self.record();
        true
    }

    /// The Find box, and the jump when it settles on a table.
    fn find_table(&mut self, ctx: &egui::Context, view: egui::Rect) {
        let Some(table) = self.find.show(ctx, &self.doc.schema, view) else {
            return;
        };
        let Some(rect) = self.doc.table_rect(table) else {
            return;
        };
        // Never zoom out — somebody at 200% asked where a table is, not to lose
        // the magnification they chose — but do zoom in far enough for the box
        // to show its columns. 1.0 rather than the 0.45 the canvas needs to
        // draw them at all, because that is what `Act::ZoomTo` already means by
        // "go and look at this table", and two gestures that end up looking at
        // a table should end up looking at it the same way.
        self.camera.zoom = self.camera.zoom.max(1.0);
        self.camera.look_at(rect.center(), view);
        self.canvas.pin(self.doc.schema.tables[table].name.clone());
    }

    /// The inline field, positioned over the row it edits.
    fn inline_edit(&mut self, ctx: &egui::Context, view: egui::Rect) {
        let Some((table, hit)) = self.inline.target(&self.doc.schema) else {
            return;
        };
        let Some(bounds) = self.doc.table_rect(table) else {
            self.inline.close();
            return;
        };
        let screen = egui::Rect::from_min_size(
            self.camera.to_screen(bounds.min, view),
            bounds.size() * self.camera.zoom,
        );
        let size = draft_layout::Size {
            w: bounds.width(),
            h: bounds.height(),
        };
        let at = crate::inline::field_rect(screen, size, hit, self.camera.zoom);

        if let crate::inline::Outcome::Apply(edit) =
            self.inline.show(ctx, at, &self.doc.schema, &self.doc.sql)
        {
            self.splice(ctx, &edit);
        }
    }

    /// The text field over an annotation.
    ///
    /// A real `TextEdit` in an `Area`, for the same reason as the inline schema
    /// field: a note is the one place in this application where someone types a
    /// paragraph, and reimplementing a caret and an IME over a painter would be
    /// a worse version of what egui already has.
    fn note_editor(&mut self, ctx: &egui::Context, view: egui::Rect) {
        let Some(index) = self.note_edit else {
            return;
        };
        let Some(note) = self.doc.annotations.get(index) else {
            self.note_edit = None;
            return;
        };
        let rect = egui::Rect::from_min_size(
            self.camera.to_screen(note.rect.min, view),
            note.rect.size() * self.camera.zoom,
        );

        let mut done = false;
        egui::Area::new(egui::Id::new("note-edit"))
            .order(egui::Order::Foreground)
            .fixed_pos(rect.min)
            .show(ctx, |ui| {
                ui.set_max_width(rect.width().clamp(180.0, 420.0));
                egui::Frame::popup(ui.style()).show(ui, |ui| {
                    let Some(text) = self.doc.annotations.text_mut(index) else {
                        return;
                    };
                    let field = ui.add(
                        egui::TextEdit::multiline(text)
                            .desired_rows(3)
                            .hint_text("note"),
                    );
                    if !field.has_focus() && !field.clicked() {
                        field.request_focus();
                    }
                    // Enter inserts a newline in a note, so committing is
                    // Escape or clicking away — the same as every other
                    // free-text field people have used.
                    done = ui.input(|i| i.key_pressed(egui::Key::Escape)) || field.lost_focus();
                });
            });
        if done {
            self.note_edit = None;
            // One entry for the whole note — the box, its text, and nothing in
            // between. A note is typed into, and an entry per keystroke in a
            // paragraph would bury everything else in the history.
            self.record();
        }
    }

    /// Add an annotation in the middle of what is on screen, and open a field on
    /// it. An empty box appearing somewhere off-view would be worse than useless.
    fn add_note(&mut self, kind: Kind, view: egui::Rect) {
        let at = self.camera.to_world(view.center(), view);
        self.note_edit = Some(self.doc.annotations.add(kind, at));
    }

    fn save_project(&self) {
        let name = file_stem(&self.doc.name);
        platform::download(
            &format!("{name}.draft.json"),
            self.project().to_json().into_bytes(),
            "application/json",
        );
    }

    /// Put the whole project in the address bar and on the clipboard.
    fn share_link(&self, ctx: &egui::Context) {
        let fragment = format!("#p1={}", share::encode(&self.project().to_json()));
        platform::set_fragment(&fragment);
        ctx.copy_text(platform::share_url(&fragment));
    }

    /// The whole diagram, with its top-left at the origin, built at `scale`.
    ///
    /// The same shapes the canvas draws, from the same functions, so an export
    /// cannot drift away from what is on screen. Not taken from the canvas's
    /// cache, though: that holds whatever zoom the view happens to be at, and
    /// only the tables that were visible.
    fn export_shapes(&self, ctx: &egui::Context, scale: f32) -> (Vec<egui::Shape>, egui::Vec2) {
        let theme = self.settings.theme();
        let dark = self.settings.dark;
        let bounds = self.doc.bounds();
        let mut shapes = ctx.fonts_mut(|fonts| {
            // Back to front, exactly as the canvas layers them.
            let mut out = self
                .doc
                .annotations
                .shapes(Kind::Group, &theme, dark, scale, fonts);
            out.extend(draft_view::shapes(
                &self.doc.schema,
                &self.doc.layout,
                &theme,
                &self.styles,
                scale,
                fonts,
            ));
            out.extend(
                self.doc
                    .annotations
                    .shapes(Kind::Note, &theme, dark, scale, fonts),
            );
            out
        });
        let shift = egui::emath::TSTransform::from_translation(-bounds.min.to_vec2() * scale);
        for shape in &mut shapes {
            shape.transform(shift);
        }
        (shapes, bounds.size() * scale)
    }

    fn export_svg(&self, ctx: &egui::Context) {
        let (shapes, size) = self.export_shapes(ctx, 1.0);
        let svg = draft_export::svg(&shapes, size, self.settings.theme().background, EXPORT_PAD);
        platform::download(
            &format!("{}.svg", file_stem(&self.doc.name)),
            svg.into_bytes(),
            "image/svg+xml",
        );
    }

    /// A raster export, at 2x so the file is worth putting in a document rather
    /// than being the pixels the screen already had.
    ///
    /// One function for both formats because they differ in nothing but the
    /// encoder: the same shapes, the same scale, the same padding. Two copies
    /// would be two places for those to drift apart.
    fn export_raster(&self, ctx: &egui::Context, format: Raster) {
        const SCALE: f32 = 2.0;
        let (shapes, size) = self.export_shapes(ctx, SCALE);
        let background = self.settings.theme().background;
        let pad = EXPORT_PAD * SCALE;
        let image = ctx.fonts_mut(|fonts| match format {
            Raster::Png => draft_export::png(&shapes, size, background, pad, fonts),
            Raster::Webp => draft_export::webp(&shapes, size, background, pad, fonts),
        });
        match image {
            Ok(bytes) => platform::download(
                &format!("{}.{}", file_stem(&self.doc.name), format.extension()),
                bytes,
                format.mime(),
            ),
            Err(e) => eprintln!("draft: {e}"),
        }
    }

    /// The toolbar, in one of two arrangements.
    ///
    /// Wide is the whole bar. Narrow keeps the four controls that get used
    /// repeatedly — *Open*, *SQL*, *Find*, *Fit* — and folds the rest into
    /// *More*, because a clipped toolbar is not a smaller toolbar: a button past
    /// the edge cannot be reached at all, and one of the ones that fell off was
    /// the one that closes the SQL pane.
    fn toolbar(&mut self, ui: &mut egui::Ui, narrow: bool) {
        ui.add_space(4.0);
        ui.horizontal(|ui| {
            if narrow {
                self.open_button(ui);
                self.sql_toggle(ui);
                self.view_buttons(ui);
                menu(ui, "More", |ui| {
                    self.share_menu(ui);
                    self.sample_menu(ui);
                    ui.separator();
                    self.history_buttons(ui);
                    ui.separator();
                    self.layout_controls(ui, true);
                    ui.separator();
                    self.annotate_buttons(ui);
                    ui.separator();
                    self.appearance_buttons(ui);
                });
                return;
            }
            self.open_button(ui);
            self.share_menu(ui);
            self.sample_menu(ui);
            self.history_buttons(ui);
            self.sql_toggle(ui);
            ui.separator();
            self.layout_controls(ui, false);
            ui.separator();
            self.annotate_buttons(ui);
            ui.separator();
            self.view_buttons(ui);
            ui.with_layout(UiLayout::right_to_left(Align::Center), |ui| {
                self.appearance_buttons(ui);
            });
        });
        ui.add_space(4.0);
    }

    fn open_button(&mut self, ui: &mut egui::Ui) {
        if ui
            .button("Open…")
            .on_hover_text("Ctrl/Cmd + O — a .sql schema or a saved project")
            .clicked()
        {
            self.picker.open();
        }
    }

    /// Everything that leaves the tab. A menu on the bar, a submenu inside
    /// *More*: `menu_button` is whichever of the two it finds itself in.
    fn share_menu(&mut self, ui: &mut egui::Ui) {
        menu(ui, "Share", |ui| {
            if ui
                .button("Copy link")
                .on_hover_text(
                    "The whole project travels in the URL fragment,\n\
                     which a browser never sends to a server.",
                )
                .clicked()
            {
                self.share_link(ui.ctx());
                ui.close();
            }
            if ui.button("Save project…").clicked() {
                self.save_project();
                ui.close();
            }
            ui.separator();
            if ui.button("Export SVG…").clicked() {
                self.export_svg(ui.ctx());
                ui.close();
            }
            if ui.button("Export PNG…").on_hover_text("2x").clicked() {
                self.export_raster(ui.ctx(), Raster::Png);
                ui.close();
            }
            if ui
                .button("Export WebP…")
                .on_hover_text("2x, lossless — usually a smaller file than the PNG")
                .clicked()
            {
                self.export_raster(ui.ctx(), Raster::Webp);
                ui.close();
            }
        });
    }

    /// A menu rather than a button: the samples differ by the dialect they are
    /// written in, so the dialect is the choice. Listed by vendor name, which is
    /// what somebody arriving with their own schema recognises.
    fn sample_menu(&mut self, ui: &mut egui::Ui) {
        menu(ui, "Sample", |ui| {
            for sample in sample::ALL {
                if ui.button(sample.dialect.label()).clicked() {
                    self.load(sample.name, sample.sql);
                    ui.close();
                }
            }
        });
    }

    fn history_buttons(&mut self, ui: &mut egui::Ui) {
        // Disabled rather than hidden: greyed out is also how this says "there
        // is nothing to come back to", which is the question somebody about to
        // press Arrange is actually asking.
        if ui
            .add_enabled(self.history.can_undo(), egui::Button::new("Undo"))
            .on_hover_text("Ctrl/Cmd + Z")
            .clicked()
            && let Some(snap) = self.history.undo()
        {
            self.restore(snap);
        }
        if ui
            .add_enabled(self.history.can_redo(), egui::Button::new("Redo"))
            .on_hover_text("Ctrl/Cmd + Shift + Z")
            .clicked()
            && let Some(snap) = self.history.redo()
        {
            self.restore(snap);
        }
    }

    fn sql_toggle(&mut self, ui: &mut egui::Ui) {
        if ui
            .selectable_label(self.settings.show_editor, "SQL")
            .on_hover_text("Show the schema text")
            .clicked()
        {
            self.settings.show_editor = !self.settings.show_editor;
        }
    }

    /// Direction, spacing and Arrange — the three ways the diagram goes back to
    /// the engine, which is why they are one group and share one guard.
    fn layout_controls(&mut self, ui: &mut egui::Ui, compact: bool) {
        // Captured before the menus can change it, because Cancel has to be
        // able to put it back.
        let was = (self.settings.direction, self.settings.spacing);
        let before = self.settings.options();
        if compact {
            // Submenus rather than combo boxes: a combo box opened from inside a
            // menu is a popup inside a popup, and the outer one closes on the
            // click that opens the inner one. The value is in the label instead
            // of a selected_text.
            menu(
                ui,
                format!("Direction: {}", self.settings.direction.label()),
                |ui| {
                    for option in Dir::ALL {
                        ui.selectable_value(&mut self.settings.direction, option, option.label());
                    }
                },
            );
            menu(
                ui,
                format!("Spacing: {}", self.settings.spacing.label()),
                |ui| {
                    for option in Gap::ALL {
                        ui.selectable_value(&mut self.settings.spacing, option, option.label());
                    }
                },
            );
        } else {
            combo(ui, "direction", self.settings.direction.label(), |ui| {
                for option in Dir::ALL {
                    ui.selectable_value(&mut self.settings.direction, option, option.label());
                }
            });
            combo(ui, "spacing", self.settings.spacing.label(), |ui| {
                for option in Gap::ALL {
                    ui.selectable_value(&mut self.settings.spacing, option, option.label());
                }
            });
        }
        let after = self.settings.options();
        if after.direction != before.direction || after.spacing != before.spacing {
            self.request_arrange(after, was);
        }

        if ui
            .button("Arrange")
            .on_hover_text(
                "Lay the diagram out again. Tables you moved by hand go back\n\
                 where the engine puts them — it asks first.",
            )
            .clicked()
        {
            self.request_arrange(after, was);
        }
    }

    fn annotate_buttons(&mut self, ui: &mut egui::Ui) {
        if ui
            .button("Note")
            .on_hover_text("A sticky note, on top of the diagram")
            .clicked()
        {
            self.add_note(Kind::Note, self.last_view);
        }
        if ui
            .button("Group")
            .on_hover_text("A box drawn around a set of tables")
            .clicked()
        {
            self.add_note(Kind::Group, self.last_view);
        }
    }

    fn view_buttons(&mut self, ui: &mut egui::Ui) {
        // A button as well as a shortcut: a diagram too big to read by panning
        // is exactly the situation in which nobody thinks to guess at a key, and
        // the browser's own Ctrl+F finds nothing here.
        if ui
            .button("Find")
            .on_hover_text("Ctrl/Cmd + F, or / — go to a table by name")
            .clicked()
        {
            self.find.open();
        }
        if ui.button("Fit").on_hover_text("F").clicked() {
            self.fit_pending = true;
        }
        ui.label(format!("{:.0}%", self.camera.zoom * 100.0));
    }

    fn appearance_buttons(&mut self, ui: &mut egui::Ui) {
        if ui
            .selectable_label(self.settings.show_stats, "Stats")
            .on_hover_text("Frame cost and what the canvas is drawing")
            .clicked()
        {
            self.settings.show_stats = !self.settings.show_stats;
        }
        let label = if self.settings.dark { "Light" } else { "Dark" };
        if ui.button(label).clicked() {
            self.settings.dark = !self.settings.dark;
            apply_visuals(ui.ctx(), self.settings.dark);
            // Colours are baked into both caches.
            self.editor.invalidate();
            self.touch();
        }
    }

    /// Ask for a re-arrange, which may need permission first.
    ///
    /// The button and the direction and spacing menus all land here: every one
    /// of them hands the diagram back to the engine, so every one of them has
    /// the same thing to lose, and a rule that guarded only the button would be
    /// a trap on the other two.
    fn request_arrange(&mut self, options: Options, was: (Dir, Gap)) {
        let moved = self.doc.placement.moved();
        if moved == 0 {
            self.arrange(options);
            return;
        }
        self.pending_arrange = Some(Arrange {
            options,
            was,
            moved,
        });
    }

    fn arrange(&mut self, options: Options) {
        self.doc.relayout(&options);
        self.touch();
        self.fit_pending = true;
        // The one gesture with nothing to recompute it from: the positions it
        // discards were somebody's work, and the confirmation it asks for is
        // only a warning. This is the part that gives them back.
        self.record();
    }

    /// The one question this application asks before doing something.
    ///
    /// Arranging is cheap to redo and impossible to undo: the engine's answer
    /// is a pure function of the schema, but the half hour somebody spent
    /// moving boxes is not recoverable from anything. So it asks — and only
    /// when there is something to lose, because a confirmation that appears
    /// when the answer is obviously yes is a dialog that teaches people to
    /// dismiss dialogs.
    fn arrange_confirm(&mut self, ctx: &egui::Context) {
        let Some(pending) = self.pending_arrange else {
            return;
        };
        let mut decided = None;
        let modal = egui::Modal::new(egui::Id::new("confirm-arrange")).show(ctx, |ui| {
            ui.set_max_width(340.0);
            ui.label(RichText::new("Re-arrange the diagram?").strong());
            ui.add_space(8.0);
            ui.label(match pending.moved {
                1 => "One table you moved by hand will go back where the layout \
                      engine puts it."
                    .to_owned(),
                n => format!(
                    "{n} tables you moved by hand will go back where the layout \
                     engine puts them."
                ),
            });
            ui.add_space(12.0);
            ui.horizontal(|ui| {
                if ui.button("Cancel").clicked() {
                    decided = Some(false);
                }
                if ui.button("Arrange").clicked() {
                    decided = Some(true);
                }
            });
        });
        // Escape and a click on the backdrop say the same thing as Cancel.
        if modal.should_close() {
            decided = Some(false);
        }
        match decided {
            Some(true) => {
                self.pending_arrange = None;
                self.arrange(pending.options);
            }
            Some(false) => {
                self.pending_arrange = None;
                (self.settings.direction, self.settings.spacing) = pending.was;
            }
            None => {}
        }
    }

    /// Why a URL produced nothing.
    ///
    /// The only dialog here that is not a question, and the one place a dialog
    /// is right: somebody followed a link expecting a particular schema, and
    /// being shown an unrelated diagram with no explanation is worse than being
    /// interrupted. The text says what to try, because the commonest cause —
    /// a repository page instead of a raw file — has an obvious fix and an
    /// opaque symptom.
    fn problem_dialog(&mut self, ctx: &egui::Context) {
        let Some(problem) = self.problem.clone() else {
            return;
        };
        let modal = egui::Modal::new(egui::Id::new("problem")).show(ctx, |ui| {
            ui.set_max_width(440.0);
            ui.label(RichText::new("Could not open that link").strong());
            ui.add_space(8.0);
            ui.label(problem);
            ui.add_space(12.0);
            if ui.button("Close").clicked() {
                self.problem = None;
            }
        });
        if modal.should_close() {
            self.problem = None;
        }
    }

    /// Which dialect this is, and the chance to disagree.
    ///
    /// A menu rather than a label because the answer is read off markers in
    /// somebody else's script and will sometimes be wrong, and the place to
    /// correct a wrong answer is where it is shown. Pinning one changes what
    /// this says and nothing else: there is one tolerant parser and it reads
    /// every dialect the same way (docs/architecture.md D1).
    fn dialect_picker(&mut self, ui: &mut egui::Ui) {
        let detected = self.doc.detected_dialect();
        let pin = self.doc.dialect_pin;
        let auto = match detected {
            Some(d) => format!("Auto — {}", d.label()),
            None => "Auto — nothing specific".to_owned(),
        };
        let shown = match (pin, self.doc.dialect()) {
            // Strong when pinned, so a claim somebody made is visibly not the
            // same kind of thing as a guess this made.
            (Some(d), _) => RichText::new(d.label()).strong(),
            (None, Some(d)) => RichText::new(d.label()),
            (None, None) => RichText::new("dialect?").weak(),
        };

        let menu = ui.menu_button(shown, |ui| {
            if ui.selectable_label(pin.is_none(), &auto).clicked() {
                self.doc.dialect_pin = None;
                ui.close();
            }
            ui.separator();
            for option in Dialect::ALL {
                if ui
                    .selectable_label(pin == Some(option), option.label())
                    .clicked()
                {
                    self.doc.dialect_pin = Some(option);
                    ui.close();
                }
            }
        });
        // The pin travels in the undo history because it travels in the
        // project. A change nobody recorded would be silently reverted by the
        // next undo of something else.
        if self.doc.dialect_pin != pin {
            self.record();
        }
        menu.response.on_hover_text(match (pin, detected) {
            (Some(p), Some(d)) if p != d => format!(
                "Pinned to {}, and saved with the project.\n\
                 The script itself reads as {d}.\n\
                 This is a label: it does not change how the SQL is parsed.",
                p.label(),
                d = d.label(),
            ),
            (Some(_), _) => "Pinned, and saved with the project.\n\
                             This is a label: it does not change how the SQL is parsed."
                .to_owned(),
            (None, Some(_)) => "Read off the markers in the script.\n\
                                This is a label: it does not change how the SQL is parsed.\n\
                                Click to pin a dialect instead."
                .to_owned(),
            (None, None) => "This script uses nothing specific to one dialect.\n\
                             Click to pin one anyway."
                .to_owned(),
        });
    }

    fn status(&mut self, ui: &mut egui::Ui, narrow: bool) {
        ui.add_space(2.0);
        if narrow {
            // Wrapped onto a second line rather than clipped, and no
            // right-aligned half at all: at 390 px the two halves of one row
            // overprint each other, and what becomes unreadable is the half
            // that says how many warnings the script has.
            ui.horizontal_wrapped(|ui| self.status_items(ui, true));
        } else {
            ui.horizontal(|ui| self.status_items(ui, false));
        }
        ui.add_space(2.0);
    }

    fn status_items(&mut self, ui: &mut egui::Ui, narrow: bool) {
        ui.label(RichText::new(&self.doc.name).strong());
        ui.label(separator_dot());
        ui.label(plural(self.doc.schema.tables.len(), "table"));
        ui.label(separator_dot());
        ui.label(plural(self.doc.schema.relations.len(), "relation"));
        ui.label(separator_dot());
        self.dialect_picker(ui);

        if !self.doc.annotations.is_empty() {
            ui.label(separator_dot());
            ui.label(plural(self.doc.annotations.len(), "note"))
                .on_hover_text("Saved, shared and exported with the diagram");
        }

        if let Some(name) = self.canvas.pinned() {
            ui.label(separator_dot());
            ui.label(RichText::new(format!("focused on {name}")).strong())
                .on_hover_text("Escape, or click empty space, to see everything again");
        }

        if self.doc.stale {
            ui.label(separator_dot());
            ui.label(
                RichText::new("showing last valid diagram").color(self.settings.theme().key_text),
            )
            .on_hover_text(
                "The text does not currently define any table, so the previous\n\
                     diagram is still on screen. It will catch up as soon as it does.",
            );
        }

        let warnings = self.doc.schema.warnings.len();
        let dangling = self.doc.dangling();
        if warnings > 0 || dangling > 0 {
            ui.label(separator_dot());
            let mut text = Vec::new();
            if warnings > 0 {
                text.push(plural(warnings, "warning"));
            }
            if dangling > 0 {
                text.push(format!("{dangling} dangling"));
            }
            ui.label(RichText::new(text.join(", ")).color(self.settings.theme().edge_dangling))
                .on_hover_text(self.warning_summary());
        }

        if narrow {
            // The mouse hint is dropped rather than shortened: there is no
            // pointer to drag and no ctrl+scroll to hold on the screens this
            // layout is for, and a hint the device cannot honour is worse than
            // no hint. Stats, if asked for, wrap with everything else.
            if self.settings.show_stats {
                ui.label(separator_dot());
                ui.label(RichText::new(self.canvas_summary()).monospace().weak());
            }
            return;
        }
        ui.with_layout(UiLayout::right_to_left(Align::Center), |ui| {
            if self.settings.show_stats {
                ui.label(RichText::new(self.canvas_summary()).monospace().weak());
            } else {
                ui.label(RichText::new("drag to pan · ctrl+scroll to zoom").weak());
            }
        });
    }

    /// What the canvas is drawing, and what it cost.
    fn canvas_summary(&self) -> String {
        let counts = self.canvas.counts;
        format!(
            "{} · {} visible · {} shapes · {}",
            lod_label(Lod::for_zoom(self.camera.zoom)),
            counts.visible,
            counts.shapes,
            self.stats.summary(),
        )
    }

    /// The first few warnings, in full. A count alone tells you something is
    /// wrong without telling you what, which is the least useful of the two.
    fn warning_summary(&self) -> String {
        let mut lines: Vec<String> = self
            .doc
            .schema
            .warnings
            .iter()
            .take(8)
            .map(|w| match w.span {
                Some(span) => format!("byte {}: {}", span.start, w.message),
                None => w.message.clone(),
            })
            .collect();
        for relation in self.doc.schema.relations.iter().filter(|r| r.to_missing) {
            if lines.len() >= 12 {
                break;
            }
            lines.push(format!(
                "{} references {}, which this script does not define",
                relation.from_table, relation.to_table
            ));
        }
        if lines.is_empty() {
            "no warnings".to_owned()
        } else {
            lines.join("\n")
        }
    }

    fn shortcuts(&mut self, ctx: &egui::Context, view: egui::Rect) {
        use egui::Key;

        // A modal owns the keyboard while it is up. The only key it cares about
        // is Escape and it reads that itself; letting F re-frame the camera
        // behind a dialog asking about the layout would be absurd.
        if self.pending_arrange.is_some() || self.problem.is_some() {
            return;
        }

        // An unmodified letter means "camera" to the canvas and "text" to the
        // editor, and egui's `filtered_events` copies rather than drains — a
        // focused `TextEdit` does not hide the keypress from anyone else. So
        // the split has to be made here: bare keys and paste belong to whatever
        // has focus, modified ones are application-wide.
        let typing = ctx.egui_wants_keyboard_input();
        let (open, find, fit, zoom_in, zoom_out, reset, unpin, pasted) = ctx.input(|i| {
            (
                i.modifiers.command && i.key_pressed(Key::O),
                // The other half of Ctrl/Cmd+F, which [`App::intercept`] has to
                // take before the SQL pane is drawn. A bare slash is what every
                // application with a list in it uses, and on a keyboard where
                // Cmd+F is spoken for it is the only one left.
                i.key_pressed(Key::Slash) && !typing,
                (i.key_pressed(Key::F) && !typing)
                    || (i.modifiers.command && i.key_pressed(Key::Num0)),
                !typing && (i.key_pressed(Key::Plus) || i.key_pressed(Key::Equals)),
                !typing && i.key_pressed(Key::Minus),
                !typing && i.key_pressed(Key::Num0) && !i.modifiers.command,
                i.key_pressed(Key::Escape),
                i.events.iter().find_map(|e| match e {
                    egui::Event::Paste(text) if !typing => Some(text.clone()),
                    _ => None,
                }),
            )
        });
        if open {
            self.picker.open();
        }
        if find {
            self.find.open();
        }
        // Escape works while typing too: it is the one key whose meaning is
        // "stop whatever is going on", and a pinned table outlives the click
        // that pinned it. One Escape cancels one thing, innermost first — an
        // open field before the focus it was opened inside.
        if unpin && !self.inline.is_open() && self.note_edit.is_none() {
            self.canvas.unpin();
        }
        if fit {
            self.fit_pending = true;
        }
        if zoom_in {
            self.zoom_by(1.25, view);
        }
        if zoom_out {
            self.zoom_by(0.8, view);
        }
        if reset {
            self.camera.zoom = 1.0;
        }
        // Pasting a schema is the fastest way in, and on the web it avoids the
        // file dialog entirely. Anything shorter than a CREATE TABLE is far
        // more likely to be a stray copy than a schema.
        //
        // A pasted *link* is fetched instead, which is how anybody finds out
        // that `#u=` exists: copying a raw URL and pressing paste is the gesture
        // people already try, and until now it drew a diagram of one line of
        // text.
        if let Some(text) = pasted {
            if platform::looks_like_url(&text) {
                self.picker.fetch(text.trim());
            } else if text.len() > 16 {
                self.open(ctx, "pasted".to_owned(), text);
            }
        }
    }

    fn take_dropped_files(&mut self, ctx: &egui::Context) {
        let dropped = ctx.input(|i| i.raw.dropped_files.clone());
        if let Some(file) = dropped.into_iter().next() {
            self.picker.accept_drop(file);
        }
    }

    fn run_bench(
        &mut self,
        ctx: &egui::Context,
        view: egui::Rect,
        settled: Option<Cost>,
        mirrored: Option<f32>,
    ) {
        let Some(run) = &mut self.bench else {
            return;
        };
        let finished = match run {
            Run::Canvas(bench) => {
                bench.tick(
                    &mut self.camera,
                    view,
                    self.doc.bounds(),
                    self.cpu_ms,
                    self.canvas.counts,
                );
                bench.finished.as_deref()
            }
            Run::Typing(bench) => {
                let now = ctx.input(|i| i.time);
                if bench.tick(&mut self.doc.sql, now, self.cpu_ms, settled, mirrored) {
                    self.editor.mark_dirty(now);
                }
                bench.finished.as_deref()
            }
        };
        if let Some(line) = finished {
            if !self.bench_reported {
                self.bench_reported = true;
                platform::report(line);
                #[cfg(not(target_arch = "wasm32"))]
                ctx.send_viewport_cmd(egui::ViewportCommand::Close);
            }
        } else {
            // A measurement must not be paced by egui's idle repaint.
            ctx.request_repaint();
        }
    }
}

/// A menu on the bar, or a submenu inside another menu — whichever this `ui`
/// turns out to be, which is what lets the same group of buttons serve both
/// toolbar arrangements.
///
/// Not `Ui::menu_button`, for one reason: its submenu arrow is U+23F5, which
/// **neither** Ubuntu Light nor Hack carries, so egui draws a tofu box beside
/// every submenu. `›` is in both faces — checked, not assumed.
fn menu(
    ui: &mut egui::Ui,
    label: impl Into<egui::WidgetText>,
    contents: impl FnOnce(&mut egui::Ui),
) {
    use egui::containers::menu;

    let label = label.into();
    if menu::is_in_menu(ui) {
        menu::SubMenuButton::from_button(egui::Button::new(label).right_text("›")).ui(ui, contents);
    } else {
        menu::MenuButton::new(label).ui(ui, contents);
    }
}

fn combo(ui: &mut egui::Ui, id: &str, selected: &str, contents: impl FnOnce(&mut egui::Ui)) {
    egui::ComboBox::from_id_salt(id)
        .selected_text(selected)
        .show_ui(ui, contents);
}

fn lod_label(lod: Lod) -> &'static str {
    match lod {
        Lod::Full => "full",
        Lod::Header => "headers",
        Lod::Block => "blocks",
    }
}

fn plural(n: usize, noun: &str) -> String {
    if n == 1 {
        format!("{n} {noun}")
    } else {
        format!("{n} {noun}s")
    }
}

/// A column name not already taken in this table.
fn free_column_name(schema: &draft_ddl::Schema, table: usize) -> String {
    let Some(t) = schema.tables.get(table) else {
        return "new_column".to_owned();
    };
    (0..)
        .map(|n| match n {
            0 => "new_column".to_owned(),
            n => format!("new_column_{n}"),
        })
        .find(|name| t.column(name).is_none())
        .expect("an unbounded sequence contains an unused name")
}

fn separator_dot() -> RichText {
    RichText::new("·").weak()
}

/// A file name without its extension, for naming an export after its schema.
fn file_stem(name: &str) -> &str {
    match name.rsplit_once('.') {
        Some((stem, _)) if !stem.is_empty() => stem,
        _ => name,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::camera::{MAX_ZOOM, MIN_ZOOM};

    /// The zoom range has to survive a round trip through the stored project,
    /// or a stored camera could restore the app to a blank screen.
    #[test]
    fn the_camera_survives_being_stored_at_either_end_of_its_range() {
        for zoom in [MIN_ZOOM, 0.37, 1.0, MAX_ZOOM] {
            let project = Project {
                camera: Some(Camera {
                    origin: egui::Pos2::new(-12.5, 400.0),
                    zoom,
                }),
                sql: sample::DEFAULT.sql.to_owned(),
                ..Project::default()
            };
            let back = Project::from_json(&project.to_json()).expect("a project we just wrote");
            assert_eq!(back.camera, project.camera);
        }
    }

    /// Adding a field in a later release must not throw away what a user
    /// already had stored — and a project file is also a file people edit.
    #[test]
    fn a_stored_project_missing_fields_still_loads() {
        let back: Project =
            serde_json::from_str(r#"{"settings":{"dark":false},"sql":"CREATE TABLE t (id int);"}"#)
                .expect("deserialise");
        assert!(!back.settings.dark);
        assert_eq!(back.settings.spacing, Gap::Comfortable);
        assert!(back.settings.show_editor);
        assert_eq!(
            back.camera, None,
            "no stored camera means frame the diagram"
        );
        assert!(back.annotations.is_empty());
    }

    /// The file name an export is offered under. A schema called `shop.sql`
    /// should not produce `shop.sql.png`.
    #[test]
    fn an_export_is_named_after_its_schema() {
        assert_eq!(file_stem("shop.sql"), "shop");
        assert_eq!(file_stem("pagila-pg_dump.sql"), "pagila-pg_dump");
        assert_eq!(file_stem("no-extension"), "no-extension");
        assert_eq!(file_stem(".hidden"), ".hidden");
    }

    /// Every sample is a shop window, not a fixture: whichever one the menu
    /// opens has to parse without a complaint, show enough structure to be worth
    /// looking at, and read as the dialect it is offered under — the menu names
    /// the dialect, so a sample the detector cannot place would be advertising
    /// something it does not demonstrate.
    #[test]
    fn every_sample_is_the_schema_we_advertise() {
        assert_eq!(
            sample::ALL.map(|s| s.dialect),
            Dialect::ALL,
            "the menu offers one sample per dialect, in the dialects' own order"
        );

        for sample in sample::ALL {
            let name = sample.name;
            let schema = draft_ddl::parse(sample.sql);
            assert!(schema.warnings.is_empty(), "{name}: {:?}", schema.warnings);
            assert!(
                schema.tables.len() >= 8,
                "{name}: {} tables is too few to show what the layout does",
                schema.tables.len()
            );
            assert_eq!(
                schema.relations.iter().filter(|r| r.to_missing).count(),
                0,
                "{name} shows a dangling reference on first load"
            );
            assert!(
                schema.relations.len() >= 8,
                "{name}: {} relations is too few to show what they look like",
                schema.relations.len()
            );
            assert_eq!(
                draft_ddl::detect(sample.sql),
                Some(sample.dialect),
                "{name} does not read as the dialect the menu offers it under"
            );
        }
    }

    /// The default is what a first visit opens and what the landing page draws,
    /// and `web/site.mjs` draws it by reading `sample.sql` directly. Renaming
    /// that file would silently leave the picture and the application showing
    /// different schemas.
    #[test]
    fn the_default_sample_is_the_one_the_landing_page_draws() {
        assert_eq!(sample::DEFAULT.name, "sample.sql");
        assert_eq!(sample::DEFAULT.dialect, Dialect::Postgres);
        assert_eq!(draft_ddl::parse(sample::DEFAULT.sql).tables.len(), 9);
    }

    #[test]
    fn the_zoom_buttons_stay_inside_the_range() {
        let view = egui::Rect::from_min_size(egui::Pos2::ZERO, egui::Vec2::new(800.0, 600.0));
        let mut camera = Camera::default();
        for _ in 0..100 {
            camera.zoom_about(0.8, view.center(), view);
        }
        assert_eq!(camera.zoom, MIN_ZOOM);
        for _ in 0..100 {
            camera.zoom_about(1.25, view.center(), view);
        }
        assert_eq!(camera.zoom, MAX_ZOOM);
    }
}
