//! Which faces this project draws with, and when a second one is needed.
//!
//! Two Latin faces are registered up front and are the whole of the shipped
//! payload's font cost (267 K brotli of it). Everything else — a schema with
//! Chinese table names, a comment written in Japanese — needs a CJK face, and
//! the CJK face is 16.4 MB. So it is not shipped: it is registered the moment
//! the text on screen turns out to need it, and never at all for the Latin
//! schemas that are the large majority. See docs/architecture.md D4 and
//! docs/risks.md R3.
//!
//! Pan-CJK rather than a regional subset, which was measured rather than
//! assumed: `NotoSansTC-Regular` is 5.4 MB and draws 訂單 but not 订单, so a
//! simplified schema would still be half boxes. One file that always works
//! beats three files and a rule for choosing between them.
//!
//! **The one thing to know about the lazy face**: registering a font rebuilds
//! epaint's atlas *and* invalidates every width measured before it. The
//! measurement cache notices by itself — [`crate::Sizes`]'s witness string
//! contains a Han character, so the cache it keyed with a Latin-only font
//! cannot be mistaken for one keyed with the CJK face present.

use epaint::text::{FontData, FontDefinitions, FontFamily};

/// The face registered lazily, named so a second registration can be
/// recognised as a no-op.
pub const CJK: &str = "cjk";

/// The CJK face, compiled in.
///
/// Not for wasm: 16.4 MB is eight times the entire web payload budget, and the
/// browser fetches the same file from our own origin instead. The desktop and
/// the CLI have no origin to fetch from and must work offline, so there the
/// bytes travel in the binary.
#[cfg(not(target_arch = "wasm32"))]
pub const CJK_BYTES: &[u8] = include_bytes!("../assets/NotoSansCJKtc-Regular.otf");

/// The file name the web build fetches, which is also what `trunk` copies into
/// `dist/` — one name, declared once, so the two cannot drift apart.
pub const CJK_FILE: &str = "NotoSansCJKtc-Regular.otf";

/// The faces every target starts with.
///
/// Not `FontDefinitions::default()`: that pulls in epaint's bundled set, most
/// of which is two emoji faces worth 400 K that nothing here draws.
pub fn definitions() -> FontDefinitions {
    use std::sync::Arc;

    let mut fonts = FontDefinitions::empty();
    fonts.font_data.insert(
        "ui".to_owned(),
        Arc::new(FontData::from_static(epaint_default_fonts::UBUNTU_LIGHT)),
    );
    fonts.font_data.insert(
        "mono".to_owned(),
        Arc::new(FontData::from_static(epaint_default_fonts::HACK_REGULAR)),
    );
    // Each family falls back to the other, so a glyph missing from one is still
    // drawn rather than becoming a box.
    fonts.families.insert(
        FontFamily::Proportional,
        vec!["ui".to_owned(), "mono".to_owned()],
    );
    fonts.families.insert(
        FontFamily::Monospace,
        vec!["mono".to_owned(), "ui".to_owned()],
    );
    fonts
}

/// Add the CJK face as the last fallback of both families.
///
/// Last, not first: the Latin faces are what the UI is designed in, and this
/// face carries Latin glyphs of its own that would otherwise silently take
/// over every label in the application.
pub fn add_cjk(fonts: &mut FontDefinitions, bytes: Vec<u8>) {
    use std::sync::Arc;

    fonts
        .font_data
        .insert(CJK.to_owned(), Arc::new(FontData::from_owned(bytes)));
    for family in [FontFamily::Proportional, FontFamily::Monospace] {
        if let Some(list) = fonts.families.get_mut(&family) {
            list.push(CJK.to_owned());
        }
    }
}

