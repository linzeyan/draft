//! Diagram geometry and shapes.
//!
//! Everything visual that does not need a window lives here: how wide a table
//! is, where its columns sit, what colour anything is, and the list of
//! [`epaint::Shape`]s that draws it. The GUI hands those shapes to egui's
//! painter; the CLI hands the *same* shapes to the SVG writer. One geometry,
//! three targets.
//!
//! The crate depends on `epaint` rather than `egui` so it builds and tests with
//! no event loop and no GPU, and so text is measured by the same engine that
//! will eventually draw it. A measurement taken with a different font engine
//! than the renderer's is not a measurement.

pub mod fonts;

use std::collections::HashMap;
use std::sync::Arc;

use draft_ddl::{Schema, Table};
use draft_geom as geom;
use draft_layout::{Layout, Size};
use epaint::text::{FontsView, LayoutJob};
use epaint::{
    Color32, CornerRadius, FontFamily, FontId, Galley, Pos2, Rect, Shape, Stroke, StrokeKind, Vec2,
};

// The box metrics live in `draft-geom`, which has no font engine in it, and
// are re-exported here because this crate is the epaint-facing face of the same
// geometry: a caller drawing with `Shape`s should not have to know that the
// arithmetic is shared with a front end that measures its own text.
pub use draft_geom::{
    BADGE_W, GAP, HEADER_H, INDEX_H, INDEX_SEP, Lod, MAX_W, MIN_W, Measure, PAD_X, ROW_H, badge,
    index_row,
};

/// Fonts for each kind of text in a table box.
#[derive(Clone, Debug)]
pub struct TextStyles {
    pub header: FontId,
    pub name: FontId,
    pub ty: FontId,
    pub badge: FontId,
}

impl Default for TextStyles {
    fn default() -> Self {
        Self {
            header: FontId::new(14.0, FontFamily::Proportional),
            name: FontId::new(12.5, FontFamily::Proportional),
            ty: FontId::new(11.0, FontFamily::Monospace),
            badge: FontId::new(9.5, FontFamily::Proportional),
        }
    }
}

#[derive(Clone, Copy, Debug)]
pub struct Theme {
    pub background: Color32,
    pub table_fill: Color32,
    pub table_stroke: Color32,
    pub header_fill: Color32,
    pub header_text: Color32,
    pub column_text: Color32,
    /// Between [`Self::column_text`] and [`Self::type_text`]. Two things are
    /// drawn in it, and both are "there is less to this than to its
    /// neighbours": a nullable column's name, and an index's name.
    pub text_secondary: Color32,
    pub type_text: Color32,
    pub key_text: Color32,
    /// Low-contrast by default, so a dense schema stays readable.
    pub edge: Color32,
    /// A foreign key whose target this script never defines.
    pub edge_dangling: Color32,
}

impl Theme {
    pub fn light() -> Self {
        Self {
            background: Color32::from_rgb(0xf7, 0xf8, 0xfa),
            table_fill: Color32::WHITE,
            table_stroke: Color32::from_rgb(0xcf, 0xd6, 0xdf),
            header_fill: Color32::from_rgb(0xe8, 0xed, 0xf4),
            header_text: Color32::from_rgb(0x14, 0x1a, 0x22),
            column_text: Color32::from_rgb(0x2c, 0x35, 0x42),
            text_secondary: Color32::from_rgb(0x5b, 0x67, 0x76),
            type_text: Color32::from_rgb(0x7a, 0x86, 0x96),
            key_text: Color32::from_rgb(0xa2, 0x6e, 0x1a),
            edge: Color32::from_rgb(0x9a, 0xa6, 0xb6),
            edge_dangling: Color32::from_rgb(0xc2, 0x6a, 0x6a),
        }
    }

    pub fn dark() -> Self {
        Self {
            background: Color32::from_rgb(0x15, 0x18, 0x1d),
            table_fill: Color32::from_rgb(0x1e, 0x23, 0x2b),
            table_stroke: Color32::from_rgb(0x38, 0x40, 0x4c),
            header_fill: Color32::from_rgb(0x2a, 0x31, 0x3b),
            header_text: Color32::from_rgb(0xec, 0xf0, 0xf5),
            column_text: Color32::from_rgb(0xc4, 0xcc, 0xd6),
            text_secondary: Color32::from_rgb(0x98, 0xa3, 0xb0),
            type_text: Color32::from_rgb(0x78, 0x84, 0x93),
            key_text: Color32::from_rgb(0xd8, 0xa5, 0x50),
            edge: Color32::from_rgb(0x4e, 0x5a, 0x68),
            edge_dangling: Color32::from_rgb(0x9c, 0x55, 0x55),
        }
    }
}

/// Colours for the SQL editor, one per [`draft_ddl::Token`].
///
/// Here rather than in the application so that "light" and "dark" are decided
/// in one file. A diagram whose boxes and whose source text disagree about
/// which theme is in force looks broken in a way nobody can quite name.
#[derive(Clone, Copy, Debug)]
pub struct Syntax {
    pub plain: Color32,
    pub keyword: Color32,
    pub ty: Color32,
    pub literal: Color32,
    pub quoted: Color32,
    pub comment: Color32,
    pub number: Color32,
    pub punct: Color32,
    /// Behind the editor pane.
    pub background: Color32,
}

