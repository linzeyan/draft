// Serve web/front/dist, so the DOM front end can be looked at by hand.
//
// The same server the measurements use, pointed at the other bundle: a second
// static server would be a second set of headers, and brotli behaviour is part
// of what this bundle is judged on.
//
// Run: make front-serve   (or: node web/serve-front.mjs)

import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { serveDist } from "./serve.mjs";

const dir = resolve(fileURLToPath(new URL(".", import.meta.url)), "front/dist");
const { port } = await serveDist({ dir });
console.log(`http://127.0.0.1:${port}/  (serving ${dir}; ctrl-c to stop)`);
