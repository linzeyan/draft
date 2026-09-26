//! `draft` — render a SQL schema to a diagram without a browser.
//!
//! The CLI exists for more than convenience: it runs the same parser, the same
//! layout and the same geometry as the GUI, with no window and no GPU. That
//! makes it the thing to reach for when a schema renders wrongly, and it keeps
//! the core honest about not depending on a frame loop.

use std::io::Write as _;
use std::process::ExitCode;

use draft_ddl::Schema;
use draft_layout::{Direction, Options, Spacing};
use draft_view::{TextStyles, Theme};
use epaint::Vec2;
use epaint::text::{Fonts, TextOptions};

mod json;

const USAGE: &str = "\
draft — render a SQL schema to an ER diagram

USAGE:
    draft render <schema.sql> [OPTIONS]

OPTIONS:
    -o, --output <file>      Write here instead of stdout
        --dir <direction>    horizontal (default) | vertical
        --spacing <amount>   compact | comfortable (default) | spacious
        --theme <name>       light (default) | dark
        --png                Raster output at 2x instead of SVG
        --json               Emit the parsed schema instead of a diagram
    -q, --quiet              Do not report parse warnings
    -h, --help               Show this message
";

/// Space around the diagram in the exported file.
const MARGIN: f32 = 32.0;

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(message) => {
            eprintln!("draft: {message}");
            ExitCode::FAILURE
        }
    }
}

struct Args {
    input: String,
    output: Option<String>,
    options: Options,
    theme: Theme,
    png: bool,
    json: bool,
    quiet: bool,
}

/// What a render produced. Bytes rather than a string because a PNG is not one,
/// and pretending otherwise would mean a lossy conversion on the way to disk.
enum Output {
    Text(String),
    Bytes(Vec<u8>),
}

fn run() -> Result<(), String> {
    let argv: Vec<String> = std::env::args().skip(1).collect();
    if argv.is_empty() || argv.iter().any(|a| a == "-h" || a == "--help") {
        print!("{USAGE}");
        return Ok(());
    }
    let args = parse_args(&argv)?;

    let sql = std::fs::read_to_string(&args.input)
        .map_err(|e| format!("cannot read {}: {e}", args.input))?;
    let schema = draft_ddl::parse(&sql);

    if !args.quiet {
        report(&schema);
    }

    let body = if args.json {
        Output::Text(json::schema(&schema))
    } else {
        render(&schema, &sql, &args)?
    };
    write_out(args.output.as_deref(), &body)
}

/// 2x for the raster, matching the application's own export. A diagram at 1x
/// is a diagram that looks soft in every document it is pasted into.
const PNG_SCALE: f32 = 2.0;

fn render(schema: &Schema, sql: &str, args: &Args) -> Result<Output, String> {
    // One `Fonts` for the whole run: measuring and drawing must agree, and they
    // only agree if they are the same font engine with the same atlas.
    //
    // The CJK face is registered up front when the script needs one, rather
    // than fetched the way the web build fetches it: there is no frame loop
    // here to register it into, and a diagram rendered with boxes where the
    // table names should be is not worth writing to disk.
    let mut definitions = draft_view::fonts::definitions();
    if draft_view::fonts::needs_cjk(sql) {
        draft_view::fonts::add_cjk(&mut definitions, draft_view::fonts::CJK_BYTES.to_vec());
    }
    let mut fonts = Fonts::new(
        TextOptions {
            max_texture_side: 8192,
            ..Default::default()
        },
        definitions,
    );
    let mut view = fonts.with_pixels_per_point(1.0);
    let styles = TextStyles::default();

    let sizes = draft_view::measure(schema, &mut view, &styles);
    let placed = draft_layout::layout(schema, &sizes, &args.options);
    // Text is laid out at the scale it will be rasterised at, so the raster
    // path builds its own shapes rather than scaling the vector ones.
    let scale = if args.png { PNG_SCALE } else { 1.0 };
    let shapes = draft_view::shapes(schema, &placed, &args.theme, &styles, scale, &mut view);
    let size = Vec2::new(placed.size.w, placed.size.h) * scale;

    if args.png {
        return draft_export::png(
            &shapes,
            size,
            args.theme.background,
            MARGIN * scale,
            &mut view,
        )
        .map(Output::Bytes);
    }
    Ok(Output::Text(draft_export::svg(
        &shapes,
        size,
        args.theme.background,
        MARGIN,
    )))
}

/// Warnings go to stderr so they never contaminate a redirected diagram.
fn report(schema: &Schema) {
    for warning in &schema.warnings {
        match warning.span {
            Some(span) => eprintln!("warning: {} (byte {})", warning.message, span.start),
            None => eprintln!("warning: {}", warning.message),
        }
    }
    let dangling = schema.relations.iter().filter(|r| r.to_missing).count();
    if dangling > 0 {
        eprintln!(
            "warning: {dangling} foreign key(s) reference tables this script does not define"
        );
    }
    if schema.tables.is_empty() {
        eprintln!("warning: no CREATE TABLE statements were found");
    }
}

fn write_out(path: Option<&str>, body: &Output) -> Result<(), String> {
    let bytes = match body {
        Output::Text(text) => text.as_bytes(),
        Output::Bytes(bytes) => bytes.as_slice(),
    };
    match path {
        Some(path) => std::fs::write(path, bytes).map_err(|e| format!("cannot write {path}: {e}")),
        None => std::io::stdout()
            .write_all(bytes)
            .map_err(|e| format!("cannot write to stdout: {e}")),
    }
}

fn parse_args(argv: &[String]) -> Result<Args, String> {
    let mut rest = argv.iter();
    match rest.next().map(String::as_str) {
        Some("render") => {}
        Some(other) => return Err(format!("unknown command {other:?}; try --help")),
        None => return Err("nothing to do; try --help".into()),
    }

    let mut args = Args {
        input: String::new(),
        output: None,
        options: Options::default(),
        theme: Theme::light(),
        png: false,
        json: false,
        quiet: false,
    };

    while let Some(arg) = rest.next() {
        let mut value = |flag: &str| {
            rest.next()
                .cloned()
                .ok_or_else(|| format!("{flag} needs a value"))
        };
        match arg.as_str() {
            "-o" | "--output" => args.output = Some(value("--output")?),
            "--dir" => {
                args.options.direction = match value("--dir")?.as_str() {
                    "horizontal" | "h" => Direction::Horizontal,
                    "vertical" | "v" => Direction::Vertical,
                    other => return Err(format!("unknown direction {other:?}")),
                }
            }
            "--spacing" => {
                args.options.spacing = match value("--spacing")?.as_str() {
                    "compact" => Spacing::Compact,
                    "comfortable" => Spacing::Comfortable,
                    "spacious" => Spacing::Spacious,
                    other => return Err(format!("unknown spacing {other:?}")),
                }
            }
            "--theme" => {
                args.theme = match value("--theme")?.as_str() {
                    "light" => Theme::light(),
                    "dark" => Theme::dark(),
                    other => return Err(format!("unknown theme {other:?}")),
                }
            }
            "--png" => args.png = true,
            "--json" => args.json = true,
            "-q" | "--quiet" => args.quiet = true,
            other if other.starts_with('-') => return Err(format!("unknown option {other:?}")),
            other if args.input.is_empty() => args.input = other.to_owned(),
            other => return Err(format!("unexpected argument {other:?}")),
        }
    }

    if args.input.is_empty() {
        return Err("no input file; try --help".into());
    }
    Ok(args)
}
