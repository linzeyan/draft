//! Phase 0 spike S3 -- canvas scale.
//!
//! Answers: can egui hold 60fps while panning and zooming 1,000 tables?
//!
//! Tests the three techniques from docs/architecture.md#d5 -- viewport culling,
//! a per-table shape cache, and level of detail -- and nothing else. If these
//! three are enough, the texture atlas stays out of the plan.
//!
//! The reference tool rasterises each table to an offscreen bitmap once and
//! blits it while panning. That does not port to immediate mode: rebuilding a
//! frame is the model, and 1,000 individual textures would cost more than they
//! save.
//!
//! The camera sweeps deterministically from fully zoomed in to fully zoomed out
//! across the run. An earlier version orbited on a sinusoid whose period was
//! longer than the run itself, so it never zoomed far enough to put more than
//! ~65 tables on screen and cheerfully reported sub-millisecond frames for a
//! test that was not testing anything. The sweep now ends with the entire world
//! framed, and the peak visible count is reported so that failure mode cannot
//! recur silently.

use egui::{Align2, Color32, FontFamily, FontId, Pos2, Rect, Sense, Shape, Stroke, Vec2};

use crate::stats::Stats;

pub struct Table {
    name: String,
    columns: Vec<(String, String)>,
    pos: Pos2,
    size: Vec2,
    /// Shapes in table-local space, rebuilt only when the LOD bucket changes.
    cache: Option<(Lod, Vec<Shape>)>,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Lod {
    /// Every column legible.
    Full,
    /// Header only; column text would be sub-pixel anyway.
    Header,
    /// A solid block. Shape and colour still carry position and size, which is
    /// all the user can perceive at this zoom.
    Block,
}

fn lod_for(zoom: f32) -> Lod {
    if zoom > 0.55 {
        Lod::Full
    } else if zoom > 0.22 {
        Lod::Header
    } else {
        Lod::Block
    }
}

const ROW_H: f32 = 26.0;
const HEADER_H: f32 = 34.0;
const PAD_X: f32 = 12.0;
const CELL_W: f32 = 400.0;
const CELL_H: f32 = 320.0;

pub struct CanvasSpike {
    tables: Vec<Table>,
    pan: Vec2,
    zoom: f32,
    t: f32,
    /// Full extent of the generated grid, used to frame the camera.
    world: Vec2,
    stats: Stats,
    last_visible: usize,
    last_shapes: usize,
    /// Peak load actually reached during the run.
    ///
    /// Without these, a fast result is indistinguishable from a spike that
    /// culled everything and measured an empty screen.
    peak_visible: usize,
    peak_shapes: usize,
    total_frames: usize,
    pub frames_left: Option<usize>,
    pub finished: Option<String>,
}

impl CanvasSpike {
    /// Tables are packed into a dense grid rather than placed by a real layout.
    ///
    /// This is deliberately conservative: a dagre layout of this fixture is 2%
    /// dense and sprawling, so culling would hide almost everything. A tight
    /// grid keeps far more tables on screen at once, which is the harder test.
    pub fn new(count: usize, frames: Option<usize>) -> Self {
        let mut tables = Vec::with_capacity(count);
        let cols = (count as f32).sqrt().ceil() as usize;
        let mut seed = 0x2545_F491_4F6C_DD1Du64;
        let mut rand = move || {
            seed ^= seed << 13;
            seed ^= seed >> 7;
            seed ^= seed << 17;
            (seed >> 11) as f32 / (1u64 << 53) as f32
        };

        for i in 0..count {
            let n_cols = 3 + (rand() * 12.0) as usize;
            let columns: Vec<(String, String)> = (0..n_cols)
                .map(|c| {
                    (
                        format!("column_name_{c}"),
                        ["bigint", "text", "varchar(255)", "timestamptz", "boolean"]
                            [(rand() * 5.0) as usize % 5]
                            .to_string(),
                    )
                })
                .collect();
            let w = 240.0 + rand() * 100.0;
            let h = HEADER_H + columns.len() as f32 * ROW_H;
            tables.push(Table {
                name: format!("table_{i}"),
                columns,
                pos: Pos2::new((i % cols) as f32 * CELL_W, (i / cols) as f32 * CELL_H),
                size: Vec2::new(w, h),
                cache: None,
            });
        }

        let rows = count.div_ceil(cols);
        let total = frames.unwrap_or(600);
        Self {
            tables,
            pan: Vec2::ZERO,
            zoom: 1.0,
            t: 0.0,
            world: Vec2::new(cols as f32 * CELL_W, rows as f32 * CELL_H),
            stats: Stats::new(30),
            last_visible: 0,
            last_shapes: 0,
            peak_visible: 0,
            peak_shapes: 0,
            total_frames: total,
            frames_left: frames,
            finished: None,
        }
    }

