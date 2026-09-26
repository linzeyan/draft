//! The two things that are genuinely different between a browser tab and a
//! desktop window: opening a file, and where start-up arguments come from.
//!
//! Everything else in this application is the same code on both targets. These
//! functions exist so that stays true.

use std::cell::RefCell;
use std::rc::Rc;

pub struct Loaded {
    pub name: String,
    pub text: String,
}

/// How big a fetched schema may be.
///
/// Not a security boundary — it is the user's own link — but a browser tab that
/// silently pulls a 400 MB dump and then dies is worse than one that says no.
/// Eight megabytes is thirty times the size at which the editor is documented
/// to drop frames.
#[cfg(target_arch = "wasm32")]
const MAX_FETCH: f64 = 8.0 * 1024.0 * 1024.0;

/// A file dialog that hands its result back through a slot rather than a
/// return value, because on the web the dialog is asynchronous and there is no
/// value to return yet when it opens.
///
/// [`FilePicker::fetch`] shares the slot: a URL is another door text arrives
/// through, and putting it here means a fetched `.draft.json` is recognised
/// as a project exactly the way a dropped one is.
#[derive(Default, Clone)]
pub struct FilePicker {
    slot: Rc<RefCell<Option<Loaded>>>,
    /// Why the last attempt produced nothing. Only a fetch fills this in: a
    /// cancelled dialog is not a failure, but a link that does not open is,
    /// and the person who followed it is owed the reason.
    problem: Rc<RefCell<Option<String>>>,
}

impl FilePicker {
    pub fn take(&self) -> Option<Loaded> {
        self.slot.borrow_mut().take()
    }

    pub fn take_problem(&self) -> Option<String> {
        self.problem.borrow_mut().take()
    }

    #[cfg(not(target_arch = "wasm32"))]
    pub fn open(&self) {
        // Blocking, on the UI thread, on purpose. It is a modal dialog: there
        // is nothing for the window behind it to do, and the alternative — a
        // worker thread — has to marshal back to the main thread on macOS
        // anyway.
        // Projects as well as schemas: `Open…` reads both, and a filter that
        // greys out the `.draft.json` this application just wrote is a dialog
        // arguing with its own Save.
        let Some(path) = rfd::FileDialog::new()
            .add_filter("Schemas and projects", &["sql", "ddl", "txt", "json"])
            .pick_file()
        else {
            return;
        };
        if let Ok(text) = std::fs::read_to_string(&path) {
            let name = path
                .file_name()
                .map(|n| n.to_string_lossy().into_owned())
                .unwrap_or_else(|| path.display().to_string());
            *self.slot.borrow_mut() = Some(Loaded { name, text });
        }
    }

    #[cfg(target_arch = "wasm32")]
    pub fn open(&self) {
        use wasm_bindgen::JsCast as _;
        use wasm_bindgen::closure::Closure;

        let Some(document) = web_sys::window().and_then(|w| w.document()) else {
            return;
        };
        let Ok(input) = document.create_element("input") else {
            return;
        };
        let input: web_sys::HtmlInputElement = input.unchecked_into();
        input.set_type("file");
        input.set_accept(".sql,.ddl,.txt,.json,text/plain,application/json");

        let slot = self.slot.clone();
        let source = input.clone();
        let on_change = Closure::<dyn FnMut()>::new(move || {
            let Some(file) = source.files().and_then(|f| f.get(0)) else {
                return;
            };
            let Ok(reader) = web_sys::FileReader::new() else {
                return;
            };
            let name = file.name();
            let slot = slot.clone();
            let done = reader.clone();
            let on_load = Closure::<dyn FnMut()>::new(move || {
                if let Some(text) = done.result().ok().and_then(|v| v.as_string()) {
                    *slot.borrow_mut() = Some(Loaded {
                        name: name.clone(),
                        text,
                    });
                }
            });
            reader.set_onload(Some(on_load.as_ref().unchecked_ref()));
            // The closure has to outlive this scope to be callable at all, and
            // the element it belongs to is dropped by the browser once the
            // dialog closes. One small leak per file opened, by hand, is the
            // price of the platform's callback model.
            on_load.forget();
            let _ = reader.read_as_text(&file);
        });
        input.set_onchange(Some(on_change.as_ref().unchecked_ref()));
        on_change.forget();
        input.click();
    }
}

