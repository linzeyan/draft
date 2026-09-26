//! SVG output, written from the diagram's own [`epaint::Shape`]s.
//!
//! The shapes come from `draft-view`, unchanged — the same list the canvas
//! renders. Nothing here re-derives geometry, so an SVG cannot drift away from
//! what the app shows; a bug in one is a bug in both.
//!
//! Text is the one place SVG cannot simply be told what we measured, because
//! the viewer picks the font. Each run is emitted with the `textLength` we
//! measured, so a viewer without our font stretches the glyphs slightly instead
//! of overflowing the table box it sits in. Geometry wins over typography,
//! which for a diagram is the right way round.

mod raster;

pub use raster::{png, webp};

use std::fmt::Write as _;

use epaint::{Color32, FontFamily, Shape, Stroke, StrokeKind};

/// Render shapes to a standalone SVG document.
///
/// `size` is the diagram's own bounding box; `margin` is added on every side.
pub fn svg(shapes: &[Shape], size: epaint::Vec2, background: Color32, margin: f32) -> String {
    let (w, h) = (size.x + margin * 2.0, size.y + margin * 2.0);
    let mut out = String::with_capacity(shapes.len() * 128);

    let _ = writeln!(
        out,
        r#"<svg xmlns="http://www.w3.org/2000/svg" width="{}" height="{}" viewBox="0 0 {} {}">"#,
        n(w),
        n(h),
        n(w),
        n(h)
    );
    if background != Color32::TRANSPARENT {
        let _ = writeln!(
            out,
            r#"<rect width="{}" height="{}" fill="{}"/>"#,
            n(w),
            n(h),
            hex(background)
        );
    }
    let _ = writeln!(
        out,
        r#"<g transform="translate({},{})">"#,
        n(margin),
        n(margin)
    );
    for shape in shapes {
        write_shape(&mut out, shape);
    }
    out.push_str("</g>\n</svg>\n");
    out
}

