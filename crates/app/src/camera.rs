//! The mapping between diagram coordinates and the screen.
//!
//! Kept separate and free of egui types so it can be reasoned about — and
//! tested — without a frame, because every bug in here shows up as the diagram
//! sliding out from under the cursor.

use egui::{Pos2, Rect, Vec2};

#[derive(Clone, Copy, Debug, PartialEq, serde::Serialize, serde::Deserialize)]
pub struct Camera {
    /// Diagram point drawn at the top-left of the viewport.
    pub origin: Pos2,
    pub zoom: f32,
}

/// Below this the diagram is a texture; above it, the text is bigger than it
/// would ever usefully be.
pub const MIN_ZOOM: f32 = 0.02;
pub const MAX_ZOOM: f32 = 4.0;

impl Default for Camera {
    fn default() -> Self {
        Self {
            origin: Pos2::ZERO,
            zoom: 1.0,
        }
    }
}

impl Camera {
    pub fn to_screen(self, world: Pos2, viewport: Rect) -> Pos2 {
        viewport.min + (world - self.origin) * self.zoom
    }

    pub fn to_world(self, screen: Pos2, viewport: Rect) -> Pos2 {
        self.origin + (screen - viewport.min) / self.zoom
    }

    /// The diagram rectangle currently visible. Culling compares against this.
    pub fn visible_world(self, viewport: Rect) -> Rect {
        Rect::from_min_size(self.origin, viewport.size() / self.zoom)
    }

    pub fn pan(&mut self, screen_delta: Vec2) {
        self.origin -= screen_delta / self.zoom;
    }

    /// Zoom about a fixed screen point, so the diagram under the cursor stays
    /// under the cursor. Anything else feels like the canvas is fighting you.
    pub fn zoom_about(&mut self, factor: f32, anchor: Pos2, viewport: Rect) {
        let before = self.to_world(anchor, viewport);
        self.zoom = (self.zoom * factor).clamp(MIN_ZOOM, MAX_ZOOM);
        let after = self.to_world(anchor, viewport);
        self.origin += before - after;
    }

    /// Centre the view on a diagram point, leaving the zoom alone.
    pub fn look_at(&mut self, target: Pos2, viewport: Rect) {
        self.origin = target - viewport.size() / self.zoom / 2.0;
    }

    /// Frame `content` in `viewport` with a margin, clamped to the zoom range.
    pub fn fit(&mut self, content: Rect, viewport: Rect, margin: f32) {
        if content.width() <= 0.0 || content.height() <= 0.0 || !viewport.is_positive() {
            *self = Self::default();
            return;
        }
        let usable = (viewport.size() - Vec2::splat(margin * 2.0)).max(Vec2::splat(1.0));
        let scale = (usable.x / content.width()).min(usable.y / content.height());
        self.zoom = scale.clamp(MIN_ZOOM, MAX_ZOOM);
        // Centring matters when the fit is clamped: the diagram then does not
        // fit at all, and the middle is the least arbitrary place to be.
        self.look_at(content.center(), viewport);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn viewport() -> Rect {
        Rect::from_min_size(Pos2::new(10.0, 20.0), Vec2::new(800.0, 600.0))
    }

    fn close(a: Pos2, b: Pos2) -> bool {
        (a - b).length() < 0.01
    }

    #[test]
    fn screen_and_world_are_inverses_at_any_zoom() {
        for zoom in [0.05, 0.5, 1.0, 3.7] {
            let camera = Camera {
                origin: Pos2::new(-140.0, 55.0),
                zoom,
            };
            for p in [
                Pos2::ZERO,
                Pos2::new(123.0, -45.0),
                Pos2::new(9999.0, 8888.0),
            ] {
                let round_trip = camera.to_world(camera.to_screen(p, viewport()), viewport());
                assert!(close(round_trip, p), "zoom {zoom}: {p:?} -> {round_trip:?}");
            }
        }
    }

    /// The property that makes zooming feel like zooming rather than like the
    /// canvas shoving you sideways.
    #[test]
    fn zooming_keeps_the_point_under_the_cursor_still() {
        let mut camera = Camera {
            origin: Pos2::new(30.0, 40.0),
            zoom: 1.0,
        };
        let anchor = Pos2::new(400.0, 300.0);
        let before = camera.to_world(anchor, viewport());
        for factor in [1.1, 1.1, 0.7, 2.0, 0.5] {
            camera.zoom_about(factor, anchor, viewport());
            let after = camera.to_world(anchor, viewport());
            assert!(
                close(before, after),
                "anchor drifted to {after:?} from {before:?}"
            );
        }
    }

    #[test]
    fn zoom_stays_inside_its_limits() {
        let mut camera = Camera::default();
        for _ in 0..200 {
            camera.zoom_about(0.5, Pos2::ZERO, viewport());
        }
        assert_eq!(camera.zoom, MIN_ZOOM);
        for _ in 0..200 {
            camera.zoom_about(2.0, Pos2::ZERO, viewport());
        }
        assert_eq!(camera.zoom, MAX_ZOOM);
    }

    #[test]
    fn panning_moves_the_diagram_with_the_pointer() {
        let mut camera = Camera {
            origin: Pos2::ZERO,
            zoom: 2.0,
        };
        let world = Pos2::new(50.0, 50.0);
        let before = camera.to_screen(world, viewport());
        camera.pan(Vec2::new(30.0, -10.0));
        let after = camera.to_screen(world, viewport());
        assert!(close(after, before + Vec2::new(30.0, -10.0)));
    }

    #[test]
    fn fit_frames_the_whole_diagram() {
        let mut camera = Camera::default();
        let content = Rect::from_min_size(Pos2::new(0.0, 0.0), Vec2::new(4000.0, 1000.0));
        camera.fit(content, viewport(), 24.0);

        let visible = camera.visible_world(viewport());
        assert!(
            visible.contains_rect(content),
            "{visible:?} does not contain {content:?}"
        );
        assert!(camera.zoom < 1.0, "a big diagram should zoom out");
    }

    #[test]
    fn fitting_nothing_is_not_a_division_by_zero() {
        let mut camera = Camera {
            origin: Pos2::new(5.0, 5.0),
            zoom: 3.0,
        };
        camera.fit(
            Rect::from_min_size(Pos2::ZERO, Vec2::ZERO),
            viewport(),
            24.0,
        );
        assert_eq!(camera.zoom, 1.0);
        assert!(camera.zoom.is_finite() && camera.origin.x.is_finite());
    }
}
