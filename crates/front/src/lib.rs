//! The wasm core the DOM front end talks to.
//!
//! Promoted from `spikes/dom-front/core`, which measured the payload floor this
//! exists to reach: 123 K brotli for the parser, the layout engine, the splice
//! logic and the highlighter, against 1273 K for the canvas build
//! ([D19](../../../docs/architecture.md#d19--the-dom-front-end-is-the-plan)).
//!
//! Two properties of the design, both from writing the spike rather than from
//! planning it:
//!
//! 1. **Nothing here parses JSON.** Sizes and positions cross as typed arrays;
//!    the schema and the edge routes go out as JSON this file writes by hand.
//! 2. **The session holds the parse.** The front end sends the script once and
//!    then asks questions about it, exactly as the canvas build's `Document`
//!    does, so re-parsing per call never happens.
//!
//! And one that is the whole reason a DOM front end is possible at all: **the
//! browser measures the text**. Every width arrives from `measureText`, the
//! arithmetic on top of it is `draft_geom`'s — the same arithmetic the CLI
//! uses with epaint's widths — and
//! [S5](../../../docs/measurements.md#s5--what-a-dom-front-end-would-cost-and-whether-its-geometry-holds)
//! measured the two engines agreeing to 0.02 px. That is what lets the typefaces
//! stay out of this module.

use draft_ddl::{Cardinality, Schema};
use draft_geom as geom;
use draft_layout::{Direction, Options, Placement, Rect, Size, Spacing};
use wasm_bindgen::prelude::*;

/// One script, parsed once, asked about many times.
#[wasm_bindgen]
pub struct Session {
    sql: String,
    schema: Schema,
    /// Where the tables sit, which outlives the parse they were first placed
    /// by. See [`Placement`]: the engine is a pure function of the schema, so
    /// without this a diagram rearranges itself while you type.
    placement: Placement,
    /// What [`Self::place`] was last asked for. Changing direction or spacing
    /// describes a different arrangement, so it has to hand the diagram back to
    /// the engine rather than keep positions that answered a different
    /// question — the canvas build calls `reset` from the menu that changes
    /// them, and this notices instead.
    arranged: Option<Options>,
}

#[wasm_bindgen]
impl Session {
    #[wasm_bindgen(constructor)]
    pub fn new(sql: String) -> Self {
        let schema = draft_ddl::parse(&sql);
        Self {
            sql,
            schema,
            placement: Placement::default(),
            arranged: None,
        }
    }

    /// The same document, edited.
    ///
    /// Keeps the placement, which is the entire difference between this and
    /// constructing a new session: a table you dragged, and every table that
    /// was already on screen, stays where it is.
    pub fn reparse(&mut self, sql: String) {
        self.schema = draft_ddl::parse(&sql);
        self.sql = sql;
    }

