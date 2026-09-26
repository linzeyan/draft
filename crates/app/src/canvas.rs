//! The diagram canvas: input, culling, caching, drawing.
//!
//! The three techniques from docs/architecture.md D5, in the order they earn
//! their keep: cull to the viewport, cache each table's shapes, drop detail as
//! the zoom pulls back. Spike S3 showed those three carry 1,000 tables at
//! 60 fps without a texture atlas.

use draft_ddl::Schema;
use draft_layout::Size;
use draft_view::{Hit, Lod, TextStyles, Theme};
use egui::emath::TSTransform;
use egui::{Color32, CursorIcon, Rect, Sense, Shape, Vec2};

use crate::annotate::{Grab, Kind, PALETTE};
use crate::camera::{Camera, MAX_ZOOM};
use crate::document::Document;

/// What the last frame cost, for the stats overlay and for the bench harness.
///
/// Without `visible` a fast frame is indistinguishable from one that culled
/// everything and drew an empty screen — which is how an earlier version of the
/// S3 spike reported a pass while testing nothing.
#[derive(Clone, Copy, Default)]
pub struct Counts {
    pub visible: usize,
    pub shapes: usize,
    /// Tables whose shapes had to be built this frame rather than reused.
    pub built: usize,
}

/// Everything the canvas needs that it does not own.
pub struct Params<'a> {
    pub doc: &'a Document,
    pub camera: &'a mut Camera,
    pub theme: &'a Theme,
    /// Which register the palette should draw annotations in. Derived from the
    /// setting rather than sniffed from the theme's colours, which would be a
    /// guess about our own data.
    pub dark: bool,
    pub styles: &'a TextStyles,
    /// Bumped by the app whenever the diagram or its colours change. The cache
    /// is keyed on it rather than on a hash of the schema, because the app
    /// already knows when something changed and hashing a 400 KB script every
    /// frame to rediscover that would be absurd.
    pub generation: u64,
}

#[derive(Clone, Copy, PartialEq)]
struct Key {
    generation: u64,
    lod: Lod,
    scale: f32,
}

/// A relationship curve, ready to cull and to highlight.
struct Edge {
    bounds: Rect,
    shape: Shape,
    from: usize,
    to: Option<usize>,
}

/// Something the canvas noticed that only the application can act on.
///
/// An enum rather than a struct of options because these are readings of the
/// same gesture and cannot happen together: a drag is not a double-click.
pub enum Act {
    /// A table was dragged to a new world position.
    Moved(usize, egui::Pos2),
    /// A double-click landed on something nameable.
    Edit(usize, Hit),
    /// A double-click below the detail threshold, where a text field would be
    /// too small to read. Go and look at the table instead of refusing.
    ZoomTo(usize),
    /// Append a column to this table.
    AddColumn(usize),
    /// An annotation was moved or resized to this rectangle.
    NoteMoved(usize, Rect),
    /// Open a text field on an annotation.
    NoteEdit(usize),
    NoteColour(usize, usize),
    NoteDelete(usize),
}

/// A drag in progress, in world space.
///
/// The grab offset is what stops the table jumping so its corner meets the
/// cursor the moment you touch it.
#[derive(Clone, Copy)]
struct Drag {
    table: usize,
    grab: Vec2,
}

/// An annotation being moved or resized, in world space.
#[derive(Clone, Copy)]
struct NoteDrag {
    index: usize,
    grab: Grab,
    /// Pointer minus the corner the gesture is anchored to.
    offset: Vec2,
}

/// What the open context menu was raised on.
///
/// A table is held by name because a re-parse renumbers them; an annotation by
/// index because nothing renumbers those while a menu is open. The column is
/// the row the press landed on, by name for the same reason as the table.
#[derive(Clone)]
enum MenuOn {
    Table(String, Option<String>),
    Note(usize),
}

