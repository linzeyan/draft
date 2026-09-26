//! PNG and WebP output, rasterised from the same shapes the SVG is written
//! from.
//!
//! There is no GPU here and no second description of what a diagram looks like.
//! `epaint`'s tessellator turns the shapes into triangles — the identical
//! triangles the application's renderer is handed — and this walks them into a
//! buffer. Antialiasing comes with them: epaint feathers its edges with extra
//! geometry rather than relying on multisampling, so a software rasteriser gets
//! the same smooth edges the screen does.
//!
//! The alternative was to read the pixels back from the window, which would cap
//! an export at whatever is on screen, at whatever zoom, at whatever size the
//! window happens to be. A diagram is worth more than a screenshot of one.

use epaint::text::FontsView;
use epaint::{Color32, ColorImage, Mesh, Shape, Tessellator, Vec2, Vertex};

/// Render shapes to a PNG, one unit per pixel.
pub fn png(
    shapes: &[Shape],
    size: Vec2,
    background: Color32,
    margin: f32,
    fonts: &mut FontsView<'_>,
) -> Result<Vec<u8>, String> {
    let buffer = raster(shapes, size, background, margin, fonts)?;
    let mut out = Vec::new();
    let mut encoder = png::Encoder::new(&mut out, buffer.w as u32, buffer.h as u32);
    encoder.set_color(png::ColorType::Rgba);
    encoder.set_depth(png::BitDepth::Eight);
    encoder
        .write_header()
        .and_then(|mut w| w.write_image_data(&buffer.pixels))
        .map_err(|e| format!("writing PNG: {e}"))?;
    Ok(out)
}

/// The same image as a lossless WebP.
///
/// Lossless for the same reason the export is not a screenshot: a diagram is
/// text and flat fills, and the chroma subsampling in lossy WebP puts coloured
/// fringes on exactly that. Flat fills are also what VP8L compresses best, so
/// the lossless file is normally the smaller of the two formats as well — which
/// is the whole reason to offer it beside PNG rather than instead of it.
pub fn webp(
    shapes: &[Shape],
    size: Vec2,
    background: Color32,
    margin: f32,
    fonts: &mut FontsView<'_>,
) -> Result<Vec<u8>, String> {
    let buffer = raster(shapes, size, background, margin, fonts)?;
    let mut out = Vec::new();
    image_webp::WebPEncoder::new(&mut out)
        .encode(
            &buffer.pixels,
            buffer.w as u32,
            buffer.h as u32,
            image_webp::ColorType::Rgba8,
        )
        .map_err(|e| format!("writing WebP: {e}"))?;
    Ok(out)
}

/// Shapes to pixels. The two formats differ only in what encodes the result,
/// and a second rasteriser would be a second answer to the question of what
/// this diagram looks like.
///
/// Deliberately *not* given a scale factor. Glyphs are rasterised at the size
/// they are laid out at, so a 2x export is shapes built at scale 2 — the same
/// rule the canvas follows when you zoom in. Scaling here instead would magnify
/// the font atlas and produce a blurry image that looked like a bug in this
/// file.
fn raster(
    shapes: &[Shape],
    size: Vec2,
    background: Color32,
    margin: f32,
    fonts: &mut FontsView<'_>,
) -> Result<Buffer, String> {
    let canvas = size + Vec2::splat(margin * 2.0);
    let (w, h) = (canvas.x.round() as usize, canvas.y.round() as usize);
    if w == 0 || h == 0 {
        return Err("nothing to export: the diagram has no area".to_owned());
    }
    // Four bytes a pixel here, and a second buffer inside the encoder. A wide
    // schema at 2x reaches this quickly, and the failure mode of finding out by
    // allocating is a browser tab that simply dies.
    const LIMIT: usize = 64_000_000;
    if w * h > LIMIT {
        return Err(format!(
            "the diagram is {w} x {h} pixels, which is more than an image can \
             usefully be — export SVG instead"
        ));
    }

    let atlas = fonts.image();
    let mut buffer = Buffer::new(w, h, background);
    // One unit per pixel, so epaint's feathering — which it sizes in pixels —
    // comes out exactly one pixel wide, as it does on screen.
    let mut tessellator = Tessellator::new(
        1.0,
        epaint::TessellationOptions::default(),
        fonts.font_image_size(),
        Vec::new(),
    );

    let mut mesh = Mesh::default();
    for shape in shapes {
        let mut shape = shape.clone();
        shape.translate(Vec2::splat(margin));
        tessellator.tessellate_shape(shape, &mut mesh);
        // Drawn and cleared per shape rather than accumulated: one mesh for a
        // whole diagram is hundreds of megabytes of vertices before a single
        // pixel has been written.
        buffer.draw(&mesh, &atlas);
        mesh.clear();
    }
    Ok(buffer)
}