impl FilePicker {
    /// Take a file dropped onto the window. Reading it is synchronous on the
    /// desktop and asynchronous in a browser, which is the whole reason the
    /// result comes back through the slot rather than as a return value.
    #[cfg(not(target_arch = "wasm32"))]
    pub fn accept_drop(&self, file: egui::DroppedFileHandle) {
        let name = file
            .path()
            .file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_else(|| "dropped.sql".to_owned());
        if let Ok(bytes) = file.bytes()
            && let Ok(text) = String::from_utf8(bytes)
        {
            *self.slot.borrow_mut() = Some(Loaded { name, text });
        }
    }

    #[cfg(target_arch = "wasm32")]
    pub fn accept_drop(&self, file: egui::DroppedFileHandle) {
        let name = file
            .path()
            .file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_else(|| "dropped.sql".to_owned());
        let slot = self.slot.clone();
        wasm_bindgen_futures::spawn_local(async move {
            if let Ok(bytes) = file.bytes_async().await
                && let Ok(text) = String::from_utf8(bytes)
            {
                *slot.borrow_mut() = Some(Loaded { name, text });
            }
        });
    }
}

impl FilePicker {
    /// Open a schema from a URL — the `#u=` start-up form, and what a pasted
    /// link means.
    ///
    /// The one request this application makes that leaves its own origin, and it
    /// only ever happens because somebody asked for it. That makes CORS the
    /// governing fact rather than an inconvenience: a raw host that sends
    /// `access-control-allow-origin` works, and one that does not cannot be made
    /// to. Proxying around it would mean running a server, which would cost the
    /// property this whole application is arranged around.
    #[cfg(target_arch = "wasm32")]
    pub fn fetch(&self, url: &str) {
        use wasm_bindgen::JsCast as _;
        use wasm_bindgen_futures::JsFuture;

        let (slot, problem) = (self.slot.clone(), self.problem.clone());
        let url = url.to_owned();
        wasm_bindgen_futures::spawn_local(async move {
            let report = |message: String| {
                warn(&message);
                *problem.borrow_mut() = Some(message);
            };
            let Some(window) = web_sys::window() else {
                return;
            };
            let Ok(response) = JsFuture::from(window.fetch_with_str(&url)).await else {
                // A CORS refusal and a dead host are the same opaque failure
                // here: the browser deliberately tells a page nothing about a
                // response it was not allowed to read. So the message has to
                // cover both, and name the fix for the common one.
                return report(format!(
                    "cannot read {url}\n\nThe host either does not exist or does not allow \
                     browsers to read it from another site. A raw file URL usually works \
                     where a repository page does not."
                ));
            };
            let response: web_sys::Response = response.unchecked_into();
            if !response.ok() {
                return report(format!(
                    "{url}\n\nThe server answered {}.",
                    response.status()
                ));
            }
            if let Some(size) = response
                .headers()
                .get("content-length")
                .ok()
                .flatten()
                .and_then(|v| v.parse::<f64>().ok())
                && size > MAX_FETCH
            {
                return report(format!(
                    "{url}\n\nThat file is {:.0} MB, which is too big to open here.",
                    size / 1024.0 / 1024.0
                ));
            }
            let Ok(text) = response.text() else {
                return report(format!("{url}\n\nThe response had no body."));
            };
            let Ok(text) = JsFuture::from(text).await else {
                return report(format!("{url}\n\nThe body did not arrive."));
            };
            let Some(text) = text.as_string() else {
                return report(format!("{url}\n\nThat is not text."));
            };
            *slot.borrow_mut() = Some(Loaded {
                name: file_name(&url),
                text,
            });
        });
    }

    /// The desktop has no HTTP client, and adding one to follow a link would be
    /// a dependency and a network permission for a gesture the file dialog and
    /// drag-and-drop already cover. Say so rather than appearing to hang.
    #[cfg(not(target_arch = "wasm32"))]
    pub fn fetch(&self, url: &str) {
        *self.problem.borrow_mut() = Some(format!(
            "{url}\n\nOpening a URL works in the browser version. Here, save the file \
             and drop it on the window."
        ));
    }
}

