//! Sticky notes and group boxes.
//!
//! Annotations are part of the diagram and no part of the schema. They are
//! saved, shared and exported with it, and they have no representation in the
//! SQL at all — which is why they live here rather than in `model`. There is no
//! span to splice, so there is nothing to be surgical about: they are ordinary
//! mutable state, and the only thing that has to be got right is that they never
//! leak into the script.

use draft_view::Theme;
use egui::epaint::FontsView;
use egui::text::LayoutJob;
use egui::{Color32, CornerRadius, FontId, Pos2, Rect, Shape, Stroke, StrokeKind, Vec2};
use serde::{Deserialize, Serialize};

/// The corner you drag to resize, in world units.
const GRIP: f32 = 20.0;
/// A group box is grabbed by its title strip only, so clicking a table inside
/// one still reaches the table. A note is grabbed anywhere, because a note has
/// nothing underneath it worth reaching.
const STRIP: f32 = 28.0;
const PAD: f32 = 10.0;
const MIN: Vec2 = Vec2::new(90.0, 60.0);

#[derive(Clone, Copy, PartialEq, Eq, Debug, Serialize, Deserialize)]
pub enum Kind {
    Note,
    Group,
}

/// A colour is stored as an index into the palette, never as an RGB value.
///
/// The same project has to look right in both themes, and a stored `#fff8c0`
/// can only look right in one of them. An index is a choice of *hue*; each
/// theme renders it in its own register.
pub struct Swatch {
    pub name: &'static str,
    light: Color32,
    dark: Color32,
}

pub const PALETTE: [Swatch; 5] = [
    Swatch {
        name: "Yellow",
        light: Color32::from_rgb(0xff, 0xef, 0xb0),
        dark: Color32::from_rgb(0x4a, 0x3f, 0x18),
    },
    Swatch {
        name: "Blue",
        light: Color32::from_rgb(0xd4, 0xe6, 0xff),
        dark: Color32::from_rgb(0x1e, 0x33, 0x4d),
    },
    Swatch {
        name: "Green",
        light: Color32::from_rgb(0xd6, 0xf0, 0xd8),
        dark: Color32::from_rgb(0x1f, 0x3e, 0x2a),
    },
    Swatch {
        name: "Pink",
        light: Color32::from_rgb(0xff, 0xdc, 0xe4),
        dark: Color32::from_rgb(0x4b, 0x25, 0x2f),
    },
    Swatch {
        name: "Grey",
        light: Color32::from_rgb(0xe4, 0xe8, 0xee),
        dark: Color32::from_rgb(0x30, 0x36, 0x40),
    },
];

impl Swatch {
    fn fill(&self, dark: bool) -> Color32 {
        if dark { self.dark } else { self.light }
    }
}

fn swatch(colour: usize) -> &'static Swatch {
    // A project from a future build may name a colour this one does not have.
    // Falling back is better than refusing to open the file.
    PALETTE.get(colour).unwrap_or(&PALETTE[0])
}

#[derive(Clone, PartialEq, Serialize, Deserialize)]
#[serde(default)]
pub struct Annotation {
    pub kind: Kind,
    pub rect: Rect,
    pub text: String,
    pub colour: usize,
}

impl Default for Annotation {
    fn default() -> Self {
        Self {
            kind: Kind::Note,
            rect: Rect::from_min_size(Pos2::ZERO, Vec2::new(220.0, 140.0)),
            text: String::new(),
            colour: 0,
        }
    }
}

/// Which part of an annotation a press landed on.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Grab {
    Body,
    Resize,
}

// `PartialEq` so the undo history can compare two states of the diagram.
#[derive(Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct Annotations {
    items: Vec<Annotation>,
}

impl Annotations {
    pub fn len(&self) -> usize {
        self.items.len()
    }

    pub fn is_empty(&self) -> bool {
        self.items.is_empty()
    }

    pub fn get(&self, index: usize) -> Option<&Annotation> {
        self.items.get(index)
    }

    /// In the order they were added, which is the order they are drawn in.
    pub fn iter(&self) -> impl Iterator<Item = &Annotation> {
        self.items.iter()
    }

    /// Add one centred on `at`, and return its index so the caller can open a
    /// text field on it straight away.
    pub fn add(&mut self, kind: Kind, at: Pos2) -> usize {
        let size = match kind {
            Kind::Note => Vec2::new(220.0, 140.0),
            Kind::Group => Vec2::new(420.0, 300.0),
        };
        self.items.push(Annotation {
            kind,
            rect: Rect::from_center_size(at, size),
            text: String::new(),
            colour: match kind {
                Kind::Note => 0,
                // A group box is a frame around other things; a loud one fights
                // the tables it is drawn around.
                Kind::Group => 4,
            },
        });
        self.items.len() - 1
    }