/// [`MenuOn`] resolved against the schema in front of us, this frame.
#[derive(Clone, Copy)]
enum Target {
    Table(usize, Option<usize>),
    Note(usize),
}

#[derive(Default)]
pub struct Canvas {
    key: Option<Key>,
    /// Per table, in `Schema::tables` order. `None` means "not built yet";
    /// tables that never come into view are never built at all.
    tables: Vec<Option<Vec<Shape>>>,
    /// Relationship curves in world space, with the bounds used to cull them.
    /// An edge belongs to two tables, so it cannot live in either one's cache.
    edges: Vec<Edge>,
    edges_for: Option<u64>,
    drag: Option<Drag>,
    note_drag: Option<NoteDrag>,
    /// The table a click pinned, by name rather than index: a re-parse
    /// renumbers every table, and a pin that silently moved to a different
    /// table would be worse than one that was dropped.
    pinned: Option<String>,
    /// What the open context menu was raised on, latched at the click.
    menu_on: Option<MenuOn>,
    pub counts: Counts,
}

/// The scale to build a table at, given the zoom it will be drawn at.
///
/// Glyphs are rasterised at the size they are laid out at, so a table built at
/// scale 1 and magnified 4x is a magnified bitmap. Building at integer steps
/// keeps text sharp while bounding how often the cache is thrown away: zooming
/// all the way in crosses three boundaries, not sixty.
///
/// Below 1 there is nothing to gain — shrinking a galley supersamples it — so
/// the common case of zooming *out* never invalidates anything on this account.
fn sharpness(zoom: f32) -> f32 {
    zoom.clamp(1.0, MAX_ZOOM).ceil()
}

/// What a latched menu points at now.
///
/// Looked up by name every frame rather than latched as indices: a menu can
/// stay open across a re-parse, and both numbers move. A table index would
/// re-point the menu at whichever table took that slot; a column index would
/// have it describe whichever column took that row. Names that no longer exist
/// resolve to nothing, which is the honest answer.
fn resolve(menu_on: &Option<MenuOn>, doc: &Document) -> Option<Target> {
    match menu_on {
        Some(MenuOn::Table(name, column)) => {
            let table = doc.schema.index_of(name)?;
            let row = column.as_ref().and_then(|name| {
                doc.schema.tables[table]
                    .columns
                    .iter()
                    .position(|column| &column.name == name)
            });
            Some(Target::Table(table, row))
        }
        Some(MenuOn::Note(index)) => doc.annotations.get(*index).map(|_| Target::Note(*index)),
        None => None,
    }
}

/// The line the script wrote for one column, trimmed, or nothing when there is
/// no text to show.
fn definition<'a>(p: &'a Params<'_>, table: usize, row: usize) -> Option<&'a str> {
    let column = p.doc.schema.tables.get(table)?.columns.get(row)?;
    let text = column.def_span.text(&p.doc.sql).trim();
    (!text.is_empty()).then_some(text)
}