    /// Everything the DOM needs to build the boxes, as JSON.
    ///
    /// Including the decisions rather than the raw facts behind them: which
    /// badge a column has earned, and the two halves an index row is drawn as.
    /// Those are rules, they already exist in `draft_geom`, and a front end
    /// that re-derived them in JavaScript would be a second place for them to
    /// be wrong.
    pub fn schema_json(&self) -> String {
        let mut out = String::with_capacity(self.sql.len());
        out.push_str("{\"tables\":[");
        for (i, table) in self.schema.tables.iter().enumerate() {
            if i > 0 {
                out.push(',');
            }
            out.push_str("{\"name\":");
            quote(&table.name, &mut out);
            out.push_str(",\"columns\":[");
            for (j, column) in table.columns.iter().enumerate() {
                if j > 0 {
                    out.push(',');
                }
                out.push_str("{\"name\":");
                quote(&column.name, &mut out);
                out.push_str(",\"type\":");
                quote(&column.ty, &mut out);
                out.push_str(",\"badge\":");
                quote(geom::badge(column).unwrap_or(""), &mut out);
                out.push_str(",\"null\":");
                out.push_str(if column.not_null { "false" } else { "true" });
                out.push_str(",\"def\":");
                quote(column.def_span.text(&self.sql).trim(), &mut out);
                out.push('}');
            }
            out.push_str("],\"indexes\":[");
            for (j, index) in table.indexes.iter().enumerate() {
                if j > 0 {
                    out.push(',');
                }
                let (left, right) = geom::index_row(index);
                out.push_str("{\"left\":");
                quote(&left, &mut out);
                out.push_str(",\"right\":");
                quote(&right, &mut out);
                out.push_str(",\"unique\":");
                out.push_str(if index.unique { "true" } else { "false" });
                out.push('}');
            }
            out.push_str("]}");
        }
        out.push_str("],\"relations\":[");
        for (i, relation) in self.schema.relations.iter().enumerate() {
            if i > 0 {
                out.push(',');
            }
            out.push_str("{\"from\":");
            quote(&relation.from_table, &mut out);
            out.push_str(",\"to\":");
            quote(&relation.to_table, &mut out);
            out.push_str(",\"fromCols\":[");
            for (j, column) in relation.from_cols.iter().enumerate() {
                if j > 0 {
                    out.push(',');
                }
                quote(column, &mut out);
            }
            out.push_str("],\"toCols\":[");
            for (j, column) in relation.to_cols.iter().enumerate() {
                if j > 0 {
                    out.push(',');
                }
                quote(column, &mut out);
            }
            out.push_str("],\"one\":");
            out.push_str(match relation.cardinality {
                Cardinality::OneToOne => "true",
                Cardinality::OneToMany => "false",
            });
            out.push_str(",\"missing\":");
            out.push_str(if relation.to_missing { "true" } else { "false" });
            out.push('}');
        }
        out.push_str("],\"warnings\":[");
        for (i, warning) in self.schema.warnings.iter().enumerate() {
            if i > 0 {
                out.push(',');
            }
            out.push_str("{\"message\":");
            quote(&warning.message, &mut out);
            out.push_str(",\"at\":");
            out.push_str(&warning.span.map_or(-1, |s| s.start as i64).to_string());
            out.push('}');
        }
        out.push_str("]}");
        out
    }

    /// Size every box from the widths the browser measured, then place them.
    ///
    /// `widths` is one flat array in the order the schema is written: per table
    /// the header, then a name and a type per column, then the two halves of
    /// each index row. The front end walks the same structure it was given by
    /// [`Self::schema_json`], so the order is the schema's rather than a
    /// convention either side has to remember.
    ///
    /// The answer is `[x, y, w, h]` per table — the sizes come back with the
    /// positions so the caller never recomputes a box it has already been told
    /// about.
    ///
    /// Positions come from [`Placement`] rather than straight from the engine,
    /// so a table that already existed keeps its place. That is not only what
    /// makes an editable SQL pane readable — measured, widening one column
    /// moved 8 of 9 tables — it is also what makes a settle affordable: a full
    /// layout of the 1,000-table fixture is 120 ms before anything draws it.
    ///
    /// The error is a `String` rather than a `JsError` so that this is testable
    /// where the rest of this project's logic is tested: constructing a JS value
    /// aborts on a native target, and a contract nothing can test natively is
    /// one that gets checked by hand or not at all.
    pub fn place(
        &mut self,
        widths: &[f32],
        vertical: bool,
        spacing: u8,
    ) -> Result<Vec<f32>, String> {
        let wanted: usize = self
            .schema
            .tables
            .iter()
            .map(|t| 1 + 2 * t.columns.len() + 2 * t.indexes.len())
            .sum();
        // Loudly, because the alternative is a diagram drawn from widths that
        // belong to other rows: every box would be plausible and wrong.
        if widths.len() != wanted {
            return Err(format!(
                "expected {wanted} measured widths for {} tables, got {}",
                self.schema.tables.len(),
                widths.len()
            ));
        }

        let mut at = 0;
        let mut take = || {
            let width = widths[at];
            at += 1;
            width
        };
        let sizes: Vec<Size> = self
            .schema
            .tables
            .iter()
            .map(|table| {
                let mut measure = geom::Measure::table(take());
                for _ in &table.columns {
                    measure.column(take(), take());
                }
                for _ in &table.indexes {
                    measure.index(take(), take());
                }
                measure.size()
            })
            .collect();

        let options = Options {
            direction: if vertical {
                Direction::Vertical
            } else {
                Direction::Horizontal
            },
            spacing: match spacing {
                0 => Spacing::Compact,
                2 => Spacing::Spacious,
                _ => Spacing::Comfortable,
            },
        };
        if self.arranged != Some(options) {
            self.placement.reset();
            self.arranged = Some(options);
        }
        let placed = self.placement.arrange(&self.schema, &sizes, &options);
        Ok(placed
            .nodes
            .iter()
            .flat_map(|n| [n.x, n.y, n.w, n.h])
            .collect())
    }