/// The last path segment of a URL, for naming the document after the file
/// somebody pointed at rather than after the whole link.
///
/// Only the fetch calls it, but it is compiled everywhere so the test suite —
/// which runs natively — covers it.
#[cfg_attr(not(target_arch = "wasm32"), allow(dead_code))]
fn file_name(url: &str) -> String {
    let path = url.split(['?', '#']).next().unwrap_or(url);
    let last = path.rsplit('/').find(|part| !part.is_empty());
    last.unwrap_or("schema.sql").to_owned()
}

/// Whether a piece of text is a link to fetch rather than a schema to read.
///
/// Deliberately strict: one line, no whitespace, an explicit http scheme. A
/// pasted script that merely *mentions* a URL in a comment has to keep being a
/// script.
pub fn looks_like_url(text: &str) -> bool {
    let text = text.trim();
    (text.starts_with("http://") || text.starts_with("https://"))
        && !text.contains(char::is_whitespace)
}

/// The CJK face, on its way.
///
/// The same slot-rather-than-return-value shape as [`FilePicker`], for the same
/// reason: in a browser the bytes arrive later. The desktop fills the slot
/// immediately — the face is compiled into the binary there, because a desktop
/// application with no network is still expected to draw a Chinese schema.
#[derive(Default, Clone)]
pub struct FontFetch {
    slot: Rc<RefCell<Option<Vec<u8>>>>,
}

impl FontFetch {
    pub fn take(&self) -> Option<Vec<u8>> {
        self.slot.borrow_mut().take()
    }

    #[cfg(not(target_arch = "wasm32"))]
    pub fn request(&self) {
        *self.slot.borrow_mut() = Some(draft_view::fonts::CJK_BYTES.to_vec());
    }

    #[cfg(target_arch = "wasm32")]
    pub fn request(&self) {
        use wasm_bindgen::JsCast as _;
        use wasm_bindgen_futures::JsFuture;

        let slot = self.slot.clone();
        wasm_bindgen_futures::spawn_local(async move {
            // Relative, so it resolves against whatever path the app is served
            // from — the site puts it at `/app/`, `trunk serve` at `/`.
            let url = draft_view::fonts::CJK_FILE;
            let Some(window) = web_sys::window() else {
                return;
            };
            let Ok(response) = JsFuture::from(window.fetch_with_str(url)).await else {
                return warn(&format!("cannot fetch {url}"));
            };
            let response: web_sys::Response = response.unchecked_into();
            if !response.ok() {
                return warn(&format!("{url}: HTTP {}", response.status()));
            }
            let Ok(buffer) = response.array_buffer() else {
                return warn(&format!("{url}: no body"));
            };
            let Ok(buffer) = JsFuture::from(buffer).await else {
                return warn(&format!("{url}: body did not arrive"));
            };
            *slot.borrow_mut() = Some(js_sys::Uint8Array::new(&buffer).to_vec());
        });
    }
}

/// Say so, rather than quietly drawing boxes. A failed font fetch leaves the
/// application working and the text unreadable, which is exactly the kind of
/// failure that has to be findable.
#[cfg(target_arch = "wasm32")]
fn warn(message: &str) {
    web_sys::console::warn_1(&format!("draft: {message}").into());
}

/// Hand a file to the user under `name`.
///
/// A save dialog on the desktop and a download in the browser, which are the
/// same gesture wearing different clothes. Failure is reported and dropped:
/// there is nothing the application can do about a cancelled dialog, and
/// nothing it should do about one.
#[cfg(not(target_arch = "wasm32"))]
pub fn download(name: &str, bytes: Vec<u8>, _mime: &str) {
    let Some(path) = rfd::FileDialog::new().set_file_name(name).save_file() else {
        return;
    };
    if let Err(e) = std::fs::write(&path, bytes) {
        eprintln!("draft: cannot write {}: {e}", path.display());
    }
}