    pub fn ui(&mut self, ui: &mut egui::Ui, cpu_ms: Option<f32>) {
        if let Some(ms) = cpu_ms {
            self.stats.push(ms);
        }
        self.t += 1.0 / 60.0;

        let avail = ui.available_size();

        // Zoom that frames the entire world, i.e. every table visible at once.
        // This is the number the 1,000-table requirement is really about.
        let fit = (avail.x / self.world.x).min(avail.y / self.world.y) * 0.98;

        // Sweep deterministically from "reading one table" to "whole schema on
        // screen" across the run, so every zoom level and every LOD bucket is
        // visited exactly once and the worst case is guaranteed to be reached.
        let progress = match self.frames_left {
            Some(left) => 1.0 - (left as f32 / self.total_frames as f32),
            None => 0.5 + 0.5 * (self.t * 0.4).sin(),
        };
        self.zoom = 1.2 * (1.0 - progress) + fit * progress;
        let lod = lod_for(self.zoom);

        // Orbit around the middle of the world so the framing stays centred as
        // the zoom pulls back.
        let view_w = avail.x / self.zoom;
        let view_h = avail.y / self.zoom;
        self.pan = Vec2::new(
            self.world.x * 0.5 - view_w * 0.5 + (self.t * 0.9).sin() * self.world.x * 0.10,
            self.world.y * 0.5 - view_h * 0.5 + (self.t * 0.7).cos() * self.world.y * 0.10,
        );

        ui.label(format!(
            "S3 canvas · {} tables · zoom {:.3} · lod {:?} · visible {} · shapes {} · {}",
            self.tables.len(),
            self.zoom,
            lod,
            self.last_visible,
            self.last_shapes,
            self.stats.summary(),
        ));

        let (resp, painter) = ui.allocate_painter(ui.available_size(), Sense::hover());
        let view = resp.rect;
        painter.rect_filled(view, 0.0, Color32::from_rgb(0x0e, 0x11, 0x16));

        // World -> screen. Culling happens in world space against the inverse
        // of this rect, so the per-table test is two comparisons and no matrix
        // work.
        let to_screen = |p: Pos2| {
            Pos2::new(
                view.min.x + (p.x - self.pan.x) * self.zoom,
                view.min.y + (p.y - self.pan.y) * self.zoom,
            )
        };
        let world_view = Rect::from_min_max(
            Pos2::new(self.pan.x, self.pan.y),
            Pos2::new(
                self.pan.x + view.width() / self.zoom,
                self.pan.y + view.height() / self.zoom,
            ),
        );

        let mut visible = 0;
        let mut shape_count = 0;
        let mut shapes: Vec<Shape> = Vec::new();

        for table in &mut self.tables {
            let bounds = Rect::from_min_size(table.pos, table.size);
            if !bounds.intersects(world_view) {
                continue;
            }
            visible += 1;

            // Rebuild only when the LOD bucket flips, not when the zoom value
            // changes. Cached shapes are in table-local space so they survive
            // panning untouched.
            let needs_rebuild = table.cache.as_ref().map(|(l, _)| *l != lod).unwrap_or(true);
            if needs_rebuild {
                let built = ui.ctx().fonts_mut(|fonts| build_table(table, lod, fonts));
                table.cache = Some((lod, built));
            }

            let origin = to_screen(table.pos);
            if let Some((_, cached)) = &table.cache {
                shape_count += cached.len();
                for s in cached {
                    let mut s = s.clone();
                    s.transform(egui::emath::TSTransform::new(origin.to_vec2(), self.zoom));
                    shapes.push(s);
                }
            }
        }

        painter.extend(shapes);
        self.last_visible = visible;
        self.last_shapes = shape_count;
        self.peak_visible = self.peak_visible.max(visible);
        self.peak_shapes = self.peak_shapes.max(shape_count);

        if let Some(left) = &mut self.frames_left {
            *left = left.saturating_sub(1);
            if *left == 0 && self.finished.is_none() {
                self.finished = Some(format!(
                    "S3 canvas  {:>5} tables  view {:.0}x{:.0}  peak visible {:>5}  peak shapes {:>6}  {}",
                    self.tables.len(),
                    avail.x,
                    avail.y,
                    self.peak_visible,
                    self.peak_shapes,
                    self.stats.summary(),
                ));
            }
        }
        ui.ctx().request_repaint();
    }
}

/// Build one table's shapes in local space (origin at its top-left).
fn build_table(table: &Table, lod: Lod, fonts: &mut egui::epaint::FontsView<'_>) -> Vec<Shape> {
    let bg = Color32::from_rgb(0x1b, 0x21, 0x2b);
    let border = Color32::from_rgb(0x2b, 0x33, 0x3f);
    let header_bg = Color32::from_rgb(0x22, 0x2c, 0x3a);
    let header_fg = Color32::from_rgb(0xe8, 0xed, 0xf4);
    let row_fg = Color32::from_rgb(0xc4, 0xcc, 0xd6);
    let type_fg = Color32::from_rgb(0x6f, 0x7b, 0x8a);

    let full = Rect::from_min_size(Pos2::ZERO, table.size);
    let mut out = vec![Shape::rect_filled(full, 10.0, bg)];

    if lod == Lod::Block {
        out.push(Shape::rect_stroke(
            full,
            10.0,
            Stroke::new(1.0, border),
            egui::StrokeKind::Inside,
        ));
        return out;
    }

    out.push(Shape::rect_filled(
        Rect::from_min_size(Pos2::ZERO, Vec2::new(table.size.x, HEADER_H)),
        10.0,
        header_bg,
    ));
    out.push(Shape::text(
        fonts,
        Pos2::new(PAD_X, HEADER_H / 2.0),
        Align2::LEFT_CENTER,
        &table.name,
        FontId::new(14.0, FontFamily::Proportional),
        header_fg,
    ));

    if lod == Lod::Full {
        for (i, (name, ty)) in table.columns.iter().enumerate() {
            let y = HEADER_H + i as f32 * ROW_H + ROW_H / 2.0;
            out.push(Shape::text(
                fonts,
                Pos2::new(PAD_X + 18.0, y),
                Align2::LEFT_CENTER,
                name,
                FontId::new(13.0, FontFamily::Monospace),
                row_fg,
            ));
            out.push(Shape::text(
                fonts,
                Pos2::new(table.size.x - PAD_X, y),
                Align2::RIGHT_CENTER,
                ty,
                FontId::new(12.0, FontFamily::Monospace),
                type_fg,
            ));
        }
    }

    out.push(Shape::rect_stroke(
        full,
        10.0,
        Stroke::new(1.0, border),
        egui::StrokeKind::Inside,
    ));
    out
}
