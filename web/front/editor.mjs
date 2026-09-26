// The SQL pane: a real `<textarea>` with the colours painted behind it.
//
// This is the whole reason the front end exists in the shape it does
// ([D23](../../docs/architecture.md#d23--the-dom-front-end-has-no-framework-and-the-state-stays-in-the-wasm)).
// A canvas has to reimplement text editing, and egui's `TextEdit` relayouts the
// entire document on every keystroke
// ([R2](../../docs/risks.md#r2--egui-textedit-relayouts-the-entire-document)),
// which is what
// [Phase 3a](../../docs/roadmap.md#phase-3a--virtualised-editor--not-in-the-plan-with-a-trigger)
// is held in reserve for. A `<textarea>` brings selection, copy, undo, IME and
// the accessibility tree from the platform, for nothing.
//
// Two things make that work:
//
// 1. **The colours are a layer, not the text.** The textarea's own glyphs are
//    transparent; a `<pre>` under it holds the same characters in colour. They
//    stay aligned because they are the same font at the same size with the same
//    padding, and because neither wraps.
// 2. **Only what is on screen is painted.** The wasm is asked for the visible
//    *lines*, so a keystroke costs the same in a 400 KB script as in a 4 KB one
//    — this is the virtualisation Phase 3a describes, arrived at by having the
//    platform do the scrolling.
//
// The textarea is *below* the colour layer in paint order, which is the
// opposite of the usual arrangement and deliberate. A selection highlight and
// an IME composition are both filled rectangles painted with the textarea, so
// with the textarea on top they cover the coloured glyphs: composing a CJK word
// produces a solid yellow block with nothing legible in it. index.html holds
// the order and says so; this is the only thing about the arrangement that is
// not obvious from either file on its own.

import { highlight_lines } from "./draft_front.js";

export function editor({ area, ink, onSettle, debounce }) {
  // From the stylesheet rather than repeated here: the line height is what maps
  // a scroll offset to a line number, and a copy of it that drifted from the CSS
  // would slide the colours off the glyphs a line at a time.
  const style = getComputedStyle(area);
  const lineHeight = Number.parseFloat(style.lineHeight);
  if (!Number.isFinite(lineHeight)) {
    throw new Error("the editor needs an explicit line-height in px");
  }

  let timer = null;
  /// The cost of the last paint, for the typing gate.
  let painted = 0;
  /// Which lines the ink currently holds, for the gate to check the colours
  /// against the characters they are supposed to be over.
  let shown = { first: 0, count: 0 };

  function paint() {
    const started = performance.now();
    // One line of slack above and below, so a partially scrolled line is still
    // coloured and the seam is never on screen.
    const first = Math.max(0, Math.floor(area.scrollTop / lineHeight) - 1);
    const count = Math.ceil(area.clientHeight / lineHeight) + 3;
    const runs = highlight_lines(area.value, first, count);
    shown = { first, count };

    const batch = document.createDocumentFragment();
    for (let i = 0; i < runs.length; i += 2) {
      const span = document.createElement("span");
      span.className = runs[i];
      span.textContent = runs[i + 1];
      batch.append(span);
    }
    ink.replaceChildren(batch);
    // The window starts at line `first`, so it is drawn `first` lines down and
    // then pulled up by however far the textarea has scrolled. Padding is not
    // in the sum: both layers have the same, and it moves with the content.
    ink.style.transform =
      `translate(${-area.scrollLeft}px, ${first * lineHeight - area.scrollTop}px)`;
    painted = performance.now() - started;
  }

  function schedule() {
    clearTimeout(timer);
    timer = setTimeout(() => {
      timer = null;
      onSettle(area.value);
    }, debounce);
  }

  area.addEventListener("input", () => {
    paint();
    // The diagram waits. Re-parsing and re-laying out on every keystroke is the
    // one thing that cannot be afforded, and the debounce is the canvas build's
    // own (`crates/app/src/editor.rs`).
    schedule();
  });
  // Scroll events already arrive at most once a frame, and a paint is bounded
  // by the viewport, so there is nothing here worth coalescing.
  area.addEventListener("scroll", paint);

  return {
    get text() {
      return area.value;
    },
    /// Load a script without waiting for the debounce: the caller is telling
    /// us what the document is, not typing into it.
    setText(value) {
      clearTimeout(timer);
      timer = null;
      area.value = value;
      area.scrollTop = 0;
      area.scrollLeft = 0;
      paint();
    },
    /// What the last keystroke cost us, in milliseconds. The gate's number.
    get lastPaint() {
      return painted;
    },
    /// The lines the ink layer holds.
    get window() {
      return shown;
    },
    paint,
  };
}