fn write_shape(out: &mut String, shape: &Shape) {
    match shape {
        Shape::Rect(r) => {
            // SVG centres a stroke on the path; epaint can put it inside or
            // outside. Insetting keeps the drawn edge where the app draws it.
            let inset = match r.stroke_kind {
                StrokeKind::Inside => r.stroke.width / 2.0,
                StrokeKind::Outside => -r.stroke.width / 2.0,
                StrokeKind::Middle => 0.0,
            };
            let rect = r.rect.shrink(inset);
            let _ = write!(
                out,
                r#"<rect x="{}" y="{}" width="{}" height="{}""#,
                n(rect.min.x),
                n(rect.min.y),
                n(rect.width().max(0.0)),
                n(rect.height().max(0.0))
            );
            let radius = f32::from(r.corner_radius.nw);
            if radius > 0.0 {
                let _ = write!(out, r#" rx="{}""#, n(radius));
            }
            write_fill(out, r.fill);
            write_stroke(out, r.stroke);
            out.push_str("/>\n");
        }
        Shape::LineSegment { points, stroke } => {
            let _ = write!(
                out,
                r#"<line x1="{}" y1="{}" x2="{}" y2="{}" fill="none""#,
                n(points[0].x),
                n(points[0].y),
                n(points[1].x),
                n(points[1].y)
            );
            write_stroke(out, *stroke);
            out.push_str("/>\n");
        }
        Shape::CubicBezier(c) => {
            let p = c.points;
            let _ = write!(
                out,
                r#"<path d="M {} {} C {} {}, {} {}, {} {}""#,
                n(p[0].x),
                n(p[0].y),
                n(p[1].x),
                n(p[1].y),
                n(p[2].x),
                n(p[2].y),
                n(p[3].x),
                n(p[3].y)
            );
            write_fill(out, c.fill);
            // A path stroke may be a UV gradient rather than a colour. The
            // diagram emits none, and SVG would need a <linearGradient> per
            // shape to express one, so only solid strokes are written.
            if let epaint::ColorMode::Solid(color) = c.stroke.color {
                write_stroke(out, Stroke::new(c.stroke.width, color));
            }
            out.push_str("/>\n");
        }
        Shape::Circle(c) => {
            let _ = write!(
                out,
                r#"<circle cx="{}" cy="{}" r="{}""#,
                n(c.center.x),
                n(c.center.y),
                n(c.radius)
            );
            write_fill(out, c.fill);
            write_stroke(out, c.stroke);
            out.push_str("/>\n");
        }
        Shape::Text(t) => write_text(out, t),
        Shape::Vec(shapes) => shapes.iter().for_each(|s| write_shape(out, s)),
        // Meshes, callbacks and images have no SVG equivalent worth faking.
        // The diagram emits none of them; if one appears, dropping it is
        // better than emitting something that is not what the canvas shows.
        _ => {}
    }
}

fn write_text(out: &mut String, text: &epaint::TextShape) {
    let galley = &text.galley;
    // Every galley this crate is given comes from a single-format layout job,
    // so one section describes the whole run.
    let Some(section) = galley.job.sections.first() else {
        return;
    };
    let font = &section.format.font_id;
    let color = text
        .override_text_color
        .unwrap_or(match section.format.color {
            Color32::PLACEHOLDER => text.fallback_color,
            c => c,
        });

    for placed in &galley.rows {
        if placed.row.glyphs.is_empty() {
            continue;
        }
        let first = &placed.row.glyphs[0];
        let x = text.pos.x + placed.pos.x + first.pos.x;
        // `Glyph::pos` is the baseline, which is exactly what SVG `y` wants.
        let y = text.pos.y + placed.pos.y + first.pos.y;
        let advance: f32 = placed.row.glyphs.iter().map(|g| g.advance_width).sum();
        let content: String = placed.row.glyphs.iter().map(|g| g.chr).collect();

        let _ = write!(
            out,
            r#"<text x="{}" y="{}" font-family="{}" font-size="{}" fill="{}""#,
            n(x),
            n(y),
            family(&font.family),
            n(font.size),
            hex(color)
        );
        if color.a() < 255 {
            let _ = write!(
                out,
                r#" fill-opacity="{}""#,
                n(f32::from(color.a()) / 255.0)
            );
        }
        if placed.row.glyphs.len() > 1 {
            let _ = write!(
                out,
                r#" textLength="{}" lengthAdjust="spacingAndGlyphs""#,
                n(advance)
            );
        }
        let _ = writeln!(out, r#" xml:space="preserve">{}</text>"#, escape(&content));
    }
}

fn write_fill(out: &mut String, fill: Color32) {
    if fill == Color32::TRANSPARENT {
        out.push_str(r#" fill="none""#);
        return;
    }
    let _ = write!(out, r#" fill="{}""#, hex(fill));
    if fill.a() < 255 {
        let _ = write!(out, r#" fill-opacity="{}""#, n(f32::from(fill.a()) / 255.0));
    }
}

fn write_stroke(out: &mut String, stroke: Stroke) {
    if stroke.width <= 0.0 || stroke.color == Color32::TRANSPARENT {
        return;
    }
    let _ = write!(
        out,
        r#" stroke="{}" stroke-width="{}""#,
        hex(stroke.color),
        n(stroke.width)
    );
    if stroke.color.a() < 255 {
        let _ = write!(
            out,
            r#" stroke-opacity="{}""#,
            n(f32::from(stroke.color.a()) / 255.0)
        );
    }
}

/// A CSS stack rather than one name: the SVG may be opened anywhere, and
/// `textLength` keeps the geometry right whichever face the viewer picks.
fn family(family: &FontFamily) -> &'static str {
    match family {
        FontFamily::Monospace => "ui-monospace, Menlo, Consolas, monospace",
        _ => "system-ui, -apple-system, Segoe UI, Helvetica, Arial, sans-serif",
    }
}

fn hex(color: Color32) -> String {
    let [r, g, b, _] = color.to_srgba_unmultiplied();
    format!("#{r:02x}{g:02x}{b:02x}")
}

/// Two decimals is under a tenth of a pixel at any sane zoom, and keeps the
/// file from tripling in size for precision nobody can see.
fn n(value: f32) -> String {
    let rounded = (value * 100.0).round() / 100.0;
    let mut s = format!("{rounded:.2}");
    if s.contains('.') {
        s = s.trim_end_matches('0').trim_end_matches('.').to_owned();
    }
    if s == "-0" { "0".to_owned() } else { s }
}

fn escape(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    for c in text.chars() {
        match c {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            '\'' => out.push_str("&apos;"),
            _ => out.push(c),
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use epaint::text::{Fonts, TextOptions};
    use epaint::{Rect, Vec2};

    fn diagram(sql: &str) -> (Vec<Shape>, Vec2) {
        let schema = draft_ddl::parse(sql);
        let mut fonts = Fonts::new(
            TextOptions {
                max_texture_side: 2048,
                ..Default::default()
            },
            draft_view::fonts::definitions(),
        );
        let styles = draft_view::TextStyles::default();
        let sizes = draft_view::measure(&schema, &mut fonts.with_pixels_per_point(1.0), &styles);
        let placed = draft_layout::layout(&schema, &sizes, &Default::default());
        let shapes = draft_view::shapes(
            &schema,
            &placed,
            &draft_view::Theme::light(),
            &styles,
            1.0,
            &mut fonts.with_pixels_per_point(1.0),
        );
        (shapes, Vec2::new(placed.size.w, placed.size.h))
    }

    #[test]
    fn numbers_are_short_without_being_wrong() {
        assert_eq!(n(0.0), "0");
        assert_eq!(n(-0.001), "0");
        assert_eq!(n(12.0), "12");
        assert_eq!(n(12.5), "12.5");
        assert_eq!(n(12.345), "12.35");
        assert_eq!(n(-3.20), "-3.2");
    }

    #[test]
    fn markup_in_identifiers_cannot_escape_into_the_document() {
        assert_eq!(escape("a<b & c\"d'"), "a&lt;b &amp; c&quot;d&apos;");
    }

    #[test]
    fn an_empty_diagram_is_still_a_valid_document() {
        let out = svg(&[], Vec2::ZERO, Color32::WHITE, 24.0);
        assert!(out.starts_with("<svg "));
        assert!(out.trim_end().ends_with("</svg>"));
        assert!(
            out.contains(r#"width="48""#),
            "margin should still take space"
        );
    }

    #[test]
    fn a_real_schema_produces_every_element_the_diagram_needs() {
        let (shapes, size) = diagram(
            "CREATE TABLE users (id int PRIMARY KEY, email varchar(255) UNIQUE);
             CREATE TABLE orders (id int PRIMARY KEY, user_id int REFERENCES users(id));",
        );
        let out = svg(&shapes, size, Color32::WHITE, 24.0);

        assert!(out.contains("<rect"), "tables are rectangles");
        assert!(out.contains("<path d=\"M "), "the relation is a curve");
        assert!(out.contains(">users<"), "table names are in the document");
        assert!(out.contains(">email<"), "column names are in the document");
        assert!(out.contains(">PK<"), "key badges are in the document");
        assert!(
            out.contains("textLength="),
            "text carries the width we measured"
        );

        // Tags must be balanced, or the file will not open.
        assert_eq!(out.matches("<svg").count(), 1);
        assert_eq!(out.matches("<text").count(), out.matches("</text>").count());
        assert!(
            !out.contains("NaN") && !out.contains("inf"),
            "a non-finite coordinate escaped"
        );
    }

    /// The SVG has to contain the diagram, not a crop of it.
    #[test]
    fn every_shape_lands_inside_the_declared_canvas() {
        let (shapes, size) = diagram(
            "CREATE TABLE a (id int PRIMARY KEY);
             CREATE TABLE b (id int, a_id int REFERENCES a(id));
             CREATE TABLE loose (x int);",
        );
        let bounds = shapes
            .iter()
            .fold(Rect::NOTHING, |acc, s| acc.union(s.visual_bounding_rect()));
        assert!(
            bounds.min.x >= -0.5 && bounds.min.y >= -0.5,
            "content starts before the origin"
        );
        assert!(
            bounds.max.x <= size.x + 0.5 && bounds.max.y <= size.y + 0.5,
            "content {bounds:?} runs past the canvas {size:?}"
        );
        assert!(
            bounds.width() > 100.0 && bounds.height() > 50.0,
            "the diagram is suspiciously empty"
        );
    }
}