struct Buffer {
    w: usize,
    h: usize,
    /// Straight — not premultiplied — RGBA, which is what PNG stores.
    pixels: Vec<u8>,
}

impl Buffer {
    fn new(w: usize, h: usize, background: Color32) -> Self {
        let [r, g, b, a] = background.to_srgba_unmultiplied();
        Self {
            w,
            h,
            pixels: [r, g, b, a].repeat(w * h),
        }
    }

    fn draw(&mut self, mesh: &Mesh, atlas: &ColorImage) {
        for triangle in mesh.indices.chunks_exact(3) {
            let Some(v) = triangle
                .iter()
                .map(|&i| mesh.vertices.get(i as usize))
                .collect::<Option<Vec<_>>>()
            else {
                continue;
            };
            self.triangle([v[0], v[1], v[2]], atlas);
        }
    }

    /// One triangle, sampled once per pixel centre.
    ///
    /// No supersampling: epaint has already turned every antialiased edge into
    /// geometry carrying a colour ramp, so sampling at the centre reproduces
    /// that ramp. Supersampling on top would only blur it.
    fn triangle(&mut self, v: [&Vertex; 3], atlas: &ColorImage) {
        let (a, b, c) = (v[0].pos, v[1].pos, v[2].pos);
        let area = (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y);
        if area.abs() < 1e-6 || !area.is_finite() {
            return;
        }
        let x0 = a.x.min(b.x).min(c.x).floor().max(0.0) as usize;
        let y0 = a.y.min(b.y).min(c.y).floor().max(0.0) as usize;
        let x1 = (a.x.max(b.x).max(c.x).ceil().max(0.0) as usize + 1).min(self.w);
        let y1 = (a.y.max(b.y).max(c.y).ceil().max(0.0) as usize + 1).min(self.h);

        for y in y0..y1 {
            for x in x0..x1 {
                let px = x as f32 + 0.5;
                let py = y as f32 + 0.5;
                // Barycentric weights, named for the vertex each belongs to.
                let wb = ((px - a.x) * (c.y - a.y) - (c.x - a.x) * (py - a.y)) / area;
                let wc = ((b.x - a.x) * (py - a.y) - (px - a.x) * (b.y - a.y)) / area;
                let wa = 1.0 - wb - wc;
                if wa < 0.0 || wb < 0.0 || wc < 0.0 {
                    continue;
                }
                let weights = [wa, wb, wc];
                let colour = mix(v, weights);
                let uv = [
                    v[0].uv.x * wa + v[1].uv.x * wb + v[2].uv.x * wc,
                    v[0].uv.y * wa + v[1].uv.y * wb + v[2].uv.y * wc,
                ];
                // The same product the renderer's fragment shader computes:
                // the vertex colour times the texel. Solid shapes point at the
                // atlas's opaque white texel, so they come through unchanged;
                // a glyph's texel is white with the coverage in its alpha.
                let texel = sample(atlas, uv);
                self.put(
                    x,
                    y,
                    [
                        colour[0] * texel[0],
                        colour[1] * texel[1],
                        colour[2] * texel[2],
                    ],
                    colour[3] * texel[3],
                );
            }
        }
    }

    /// Source-over, in sRGB space.
    ///
    /// The GPU blends in linear space. Matching it would mean two conversions
    /// per pixel for a difference visible only on the one-pixel antialiased
    /// fringe of a shape, and an export is wanted for its geometry.
    fn put(&mut self, x: usize, y: usize, rgb: [f32; 3], alpha: f32) {
        if alpha <= 0.0 {
            return;
        }
        let i = (y * self.w + x) * 4;
        let dst_a = f32::from(self.pixels[i + 3]) / 255.0;
        let out_a = alpha + dst_a * (1.0 - alpha);
        if out_a <= 0.0 {
            return;
        }
        for (channel, src) in rgb.iter().enumerate() {
            let dst = f32::from(self.pixels[i + channel]) / 255.0;
            let mixed = (src * alpha + dst * dst_a * (1.0 - alpha)) / out_a;
            self.pixels[i + channel] = (mixed.clamp(0.0, 1.0) * 255.0).round() as u8;
        }
        self.pixels[i + 3] = (out_a.clamp(0.0, 1.0) * 255.0).round() as u8;
    }
}