impl Syntax {
    pub fn light() -> Self {
        Self {
            plain: Color32::from_rgb(0x1c, 0x22, 0x2b),
            keyword: Color32::from_rgb(0x1a, 0x5f, 0xb4),
            ty: Color32::from_rgb(0x1d, 0x7a, 0x53),
            literal: Color32::from_rgb(0xa8, 0x52, 0x1c),
            quoted: Color32::from_rgb(0x6b, 0x3f, 0xa0),
            comment: Color32::from_rgb(0x8a, 0x95, 0xa3),
            number: Color32::from_rgb(0x9a, 0x6a, 0x00),
            punct: Color32::from_rgb(0x64, 0x70, 0x7f),
            background: Color32::WHITE,
        }
    }

    pub fn dark() -> Self {
        Self {
            plain: Color32::from_rgb(0xc4, 0xcc, 0xd6),
            keyword: Color32::from_rgb(0x5a, 0xa7, 0xff),
            ty: Color32::from_rgb(0x7d, 0xd3, 0xa0),
            literal: Color32::from_rgb(0xe5, 0xa0, 0x6b),
            quoted: Color32::from_rgb(0xc0, 0x9c, 0xf0),
            comment: Color32::from_rgb(0x6f, 0x7b, 0x8a),
            number: Color32::from_rgb(0xf5, 0xc4, 0x51),
            punct: Color32::from_rgb(0x8a, 0x95, 0xa3),
            background: Color32::from_rgb(0x1a, 0x1e, 0x25),
        }
    }

    pub fn of(&self, token: draft_ddl::Token) -> Color32 {
        use draft_ddl::Token;
        match token {
            Token::Plain => self.plain,
            Token::Keyword => self.keyword,
            Token::Type => self.ty,
            Token::Literal => self.literal,
            Token::Quoted => self.quoted,
            Token::Comment => self.comment,
            Token::Number => self.number,
            Token::Punct => self.punct,
        }
    }
}

/// What a point inside a table box refers to.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Hit {
    /// The table's own name.
    Header,
    ColumnName(usize),
    ColumnType(usize),
}

/// Where the type column starts, as a fraction of the box width.
///
/// A guess, and unavoidably so: names are left-aligned and types right-aligned,
/// and where they actually meet depends on a galley this function has no fonts
/// to build. Erring towards the name is deliberate — renaming a column is the
/// common edit, and a mis-aimed click that opens the name is recoverable in a
/// way that one which rewrites the type is not.
const TYPE_ZONE: f32 = 0.62;

/// What is at `at`, measured from the table box's top-left in world units.
///
/// Here rather than in the application for the same reason as [`Sizes`]: the
/// row heights, the header height and the badge column are this module's facts,
/// and a hit test that disagreed with the drawing by one row would rename the
/// wrong column.
pub fn hit_test(table: &Table, size: Size, at: Vec2) -> Option<Hit> {
    if at.x < 0.0 || at.y < 0.0 || at.x > size.w || at.y > size.h {
        return None;
    }
    if at.y < HEADER_H {
        return Some(Hit::Header);
    }
    let row = ((at.y - HEADER_H) / ROW_H) as usize;
    if row >= table.columns.len() {
        return None;
    }
    let split = size.w * TYPE_ZONE;
    if at.x >= split && at.x <= size.w - PAD_X - BADGE_W && !table.columns[row].ty.is_empty() {
        Some(Hit::ColumnType(row))
    } else {
        Some(Hit::ColumnName(row))
    }
}

/// The box to put an inline editor in, in table-local world units.
pub fn hit_rect(size: Size, hit: Hit) -> Rect {
    let (top, height) = match hit {
        Hit::Header => (0.0, HEADER_H),
        Hit::ColumnName(row) | Hit::ColumnType(row) => (HEADER_H + ROW_H * row as f32, ROW_H),
    };
    let (left, right) = match hit {
        Hit::Header | Hit::ColumnName(_) => (PAD_X, size.w * TYPE_ZONE),
        Hit::ColumnType(_) => (size.w * TYPE_ZONE, size.w - PAD_X - BADGE_W),
    };
    Rect::from_min_max(Pos2::new(left, top), Pos2::new(right, top + height))
}

/// Measure every table, in [`Schema::tables`] order, ready to hand to
/// [`draft_layout::layout`].
///
/// For a one-shot render — the CLI, an export. A live editor re-parses on every
/// pause in typing and should use [`Sizes`] instead.
pub fn measure(schema: &Schema, fonts: &mut FontsView<'_>, styles: &TextStyles) -> Vec<Size> {
    schema
        .tables
        .iter()
        .map(|t| measure_table(t, fonts, styles))
        .collect()
}