    /// Where the edges run, given the boxes [`Self::place`] returned.
    ///
    /// The placement comes back in rather than being remembered, so that the
    /// same boxes always produce the same edges: a cached layout here would be
    /// a second answer to a question the front end already has an answer to.
    ///
    /// Per relation: `from` and `to` are table indexes with `to` null for a
    /// reference the script never declares; `path` is four points for a curve
    /// and two for a stub, self-describing so neither side infers the shape
    /// from anything else; and `marks` is the cardinality notation as line
    /// segments, because deciding what a crow's foot looks like is a rule and
    /// not a drawing.
    pub fn routes_json(&self, boxes: &[f32]) -> Result<String, String> {
        if boxes.len() != self.schema.tables.len() * 4 {
            return Err(format!(
                "expected 4 numbers per table for {} tables, got {}",
                self.schema.tables.len(),
                boxes.len()
            ));
        }
        let rects: Vec<Rect> = boxes
            .chunks_exact(4)
            .map(|b| Rect {
                x: b[0],
                y: b[1],
                w: b[2],
                h: b[3],
            })
            .collect();

        let mut out = String::new();
        out.push('[');
        let mut first = true;
        for relation in &self.schema.relations {
            let Some(from_i) = self.schema.index_of(&relation.from_table) else {
                continue;
            };
            let (Some(&from_rect), Some(from_table)) =
                (rects.get(from_i), self.schema.tables.get(from_i))
            else {
                continue;
            };
            let from_y = geom::anchor_y(from_table, from_rect, relation.from_cols.first());

            let target = match self.schema.index_of(&relation.to_table) {
                Some(to_i) => {
                    let (Some(&rect), Some(table)) =
                        (rects.get(to_i), self.schema.tables.get(to_i))
                    else {
                        continue;
                    };
                    Some((
                        to_i,
                        rect,
                        geom::anchor_y(table, rect, relation.to_cols.first()),
                    ))
                }
                None => None,
            };
            let route = geom::route(
                from_rect,
                from_y,
                target.map(|(_, rect, y)| (rect, y)),
                relation.cardinality,
            );

            if !first {
                out.push(',');
            }
            first = false;
            // The endpoints travel with the route for the same reason `view`'s
            // `Edge` carries them: highlighting a table means highlighting its
            // edges, and a `to` of `null` is what "the script never declares
            // this table" looks like — the one fact that decides the colour.
            out.push_str("{\"from\":");
            out.push_str(&from_i.to_string());
            out.push_str(",\"to\":");
            match target {
                Some((to_i, _, _)) => out.push_str(&to_i.to_string()),
                None => out.push_str("null"),
            }
            out.push_str(",\"path\":[");
            match route.path {
                geom::Path::Curve(points) => points_json(&points, &mut out),
                geom::Path::Stub(points) => points_json(&points, &mut out),
            }
            out.push_str("],\"marks\":[");
            let mut drawn = 0;
            for marks in [Some(route.start), route.end].into_iter().flatten() {
                for segment in marks.segments() {
                    if drawn > 0 {
                        out.push(',');
                    }
                    drawn += 1;
                    out.push('[');
                    points_json(segment, &mut out);
                    out.push(']');
                }
            }
            out.push_str("]}");
        }
        out.push(']');
        Ok(out)
    }