impl Canvas {
    /// Draw a frame. Returns anything the user asked for that only the
    /// application can carry out — the canvas is handed the document by
    /// reference and has no business editing it.
    pub fn show(&mut self, ui: &mut egui::Ui, mut p: Params<'_>) -> Option<Act> {
        let (response, painter) = ui.allocate_painter(ui.available_size(), Sense::click_and_drag());
        let view = response.rect;
        painter.rect_filled(view, 0.0, p.theme.background);
        let mut act = self.handle_input(ui, &response, &mut p, view);
        act = self.menu(&response, &p, view).or(act);

        let zoom = p.camera.zoom;
        let lod = Lod::for_zoom(zoom);
        let key = Key {
            generation: p.generation,
            lod,
            scale: sharpness(zoom),
        };
        if self.key != Some(key) {
            self.key = Some(key);
            self.tables.clear();
            self.tables.resize_with(p.doc.schema.tables.len(), || None);
        }
        if self.edges_for != Some(p.generation) {
            self.edges_for = Some(p.generation);
            self.edges = draft_view::relation_shapes(&p.doc.schema, &p.doc.layout, p.theme)
                .into_iter()
                .map(|e| Edge {
                    bounds: e.shape.visual_bounding_rect(),
                    shape: e.shape,
                    from: e.from,
                    to: e.to,
                })
                .collect();
        }

        // Hover only counts when nothing is pinned: a pin is a decision, and
        // having it evaporate because the pointer drifted over a neighbour is
        // the opposite of what pinning is for.
        let focus = if self.pinned.is_some() {
            self.resolve_pin(&p.doc.schema)
        } else {
            self.table_at(&p, view, ui.input(|i| i.pointer.hover_pos()))
        };

        let world = p.camera.visible_world(view);
        let mut batch: Vec<Shape> = Vec::new();
        let mut counts = Counts::default();

        // Group boxes are behind everything: they frame the tables, and an
        // opaque frame drawn over them would be a lid.
        let to_screen =
            TSTransform::new(view.min.to_vec2() - p.camera.origin.to_vec2() * zoom, zoom);
        self.draw_notes(&mut batch, Kind::Group, ui, &p, view, key.scale);

        // Edges next: they pass behind the boxes rather than over them.
        for edge in &self.edges {
            if !edge.bounds.intersects(world) {
                continue;
            }
            let mut shape = edge.shape.clone();
            shape.transform(to_screen);
            batch.push(shape);
        }
        counts.shapes = batch.len();

        for (i, table) in p.doc.schema.tables.iter().enumerate() {
            let Some(bounds) = p.doc.table_rect(i) else {
                continue;
            };
            if !bounds.intersects(world) {
                continue;
            }
            let Some(slot) = self.tables.get_mut(i) else {
                continue;
            };
            counts.visible += 1;

            if slot.is_none() {
                counts.built += 1;
                let size = Size {
                    w: bounds.width(),
                    h: bounds.height(),
                };
                *slot = Some(ui.ctx().fonts_mut(|fonts| {
                    draft_view::table_shapes(
                        table, size, key.lod, key.scale, p.theme, p.styles, fonts,
                    )
                }));
            }

            // Cached shapes are in table-local space at `key.scale`, so all
            // that is left per frame is placing them.
            let origin = p.camera.to_screen(bounds.min, view).to_vec2();
            let place = TSTransform::new(origin, zoom / key.scale);
            for shape in slot.iter().flatten() {
                let mut shape = shape.clone();
                shape.transform(place);
                batch.push(shape);
                counts.shapes += 1;
            }
        }

        // Sticky notes sit in front of the tables — that is what makes them
        // notes — but behind the focus veil, so a pinned table still stands out
        // from everything, annotations included.
        let before = batch.len();
        self.draw_notes(&mut batch, Kind::Note, ui, &p, view, key.scale);
        counts.shapes += batch.len() - before;

        if let Some(index) = focus {
            counts.shapes += self.draw_focus(&mut batch, index, &p, view, world, to_screen);
        }

        painter.extend(batch);
        self.counts = counts;
        act
    }