/// Table sizes, reused across re-parses.
///
/// A keystroke changes one table, but a re-parse produces a whole new [`Schema`]
/// with no relationship to the previous one, so measuring is otherwise a galley
/// per table name, column name and column type, every time. On a 106 KB schema
/// in a browser that is 7.9 ms — a third of everything the debounced re-parse
/// is allowed to spend. See docs/measurements.md, Phase 3.
///
/// The key is what actually determines a size, which is why it lives here
/// rather than in the caller: only this module knows that the flag badges are
/// fixed-width and so a `PRIMARY KEY` appearing changes nothing.
#[derive(Default)]
pub struct Sizes {
    cache: HashMap<u64, Size>,
    /// What the cached widths were produced *by*, rather than *from*.
    witness: u64,
}

impl Sizes {
    pub fn measure(
        &mut self,
        schema: &Schema,
        fonts: &mut FontsView<'_>,
        styles: &TextStyles,
    ) -> Vec<Size> {
        let witness = witness(fonts, styles);
        if witness != self.witness {
            self.witness = witness;
            self.cache.clear();
        }

        // Rebuilt rather than pruned: a table deleted ten keystrokes ago must
        // not keep its entry alive for the rest of the session, and "the tables
        // that exist now" is the only bound that holds without bookkeeping.
        let mut fresh = HashMap::with_capacity(schema.tables.len());
        let sizes = schema
            .tables
            .iter()
            .map(|table| {
                let key = size_key(table);
                let size = match self.cache.get(&key) {
                    Some(size) => *size,
                    None => measure_table(table, fonts, styles),
                };
                fresh.insert(key, size);
                size
            })
            .collect();
        self.cache = fresh;
        sizes
    }
}

/// Everything about a table that changes its box.
fn size_key(table: &Table) -> u64 {
    use std::hash::{Hash as _, Hasher as _};
    let mut h = std::collections::hash_map::DefaultHasher::new();
    table.name.hash(&mut h);
    for column in &table.columns {
        column.name.hash(&mut h);
        column.ty.hash(&mut h);
        // Not cosmetic: a nullable name is drawn in a different colour, and a
        // colour change is a different galley.
        column.not_null.hash(&mut h);
    }
    for index in &table.indexes {
        index.name.hash(&mut h);
        index.columns.hash(&mut h);
    }
    h.finish()
}

/// A witness for everything the cache depends on and cannot inspect: the font
/// set, the styles, and the pixels-per-point the fonts were built at — epaint
/// rounds glyph advances to physical pixels, and [`FontsView`] does not expose
/// which it is using. One galley per re-parse buys the guarantee that dragging
/// the window to a different display cannot leave stale widths behind.
fn witness(fonts: &mut FontsView<'_>, styles: &TextStyles) -> u64 {
    // The Han character is load-bearing, not decoration: the CJK face arrives
    // mid-session (see [`fonts`]) and changes no Latin width at all, so a
    // Latin-only probe would hand back widths measured against a font that is
    // no longer the one drawing. It is the cheapest possible question — one
    // glyph — that the lazy face can answer differently.
    const PROBE: &str = "MWiq01_ 漢";
    let mut bits = 0u64;
    for font in [&styles.header, &styles.name, &styles.ty, &styles.badge] {
        let width = width_of(fonts, PROBE, font);
        bits = bits
            .wrapping_mul(31)
            .wrapping_add(u64::from(width.to_bits()));
    }
    bits
}

fn measure_table(table: &Table, fonts: &mut FontsView<'_>, styles: &TextStyles) -> Size {
    let mut measure = Measure::table(width_of(fonts, &table.name, &styles.header));
    for column in &table.columns {
        measure.column(
            width_of(fonts, &column.name, &styles.name),
            width_of(fonts, &column.ty, &styles.ty),
        );
    }
    for index in &table.indexes {
        let (left, right) = index_row(index);
        measure.index(
            width_of(fonts, &left, &styles.ty),
            width_of(fonts, &right, &styles.ty),
        );
    }
    measure.size()
}

fn width_of(fonts: &mut FontsView<'_>, text: &str, font: &FontId) -> f32 {
    if text.is_empty() {
        return 0.0;
    }
    fonts
        .layout_no_wrap(text.to_owned(), font.clone(), Color32::PLACEHOLDER)
        .rect
        .width()
}

/// A galley that elides rather than overflowing. Table boxes are capped at
/// [`MAX_W`], so long type names have to give way somewhere; an ellipsis inside
/// the box is better than text spilling across a neighbour.
fn elided(
    fonts: &mut FontsView<'_>,
    text: &str,
    font: &FontId,
    color: Color32,
    max_width: f32,
) -> Arc<Galley> {
    let mut job = LayoutJob::simple(text.to_owned(), font.clone(), color, max_width.max(1.0));
    job.wrap.max_rows = 1;
    job.wrap.break_anywhere = true;
    job.wrap.overflow_character = Some('…');
    fonts.layout_job(job)
}