    /// How much of a table is worth drawing at this zoom.
    ///
    /// The thresholds are the canvas build's, reached through the same
    /// [`geom::Lod`] — a front end that picked its own would drop the column
    /// text at a different zoom from the application it replaces, which is a
    /// difference a reader would notice and nobody decided.
    pub fn lod(&self, zoom: f32) -> String {
        geom::Lod::for_zoom(zoom).name().to_owned()
    }

    /// The box metrics, so that stacking rows is arithmetic on shared numbers
    /// rather than a second opinion about them.
    ///
    /// A constant function, and deliberately not a constant in the JavaScript:
    /// the row height is the reason a hit test agrees with the drawing, and two
    /// copies of it is how they stop agreeing.
    pub fn metrics_json(&self) -> String {
        format!(
            "{{\"padX\":{},\"gap\":{},\"badgeW\":{},\"minW\":{},\"maxW\":{},\
             \"rowH\":{},\"headerH\":{},\"indexH\":{},\"indexSep\":{}}}",
            geom::PAD_X,
            geom::GAP,
            geom::BADGE_W,
            geom::MIN_W,
            geom::MAX_W,
            geom::ROW_H,
            geom::HEADER_H,
            geom::INDEX_H,
            geom::INDEX_SEP,
        )
    }

    pub fn dialect(&self) -> String {
        draft_ddl::detect(&self.sql)
            .map(|d| d.label().to_owned())
            .unwrap_or_default()
    }

    /// The splice path, which is the product's whole point: rename a column and
    /// get the rewritten script back.
    pub fn rename_column(&self, table: &str, column: &str, to: &str) -> Option<String> {
        let edit = draft_model::rename_column(&self.schema, table, column, to).ok()?;
        draft_model::apply(&self.sql, &edit.splices).ok()
    }
}

/// The lines `[first, first + count)` of a script, coloured: a CSS class, the
/// text it applies to, a class, its text, and so on.
///
/// A free function and not a [`Session`] method, because colouring is a lexer's
/// job and not a parser's: the editor asks for this on every keystroke, and
/// parsing a 396 KB script to find out that `CREATE` is a keyword would be the
/// most expensive possible way to answer. The session still holds the parse the
/// *diagram* is built from, one debounce behind the text.
///
/// **Lines, and the text itself, rather than offsets into the caller's string.**
/// The lexer works in bytes and a JavaScript string is indexed in UTF-16 code
/// units, so handing back offsets would put a conversion — and a whole class of
/// wrong-by-one-CJK-identifier bug — on the far side of the wall. Slicing here
/// costs a copy of what is on screen, which is a few kilobytes, and means the
/// editor never indexes the document at all. The class name travelling with
/// each run is the same trade: no shared table of token numbers to keep in step.
#[wasm_bindgen]
pub fn highlight_lines(sql: &str, first: u32, count: u32) -> Vec<String> {
    let (from, to) = line_range(sql, first as usize, count as usize);
    let mut out = Vec::new();
    for (span, token) in draft_ddl::highlight_until(sql, to) {
        // Runs are clipped rather than skipped: the first and last of a window
        // usually straddle it, because a run is a word and a window is a line.
        let start = span.start.max(from);
        let end = span.end.min(to);
        if end <= start {
            continue;
        }
        out.push(class_of(token).to_owned());
        out.push(sql[start..end].to_owned());
    }
    out
}

/// The byte range of a span of lines. One scan, which the lexer's own prefix
/// pass would cost anyway.
fn line_range(sql: &str, first: usize, count: usize) -> (usize, usize) {
    let last = first.saturating_add(count);
    let mut from = (first == 0).then_some(0);
    let mut to = None;
    let mut line = 0;
    for (i, &c) in sql.as_bytes().iter().enumerate() {
        if c != b'\n' {
            continue;
        }
        line += 1;
        if line == first {
            from = Some(i + 1);
        }
        if line == last {
            to = Some(i + 1);
            break;
        }
    }
    // Asked for lines past the end: an empty window, not the whole file.
    let from = from.unwrap_or(sql.len());
    (from, to.unwrap_or(sql.len()).max(from))
}