    /// The right-click menu, which a long press on a touch screen also opens.
    ///
    /// Adding a column has no natural place to click — there is no empty row at
    /// the bottom of a box to point at — and a toolbar button would have no way
    /// to say which table it meant. Right-click is where people already look
    /// for "what can I do to this thing".
    ///
    /// It carries the pressed column's definition because a touch screen has no
    /// hover: egui turns a long press into a secondary click, so this menu is
    /// the one affordance a finger can reach, and the definition would otherwise
    /// be mouse-only.
    fn menu(&mut self, response: &egui::Response, p: &Params<'_>, view: Rect) -> Option<Act> {
        // The menu outlives the click that opened it, and the contents are
        // rebuilt every frame it stays open. `interact_pointer_pos` is only
        // there on the frame of the click itself, so what was clicked has to be
        // latched: reading the pointer again on the next frame finds it over
        // the menu and reports that there is no table under it.
        if response.secondary_clicked() {
            let at = response.interact_pointer_pos();
            self.menu_on = self
                .note_at(p, view, at)
                .map(|(i, _)| MenuOn::Note(i))
                .or_else(|| {
                    let table = self.table_at(p, view, at).or_else(|| self.menu_target(p))?;
                    let column = at
                        .and_then(|at| self.column_at(p, view, table, at))
                        .and_then(|row| p.doc.schema.tables[table].columns.get(row))
                        .map(|column| column.name.clone());
                    Some(MenuOn::Table(
                        p.doc.schema.tables[table].name.clone(),
                        column,
                    ))
                });
        }
        // Resolved fresh every frame, so a menu left open across a re-parse acts
        // on the table it names or on nothing at all.
        let target = resolve(&self.menu_on, p.doc);

        let mut act = None;
        response.context_menu(|ui| match target {
            Some(Target::Table(table, column)) => {
                ui.label(egui::RichText::new(&p.doc.schema.tables[table].name).strong());
                if let Some(text) = column.and_then(|row| definition(p, table, row)) {
                    ui.label(egui::RichText::new(text).monospace());
                }
                ui.separator();
                if ui.button("Rename table…").clicked() {
                    act = Some(Act::Edit(table, Hit::Header));
                    ui.close();
                }
                if ui.button("Add column").clicked() {
                    act = Some(Act::AddColumn(table));
                    ui.close();
                }
            }
            Some(Target::Note(index)) => {
                let Some(note) = p.doc.annotations.get(index) else {
                    return;
                };
                ui.label(
                    egui::RichText::new(match note.kind {
                        Kind::Note => "Sticky note",
                        Kind::Group => "Group box",
                    })
                    .strong(),
                );
                ui.separator();
                if ui.button("Edit text…").clicked() {
                    act = Some(Act::NoteEdit(index));
                    ui.close();
                }
                ui.horizontal(|ui| {
                    for (i, swatch) in PALETTE.iter().enumerate() {
                        if ui.selectable_label(note.colour == i, swatch.name).clicked() {
                            act = Some(Act::NoteColour(index, i));
                            ui.close();
                        }
                    }
                });
                ui.separator();
                if ui.button("Delete").clicked() {
                    act = Some(Act::NoteDelete(index));
                    ui.close();
                }
            }
            None => {
                ui.label(egui::RichText::new("nothing here").weak());
            }
        });
        act
    }

    /// The pinned table, as a fallback for a menu opened on empty space.
    fn menu_target(&self, p: &Params<'_>) -> Option<usize> {
        p.doc.schema.index_of(self.pinned.as_deref()?)
    }

    /// Resolve the pin against the schema in front of us, dropping it if the
    /// table it names has gone.
    ///
    /// Pinning a table is usually the prelude to renaming it, and the rename
    /// takes the pinned name with it. Keeping the old one would leave the veil
    /// lifted while the status bar went on claiming focus on a table that is no
    /// longer anywhere on the diagram.
    fn resolve_pin(&mut self, schema: &Schema) -> Option<usize> {
        let name = self.pinned.take()?;
        let found = schema.index_of(&name);
        self.pinned = found.map(|_| name);
        found
    }

    /// One annotation layer, built fresh every frame.
    ///
    /// No per-item cache, unlike tables: a diagram has a handful of these
    /// against a possible three thousand tables, and a cache would cost more in
    /// invalidation rules than it could ever save.
    fn draw_notes(
        &self,
        batch: &mut Vec<Shape>,
        layer: Kind,
        ui: &egui::Ui,
        p: &Params<'_>,
        view: Rect,
        scale: f32,
    ) {
        if p.doc.annotations.is_empty() {
            return;
        }
        let shapes = ui.ctx().fonts_mut(|fonts| {
            p.doc
                .annotations
                .shapes(layer, p.theme, p.dark, scale, fonts)
        });
        // Built in world units multiplied by `scale`, so the transform that
        // places them is the camera's, divided by the scale they were built at.
        let place = TSTransform::new(
            view.min.to_vec2() - p.camera.origin.to_vec2() * p.camera.zoom,
            p.camera.zoom / scale,
        );
        for mut shape in shapes {
            shape.transform(place);
            batch.push(shape);
        }
    }

