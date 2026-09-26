// The mapping between diagram coordinates and the screen.
//
// This is the one part of the front end that is deliberately *not* in the wasm.
// [D23](../../docs/architecture.md#d23--the-dom-front-end-has-no-framework-and-the-state-stays-in-the-wasm)
// draws the line there: the document lives in the wasm and "the DOM holds only
// where the camera is pointing". Pan and zoom are one `transform` on one `<g>`,
// so the thing that owns the transform should own the numbers behind it — a
// round trip into wasm per pointer move would buy nothing and could disagree
// with the attribute actually on the element.
//
// The arithmetic is `crates/app/src/camera.rs`'s, method for method, because
// the two builds have to feel the same while both exist. It transfers exactly:
// egui works in logical points and an SVG with no `viewBox` works in CSS
// pixels, so `zoom = 1` means one world unit per CSS pixel in both, which is
// also what makes the shared level-of-detail thresholds mean the same thing.
// Its properties are asserted in the browser by web/front-check.mjs, where the
// Rust has unit tests.

/// Below this the diagram is a texture; above it, the text is bigger than it
/// would ever usefully be. `crates/app/src/camera.rs`'s values.
export const MIN_ZOOM = 0.02;
export const MAX_ZOOM = 4.0;

export class Camera {
  constructor() {
    /// Diagram point drawn at the top-left of the viewport.
    this.x = 0;
    this.y = 0;
    this.zoom = 1;
  }

  /// Screen position, in CSS pixels relative to the viewport's top-left.
  toScreen(wx, wy) {
    return { x: (wx - this.x) * this.zoom, y: (wy - this.y) * this.zoom };
  }

  toWorld(sx, sy) {
    return { x: this.x + sx / this.zoom, y: this.y + sy / this.zoom };
  }

  /// The diagram rectangle currently visible. Culling compares against this.
  visibleWorld(size) {
    return {
      x: this.x,
      y: this.y,
      w: size.w / this.zoom,
      h: size.h / this.zoom,
    };
  }

  pan(dx, dy) {
    this.x -= dx / this.zoom;
    this.y -= dy / this.zoom;
  }

  /// Zoom about a fixed screen point, so the diagram under the cursor stays
  /// under the cursor. Anything else feels like the canvas is fighting you.
  zoomAbout(factor, sx, sy) {
    const before = this.toWorld(sx, sy);
    this.zoom = Math.min(Math.max(this.zoom * factor, MIN_ZOOM), MAX_ZOOM);
    const after = this.toWorld(sx, sy);
    this.x += before.x - after.x;
    this.y += before.y - after.y;
  }

  /// Centre the view on a diagram point, leaving the zoom alone.
  lookAt(wx, wy, size) {
    this.x = wx - size.w / this.zoom / 2;
    this.y = wy - size.h / this.zoom / 2;
  }

  /// Frame `content` in a viewport of `size` with a margin, clamped to the
  /// zoom range.
  fit(content, size, margin) {
    if (content.w <= 0 || content.h <= 0 || size.w <= 0 || size.h <= 0) {
      this.x = 0;
      this.y = 0;
      this.zoom = 1;
      return;
    }
    const usable = {
      w: Math.max(size.w - margin * 2, 1),
      h: Math.max(size.h - margin * 2, 1),
    };
    const scale = Math.min(usable.w / content.w, usable.h / content.h);
    this.zoom = Math.min(Math.max(scale, MIN_ZOOM), MAX_ZOOM);
    // Centring matters when the fit is clamped: the diagram then does not fit
    // at all, and the middle is the least arbitrary place to be.
    this.lookAt(content.x + content.w / 2, content.y + content.h / 2, size);
  }

  /// What goes on the `<g>`. Translate in screen units after scaling, so the
  /// numbers in the attribute are the same ones `toScreen` computes.
  transform() {
    return `translate(${-this.x * this.zoom} ${-this.y * this.zoom}) scale(${this.zoom})`;
  }
}

/// Do two world rectangles overlap? The cull test, and the reason a thousand
/// tables cost the same as the twenty on screen.
export function overlaps(a, b) {
  return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
}