/// The one place a token kind becomes a name. Nothing else maps them, so there
/// is no second list to fall out of step with the enum.
fn class_of(token: draft_ddl::Token) -> &'static str {
    use draft_ddl::Token;
    match token {
        Token::Plain => "t-plain",
        Token::Keyword => "t-keyword",
        Token::Type => "t-type",
        Token::Literal => "t-literal",
        Token::Quoted => "t-quoted",
        Token::Comment => "t-comment",
        Token::Number => "t-number",
        Token::Punct => "t-punct",
    }
}

/// Points as a flat `x, y, x, y` list, which is how both an SVG `path` and a
/// comparison against the CLI want them.
fn points_json(points: &[geom::Pos], out: &mut String) {
    for (i, p) in points.iter().enumerate() {
        if i > 0 {
            out.push(',');
        }
        out.push_str(&format!("{},{}", p.x, p.y));
    }
}

/// A JSON string literal. Enough of the escape rules for identifiers and
/// messages, which is all that crosses this wall.
fn quote(text: &str, out: &mut String) {
    out.push('"');
    for c in text.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
}

#[cfg(test)]
mod tests {
    use super::*;

    const SQL: &str = "\
        CREATE TABLE customers (id bigserial PRIMARY KEY, email varchar(255) NOT NULL UNIQUE);\n\
        CREATE TABLE orders (\n\
          id bigserial PRIMARY KEY,\n\
          customer_id bigint NOT NULL REFERENCES customers(id),\n\
          KEY (customer_id)\n\
        );\n";

    /// The contract the front end is written against: one width per string it
    /// was asked to measure, in the schema's own order. Getting it wrong has to
    /// be an exception and not a diagram, because every box would still look
    /// plausible.
    #[test]
    fn a_wrong_number_of_widths_is_refused_rather_than_drawn() {
        let mut session = Session::new(SQL.to_owned());
        // customers: a header and two columns, so 5. orders: a header, two
        // columns and one index row, so 7.
        assert_eq!(session.place(&[0.0; 12], false, 1).unwrap().len(), 8);
        assert!(session.place(&[0.0; 11], false, 1).is_err());
        assert!(session.place(&[0.0; 13], false, 1).is_err());
    }

    /// Phase 4's acceptance criterion, which became this crate's the moment the
    /// SQL pane could be typed into: editing the script must not move the
    /// tables that were already there.
    ///
    /// The engine is a pure function of the schema, so making one column wider
    /// re-ranks the whole diagram — measured in the browser at **8 of 9 tables
    /// moving, the worst by 159 pt**, before `Placement` was on this side of
    /// the wall. A diagram that rearranges itself while you type is unreadable,
    /// and this is the test that says so.
    #[test]
    fn an_edit_leaves_every_existing_table_where_it_was() {
        let mut session = Session::new(SQL.to_owned());
        let before = session.place(&[0.0; 12], false, 1).unwrap();

        // A wider column, which is what re-ranks a layered layout: the same
        // tables, the same relations, one bigger box.
        let mut widths = [0.0f32; 12];
        widths[2] = 500.0;
        session.reparse(SQL.replace("email", "email_address"));
        let after = session.place(&widths, false, 1).unwrap();

        for (i, name) in ["customers", "orders"].iter().enumerate() {
            assert_eq!(
                (after[i * 4], after[i * 4 + 1]),
                (before[i * 4], before[i * 4 + 1]),
                "{name} moved"
            );
        }
        assert!(
            after[2] > before[2],
            "the wider column did not widen the box"
        );
    }