/// Build every shape in the diagram, back to front.
///
/// `scale` multiplies every dimension, for the same reason as in
/// [`table_shapes`]: a 2x raster export has to lay its text out at 2x, because
/// scaling the shapes afterwards would only magnify the glyphs' bitmaps.
pub fn shapes(
    schema: &Schema,
    layout: &Layout,
    theme: &Theme,
    styles: &TextStyles,
    scale: f32,
    fonts: &mut FontsView<'_>,
) -> Vec<Shape> {
    let mut edges = Vec::with_capacity(schema.relations.len());
    relations(schema, layout, theme, &mut edges);
    // Edges first: they pass behind the boxes rather than over them. They carry
    // no text, so scaling the finished curve is exact.
    let grow = epaint::emath::TSTransform::from_scaling(scale);
    let mut shapes: Vec<Shape> = edges
        .into_iter()
        .map(|e| {
            let mut shape = e.shape;
            shape.transform(grow);
            shape
        })
        .collect();
    shapes.reserve(schema.tables.len() * 4);
    for (i, table) in schema.tables.iter().enumerate() {
        let Some(&rect) = layout.nodes.get(i) else {
            continue;
        };
        let size = Size {
            w: rect.w,
            h: rect.h,
        };
        for mut shape in table_shapes(table, size, Lod::Full, scale, theme, styles, fonts) {
            shape.translate(Vec2::new(rect.x, rect.y) * scale);
            shapes.push(shape);
        }
    }
    shapes
}

/// Just the relationship curves, in world space. Separate from the tables
/// because they are the one thing that cannot be cached per table: an edge
/// belongs to two of them.
pub fn relation_shapes(schema: &Schema, layout: &Layout, theme: &Theme) -> Vec<Edge> {
    let mut out = Vec::with_capacity(schema.relations.len());
    relations(schema, layout, theme, &mut out);
    out
}

/// One drawn relationship, and the tables it joins.
///
/// The endpoints travel with the shape because highlighting a table means
/// highlighting its edges, and recovering that from a bare `Shape` would mean
/// resolving every relation's names again on every frame of a hover.
pub struct Edge {
    pub shape: Shape,
    pub from: usize,
    /// `None` when the script never defines the referenced table.
    pub to: Option<usize>,
}

/// Metrics at a given scale. Everything a table box is made of is proportional,
/// so one multiplier covers the lot.
#[derive(Clone, Copy)]
struct Metrics {
    pad_x: f32,
    gap: f32,
    badge_w: f32,
    row_h: f32,
    header_h: f32,
    radius: u8,
}

impl Metrics {
    fn at(scale: f32) -> Self {
        Self {
            pad_x: PAD_X * scale,
            gap: GAP * scale,
            badge_w: BADGE_W * scale,
            row_h: ROW_H * scale,
            header_h: HEADER_H * scale,
            radius: (6.0 * scale).round().clamp(0.0, 255.0) as u8,
        }
    }
}

fn scaled(font: &FontId, scale: f32) -> FontId {
    FontId::new(font.size * scale, font.family.clone())
}

/// One table's shapes, in table-local coordinates with its top-left at the
/// origin.
///
/// Local rather than world space so the canvas can cache the result per table
/// and reuse it across pans — only the translation changes. The CLI translates
/// them once and is done. Either way there is exactly one description of what a
/// table looks like.
///
/// `scale` multiplies every dimension, `size` included. It exists because
/// glyphs are rasterised at the size they are laid out at: a galley built at
/// scale 1 and then magnified 4x on screen is a 4x-magnified bitmap. Building
/// at the scale the table will be drawn at — and drawing with a transform of
/// roughly 1 — keeps text sharp at any zoom. Geometry is self-similar under
/// this, so elision and wrapping decisions come out identical.
pub fn table_shapes(
    table: &Table,
    size: Size,
    lod: Lod,
    scale: f32,
    theme: &Theme,
    styles: &TextStyles,
    fonts: &mut FontsView<'_>,
) -> Vec<Shape> {
    let m = Metrics::at(scale);
    let mut out = Vec::new();
    let rect = Rect::from_min_size(Pos2::ZERO, Vec2::new(size.w, size.h) * scale);
    let radius = CornerRadius::same(m.radius);

    if lod == Lod::Block {
        out.push(Shape::Rect(epaint::RectShape::new(
            rect,
            radius,
            theme.header_fill,
            Stroke::new(scale, theme.table_stroke),
            StrokeKind::Inside,
        )));
        return out;
    }
    let out = &mut out;
    out.push(Shape::Rect(epaint::RectShape::new(
        rect,
        radius,
        theme.table_fill,
        Stroke::new(scale, theme.table_stroke),
        StrokeKind::Inside,
    )));

    let header = Rect::from_min_size(rect.min, Vec2::new(rect.width(), m.header_h));
    out.push(Shape::Rect(epaint::RectShape::filled(
        header,
        radius,
        theme.header_fill,
    )));
    // Square off the bottom of the header so it meets the first row cleanly.
    out.push(Shape::rect_filled(
        Rect::from_min_max(
            Pos2::new(header.min.x, header.max.y - f32::from(radius.nw)),
            header.max,
        ),
        0,
        theme.header_fill,
    ));

    let name = elided(
        fonts,
        &table.name,
        &scaled(&styles.header, scale),
        theme.header_text,
        rect.width() - m.pad_x * 2.0,
    );
    out.push(Shape::galley(
        Pos2::new(
            rect.min.x + m.pad_x,
            header.center().y - name.rect.height() / 2.0,
        ),
        name,
        theme.header_text,
    ));

    if lod == Lod::Header {
        return std::mem::take(out);
    }

    for (i, column) in table.columns.iter().enumerate() {
        let top = rect.min.y + m.header_h + m.row_h * i as f32;
        let mid = top + m.row_h / 2.0;
        let mark = badge(column);
        let badge_space = if mark.is_some() { m.badge_w } else { 0.0 };

        // A nullable column is drawn a shade back from a required one. No
        // marker, no extra column: the diagram is read at a glance and at a
        // glance a row of asterisks is noise, while "this one is fainter" is
        // legible without being told. What exactly the script says about the
        // column — its default, its comment, its `CHECK` — is on hover, where
        // there is room for the answer in the script's own words.
        let name_colour = if column.not_null {
            theme.column_text
        } else {
            theme.text_secondary
        };
        let name_max = rect.width() - m.pad_x * 2.0 - badge_space;
        let name = elided(
            fonts,
            &column.name,
            &scaled(&styles.name, scale),
            name_colour,
            name_max,
        );
        let name_w = name.rect.width();
        out.push(Shape::galley(
            Pos2::new(rect.min.x + m.pad_x, mid - name.rect.height() / 2.0),
            name,
            name_colour,
        ));

        if !column.ty.is_empty() {
            let room = rect.width() - m.pad_x * 2.0 - badge_space - name_w - m.gap;
            if room > 12.0 * scale {
                let ty = elided(
                    fonts,
                    &column.ty,
                    &scaled(&styles.ty, scale),
                    theme.type_text,
                    room,
                );
                let right = rect.max.x - m.pad_x - badge_space;
                out.push(Shape::galley(
                    Pos2::new(right - ty.rect.width(), mid - ty.rect.height() / 2.0),
                    ty,
                    theme.type_text,
                ));
            }
        }

        if let Some(mark) = mark {
            let g = elided(
                fonts,
                mark,
                &scaled(&styles.badge, scale),
                theme.key_text,
                m.badge_w,
            );
            out.push(Shape::galley(
                Pos2::new(
                    rect.max.x - m.pad_x - g.rect.width(),
                    mid - g.rect.height() / 2.0,
                ),
                g,
                theme.key_text,
            ));
        }
    }

    indexes(table, rect, &m, scale, theme, styles, fonts, out);
    std::mem::take(out)
}