/// Does this text contain something the Latin faces cannot draw?
///
/// Asked of the whole SQL, not of the identifiers: a comment in Chinese is
/// drawn in the editor pane and would be a wall of boxes there just as surely.
///
/// The ranges are the ones the lazy face answers for — Han, kana, Hangul,
/// Bopomofo and the CJK punctuation and fullwidth forms that come with them. A
/// schema written in Thai or Arabic is *not* reported here, because fetching
/// this face would not draw it either; that is a known gap rather than a silent
/// one. Plane 2 is the one range listed without being covered: a name using it
/// is nearly certain to use ordinary Han as well, and fetching for the rest of
/// the text is the better failure.
pub fn needs_cjk(text: &str) -> bool {
    text.chars().any(|c| {
        matches!(c as u32,
            0x1100..=0x11FF     // Hangul Jamo
            | 0x2E80..=0x2EFF   // CJK radicals supplement
            | 0x3000..=0x303F   // CJK symbols and punctuation
            | 0x3040..=0x30FF   // Hiragana, Katakana
            | 0x3100..=0x312F   // Bopomofo
            | 0x3130..=0x318F   // Hangul compatibility jamo
            | 0x31A0..=0x31BF   // Bopomofo extended
            | 0x3400..=0x4DBF   // CJK extension A
            | 0x4E00..=0x9FFF   // CJK unified ideographs
            | 0xAC00..=0xD7AF   // Hangul syllables
            | 0xF900..=0xFAFF   // CJK compatibility ideographs
            | 0xFF00..=0xFFEF   // Halfwidth and fullwidth forms
            | 0x20000..=0x2FA1F // CJK extensions B and beyond
        )
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The trigger decides whether 16.4 MB is fetched, so both answers matter:
    /// a false negative is a screen full of boxes, a false positive is a
    /// download nobody needed.
    #[test]
    fn the_trigger_fires_on_what_the_face_answers_for_and_nothing_else() {
        assert!(!needs_cjk("CREATE TABLE customers (id bigserial);"));
        assert!(!needs_cjk("-- naïve, Grüße, Привет, Ελλάδα"));
        assert!(!needs_cjk(""));

        assert!(needs_cjk("CREATE TABLE 訂單 (id int);"), "Han");
        assert!(needs_cjk("-- 発注のテーブル"), "kana");
        assert!(needs_cjk("-- 주문 테이블"), "Hangul");
        assert!(needs_cjk("-- 一張表，兩個索引。"), "CJK punctuation");
        assert!(needs_cjk("CREATE TABLE 𠀀 (id int);"), "beyond the BMP");
    }

    /// Registering the face must not change what the UI's own text is drawn
    /// with: the CJK face carries Latin glyphs too, and if it won the lookup
    /// every button in the application would change shape the moment somebody
    /// pasted a Chinese schema.
    #[test]
    fn the_latin_faces_stay_in_front() {
        let mut fonts = definitions();
        add_cjk(&mut fonts, CJK_BYTES.to_vec());

        for family in [FontFamily::Proportional, FontFamily::Monospace] {
            let list = &fonts.families[&family];
            assert_eq!(
                list.last().map(String::as_str),
                Some(CJK),
                "{family:?} does not have the lazy face last"
            );
            assert!(list.len() == 3, "{family:?}: {list:?}");
        }
    }

    /// The whole point, asserted against the real font file: before it is
    /// registered these glyphs cannot be drawn, and after it they can. If the
    /// file were the wrong format or the wrong subset, this is where it shows.
    #[test]
    fn the_face_draws_what_the_latin_faces_cannot() {
        use epaint::text::{FontId, Fonts, TextOptions};

        let options = TextOptions {
            max_texture_side: 8192,
            ..Default::default()
        };
        let id = FontId::new(14.0, FontFamily::Proportional);

        let mut latin = Fonts::new(options, definitions());
        let mut view = latin.with_pixels_per_point(1.0);
        assert!(view.has_glyphs(&id, "customers"));
        assert!(!view.has_glyphs(&id, "訂單"), "Han in a Latin-only build");

        let mut with_cjk = definitions();
        add_cjk(&mut with_cjk, CJK_BYTES.to_vec());
        let mut fonts = Fonts::new(options, with_cjk);
        let mut view = fonts.with_pixels_per_point(1.0);
        assert!(view.has_glyphs(&id, "訂單 客戶 發票"), "Traditional Han");
        assert!(view.has_glyphs(&id, "订单 客户 数据库"), "Simplified Han");
        assert!(view.has_glyphs(&id, "発注 請求書 テーブル"), "Japanese");
        assert!(view.has_glyphs(&id, "주문 테이블"), "Korean");
        assert!(view.has_glyphs(&id, "，。「」ＡＢ ㄅㄆ"), "the punctuation");
        assert!(view.has_glyphs(&id, "customers"), "Latin still resolves");

        // The one thing this face does not answer for, recorded so nobody has
        // to rediscover it: plane 2 is not in any Noto Sans CJK weight. A name
        // written in 𠀀 still boxes, and a regional subset would not have
        // helped — the character is simply not there.
        assert!(!view.has_glyphs(&id, "𠀀"), "CJK extension B");
    }
}