    /// Veil the diagram and redraw one table's neighbourhood over the top.
    ///
    /// Fading by covering rather than by recolouring: the shapes are already
    /// cached in the theme's colours, and a second cache in faded colours would
    /// double both the memory and the rebuild cost of every zoom step, to say
    /// the same thing one translucent rectangle says.
    fn draw_focus(
        &self,
        batch: &mut Vec<Shape>,
        index: usize,
        p: &Params<'_>,
        view: Rect,
        world: Rect,
        to_screen: TSTransform,
    ) -> usize {
        let veil = p.theme.background.gamma_multiply(0.82).to_opaque();
        batch.push(Shape::rect_filled(
            view,
            0,
            Color32::from_rgba_unmultiplied(veil.r(), veil.g(), veil.b(), 205),
        ));

        let mut related = vec![index];
        let before = batch.len();
        for edge in &self.edges {
            let other = match (edge.from, edge.to) {
                (from, Some(to)) if from == index => to,
                (from, Some(to)) if to == index => from,
                (from, None) if from == index => index,
                _ => continue,
            };
            related.push(other);
            if edge.bounds.intersects(world) {
                let mut shape = edge.shape.clone();
                shape.transform(to_screen);
                batch.push(shape);
            }
        }

        related.sort_unstable();
        related.dedup();
        let zoom = p.camera.zoom;
        let scale = self.key.map_or(1.0, |k| k.scale);
        for i in related {
            let (Some(bounds), Some(Some(shapes))) = (p.doc.table_rect(i), self.tables.get(i))
            else {
                continue;
            };
            if !bounds.intersects(world) {
                continue;
            }
            let place =
                TSTransform::new(p.camera.to_screen(bounds.min, view).to_vec2(), zoom / scale);
            for shape in shapes {
                let mut shape = shape.clone();
                shape.transform(place);
                batch.push(shape);
            }
        }
        batch.len() - before + 1
    }

    /// Resolve a double-click on `table` into something to do.
    ///
    /// Below `Lod::Full` the table is drawn as a header or a plain block, so
    /// there is nothing on screen to point at and a text field would be smaller
    /// than its own text. Zooming to the table is the useful answer: it is what
    /// the next click would have wanted anyway.
    fn what_was_clicked(
        &self,
        p: &mut Params<'_>,
        view: Rect,
        table: usize,
        at: egui::Pos2,
    ) -> Act {
        let Some(bounds) = p.doc.table_rect(table) else {
            return Act::ZoomTo(table);
        };
        if Lod::for_zoom(p.camera.zoom) != Lod::Full {
            return Act::ZoomTo(table);
        }
        let local = p.camera.to_world(at, view) - bounds.min;
        let size = Size {
            w: bounds.width(),
            h: bounds.height(),
        };
        match p
            .doc
            .schema
            .tables
            .get(table)
            .and_then(|t| draft_view::hit_test(t, size, local))
        {
            Some(hit) => Act::Edit(table, hit),
            None => Act::ZoomTo(table),
        }
    }

