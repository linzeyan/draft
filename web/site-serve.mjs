// Serve web/dist the way a static host would, so the landing pages and the
// application can be checked in one place before a deploy.
//
// Directory URLs resolve to index.html, which is what every static host does
// and what the generated links assume. Without that, /privacy/ is a 404 here
// and a page in production — the worst kind of difference to find late.
//
// Run: make site-serve   (or: node web/site-serve.mjs [port])

import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { extname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const DIST = resolve(fileURLToPath(new URL(".", import.meta.url)), "dist");

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript",
  ".wasm": "application/wasm",
  ".css": "text/css",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".xml": "application/xml",
  ".txt": "text/plain; charset=utf-8",
};

/// Start a server on `port`, or an ephemeral one when it is 0.
export async function serveSite(port = 0) {
  const server = createServer(async (req, res) => {
    const path = decodeURIComponent(req.url.split("?")[0].split("#")[0]);
    let file = join(DIST, path);
    try {
      if (((await stat(file).catch(() => null))?.isDirectory() ?? false) || path.endsWith("/")) {
        file = join(file, "index.html");
      }
      const body = await readFile(file);
      res.writeHead(200, {
        "content-type": MIME[extname(file)] ?? "application/octet-stream",
        "content-length": body.length,
        "cache-control": "no-store",
      });
      res.end(body);
    } catch {
      res.writeHead(404, { "content-type": "text/plain" }).end(`not found: ${path}`);
    }
  });

  const bound = await new Promise((ok) => {
    server.listen(port, "127.0.0.1", () => ok(server.address().port));
  });
  return { port: bound, close: () => server.close() };
}

// Only when run directly: web/site-check.mjs imports the function above.
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const { port } = await serveSite(Number(process.argv[2] ?? 8081));
  console.log(`  site:        http://127.0.0.1:${port}/`);
  console.log(`  application: http://127.0.0.1:${port}/app/`);
  console.log("  ctrl-c to stop");
}
