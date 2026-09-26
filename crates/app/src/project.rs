//! The `.json` project: everything on screen that the SQL does not already say.
//!
//! One format for three jobs — Save, Open, and the share link — because they
//! are the same question asked three ways. A share link that carried less than
//! a saved file would be a second format with its own bugs, and the thing most
//! likely to be shared is the thing someone has just spent an afternoon
//! arranging.
//!
//! The SQL text is stored verbatim, not a parsed schema. Everything else here
//! is a view of it.

use draft_layout::Placement;
use serde::{Deserialize, Serialize};

use crate::annotate::Annotations;
use crate::app::Settings;
use crate::camera::Camera;

/// Bumped only when an older build would misread a newer file, which has not
/// happened yet. `serde(default)` covers fields being added.
pub const VERSION: u32 = 1;

#[derive(Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Project {
    pub version: u32,
    pub name: String,
    pub sql: String,
    pub settings: Settings,
    pub camera: Option<Camera>,
    pub placement: Placement,
    pub annotations: Annotations,
    /// A dialect somebody pinned, by the name the vendor uses — `"MySQL"`, not
    /// a Rust variant name. Absent means "whatever the script looks like",
    /// which is the normal case and is derived from `sql` rather than stored.
    ///
    /// A label rather than a serde derive on `draft_ddl::Dialect` for two
    /// reasons: that crate has no dependencies and is not acquiring one for
    /// this, and this file is text people edit.
    pub dialect: Option<String>,
}

impl Project {
    pub fn to_json(&self) -> String {
        // Pretty-printed: a project file is text in a repository, and a diff
        // that is one enormous line is a diff nobody can review.
        serde_json::to_string_pretty(self).unwrap_or_default()
    }

    /// Read a project, or decide this is not one.
    ///
    /// `Open…` takes both `.sql` and `.json`, and telling them apart by what
    /// the bytes are beats trusting a file extension that anyone can rename.
    pub fn from_json(text: &str) -> Option<Self> {
        let project: Self = serde_json::from_str(text).ok()?;
        // A JSON document that happens to parse but carries no schema is not a
        // project — most likely somebody opened a package.json.
        (!project.sql.is_empty()).then_some(project)
    }
}

/// Is this file a project, or a schema?
///
/// Cheap enough to run before parsing, and it keeps a `.sql` file that begins
/// with a comment from being handed to the JSON parser.
pub fn looks_like_json(text: &str) -> bool {
    text.trim_start().starts_with('{')
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::annotate::Kind;
    use draft_ddl::Dialect;
    use draft_layout::Size;
    use egui::Pos2;

    fn project() -> Project {
        let mut annotations = Annotations::default();
        let note = annotations.add(Kind::Note, Pos2::new(40.0, 40.0));
        *annotations.text_mut(note).unwrap() = "denormalised on purpose".to_owned();
        annotations.set_colour(note, 3);
        annotations.add(Kind::Group, Pos2::new(500.0, 220.0));

        Project {
            version: VERSION,
            name: "shop.sql".to_owned(),
            sql: crate::sample::DEFAULT.sql.to_owned(),
            settings: Settings::default(),
            camera: Some(Camera {
                origin: Pos2::new(-12.5, 400.0),
                zoom: 0.37,
            }),
            placement: Placement::default(),
            annotations,
            // Pinned to something the sample is not, so a round trip that
            // silently dropped it would not be masked by detection agreeing.
            dialect: Some("MySQL".to_owned()),
        }
    }

    /// A project has to survive the round trip it exists for. Asserting on the
    /// parts a person would notice missing: the text, where they put things, and
    /// what they wrote on them.
    #[test]
    fn a_project_survives_being_saved_and_opened() {
        let before = project();
        let after = Project::from_json(&before.to_json()).expect("a project we just wrote");

        assert_eq!(after.sql, before.sql);
        assert_eq!(after.name, before.name);
        assert_eq!(after.camera, before.camera);
        assert_eq!(
            after.dialect.as_deref().and_then(Dialect::from_label),
            Some(Dialect::MySql),
            "a pinned dialect did not survive being saved and opened"
        );
        assert_eq!(after.annotations.len(), 2);
        assert_eq!(
            after.annotations.get(0).unwrap().text,
            "denormalised on purpose"
        );
        assert_eq!(after.annotations.get(0).unwrap().colour, 3);
        assert_eq!(
            after.annotations.get(1).unwrap().kind,
            Kind::Group,
            "a group box came back as a sticky note"
        );
    }

    /// Positions are the expensive thing to recreate by hand, so they are the
    /// thing a share link most has to keep.
    #[test]
    fn a_dragged_table_keeps_its_position_through_a_share_link() {
        let schema = draft_ddl::parse(crate::sample::DEFAULT.sql);
        let sizes = vec![Size { w: 180.0, h: 120.0 }; schema.tables.len()];
        let mut placement = Placement::default();
        placement.arrange(&schema, &sizes, &Default::default());
        placement.set(0, draft_layout::Pos::new(-120.5, 880.0));

        let mut before = project();
        before.placement = placement;
        let payload = crate::share::encode(&before.to_json());
        let after = Project::from_json(&crate::share::decode(&payload).expect("decodes"))
            .expect("a project we just encoded");

        let layout = after
            .placement
            .clone()
            .arrange(&schema, &sizes, &Default::default());
        assert_eq!(
            (layout.nodes[0].x, layout.nodes[0].y),
            (-120.5, 880.0),
            "the first table did not come back where it was left"
        );
        assert_eq!(
            after.annotations.get(0).unwrap().text,
            "denormalised on purpose",
            "the annotations did not come back with it"
        );
    }

    /// Open takes both kinds of file, and the only honest way to tell them apart
    /// is to look at the bytes — a `.sql` file renamed to `.json` is still SQL.
    #[test]
    fn a_schema_is_not_mistaken_for_a_project() {
        assert!(!looks_like_json(crate::sample::DEFAULT.sql));
        assert!(!looks_like_json("-- a comment\nCREATE TABLE t (id int);"));
        assert!(looks_like_json("  {\"sql\": \"CREATE TABLE t (id int);\"}"));

        assert!(
            Project::from_json(r#"{"name":"package.json","dependencies":{}}"#).is_none(),
            "a JSON file with no schema in it is not a project"
        );
        assert!(Project::from_json(crate::sample::DEFAULT.sql).is_none());
    }
}