    /// Direction and spacing describe an arrangement, so asking for a different
    /// one has to hand the diagram back to the engine. Keeping positions that
    /// answered the previous question would make the option do nothing.
    #[test]
    fn changing_the_options_re_runs_the_engine() {
        let mut session = Session::new(SQL.to_owned());
        let horizontal = session.place(&[0.0; 12], false, 1).unwrap();
        let vertical = session.place(&[0.0; 12], true, 1).unwrap();
        assert_ne!(horizontal, vertical, "vertical was the horizontal layout");
    }

    /// The widths have to reach the box they were measured for. A table whose
    /// name is enormous must come back wider than its neighbour, or the front
    /// end is drawing someone else's measurements.
    #[test]
    fn a_width_lands_on_the_table_it_was_measured_for() {
        let mut session = Session::new(SQL.to_owned());
        let mut widths = [0.0f32; 12];
        widths[5] = 600.0; // the `orders` header, past MAX_W on its own
        let placed = session.place(&widths, false, 1).unwrap();
        assert_eq!(placed[2], geom::MIN_W, "customers was measured at nothing");
        assert_eq!(placed[6], geom::MAX_W, "orders was measured at 600");
    }

    /// Boxes are as tall as their contents, and the index block only exists
    /// where the script declares one — the same rule the canvas build draws by,
    /// reached here through the same crate.
    #[test]
    fn height_comes_from_the_rows_the_script_declares() {
        let mut session = Session::new(SQL.to_owned());
        let placed = session.place(&[0.0; 12], false, 1).unwrap();
        assert_eq!(placed[3], geom::HEADER_H + geom::ROW_H * 2.0);
        assert_eq!(
            placed[7],
            geom::HEADER_H + geom::ROW_H * 2.0 + geom::INDEX_SEP + geom::INDEX_H
        );
    }

    /// The JSON carries the decisions, not the raw flags: an unnamed `KEY` has
    /// its columns in the name's place, and a primary key is badged `PK` rather
    /// than leaving the front end to work out which badge wins.
    #[test]
    fn the_json_carries_the_rules_already_applied() {
        let session = Session::new(SQL.to_owned());
        let json = session.schema_json();
        assert!(json.contains("\"badge\":\"PK\""), "{json}");
        assert!(json.contains("\"badge\":\"FK\""), "{json}");
        assert!(
            json.contains("\"left\":\"(customer_id)\",\"right\":\"\""),
            "an unnamed index says its columns where a name would go: {json}"
        );
        assert!(
            json.contains("\"null\":true"),
            "nullability travels as what the diagram draws, not as NOT NULL: {json}"
        );
    }

    /// The metrics have to be the geometry crate's own numbers, because the
    /// front end stacks rows with them and the CLI draws rows with them.
    #[test]
    fn the_metrics_are_the_shared_ones() {
        let session = Session::new(String::new());
        let json = session.metrics_json();
        assert!(
            json.contains(&format!("\"rowH\":{}", geom::ROW_H)),
            "{json}"
        );
        assert!(
            json.contains(&format!("\"headerH\":{}", geom::HEADER_H)),
            "{json}"
        );
    }

    /// Edges are routed here, from the boxes the caller was given, so that the
    /// front end draws the curve `draft render` draws rather than a curve
    /// JavaScript invented. The shape of a route is readable from the route
    /// itself: four points bend, two points stop.
    #[test]
    fn edges_come_back_routed_and_say_which_kind_they_are() {
        let mut session = Session::new(SQL.to_owned());
        let boxes = session.place(&[0.0; 12], false, 1).unwrap();
        let json = session.routes_json(&boxes).unwrap();
        // `orders` references `customers`, so the edge runs 1 -> 0.
        assert!(json.contains("\"from\":1,\"to\":0"), "{json}");
        let path = json
            .split("\"path\":[")
            .nth(1)
            .and_then(|rest| rest.split(']').next())
            .expect("a path");
        assert_eq!(path.split(',').count(), 8, "a curve is four points: {path}");
        // The child end is a crow's foot and the parent end a bar, so three
        // segments cross for one one-to-many relation.
        assert_eq!(json.matches("],[").count() + 1, 3, "{json}");

        let mut dangling = Session::new(
            "CREATE TABLE c (id int PRIMARY KEY, p_id int REFERENCES gone(id));".to_owned(),
        );
        let placed = dangling.place(&[0.0; 5], false, 1).unwrap();
        let json = dangling.routes_json(&placed).unwrap();
        assert!(json.contains("\"to\":null"), "{json}");
        let path = json
            .split("\"path\":[")
            .nth(1)
            .and_then(|rest| rest.split(']').next())
            .expect("a path");
        assert_eq!(path.split(',').count(), 4, "a stub is two points: {path}");
    }