    /// What the script says about the column under the pointer, verbatim.
    ///
    /// A row has room for a name and a type. A column definition carries more
    /// than that — a default, a `COMMENT`, a `CHECK`, a collation, a generated
    /// expression — and rather than choose which of those to squeeze into the
    /// box, hover shows the line the script actually wrote. It is the one
    /// description that cannot be out of date or incomplete, and it costs the
    /// diagram no space at all.
    fn definition_tooltip(
        &self,
        response: &egui::Response,
        p: &Params<'_>,
        view: Rect,
        under: Option<usize>,
        at: Option<egui::Pos2>,
    ) {
        let (Some(index), Some(at)) = (under, at) else {
            return;
        };
        let Some(text) = self
            .column_at(p, view, index, at)
            .and_then(|row| definition(p, index, row))
        else {
            return;
        };
        response.clone().on_hover_ui_at_pointer(|ui| {
            ui.label(egui::RichText::new(text).monospace());
        });
    }

    /// Which row of a table box a screen position is on, if any.
    fn column_at(&self, p: &Params<'_>, view: Rect, table: usize, at: egui::Pos2) -> Option<usize> {
        // Below full detail the box is drawn as a header or a plain block, so
        // there are no rows to point at.
        if Lod::for_zoom(p.camera.zoom) != Lod::Full {
            return None;
        }
        let bounds = p.doc.table_rect(table)?;
        let size = Size {
            w: bounds.width(),
            h: bounds.height(),
        };
        let local = p.camera.to_world(at, view) - bounds.min;
        match draft_view::hit_test(p.doc.schema.tables.get(table)?, size, local)? {
            Hit::ColumnName(row) | Hit::ColumnType(row) => Some(row),
            Hit::Header => None,
        }
    }

    /// The topmost table under a screen position, if any.
    ///
    /// Reverse order because later tables are painted over earlier ones, and
    /// hit-testing that disagreed with painting would pick the box you can see
    /// through.
    fn table_at(&self, p: &Params<'_>, view: Rect, at: Option<egui::Pos2>) -> Option<usize> {
        let at = p.camera.to_world(at.filter(|a| view.contains(*a))?, view);
        (0..p.doc.schema.tables.len())
            .rev()
            .find(|&i| p.doc.table_rect(i).is_some_and(|r| r.contains(at)))
    }

    /// The annotation under a screen position, and which part of it.
    fn note_at(&self, p: &Params<'_>, view: Rect, at: Option<egui::Pos2>) -> Option<(usize, Grab)> {
        let at = p.camera.to_world(at.filter(|a| view.contains(*a))?, view);
        p.doc.annotations.hit(at)
    }

    /// Drop everything. The app calls this when the schema or theme changes;
    /// the generation key handles the rest.
    pub fn clear(&mut self) {
        self.key = None;
        self.tables.clear();
        self.edges.clear();
        self.edges_for = None;
    }

    /// Stop focusing on anything. The Escape key and a click on empty space.
    pub fn unpin(&mut self) {
        self.pinned = None;
    }

    /// Focus on a table nobody clicked on.
    ///
    /// What Find does when it jumps: arriving in the middle of a cluster of
    /// boxes with no idea which one was the answer is not an answer, and the
    /// focus veil already exists to say "this one".
    pub fn pin(&mut self, name: String) {
        self.pinned = Some(name);
    }

    /// The table a click pinned, for the status bar to name.
    pub fn pinned(&self) -> Option<&str> {
        self.pinned.as_deref()
    }
}