    pub fn set_rect(&mut self, index: usize, rect: Rect) {
        if let Some(item) = self.items.get_mut(index) {
            item.rect = rect;
        }
    }

    pub fn set_colour(&mut self, index: usize, colour: usize) {
        if let Some(item) = self.items.get_mut(index) {
            item.colour = colour;
        }
    }

    pub fn text_mut(&mut self, index: usize) -> Option<&mut String> {
        self.items.get_mut(index).map(|item| &mut item.text)
    }

    pub fn remove(&mut self, index: usize) {
        if index < self.items.len() {
            self.items.remove(index);
        }
    }

    /// What is under `at`, in world units, and which part of it.
    ///
    /// Front to back, matching the order they are drawn in: a note covers a
    /// group, and a later note covers an earlier one. A group only answers for
    /// its title strip and its resize corner, so the tables it is drawn around
    /// stay clickable — a group box that swallowed every click inside it would
    /// be unusable the moment it contained anything.
    pub fn hit(&self, at: Pos2) -> Option<(usize, Grab)> {
        let mut found = None;
        for (i, item) in self.items.iter().enumerate() {
            let Some(grab) = item.grab(at) else {
                continue;
            };
            // Later wins, and a note wins over a group whatever the order.
            let beats = match found {
                None => true,
                Some((j, _)) => {
                    let other: &Annotation = &self.items[j];
                    item.kind == other.kind || item.kind == Kind::Note
                }
            };
            if beats {
                found = Some((i, grab));
            }
        }
        found
    }

    /// The rectangle covering every annotation, for framing and export.
    pub fn bounds(&self) -> Option<Rect> {
        self.items
            .iter()
            .map(|i| i.rect)
            .reduce(|acc, r| acc.union(r))
    }

    /// The shapes for one layer, in world units multiplied by `scale`.
    ///
    /// Two layers rather than one list: group boxes belong behind the tables
    /// they frame and notes belong in front of them, and there is no ordering of
    /// a single list that gives both.
    ///
    /// `scale` is here for the same reason as in `view::table_shapes` — glyphs
    /// are rasterised at the size they are laid out at, so text built at scale 1
    /// and magnified is a magnified bitmap.
    pub fn shapes(
        &self,
        layer: Kind,
        theme: &Theme,
        dark: bool,
        scale: f32,
        fonts: &mut FontsView<'_>,
    ) -> Vec<Shape> {
        let mut out = Vec::new();
        for item in self.items.iter().filter(|i| i.kind == layer) {
            item.draw(theme, dark, scale, fonts, &mut out);
        }
        out
    }
}

impl Annotation {
    fn grab(&self, at: Pos2) -> Option<Grab> {
        if !self.rect.contains(at) {
            return None;
        }
        if Rect::from_min_max(self.rect.max - Vec2::splat(GRIP), self.rect.max).contains(at) {
            return Some(Grab::Resize);
        }
        match self.kind {
            Kind::Note => Some(Grab::Body),
            Kind::Group if at.y <= self.rect.min.y + STRIP => Some(Grab::Body),
            Kind::Group => None,
        }
    }

    /// Move or resize, keeping the box a usable size either way.
    pub fn dragged(&self, grab: Grab, to: Pos2, offset: Vec2) -> Rect {
        match grab {
            Grab::Body => Rect::from_min_size(to - offset, self.rect.size()),
            Grab::Resize => {
                Rect::from_min_size(self.rect.min, ((to - offset) - self.rect.min).max(MIN))
            }
        }
    }

