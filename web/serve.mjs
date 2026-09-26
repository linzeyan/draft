// A static server for crates/app/dist, shared by the browser measurements.
//
// Brotli-aware on purpose: a CDN serves the wasm compressed, so a cold-load
// measurement against an uncompressed 4.3 MB file would be measuring a
// deployment nobody will ever make.

import { createServer } from "node:http";
import { readdir, readFile } from "node:fs/promises";
import { extname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { brotliCompress, constants } from "node:zlib";
import { promisify } from "node:util";

const compress = promisify(brotliCompress);

export const DIST = resolve(fileURLToPath(new URL(".", import.meta.url)), "../crates/app/dist");

const MIME = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".mjs": "text/javascript",
  ".wasm": "application/wasm",
  ".css": "text/css",
  ".ttf": "font/ttf",
  ".sql": "text/plain",
};

/// Start a server on an ephemeral port. Returns `{ port, close }`.
///
/// `dir` so that the DOM front end's bundle is measured by the same server the
/// canvas build is measured by: two static servers would be two sets of
/// headers, and the brotli behaviour above is part of what is being measured.
export async function serveDist({ brotli = true, dir = DIST } = {}) {
  const cache = new Map();

  // Compressing 4 MB of wasm at quality 11 takes seconds. Doing it lazily on
  // the first request made the first cold-load measurement 6.8 s and every
  // later one 0.5 s — an artefact of the harness that looked exactly like a
  // real first-visit penalty. Pay it up front, before anything is timed.
  async function warm() {
    for (const name of await readdir(dir)) {
      for (const encoded of brotli ? [true, false] : [false]) {
        await body(join(dir, name), encoded);
      }
    }
  }

  async function body(file, wantsBrotli) {
    const key = `${file}|${wantsBrotli}`;
    if (!cache.has(key)) {
      const raw = await readFile(file);
      cache.set(
        key,
        wantsBrotli
          ? await compress(raw, { params: { [constants.BROTLI_PARAM_QUALITY]: 11 } })
          : raw,
      );
    }
    return cache.get(key);
  }

  // Trunk emits a hashed bundle; serving dist/ verbatim keeps the harness
  // independent of those names.
  const server = createServer(async (req, res) => {
    const path = decodeURIComponent(req.url.split("?")[0].split("#")[0]);
    const file = join(dir, path === "/" ? "index.html" : path);
    const wantsBrotli = brotli && (req.headers["accept-encoding"] ?? "").includes("br");
    try {
      const payload = await body(file, wantsBrotli);
      res.writeHead(200, {
        "content-type": MIME[extname(file)] ?? "application/octet-stream",
        "content-length": payload.length,
        ...(wantsBrotli ? { "content-encoding": "br" } : {}),
        // No caching: every measurement here is meant to be a cold one.
        "cache-control": "no-store",
      });
      res.end(payload);
    } catch {
      res.writeHead(404).end("not found");
    }
  });

  await warm();
  const port = await new Promise((ok) => {
    server.listen(0, "127.0.0.1", () => ok(server.address().port));
  });
  return { port, close: () => server.close() };
}
