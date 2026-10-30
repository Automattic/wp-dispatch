// Renders each website demo scene in headless Chromium at 1:1 and records where every
// [data-drift] part landed, relative to the panel: <out>/<scene>.json and <scene>.png.
// Usage: node measure.mjs <repo> <out> <scene>…
import { createRequire } from "module";
import http from "http";
import fs from "fs";
import path from "path";
import os from "os";

const [repo, out, ...scenes] = process.argv.slice(2);
function playwright() {
  for (const from of [import.meta.url, path.join(os.homedir(), ".cache/pr-screenshots/")]) {
    try { return createRequire(from)("playwright"); } catch {}
  }
  console.error("Playwright isn't installed. Run: (cd tools/drift && npm install && npx playwright install chromium-headless-shell)");
  process.exit(2);
}
const { chromium } = playwright();

const types = { ".html": "text/html", ".css": "text/css", ".js": "text/javascript", ".json": "application/json" };
const server = http.createServer((req, res) => {
  const file = path.join(repo, decodeURIComponent(new URL(req.url, "http://x").pathname));
  if (!file.startsWith(repo) || !fs.existsSync(file)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { "content-type": types[path.extname(file)] || "application/octet-stream" });
  fs.createReadStream(file).pipe(res);
}).listen(0, "127.0.0.1");
await new Promise((ok) => server.on("listening", ok));
const base = `http://127.0.0.1:${server.address().port}`;

fs.mkdirSync(out, { recursive: true });
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1000, height: 700 }, deviceScaleFactor: 2, colorScheme: "light", reducedMotion: "reduce" });
for (const scene of scenes) {
  await page.goto(`${base}/tools/drift/stage.html?scene=${scene}`);
  await page.waitForSelector(".sim-row");
  await page.waitForTimeout(600);
  const doc = await page.evaluate(() => {
    const panel = document.querySelector(".sim-panel").getBoundingClientRect();
    const frames = {};
    for (const el of document.querySelectorAll("[data-drift]")) {
      const r = el.getBoundingClientRect();
      if (!r.width || !r.height || r.right <= panel.left + 1 || r.left >= panel.right - 1) continue; // hidden, or clipped out
      const round = (v) => Math.round(v * 10) / 10;
      frames[el.dataset.drift] = [round(r.left - panel.left), round(r.top - panel.top), round(r.width), round(r.height)];
    }
    return { width: panel.width, height: panel.height, box: [panel.left, panel.top, panel.width, panel.height], frames };
  });
  const [x, y, width, height] = doc.box;
  await page.screenshot({ path: path.join(out, `${scene}.png`), clip: { x, y, width, height } });
  delete doc.box;
  fs.writeFileSync(path.join(out, `${scene}.json`), JSON.stringify(doc, null, 2));
}
await browser.close();
server.close();
