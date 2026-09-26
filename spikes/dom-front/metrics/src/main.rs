//! Spike S5b — do epaint and a browser measure the same string the same width?
//!
//! The other half of the DOM front end question. Table box widths come from
//! measured text, and layout comes from box widths, so whoever measures decides
//! the geometry. A DOM front end would let the *browser* measure — that is how
//! the wasm in `../core` gets to 123 K with no typefaces in it — and the price
//! of that is whatever this divergence turns out to be, because the CLI has no
//! browser and would go on measuring with epaint.
//!
//! Prints the epaint side as JSON. `compare.mjs` measures the same corpus in
//! Chrome against the same font files and reports the difference.
//!
//! Two pixels-per-point values are printed on purpose: epaint rounds each glyph
//! advance to a whole *physical* pixel, so its answer is a function of the
//! display it is laying out for, while `measureText` uses fractional advances.
//! If that rounding is the whole story, ppp=2 will sit closer to the browser
//! than ppp=1 does.

use epaint::text::{Fonts, TextOptions};
use epaint::{Color32, FontId};
use draft_view::TextStyles;

/// Identifiers and type names of the kind that actually decide a box's width,
/// plus the awkward cases: all-caps, digits, underscores, a long compound, and
/// CJK, which is where a fallback face gets involved.
const CORPUS: &[&str] = &[
    "id",
    "customer_id",
    "order_lines",
    "display_name",
    "TOTAL_CENTS",
    "varchar(255)",
    "timestamptz",
    "bigserial",
    "uq_category_slug",
    "idx_post_search",
    "iiiiiiiiiiii",
    "WWWWWWWWWWWW",
    "客戶編號",
    "注文明細",
];

fn main() {
    let styles = TextStyles::default();
    let named: [(&str, &FontId); 4] = [
        ("header", &styles.header),
        ("name", &styles.name),
        ("type", &styles.ty),
        ("badge", &styles.badge),
    ];

    // The same font set the application and the CLI measure with, CJK included:
    // the corpus asks about Han, and a missing face would measure boxes rather
    // than glyphs.
    let mut definitions = draft_view::fonts::definitions();
    draft_view::fonts::add_cjk(&mut definitions, draft_view::fonts::CJK_BYTES.to_vec());
    let mut fonts = Fonts::new(
        TextOptions {
            max_texture_side: 8192,
            ..Default::default()
        },
        definitions,
    );

    let mut rows: Vec<String> = Vec::new();
    for ppp in [1.0f32, 2.0] {
        let mut view = fonts.with_pixels_per_point(ppp);
        for (style, font) in named {
            for text in CORPUS {
                let width = view
                    .layout_no_wrap((*text).to_owned(), font.clone(), Color32::PLACEHOLDER)
                    .rect
                    .width();
                rows.push(format!(
                    "{{\"text\":{text:?},\"style\":\"{style}\",\"size\":{size},\
                     \"family\":\"{family}\",\"ppp\":{ppp},\"width\":{width}}}",
                    size = font.size,
                    family = match font.family {
                        epaint::FontFamily::Monospace => "mono",
                        _ => "ui",
                    },
                ));
            }
        }
    }
    println!("[{}]", rows.join(","));
}