#[cfg(target_arch = "wasm32")]
pub fn download(name: &str, bytes: Vec<u8>, mime: &str) {
    use wasm_bindgen::JsCast as _;

    let Some(document) = web_sys::window().and_then(|w| w.document()) else {
        return;
    };
    // A `Uint8Array` view over wasm memory would be invalidated by any
    // allocation before `Blob` copies it, so the bytes are handed over as an
    // owned JS array.
    let array = js_sys::Uint8Array::from(bytes.as_slice());
    let parts = js_sys::Array::of1(&array);
    let options = web_sys::BlobPropertyBag::new();
    options.set_type(mime);
    let Ok(blob) = web_sys::Blob::new_with_u8_array_sequence_and_options(&parts, &options) else {
        return;
    };
    let Ok(url) = web_sys::Url::create_object_url_with_blob(&blob) else {
        return;
    };
    if let Ok(anchor) = document.create_element("a") {
        let anchor: web_sys::HtmlAnchorElement = anchor.unchecked_into();
        anchor.set_href(&url);
        anchor.set_download(name);
        anchor.click();
    }
    // The blob is held alive by the download the click started; the handle is
    // ours to release, and not releasing it leaks the whole file.
    let _ = web_sys::Url::revoke_object_url(&url);
}

/// A link that will open this project again.
///
/// On the web that is this page with a new fragment. On the desktop there is no
/// page to point at, so the fragment travels alone — it is still the payload,
/// and it still opens when appended to wherever the app is hosted.
#[cfg(not(target_arch = "wasm32"))]
pub fn share_url(fragment: &str) -> String {
    fragment.to_owned()
}

#[cfg(target_arch = "wasm32")]
pub fn share_url(fragment: &str) -> String {
    let Some(location) = web_sys::window().map(|w| w.location()) else {
        return fragment.to_owned();
    };
    let origin = location.origin().unwrap_or_default();
    let path = location.pathname().unwrap_or_default();
    format!("{origin}{path}{fragment}")
}

/// Put the fragment in the address bar without reloading or adding a history
/// entry, so the link in the URL bar is the link the Share button just copied.
#[cfg(not(target_arch = "wasm32"))]
pub fn set_fragment(_fragment: &str) {}

#[cfg(target_arch = "wasm32")]
pub fn set_fragment(fragment: &str) {
    if let Some(history) = web_sys::window().and_then(|w| w.history().ok()) {
        let _ = history.replace_state_with_url(&wasm_bindgen::JsValue::NULL, "", Some(fragment));
    }
}

/// Put the schema's text into the page, replacing whatever was there.
///
/// Web only, and not because the desktop build cannot do it: on the desktop
/// egui's AccessKit integration is real and works, so there is a proper
/// accessibility tree already. It is the web target that has neither — see
/// [`crate::mirror`].
#[cfg(not(target_arch = "wasm32"))]
pub fn mirror_schema(_html: &str) {}

#[cfg(target_arch = "wasm32")]
pub fn mirror_schema(html: &str) {
    let element = web_sys::window()
        .and_then(|w| w.document())
        .and_then(|d| d.get_element_by_id(MIRROR_ID));
    // Missing rather than empty is possible — `index.html` is the only place
    // that declares it — and is not worth a message on every re-parse.
    if let Some(element) = element {
        element.set_inner_html(html);
    }
}

/// The element `index.html` declares for [`mirror_schema`] to write into.
#[cfg(target_arch = "wasm32")]
const MIRROR_ID: &str = "schema";

/// A measurement run, which replaces the interactive application entirely.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum BenchKind {
    /// Sweep the camera across a schema of `tables` tables.
    Canvas { tables: usize, frames: usize },
    /// Type into a document of `kb` kilobytes.
    Typing { kb: usize, frames: usize },
}

/// How the application was started.
#[derive(Debug, Default, PartialEq)]
pub struct Startup {
    /// A schema to open instead of the sample.
    pub file: Option<String>,
    /// A share link's payload, still compressed. Decoding it needs no window,
    /// but keeping it encoded here keeps this struct free of the project format.
    pub project: Option<String>,
    /// A schema to fetch, from `#u=`. Ignored when `project` is set: a share
    /// link carries a whole project and a URL is only a pointer to a script, so
    /// a link that somehow has both means the complete thing.
    pub url: Option<String>,
    pub bench: Option<BenchKind>,
}