/// The index rows, under a rule, under the columns.
///
/// Drawn at all because an index is half of why a schema behaves the way it
/// does, and a viewer that silently drops every `CREATE INDEX` is hiding
/// something the script says out loud. Drawn *quietly* — smaller rows, dimmer
/// text — because it is not what the reader came for.
#[expect(
    clippy::too_many_arguments,
    reason = "the same arguments table_shapes takes"
)]
fn indexes(
    table: &Table,
    rect: Rect,
    m: &Metrics,
    scale: f32,
    theme: &Theme,
    styles: &TextStyles,
    fonts: &mut FontsView<'_>,
    out: &mut Vec<Shape>,
) {
    if table.indexes.is_empty() {
        return;
    }
    let columns_h = m.header_h + m.row_h * table.columns.len() as f32;
    let top = rect.min.y + columns_h + INDEX_SEP * scale / 2.0;
    out.push(Shape::line_segment(
        [
            Pos2::new(rect.min.x + m.pad_x, top),
            Pos2::new(rect.max.x - m.pad_x, top),
        ],
        Stroke::new(scale, theme.table_stroke),
    ));

    let font = scaled(&styles.ty, scale);
    let row_h = INDEX_H * scale;
    for (i, index) in table.indexes.iter().enumerate() {
        let mid = rect.min.y + columns_h + INDEX_SEP * scale + row_h * (i as f32 + 0.5);
        let (left, right) = index_row(index);

        let badge = if index.unique { "UQ" } else { "IX" };
        let g = elided(
            fonts,
            badge,
            &scaled(&styles.badge, scale),
            theme.key_text,
            m.badge_w,
        );
        out.push(Shape::galley(
            Pos2::new(
                rect.max.x - m.pad_x - g.rect.width(),
                mid - g.rect.height() / 2.0,
            ),
            g,
            theme.key_text,
        ));

        let name = elided(
            fonts,
            &left,
            &font,
            theme.text_secondary,
            rect.width() - m.pad_x * 2.0 - m.badge_w,
        );
        let name_w = name.rect.width();
        out.push(Shape::galley(
            Pos2::new(rect.min.x + m.pad_x, mid - name.rect.height() / 2.0),
            name,
            theme.text_secondary,
        ));

        if right.is_empty() {
            continue;
        }
        let room = rect.width() - m.pad_x * 2.0 - m.badge_w - name_w - m.gap;
        if room > 12.0 * scale {
            let cols = elided(fonts, &right, &font, theme.type_text, room);
            out.push(Shape::galley(
                Pos2::new(
                    rect.max.x - m.pad_x - m.badge_w - cols.rect.width(),
                    mid - cols.rect.height() / 2.0,
                ),
                cols,
                theme.type_text,
            ));
        }
    }
}

fn pos(p: geom::Pos) -> Pos2 {
    Pos2::new(p.x, p.y)
}