    /// The boxes have to be the ones this schema was placed as. Routing edges
    /// from someone else's placement would draw lines between nothing.
    #[test]
    fn routing_refuses_a_placement_that_is_not_this_schemas() {
        let session = Session::new(SQL.to_owned());
        assert!(session.routes_json(&[0.0; 8]).is_ok(), "two tables");
        assert!(session.routes_json(&[0.0; 4]).is_err());
        assert!(session.routes_json(&[0.0; 12]).is_err());
    }

    /// The front end must drop detail at the zoom the canvas build drops it,
    /// not at one of its own choosing.
    #[test]
    fn the_detail_thresholds_are_the_canvas_builds() {
        let session = Session::new(String::new());
        assert_eq!(session.lod(1.0), "full");
        assert_eq!(session.lod(0.45), "full");
        assert_eq!(session.lod(0.44), "header");
        assert_eq!(session.lod(0.18), "header");
        assert_eq!(session.lod(0.17), "block");
    }

    /// The editor paints one window per keystroke, so what comes back has to be
    /// exactly the lines asked for — joining the text must give the lines back
    /// character for character, or the colours sit over the wrong glyphs.
    #[test]
    fn a_window_is_exactly_the_lines_it_asked_for() {
        let sql = "CREATE TABLE a (id int);\nCREATE TABLE b (id text);\nCREATE TABLE c ();\n";
        let lines: Vec<&str> = sql.lines().collect();

        for (first, count) in [(0, 1), (1, 1), (0, 3), (1, 2), (2, 9)] {
            let window = highlight_lines(sql, first, count);
            let text: String = window
                .chunks_exact(2)
                .map(|pair| pair[1].as_str())
                .collect();
            let wanted: String = lines
                .iter()
                .skip(first as usize)
                .take(count as usize)
                .map(|line| format!("{line}\n"))
                .collect();
            assert_eq!(text, wanted, "lines {first}+{count}");
        }

        // Past the end is an empty window and not the whole file.
        assert!(highlight_lines(sql, 99, 10).is_empty());
    }

    /// The prefix still decides what the window means: inside a comment opened
    /// above it, a line of DDL is a comment and not a row of keywords. This is
    /// the reason the lexer starts at the top rather than at the window.
    #[test]
    fn a_window_is_coloured_by_what_came_before_it() {
        let sql = "/* opened up here\nCREATE TABLE b (id int);\n";
        let window = highlight_lines(sql, 1, 1);
        assert_eq!(
            window,
            ["t-comment", "CREATE TABLE b (id int);\n"],
            "{window:?}"
        );

        // And without the comment, the same line is keywords again.
        let plain = highlight_lines("-- opened up here\nCREATE TABLE b (id int);\n", 1, 1);
        assert_eq!(plain[0], "t-keyword", "{plain:?}");
    }

    /// The reason the core is worth carrying at all: the diagram edits the
    /// script rather than a copy of it.
    #[test]
    fn a_rename_comes_back_as_rewritten_sql() {
        let session = Session::new(SQL.to_owned());
        let after = session
            .rename_column("customers", "email", "contact_email")
            .expect("customers.email exists");
        assert!(after.contains("contact_email varchar(255)"));
        assert!(
            after.contains("CREATE TABLE orders ("),
            "everything outside the splice is untouched"
        );
    }
}