impl Canvas {
    /// Pan, zoom, drag a table, pin one, or clear the pin — decided here rather
    /// than spread across the frame, because they are mutually exclusive
    /// readings of the same gesture.
    fn handle_input(
        &mut self,
        ui: &egui::Ui,
        response: &egui::Response,
        p: &mut Params<'_>,
        view: Rect,
    ) -> Option<Act> {
        let (pointer, press) = ui.input(|i| (i.pointer.hover_pos(), i.pointer.press_origin()));
        // A two-finger gesture is a zoom and nothing else. egui reports the
        // primary finger of a pinch as a moving pointer, which is exactly what
        // a one-finger pan is made of, so without this a pinch over a table
        // zooms *and* drags the table out from under it — measured, not
        // imagined: .scratch/probe-touch.mjs caught a pinch hand-placing
        // `reviews`.
        let pinching = ui.input(|i| i.multi_touch().is_some());
        // Annotations are hit-tested first because they are drawn last. A note
        // sits in front of the tables, so it has to answer for the clicks that
        // land on it.
        let note_under = self.note_at(p, view, pointer);
        let under = note_under
            .is_none()
            .then(|| self.table_at(p, view, pointer))
            .flatten();

        // What a press means is settled once, from where the button went down —
        // not from where the pointer is when egui decides a drag has begun. By
        // then it has already travelled past egui's drag threshold, and on a
        // quick flick that is far enough to be outside the box that was
        // grabbed: the gesture would silently become a camera pan.
        if response.drag_started() {
            self.note_drag = press.and_then(|at| {
                let world = p.camera.to_world(at, view);
                let (index, grab) = p.doc.annotations.hit(world)?;
                let rect = p.doc.annotations.get(index)?.rect;
                let anchor = match grab {
                    Grab::Body => rect.min,
                    Grab::Resize => rect.max,
                };
                Some(NoteDrag {
                    index,
                    grab,
                    offset: world - anchor,
                })
            });
            self.drag = self
                .note_drag
                .is_none()
                .then(|| {
                    press
                        .and_then(|at| Some((self.table_at(p, view, Some(at))?, at)))
                        .and_then(|(table, at)| {
                            let origin = p.doc.table_rect(table)?.min;
                            Some(Drag {
                                table,
                                grab: p.camera.to_world(at, view) - origin,
                            })
                        })
                })
                .flatten();
        }
        if response.drag_stopped() {
            self.drag = None;
            self.note_drag = None;
        }

        // A click, not a drag: pin what is under it, or clear the pin when
        // there is nothing there. Clicking a note is not a decision about a
        // table, so it leaves the pin alone rather than clearing it.
        if response.clicked() && note_under.is_none() {
            self.pinned = under.map(|i| p.doc.schema.tables[i].name.clone());
        }
        if response.double_clicked() {
            if let Some((index, _)) = note_under {
                return Some(Act::NoteEdit(index));
            }
            if let Some(table) = under
                && let Some(at) = pointer
            {
                return Some(self.what_was_clicked(p, view, table, at));
            }
        }

        let mut act = None;
        if response.dragged() && !pinching {
            match (self.note_drag, self.drag, pointer) {
                (Some(note), _, Some(at)) => {
                    let world = p.camera.to_world(at, view);
                    if let Some(item) = p.doc.annotations.get(note.index) {
                        act = Some(Act::NoteMoved(
                            note.index,
                            item.dragged(note.grab, world, note.offset),
                        ));
                    }
                    ui.ctx().set_cursor_icon(match note.grab {
                        Grab::Body => CursorIcon::Grabbing,
                        Grab::Resize => CursorIcon::ResizeNwSe,
                    });
                }
                (None, Some(drag), Some(at)) => {
                    act = Some(Act::Moved(
                        drag.table,
                        p.camera.to_world(at, view) - drag.grab,
                    ));
                    // Only the edges move with the table: its own shapes are
                    // cached in table-local space. Bumping the generation
                    // instead would rebuild every visible table, every frame,
                    // for the whole length of the drag.
                    self.edges_for = None;
                    ui.ctx().set_cursor_icon(CursorIcon::Grabbing);
                }
                _ => {
                    p.camera.pan(response.drag_delta());
                    ui.ctx().set_cursor_icon(CursorIcon::Grabbing);
                }
            }
        } else if response.hovered() {
            ui.ctx().set_cursor_icon(match (note_under, under) {
                (Some((_, Grab::Resize)), _) => CursorIcon::ResizeNwSe,
                (Some(_), _) | (_, Some(_)) => CursorIcon::PointingHand,
                _ => CursorIcon::Grab,
            });
            if note_under.is_none() {
                self.definition_tooltip(response, p, view, under, pointer);
            }
        }

        if !response.hovered() {
            return act;
        }
        // egui routes ctrl/cmd + wheel and pinch into `zoom_delta` and takes
        // that delta *out* of the scroll, so these two branches cannot both
        // fire for one gesture. Plain scrolling pans, which is what every other
        // canvas tool does.
        let (scroll, zoom) = ui.input(|i| (i.smooth_scroll_delta, i.zoom_delta()));
        let anchor = pointer.unwrap_or_else(|| view.center());
        if zoom != 1.0 {
            p.camera.zoom_about(zoom, anchor, view);
        } else if scroll != Vec2::ZERO {
            p.camera.pan(scroll);
        }
        act
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Zooming out is the common case and must never cost a cache rebuild;
    /// zooming in must cost a bounded number of them.
    #[test]
    fn sharpness_only_steps_up_and_only_within_the_zoom_range() {
        for zoom in [0.02, 0.1, 0.5, 0.99, 1.0] {
            assert_eq!(sharpness(zoom), 1.0, "zoom {zoom} should not rebuild");
        }
        let steps: Vec<f32> = (0..=40)
            .map(|i| sharpness(MAX_ZOOM * i as f32 / 40.0))
            .collect();
        let mut distinct = steps.clone();
        distinct.dedup();
        assert!(
            distinct.len() <= MAX_ZOOM as usize,
            "too many rebuilds across the zoom range: {distinct:?}"
        );
        assert!(steps.iter().all(|s| (1.0..=MAX_ZOOM).contains(s)));
    }

    /// Renaming the table you just pinned is the ordinary next move, and it
    /// takes the pinned name with it. The pin must not survive as a name
    /// nothing answers to.
    #[test]
    fn a_pin_does_not_outlive_the_table_it_names() {
        let mut canvas = Canvas {
            pinned: Some("products".to_owned()),
            ..Default::default()
        };
        let before = draft_ddl::parse("CREATE TABLE products (id int);");
        assert_eq!(canvas.resolve_pin(&before), Some(0));

        let renamed = draft_ddl::parse("CREATE TABLE catalogue_items (id int);");
        assert_eq!(canvas.resolve_pin(&renamed), None);
        assert!(
            canvas.pinned().is_none(),
            "the status bar would go on naming a table that is not there"
        );
    }

    /// The menu shows the pressed column's definition, so it has to be pointing
    /// at the column that was pressed. A menu can sit open while the script is
    /// edited underneath it, and a row index would then quietly describe the
    /// column that moved up into that row.
    #[test]
    fn a_menu_describes_the_column_it_was_opened_on_or_none_at_all() {
        let on = Some(MenuOn::Table("reviews".to_owned(), Some("body".to_owned())));

        let doc = Document::new(
            "sample.sql",
            "CREATE TABLE reviews (id int, rating smallint, body text);",
        );
        assert!(
            matches!(resolve(&on, &doc), Some(Target::Table(0, Some(2)))),
            "the third row is `body`"
        );

        // `rating` deleted: row 2 is now `created_at`, and the menu must not
        // claim that is what was pressed.
        let edited = Document::new(
            "sample.sql",
            "CREATE TABLE reviews (id int, body text, created_at timestamptz);",
        );
        assert!(
            matches!(resolve(&on, &edited), Some(Target::Table(0, Some(1)))),
            "`body` moved up a row and the menu should follow it"
        );

        let gone = Document::new("sample.sql", "CREATE TABLE reviews (id int);");
        assert!(
            matches!(resolve(&on, &gone), Some(Target::Table(0, None))),
            "the column is gone, but the table is still there to act on"
        );

        let nothing = Document::new("sample.sql", "CREATE TABLE products (id int);");
        assert!(resolve(&on, &nothing).is_none(), "nothing to act on");
    }
}