impl Startup {
    /// Parse `key=value` pairs, comma separated, as they appear in a URL
    /// fragment.
    ///
    /// The fragment is never sent to a server, which is also how share links
    /// will carry a whole schema later.
    ///
    /// Only the web entry point calls this, but it is compiled everywhere so
    /// that the test suite — which runs natively — covers it.
    #[cfg_attr(not(target_arch = "wasm32"), allow(dead_code))]
    pub fn from_fragment(fragment: &str) -> Self {
        let mut out = Self::default();
        for part in fragment.trim_start_matches('#').split('&') {
            let Some((key, value)) = part.split_once('=') else {
                continue;
            };
            match key {
                "bench" => {
                    out.bench =
                        parse_bench(&value.split(',').map(str::to_owned).collect::<Vec<_>>());
                }
                // `p1` rather than `p`: the number is the payload format, so a
                // later encoding can be told from a corrupt link rather than
                // producing a diagram that is subtly wrong.
                "p1" => out.project = Some(value.to_owned()),
                // Percent-decoded, because a URL is not a fragment field: it
                // carries `/`, `:` and sometimes `&`, and the last of those has
                // to be written `%26` or it would end the field early.
                "u" => out.url = Some(percent_decode(value)),
                _ => {}
            }
        }
        out
    }

    /// `draft-app [schema.sql] [--bench canvas|type <n> <frames>]`
    ///
    /// Compiled on both targets for the same reason as [`Self::from_fragment`].
    #[cfg_attr(target_arch = "wasm32", allow(dead_code))]
    pub fn from_args(args: &[String]) -> Self {
        let mut out = Self::default();
        let mut rest = args.iter();
        while let Some(arg) = rest.next() {
            match arg.as_str() {
                "--bench" => {
                    out.bench = parse_bench(&rest.by_ref().take(3).cloned().collect::<Vec<_>>());
                }
                other if !other.starts_with('-') && out.file.is_none() => {
                    out.file = Some(other.to_owned());
                }
                _ => {}
            }
        }
        out
    }
}

/// `%XX` back to bytes, and nothing else.
///
/// Hand-written rather than a dependency: this decodes one field of one URL at
/// start-up, and `percent-encoding` would be a crate in the payload for thirty
/// lines of work. A malformed escape is left as written — the URL is about to be
/// handed to the browser, which is entitled to reject it with a better message
/// than this could invent.
fn percent_decode(text: &str) -> String {
    let bytes = text.as_bytes();
    let mut out: Vec<u8> = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        let hex = (i + 2 < bytes.len())
            .then(|| std::str::from_utf8(&bytes[i + 1..i + 3]).ok())
            .flatten()
            .and_then(|pair| u8::from_str_radix(pair, 16).ok());
        match hex {
            Some(byte) if bytes[i] == b'%' => {
                out.push(byte);
                i += 3;
            }
            _ => {
                out.push(bytes[i]);
                i += 1;
            }
        }
    }
    String::from_utf8(out).unwrap_or_else(|_| text.to_owned())
}

/// `<mode>,<size>,<frames>`, every part optional. A mistyped or truncated
/// request still has to run *something*, or a broken harness invocation
/// silently starts the interactive application and then hangs waiting for a
/// result that will never come.
fn parse_bench(parts: &[String]) -> Option<BenchKind> {
    let mode = parts.first().map(String::as_str).unwrap_or("canvas");
    let size = parts.get(1).and_then(|s| s.parse().ok());
    let frames = parts.get(2).and_then(|s| s.parse().ok()).unwrap_or(600);
    Some(match mode {
        "type" | "typing" | "editor" => BenchKind::Typing {
            kb: size.unwrap_or(106),
            frames,
        },
        _ => BenchKind::Canvas {
            tables: size.unwrap_or(1000),
            frames,
        },
    })
}

/// Where a finished measurement goes on this target.
#[cfg(not(target_arch = "wasm32"))]
pub fn report(line: &str) {
    println!("{line}");
}