    fn draw(
        &self,
        theme: &Theme,
        dark: bool,
        scale: f32,
        fonts: &mut FontsView<'_>,
        out: &mut Vec<Shape>,
    ) {
        let swatch = swatch(self.colour);
        let fill = swatch.fill(dark);
        let rect = Rect::from_min_size(
            (self.rect.min.to_vec2() * scale).to_pos2(),
            self.rect.size() * scale,
        );
        let radius = CornerRadius::same((6.0 * scale) as u8);
        let ink = if dark {
            theme.header_text
        } else {
            Color32::from_rgb(0x20, 0x25, 0x2c)
        };

        match self.kind {
            Kind::Note => out.push(Shape::Rect(egui::epaint::RectShape::new(
                rect,
                radius,
                fill,
                Stroke::new(scale, theme.table_stroke),
                StrokeKind::Inside,
            ))),
            Kind::Group => {
                // Translucent, because a group box is drawn over the background
                // and under the tables: an opaque one would hide the edges that
                // pass behind it.
                out.push(Shape::Rect(egui::epaint::RectShape::new(
                    rect,
                    radius,
                    fill.gamma_multiply(0.55),
                    Stroke::new(1.5 * scale, fill),
                    StrokeKind::Inside,
                )));
            }
        }

        if self.text.is_empty() {
            return;
        }
        let pad = PAD * scale;
        let width = (rect.width() - pad * 2.0).max(1.0);
        let font = FontId::new(13.0 * scale, egui::FontFamily::Proportional);
        let mut job = LayoutJob::simple(self.text.clone(), font, ink, width);
        job.wrap.max_rows = match self.kind {
            // A group's text is its title, on the strip you drag it by.
            Kind::Group => 1,
            Kind::Note => (((rect.height() - pad * 2.0) / (17.0 * scale)) as usize).max(1),
        };
        job.wrap.overflow_character = Some('…');
        let galley = fonts.layout_job(job);
        out.push(Shape::galley(rect.min + Vec2::splat(pad), galley, ink));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn at(x: f32, y: f32) -> Pos2 {
        Pos2::new(x, y)
    }

    /// A group box is a frame drawn *around* tables. If it answered for every
    /// point inside it, every table it contained would stop being clickable —
    /// which is the one thing that would make the feature useless.
    #[test]
    fn a_group_box_does_not_swallow_the_tables_it_frames() {
        let mut notes = Annotations::default();
        let group = notes.add(Kind::Group, at(200.0, 200.0));
        notes.set_rect(
            group,
            Rect::from_min_size(at(0.0, 0.0), Vec2::new(400.0, 400.0)),
        );

        assert_eq!(
            notes.hit(at(200.0, 200.0)),
            None,
            "the middle of a group belongs to whatever is drawn inside it"
        );
        assert_eq!(
            notes.hit(at(200.0, 10.0)),
            Some((group, Grab::Body)),
            "the title strip is how a group is moved"
        );
        assert_eq!(
            notes.hit(at(395.0, 395.0)),
            Some((group, Grab::Resize)),
            "the corner is how a group is resized"
        );
    }

    /// A note is opaque and sits in front, so it has to win — otherwise a note
    /// dropped on a group could never be picked up again.
    #[test]
    fn a_note_on_top_of_a_group_is_the_one_you_grab() {
        let mut notes = Annotations::default();
        let group = notes.add(Kind::Group, at(100.0, 100.0));
        notes.set_rect(
            group,
            Rect::from_min_size(at(0.0, 0.0), Vec2::new(400.0, 400.0)),
        );
        let note = notes.add(Kind::Note, at(100.0, 10.0));

        assert_eq!(notes.hit(at(100.0, 10.0)), Some((note, Grab::Body)));
    }

    /// Dragging must move the box under the cursor rather than jump its corner
    /// to it, and resizing must not be able to turn it inside out.
    #[test]
    fn dragging_keeps_the_grab_offset_and_resizing_keeps_a_usable_box() {
        let mut notes = Annotations::default();
        let note = notes.add(Kind::Note, at(100.0, 100.0));
        let rect = notes.get(note).unwrap().rect;
        let grabbed_at = rect.min + Vec2::new(30.0, 20.0);

        let moved = notes.get(note).unwrap().dragged(
            Grab::Body,
            grabbed_at + Vec2::new(50.0, 50.0),
            Vec2::new(30.0, 20.0),
        );
        assert_eq!(moved.min, rect.min + Vec2::new(50.0, 50.0));
        assert_eq!(moved.size(), rect.size());

        let shrunk = notes
            .get(note)
            .unwrap()
            .dragged(Grab::Resize, rect.min, Vec2::ZERO);
        assert_eq!(shrunk.size(), MIN, "a box must not collapse to nothing");
        assert_eq!(shrunk.min, rect.min, "resizing moves one corner, not both");
    }

    /// Annotations travel with the project, so the format has to survive a round
    /// trip — and an older file that predates a field has to still open.
    #[test]
    fn annotations_round_trip_through_json() {
        let mut notes = Annotations::default();
        let note = notes.add(Kind::Note, at(10.0, 20.0));
        *notes.text_mut(note).unwrap() = "why this table is odd".to_owned();
        notes.set_colour(note, 2);
        notes.add(Kind::Group, at(300.0, 300.0));

        let json = serde_json::to_string(&notes).unwrap();
        let back: Annotations = serde_json::from_str(&json).unwrap();
        assert_eq!(back.len(), 2);
        assert_eq!(back.get(0).unwrap().text, "why this table is odd");
        assert_eq!(back.get(0).unwrap().colour, 2);
        assert_eq!(back.get(1).unwrap().kind, Kind::Group);

        let older: Annotations = serde_json::from_str(r#"[{"kind":"Note"}]"#).unwrap();
        assert_eq!(older.len(), 1, "a file missing a field must still open");
    }
}