/// Interpolate three vertex colours, un-premultiplied.
///
/// `Color32` is premultiplied, so a fully transparent vertex carries no hue at
/// all. Interpolating in that form drags every feathered edge towards black.
fn mix(v: [&Vertex; 3], weights: [f32; 3]) -> [f32; 4] {
    let mut out = [0.0; 4];
    for (vertex, weight) in v.iter().zip(weights) {
        let straight = vertex.color.to_srgba_unmultiplied();
        for (channel, value) in straight.iter().enumerate() {
            out[channel] += f32::from(*value) / 255.0 * weight;
        }
    }
    out
}

/// Sample the font atlas at normalised coordinates, bilinearly.
///
/// Bilinear rather than nearest because a 2x export lands between texels, and
/// nearest sampling there is visibly blocky at exactly the size an export is
/// looked at.
fn sample(atlas: &ColorImage, uv: [f32; 2]) -> [f32; 4] {
    let [w, h] = atlas.size;
    if w == 0 || h == 0 || atlas.pixels.len() < w * h {
        return [1.0; 4];
    }
    let x = (uv[0] * w as f32 - 0.5).clamp(0.0, (w - 1) as f32);
    let y = (uv[1] * h as f32 - 0.5).clamp(0.0, (h - 1) as f32);
    let (x0, y0) = (x.floor() as usize, y.floor() as usize);
    let (x1, y1) = ((x0 + 1).min(w - 1), (y0 + 1).min(h - 1));
    let (fx, fy) = (x - x0 as f32, y - y0 as f32);

    let mut out = [0.0; 4];
    for (tx, ty, weight) in [
        (x0, y0, (1.0 - fx) * (1.0 - fy)),
        (x1, y0, fx * (1.0 - fy)),
        (x0, y1, (1.0 - fx) * fy),
        (x1, y1, fx * fy),
    ] {
        let straight = atlas.pixels[ty * w + tx].to_srgba_unmultiplied();
        for (channel, value) in straight.iter().enumerate() {
            out[channel] += f32::from(*value) / 255.0 * weight;
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use epaint::text::{Fonts, TextOptions};
    use epaint::{CornerRadius, Pos2, Rect, Stroke, StrokeKind};

    fn fonts() -> Fonts {
        Fonts::new(
            TextOptions {
                max_texture_side: 2048,
                ..Default::default()
            },
            draft_view::fonts::definitions(),
        )
    }

    /// Decode back to (width, height, pixels), because a PNG that no decoder
    /// will read is not an export.
    fn decode(bytes: &[u8]) -> (usize, usize, Vec<u8>) {
        let decoder = png::Decoder::new(std::io::Cursor::new(bytes));
        let mut reader = decoder.read_info().expect("a PNG we just wrote");
        let mut buffer = vec![0; reader.output_buffer_size().expect("a bounded image")];
        let info = reader.next_frame(&mut buffer).expect("one frame");
        buffer.truncate(info.buffer_size());
        (info.width as usize, info.height as usize, buffer)
    }

    fn pixel(w: usize, pixels: &[u8], x: usize, y: usize) -> [u8; 4] {
        let i = (y * w + x) * 4;
        [pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3]]
    }

    /// The rasteriser at its simplest: a filled rectangle has to come out the
    /// colour it was asked for, inside its own edges, on the background
    /// everywhere else. Everything more elaborate is this plus interpolation.
    #[test]
    fn a_filled_rectangle_lands_where_it_was_put() {
        let mut f = fonts();
        let red = Color32::from_rgb(0xd0, 0x20, 0x30);
        let shape = Shape::Rect(epaint::RectShape::new(
            Rect::from_min_size(Pos2::new(10.0, 10.0), Vec2::new(40.0, 20.0)),
            CornerRadius::ZERO,
            red,
            Stroke::NONE,
            StrokeKind::Inside,
        ));
        let bytes = png(
            &[shape],
            Vec2::new(60.0, 40.0),
            Color32::WHITE,
            0.0,
            &mut f.with_pixels_per_point(1.0),
        )
        .expect("a diagram with area");

        let (w, h, pixels) = decode(&bytes);
        assert_eq!((w, h), (60, 40));
        assert_eq!(pixel(w, &pixels, 30, 20), [0xd0, 0x20, 0x30, 0xff]);
        assert_eq!(
            pixel(w, &pixels, 55, 35),
            [0xff, 0xff, 0xff, 0xff],
            "the background should show where nothing was drawn"
        );
    }

    /// Antialiasing is not decoration here: it is the evidence that epaint's
    /// feathered geometry survived the trip, colour ramp and all. A rasteriser
    /// that dropped the feathering would produce a hard edge and pass every
    /// other assertion in this file.
    #[test]
    fn an_edge_is_antialiased_rather_than_stepped() {
        let mut f = fonts();
        let shape = Shape::Circle(epaint::CircleShape::filled(
            Pos2::new(30.0, 30.0),
            20.0,
            Color32::BLACK,
        ));
        let bytes = png(
            &[shape],
            Vec2::new(60.0, 60.0),
            Color32::WHITE,
            0.0,
            &mut f.with_pixels_per_point(1.0),
        )
        .expect("a diagram with area");

        let (w, h, pixels) = decode(&bytes);
        // Counted over the whole image rather than along one scanline. At the
        // circle's leftmost point the edge is vertical and the one-pixel ramp
        // falls almost exactly between two pixel centres — a real property of
        // the geometry, and one that makes a single-row check prove nothing.
        let partial = (0..w * h)
            .map(|i| pixels[i * 4])
            .filter(|r| (16..=239).contains(r))
            .count();
        assert!(
            partial > 40,
            "only {partial} partly covered pixels around a 126-pixel perimeter: \
             the feathered geometry was dropped"
        );
    }

    /// The reason this file exists rather than a screenshot: text has to be
    /// rasterised from the font atlas, which is the one thing a triangle
    /// rasteriser can get wrong while everything else still looks right.
    #[test]
    fn text_is_drawn_from_the_atlas_and_not_as_blank_quads() {
        let mut f = fonts();
        let bytes = {
            let mut view = f.with_pixels_per_point(1.0);
            let galley = view.layout_no_wrap(
                "Hamburgefonstiv".to_owned(),
                epaint::FontId::proportional(24.0),
                Color32::BLACK,
            );
            let size = galley.rect.size();
            png(
                &[Shape::galley(Pos2::ZERO, galley, Color32::BLACK)],
                size,
                Color32::WHITE,
                4.0,
                &mut view,
            )
            .expect("text has area")
        };

        let (w, h, pixels) = decode(&bytes);
        let dark = (0..w * h)
            .filter(|i| pixels[i * 4] < 0x40 && pixels[i * 4 + 3] == 0xff)
            .count();
        assert!(
            dark > 50,
            "only {dark} dark pixels in a {w}x{h} image: the glyphs came out blank"
        );
        assert!(
            dark < w * h / 2,
            "{dark} of {} pixels are dark: the glyph quads were filled solid",
            w * h
        );
    }

    /// WebP is offered as a smaller file, not as a different picture. If it
    /// ever stops decoding back to the exact pixels the PNG holds, "lossless"
    /// is a claim nobody is checking and the two menu items no longer agree.
    #[test]
    fn webp_decodes_back_to_the_pixels_the_png_has() {
        let mut f = fonts();
        let shapes = [
            Shape::Rect(epaint::RectShape::new(
                Rect::from_min_size(Pos2::new(6.0, 6.0), Vec2::new(30.0, 18.0)),
                CornerRadius::same(4),
                Color32::from_rgb(0x20, 0x70, 0xc0),
                Stroke::new(1.0, Color32::BLACK),
                StrokeKind::Inside,
            )),
            Shape::Circle(epaint::CircleShape::filled(
                Pos2::new(40.0, 30.0),
                9.0,
                Color32::from_rgb(0xd0, 0x20, 0x30),
            )),
        ];
        let size = Vec2::new(60.0, 40.0);
        let (from_png, from_webp) = {
            let mut view = f.with_pixels_per_point(1.0);
            (
                png(&shapes, size, Color32::WHITE, 2.0, &mut view).expect("a diagram with area"),
                webp(&shapes, size, Color32::WHITE, 2.0, &mut view).expect("a diagram with area"),
            )
        };

        let (w, h, expected) = decode(&from_png);
        let mut decoder = image_webp::WebPDecoder::new(std::io::Cursor::new(&from_webp))
            .expect("a WebP we wrote");
        assert_eq!(decoder.dimensions(), (w as u32, h as u32));
        assert!(decoder.has_alpha(), "the alpha channel was dropped");
        let mut actual = vec![0; decoder.output_buffer_size().expect("a bounded image")];
        decoder.read_image(&mut actual).expect("one frame");
        assert_eq!(actual, expected, "the two formats disagree about the image");
    }

    /// A diagram nobody can export is better than a tab that dies allocating.
    #[test]
    fn an_impossible_size_is_refused_with_a_reason() {
        let mut f = fonts();
        let err = png(
            &[],
            Vec2::new(100_000.0, 100_000.0),
            Color32::WHITE,
            0.0,
            &mut f.with_pixels_per_point(1.0),
        )
        .expect_err("ten gigapixels");
        assert!(
            err.contains("SVG"),
            "the message should say what to do: {err}"
        );

        assert!(
            png(
                &[],
                Vec2::ZERO,
                Color32::WHITE,
                0.0,
                &mut f.with_pixels_per_point(1.0)
            )
            .is_err(),
            "an empty diagram has no image in it"
        );
    }
}
