// Measuring text, which is the one thing only the browser can do here.
//
// The wasm has no typefaces in it (docs/architecture.md D19): every width the
// box arithmetic needs arrives from `measureText`. Stage a measured the result
// against the CLI's own epaint-measured SVG and found 0.0161 pt across nine
// boxes and eleven edges — so what this file must not do is measure with
// anything other than the two faces index.html loads.

/// The font each kind of text is measured and drawn in. The sizes are
/// `TextStyles::default()`'s, and the families are the two faces index.html
/// loads; style.css repeats them for drawing, because CSS cannot read this.
export const FONTS = {
  header: '14px "draft-ui"',
  name: '12.5px "draft-ui"',
  type: '11px "draft-mono"',
  badge: '9.5px "draft-ui"',
};

const ruler = document.createElement("canvas").getContext("2d");

/// Widths already asked for, per font. `measureText` is not free, and a settle
/// re-measures the whole schema: the 1,000-table fixture is some 17,000 strings,
/// of which a keystroke changed one.
///
/// epaint has the same cache and needs it for the same reason — it is why the
/// canvas build re-measures 396 KB in 0.60 ms instead of from scratch — so this
/// is the arrangement being mirrored, not a shortcut being taken.
const widths = new Map();
/// Every prefix of every identifier anybody types ends up in here, so it has to
/// have a lid on it. Far above a real schema's string count, and dropping the
/// whole table is the right response: the next settle refills what it needs and
/// nothing is wrong in the meantime.
const CACHE_LIMIT = 50_000;

/// One string's advance width, in points.
///
/// Empty text is zero rather than whatever the engine says about an empty
/// string, because that is what `width_of` does on the Rust side and a box
/// measured differently from the one the CLI draws is the one thing the
/// geometry gate is checking for.
export function width(text, font) {
  if (!text) return 0;
  let seen = widths.get(font);
  if (seen === undefined) {
    seen = new Map();
    widths.set(font, seen);
  }
  const hit = seen.get(text);
  if (hit !== undefined) return hit;
  ruler.font = font;
  const measured = ruler.measureText(text).width;
  if (seen.size >= CACHE_LIMIT) seen.clear();
  seen.set(text, measured);
  return measured;
}

/// The longest prefix of `text` that fits `max`, with an ellipsis when it had to
/// cut. The canvas build elides for the same reason: boxes are capped at
/// `maxW`, so a long type has to give way somewhere, and an ellipsis inside the
/// box beats text spilling across a neighbour.
export function elide(text, font, max) {
  if (width(text, font) <= max) return text;
  let lo = 0;
  let hi = text.length;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    if (width(`${text.slice(0, mid)}…`, font) <= max) lo = mid;
    else hi = mid - 1;
  }
  return lo === 0 ? "" : `${text.slice(0, lo)}…`;
}

/// Every string the wasm asked to be measured, in the order it asks for them:
/// per table the header, then a name and a type per column, then the two halves
/// of each index row. The structure is the schema's own, so neither side holds a
/// convention the other has to remember.
export function measureAll(schema) {
  const widths = [];
  for (const table of schema.tables) {
    widths.push(width(table.name, FONTS.header));
    for (const column of table.columns) {
      widths.push(width(column.name, FONTS.name), width(column.type, FONTS.type));
    }
    for (const index of table.indexes) {
      widths.push(width(index.left, FONTS.type), width(index.right, FONTS.type));
    }
  }
  return new Float32Array(widths);
}

/// Both faces, before anything is measured.
///
/// `measureText` answers with the fallback face while a web font is still
/// loading, and a box sized against the wrong outlines never gets corrected.
export function loadFonts() {
  return Promise.all(Object.values(FONTS).map((font) => document.fonts.load(font)));
}