fn relations(schema: &Schema, layout: &Layout, theme: &Theme, out: &mut Vec<Edge>) {
    for relation in &schema.relations {
        let Some(from_i) = schema.index_of(&relation.from_table) else {
            continue;
        };
        let (Some(&from_rect), Some(from_table)) =
            (layout.nodes.get(from_i), schema.tables.get(from_i))
        else {
            continue;
        };
        let from_y = geom::anchor_y(from_table, from_rect, relation.from_cols.first());

        let target = match schema.index_of(&relation.to_table) {
            // A name the script never declares as a table still gets a stub,
            // but a table the layout has no node for cannot be routed at all.
            Some(to_i) => {
                let (Some(&rect), Some(table)) = (layout.nodes.get(to_i), schema.tables.get(to_i))
                else {
                    continue;
                };
                Some((
                    to_i,
                    rect,
                    geom::anchor_y(table, rect, relation.to_cols.first()),
                ))
            }
            None => None,
        };

        let route = geom::route(
            from_rect,
            from_y,
            target.map(|(_, rect, y)| (rect, y)),
            relation.cardinality,
        );
        let stroke = Stroke::new(
            1.2,
            if target.is_some() {
                theme.edge
            } else {
                theme.edge_dangling
            },
        );
        let mut shapes = vec![match route.path {
            geom::Path::Curve(points) => Shape::CubicBezier(epaint::CubicBezierShape {
                points: points.map(pos),
                closed: false,
                fill: Color32::TRANSPARENT,
                stroke: stroke.into(),
            }),
            geom::Path::Stub([a, b]) => Shape::line_segment([pos(a), pos(b)], stroke),
        }];
        for marks in [Some(route.start), route.end].into_iter().flatten() {
            shapes.extend(
                marks
                    .segments()
                    .iter()
                    .map(|&[a, b]| Shape::line_segment([pos(a), pos(b)], stroke)),
            );
        }

        out.push(Edge {
            shape: Shape::Vec(shapes),
            from: from_i,
            to: target.map(|(to_i, _, _)| to_i),
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use epaint::text::Fonts;
    use epaint::text::TextOptions;

    /// Measuring with the faces that ship, rather than with epaint's bundled
    /// set: a width measured against a font nothing draws with is not a
    /// measurement, and this is the same call every binary makes.
    fn fonts() -> Fonts {
        Fonts::new(
            TextOptions {
                max_texture_side: 2048,
                ..Default::default()
            },
            fonts::definitions(),
        )
    }

    fn widths(sql: &str) -> Vec<Size> {
        let schema = draft_ddl::parse(sql);
        let mut f = fonts();
        measure(
            &schema,
            &mut f.with_pixels_per_point(1.0),
            &TextStyles::default(),
        )
    }

    /// The cache must be invisible: same input, same answer, every time, and
    /// the same answer the uncached path gives. A measurement cache that is
    /// merely fast is a bug generator.
    #[test]
    fn cached_measurement_agrees_with_measuring_from_scratch() {
        const A: &str = "CREATE TABLE customers (id bigint, email text);\n\
                         CREATE TABLE orders (id bigint, placed_at timestamptz);\n";
        // One column renamed to something much longer, in the first table only.
        const B: &str = "CREATE TABLE customers (id bigint, email_address_for_receipts text);\n\
                         CREATE TABLE orders (id bigint, placed_at timestamptz);\n";

        let mut f = fonts();
        let styles = TextStyles::default();
        let mut sizes = Sizes::default();

        let first = sizes.measure(
            &draft_ddl::parse(A),
            &mut f.with_pixels_per_point(1.0),
            &styles,
        );
        assert_eq!(first, widths(A));
        let again = sizes.measure(
            &draft_ddl::parse(A),
            &mut f.with_pixels_per_point(1.0),
            &styles,
        );
        assert_eq!(again, first, "the same schema measured differently twice");

        let edited = sizes.measure(
            &draft_ddl::parse(B),
            &mut f.with_pixels_per_point(1.0),
            &styles,
        );
        assert_eq!(edited, widths(B));
        assert!(
            edited[0].w > first[0].w,
            "the edited table kept a stale width: {} then {}",
            first[0].w,
            edited[0].w
        );
        assert_eq!(
            edited[1], first[1],
            "an untouched table was re-measured to a different size"
        );
    }

    /// The CJK face is registered halfway through a session, and a table whose
    /// name was boxes is suddenly full of glyphs that are twice as wide. The
    /// cache has to notice — otherwise every Chinese table keeps the box width
    /// it was measured at and the text spills straight out of it.
    #[test]
    fn the_cache_notices_a_face_arriving_mid_session() {
        const SQL: &str = "CREATE TABLE 訂單 (id bigint, 客戶編號 bigint);";

        let styles = TextStyles::default();
        let mut sizes = Sizes::default();

        let mut latin = fonts();
        let before = sizes.measure(
            &draft_ddl::parse(SQL),
            &mut latin.with_pixels_per_point(1.0),
            &styles,
        );

        let mut with_cjk = fonts::definitions();
        fonts::add_cjk(&mut with_cjk, fonts::CJK_BYTES.to_vec());
        let mut installed = Fonts::new(
            TextOptions {
                max_texture_side: 2048,
                ..Default::default()
            },
            with_cjk,
        );
        let after = sizes.measure(
            &draft_ddl::parse(SQL),
            &mut installed.with_pixels_per_point(1.0),
            &styles,
        );

        assert!(
            after[0].w > before[0].w,
            "the table kept the width it had while its name was unprintable: \
             {} then {}",
            before[0].w,
            after[0].w
        );
    }

    /// The whole point is that an unchanged table is not measured again, and
    /// "it is fast" is not a testable claim. Poison a cached entry: if the
    /// poison comes back, the entry was reused rather than recomputed.
    #[test]
    fn an_unchanged_table_is_not_measured_again() {
        const SQL: &str = "CREATE TABLE a (id bigint);\nCREATE TABLE b (id bigint);\n";
        let mut f = fonts();
        let styles = TextStyles::default();
        let mut sizes = Sizes::default();
        let schema = draft_ddl::parse(SQL);

        sizes.measure(&schema, &mut f.with_pixels_per_point(1.0), &styles);
        assert_eq!(sizes.cache.len(), 2);

        let key = size_key(&schema.tables[1]);
        sizes.cache.insert(key, Size { w: 999.0, h: 999.0 });
        let again = sizes.measure(&schema, &mut f.with_pixels_per_point(1.0), &styles);
        assert_eq!(again[1], Size { w: 999.0, h: 999.0 });
    }

    /// A hit test that disagreed with the drawing by one row would rename the
    /// wrong column — silently, in someone's schema file. Walked row by row
    /// rather than spot-checked, because an off-by-one is exactly the bug that
    /// survives a spot check.
    #[test]
    fn every_row_hit_tests_to_itself() {
        let schema =
            draft_ddl::parse("CREATE TABLE t (a bigint, b text, c varchar(32), d timestamptz);");
        let table = &schema.tables[0];
        let size = widths("CREATE TABLE t (a bigint, b text, c varchar(32), d timestamptz);")[0];

        assert_eq!(
            hit_test(table, size, Vec2::new(20.0, 4.0)),
            Some(Hit::Header)
        );
        for row in 0..table.columns.len() {
            let mid = HEADER_H + ROW_H * row as f32 + ROW_H / 2.0;
            assert_eq!(
                hit_test(table, size, Vec2::new(PAD_X + 2.0, mid)),
                Some(Hit::ColumnName(row)),
                "name of row {row}"
            );
            assert_eq!(
                hit_test(table, size, Vec2::new(size.w - PAD_X - BADGE_W - 2.0, mid)),
                Some(Hit::ColumnType(row)),
                "type of row {row}"
            );
        }

        // Below the last row, and outside the box entirely.
        let past = HEADER_H + ROW_H * table.columns.len() as f32 + 2.0;
        assert_eq!(hit_test(table, size, Vec2::new(20.0, past)), None);
        assert_eq!(hit_test(table, size, Vec2::new(-1.0, 10.0)), None);
        assert_eq!(hit_test(table, size, Vec2::new(size.w + 1.0, 10.0)), None);
    }

    /// The editor has to open over the text it is editing, or it reads as a
    /// dialog that appeared from nowhere.
    #[test]
    fn the_editor_box_sits_on_the_row_it_edits() {
        let size = Size { w: 240.0, h: 200.0 };
        let name = hit_rect(size, Hit::ColumnName(2));
        let ty = hit_rect(size, Hit::ColumnType(2));
        assert_eq!(name.min.y, HEADER_H + ROW_H * 2.0);
        assert_eq!(name.height(), ROW_H);
        assert_eq!(
            name.max.x, ty.min.x,
            "the two halves must not overlap or gap"
        );
        assert!(ty.max.x < size.w, "the badge column must stay clickable");
        assert_eq!(hit_rect(size, Hit::Header).min.y, 0.0);
    }

    /// A long editing session deletes tables. Their entries must go with them,
    /// or the cache is a leak that grows with every keystroke.
    #[test]
    fn deleted_tables_do_not_keep_their_entries() {
        let mut f = fonts();
        let styles = TextStyles::default();
        let mut sizes = Sizes::default();

        for n in (1..=6).rev() {
            let sql: String = (0..n)
                .map(|i| format!("CREATE TABLE t{i} (id bigint);\n"))
                .collect();
            sizes.measure(
                &draft_ddl::parse(&sql),
                &mut f.with_pixels_per_point(1.0),
                &styles,
            );
            assert_eq!(sizes.cache.len(), n, "cache did not shrink with the schema");
        }
    }

    #[test]
    fn a_table_is_at_least_the_minimum_width_and_grows_with_its_columns() {
        let sizes = widths(
            "CREATE TABLE t (id int);
             CREATE TABLE wider (customer_reference int);
             CREATE TABLE widest (customer_reference_number int);",
        );
        assert_eq!(
            sizes[0].w, MIN_W,
            "a narrow table should sit at the minimum"
        );
        assert_eq!(sizes[0].h, HEADER_H + ROW_H);
        assert!(
            sizes[1].w > MIN_W,
            "a long column must widen the table, got {}",
            sizes[1].w
        );
        assert!(
            sizes[2].w > sizes[1].w,
            "a longer column must widen it further"
        );
        assert!(
            sizes.iter().all(|s| s.w <= MAX_W),
            "a table escaped the width cap"
        );
    }

    /// The width cap is only useful if something actually hits it.
    #[test]
    fn an_unreasonably_long_name_is_capped_not_honoured() {
        let name = "x".repeat(400);
        let sizes = widths(&format!("CREATE TABLE t ({name} int);"));
        assert_eq!(sizes[0].w, MAX_W);
    }

    #[test]
    fn height_is_exactly_the_header_plus_its_rows() {
        let schema = draft_ddl::parse("CREATE TABLE t (a int, b int, c int, d int);");
        let mut f = fonts();
        let sizes = measure(
            &schema,
            &mut f.with_pixels_per_point(1.0),
            &TextStyles::default(),
        );
        assert_eq!(sizes[0].h, HEADER_H + ROW_H * 4.0);
    }

    #[test]
    fn every_table_and_relation_produces_shapes() {
        let schema = draft_ddl::parse(
            "CREATE TABLE a (id int PRIMARY KEY);
             CREATE TABLE b (id int PRIMARY KEY, a_id int REFERENCES a(id));
             CREATE TABLE c (id int, missing_id int REFERENCES nowhere(id));",
        );
        let mut f = fonts();
        let styles = TextStyles::default();
        let sizes = measure(&schema, &mut f.with_pixels_per_point(1.0), &styles);
        let placed = draft_layout::layout(&schema, &sizes, &Default::default());
        let shapes = shapes(
            &schema,
            &placed,
            &Theme::light(),
            &styles,
            1.0,
            &mut f.with_pixels_per_point(1.0),
        );

        // An edge is a curve and its cardinality marks, grouped, so the count
        // has to look inside the group. `Shape::Vec` is not a problem for
        // anything downstream: the tessellator walks it and so does the SVG
        // writer.
        let flat = flatten(&shapes);
        let rects = flat.iter().filter(|s| matches!(s, Shape::Rect(_))).count();
        assert!(
            rects >= schema.tables.len() * 2,
            "every table needs a body and a header"
        );
        assert_eq!(
            flat.iter()
                .filter(|s| matches!(s, Shape::CubicBezier(_)))
                .count(),
            1,
            "one resolvable relation, one curve"
        );
        let lines = flat
            .iter()
            .filter(|s| matches!(s, Shape::LineSegment { .. }))
            .count();
        assert_eq!(
            lines, 6,
            "the resolved edge carries a crow's foot and a bar (3 segments) \
             and the dangling one a stub and a crow's foot (3 more)"
        );
    }

    fn flatten(shapes: &[Shape]) -> Vec<Shape> {
        shapes
            .iter()
            .flat_map(|s| match s {
                Shape::Vec(inner) => flatten(inner),
                other => vec![other.clone()],
            })
            .collect()
    }

    /// The canvas relies on this: it builds a table at the scale it is about to
    /// be drawn at, so the only thing left for the per-frame transform to do is
    /// translate. If scaling were not proportional, zooming would reflow text.
    #[test]
    fn building_at_a_higher_scale_is_the_same_table_twice_as_big() {
        let schema = draft_ddl::parse(
            "CREATE TABLE orders (id int PRIMARY KEY, customer_reference varchar(64));",
        );
        let table = &schema.tables[0];
        let mut f = fonts();
        let styles = TextStyles::default();
        let size = measure(&schema, &mut f.with_pixels_per_point(1.0), &styles)[0];

        let one = table_shapes(
            table,
            size,
            Lod::Full,
            1.0,
            &Theme::light(),
            &styles,
            &mut f.with_pixels_per_point(1.0),
        );
        let two = table_shapes(
            table,
            size,
            Lod::Full,
            2.0,
            &Theme::light(),
            &styles,
            &mut f.with_pixels_per_point(1.0),
        );

        assert_eq!(
            one.len(),
            two.len(),
            "the same table should produce the same shapes at any scale"
        );
        let bounds = |v: &[Shape]| {
            v.iter()
                .fold(Rect::NOTHING, |acc, s| acc.union(s.visual_bounding_rect()))
        };
        let (a, b) = (bounds(&one), bounds(&two));
        assert!(
            (b.width() / a.width() - 2.0).abs() < 0.05,
            "width {} vs {}",
            a.width(),
            b.width()
        );
        assert!(
            (b.height() / a.height() - 2.0).abs() < 0.05,
            "height {} vs {}",
            a.height(),
            b.height()
        );
    }

    #[test]
    fn an_empty_schema_draws_nothing_rather_than_panicking() {
        let schema = draft_ddl::parse("-- nothing here\n");
        let mut f = fonts();
        let styles = TextStyles::default();
        let sizes = measure(&schema, &mut f.with_pixels_per_point(1.0), &styles);
        let placed = draft_layout::layout(&schema, &sizes, &Default::default());
        assert!(
            shapes(
                &schema,
                &placed,
                &Theme::dark(),
                &styles,
                1.0,
                &mut f.with_pixels_per_point(1.0)
            )
            .is_empty()
        );
    }
}
