//! Share links: the whole project in the URL fragment, and nothing on a wire.
//!
//! The fragment is the one part of a URL a browser never transmits, so a link
//! that carries its payload there needs no backend, no database and no account,
//! and cannot leak a schema to us even by accident. That is the entire design.
//!
//! Deflate then base64url, in that order. Base64 costs a third more bytes, so
//! compressing afterwards would be compressing our own padding; a schema is
//! repetitive text and deflates to roughly a fifth of its size first.

/// Compress and encode a payload for a `#p1=` fragment.
pub fn encode(text: &str) -> String {
    // Level 9: this runs once per Share click on text measured in kilobytes,
    // and the result is pasted into places with length limits.
    let packed = miniz_oxide::deflate::compress_to_vec(text.as_bytes(), 9);
    base64url(&packed)
}

/// The inverse. `None` for anything that is not a payload this wrote — a
/// truncated link, a fragment that meant something else, a link from a build
/// that compressed differently.
pub fn decode(payload: &str) -> Option<String> {
    let packed = un_base64url(payload)?;
    // Bounded on purpose. The payload arrives from a URL somebody else wrote,
    // and an unbounded inflate is an invitation to expand 30 KB into a gigabyte.
    let raw = miniz_oxide::inflate::decompress_to_vec_with_limit(&packed, 16 << 20).ok()?;
    String::from_utf8(raw).ok()
}

const ALPHABET: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

/// Base64 in the URL-safe alphabet, unpadded.
///
/// Written out rather than taken from a crate: it is twenty lines, it is in the
/// payload of every page load, and the alternative is a dependency whose only
/// job is a table lookup.
fn base64url(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len().div_ceil(3) * 4);
    for chunk in bytes.chunks(3) {
        let b = [
            chunk[0],
            chunk.get(1).copied().unwrap_or(0),
            chunk.get(2).copied().unwrap_or(0),
        ];
        let n = u32::from(b[0]) << 16 | u32::from(b[1]) << 8 | u32::from(b[2]);
        // Three bytes are four characters; a short final chunk drops the
        // characters that would only encode the zeros we padded with.
        for i in 0..chunk.len() + 1 {
            out.push(ALPHABET[(n >> (18 - i * 6)) as usize & 0x3f] as char);
        }
    }
    out
}

fn un_base64url(text: &str) -> Option<Vec<u8>> {
    let mut out = Vec::with_capacity(text.len() / 4 * 3);
    for chunk in text.as_bytes().chunks(4) {
        if chunk.len() == 1 {
            // One character is six bits: not a whole byte, so the payload was
            // truncated rather than merely unpadded.
            return None;
        }
        let mut n = 0u32;
        for (i, c) in chunk.iter().enumerate() {
            n |= u32::from(digit(*c)?) << (18 - i * 6);
        }
        for i in 0..chunk.len() - 1 {
            out.push((n >> (16 - i * 8)) as u8);
        }
    }
    Some(out)
}

fn digit(c: u8) -> Option<u8> {
    match c {
        b'A'..=b'Z' => Some(c - b'A'),
        b'a'..=b'z' => Some(c - b'a' + 26),
        b'0'..=b'9' => Some(c - b'0' + 52),
        b'-' => Some(62),
        b'_' => Some(63),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The property the whole feature rests on: what goes in comes out, for
    /// every length — the ones that need padding are exactly where a hand-
    /// written base64 goes wrong.
    #[test]
    fn every_payload_length_round_trips() {
        for len in 0..200 {
            let text: String = (0..len)
                .map(|i| char::from(b'a' + (i % 26) as u8))
                .collect();
            assert_eq!(
                decode(&encode(&text)).as_deref(),
                Some(text.as_str()),
                "length {len} did not survive"
            );
        }
    }

    #[test]
    fn the_alphabet_is_safe_in_a_url() {
        let payload = encode(&(0..=255u8).map(char::from).collect::<String>());
        assert!(
            payload
                .bytes()
                .all(|c| c.is_ascii_alphanumeric() || c == b'-' || c == b'_'),
            "a share link must survive being pasted into a URL: {payload}"
        );
    }

    /// A schema is repetitive text. If compression were not buying anything the
    /// fragment would be a third *larger* than the SQL, and the feature would be
    /// worse than useless.
    #[test]
    fn a_schema_gets_smaller_not_larger() {
        let sql = crate::sample::DEFAULT.sql;
        let payload = encode(sql);
        assert!(
            payload.len() < sql.len() / 2,
            "{} bytes of SQL became a {} byte fragment",
            sql.len(),
            payload.len()
        );
    }

    /// Links get truncated by chat clients and mangled by mail readers. Every
    /// one of those has to come back as "this is not a project", not as a panic
    /// and not as a plausible-looking empty diagram.
    #[test]
    fn a_damaged_link_is_refused_rather_than_guessed_at() {
        let good = encode("CREATE TABLE t (id int);");
        assert!(decode(&good).is_some());

        assert_eq!(decode(&good[..good.len() - 4]), None, "truncated");
        assert_eq!(decode("not a payload!!"), None, "outside the alphabet");
        assert_eq!(decode("A"), None, "six bits is not a byte");
        assert_eq!(decode("AAAAAAAA"), None, "valid base64, not valid deflate");
    }
}