#[cfg(target_arch = "wasm32")]
pub fn report(line: &str) {
    // The browser harness scrapes console output for this prefix.
    web_sys::console::log_1(&format!("RESULT {line}").into());
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_file_argument_and_a_bench_request_are_told_apart() {
        assert_eq!(
            Startup::from_args(&["schema.sql".into()]),
            Startup {
                file: Some("schema.sql".into()),
                ..Startup::default()
            }
        );
        assert_eq!(
            Startup::from_args(&[
                "--bench".into(),
                "canvas".into(),
                "300".into(),
                "200".into()
            ]),
            Startup {
                bench: Some(BenchKind::Canvas {
                    tables: 300,
                    frames: 200
                }),
                ..Startup::default()
            }
        );
        assert_eq!(
            Startup::from_fragment("#bench=canvas,1000,600").bench,
            Some(BenchKind::Canvas {
                tables: 1000,
                frames: 600
            })
        );
        assert_eq!(
            Startup::from_fragment("#bench=type,106,400").bench,
            Some(BenchKind::Typing {
                kb: 106,
                frames: 400
            })
        );
    }

    /// A bench request with nothing after it still has to mean something, or a
    /// mistyped harness invocation silently runs the interactive app instead.
    #[test]
    fn bench_defaults_rather_than_disappearing() {
        let canvas = Some(BenchKind::Canvas {
            tables: 1000,
            frames: 600,
        });
        assert_eq!(Startup::from_args(&["--bench".into()]).bench, canvas);
        assert_eq!(Startup::from_fragment("#bench=").bench, canvas);
        assert_eq!(
            Startup::from_fragment("#bench=type").bench,
            Some(BenchKind::Typing {
                kb: 106,
                frames: 600
            })
        );
    }

    /// The `#u=` form, which is how a schema on somebody else's server becomes
    /// a link to this application. The URL has to survive the trip intact in
    /// both spellings people will write it in.
    #[test]
    fn a_url_fragment_asks_for_the_schema_it_names() {
        const RAW: &str = "https://raw.githubusercontent.com/o/r/main/db/schema.sql";
        assert_eq!(
            Startup::from_fragment(&format!("#u={RAW}")).url.as_deref(),
            Some(RAW),
            "a URL pasted in as-is"
        );
        assert_eq!(
            Startup::from_fragment("#u=https%3A%2F%2Fex.com%2Fa.sql%3Fv%3D1%26t%3D2")
                .url
                .as_deref(),
            Some("https://ex.com/a.sql?v=1&t=2"),
            "an encoded URL, which is the only way to carry an ampersand"
        );
        // A complete project beats a pointer to a script.
        let both = Startup::from_fragment(&format!("#p1=abc&u={RAW}"));
        assert_eq!(both.project.as_deref(), Some("abc"));
        assert_eq!(both.url.as_deref(), Some(RAW));
        assert_eq!(Startup::from_fragment("#bench=canvas").url, None);
    }

    /// A pasted link is fetched and a pasted script is parsed, and telling them
    /// apart wrongly means either a script that vanishes or a diagram of one
    /// line of text.
    #[test]
    fn a_pasted_link_is_told_from_a_pasted_schema() {
        assert!(looks_like_url("https://example.com/schema.sql"));
        assert!(looks_like_url("  http://example.com/a.sql\n"));
        assert!(!looks_like_url("CREATE TABLE t (id int);"));
        assert!(!looks_like_url(
            "-- see https://example.com/a.sql\nCREATE TABLE t (id int);"
        ));
        assert!(!looks_like_url("ftp://example.com/a.sql"));
        assert!(!looks_like_url(""));
    }

    /// The document is named after the file, not after the link — a status bar
    /// reading `https://raw.githubusercontent.com/…` tells nobody anything.
    #[test]
    fn a_fetched_schema_is_named_after_its_file() {
        assert_eq!(file_name("https://x.dev/a/b/schema.sql"), "schema.sql");
        assert_eq!(
            file_name("https://x.dev/a/b/schema.sql?raw=1"),
            "schema.sql"
        );
        assert_eq!(file_name("https://x.dev/a/"), "a");
        assert_eq!(file_name("https://x.dev"), "x.dev");
    }

    #[test]
    fn an_unrelated_fragment_is_not_a_bench_run() {
        assert_eq!(Startup::from_fragment("#p1=abc123").bench, None);
        assert_eq!(Startup::from_fragment("").bench, None);
    }

    /// A share link is the one fragment a user will ever see, and it has to
    /// arrive whole — a payload split on its own `=` or `&` would decode to
    /// nothing with no way to tell why.
    #[test]
    fn a_share_link_carries_its_payload_intact() {
        let payload = crate::share::encode(crate::sample::DEFAULT.sql);
        let fragment = format!("#p1={payload}");
        assert_eq!(
            Startup::from_fragment(&fragment).project.as_deref(),
            Some(payload.as_str())
        );
        assert_eq!(Startup::from_fragment("#bench=canvas").project, None);
    }
}
