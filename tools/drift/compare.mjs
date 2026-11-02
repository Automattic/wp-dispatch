// Compares the app's and the website's frames for each scene and writes report.html.
// Exits 1 when anything drifted. Usage: node compare.mjs <dir> <scene>…  (<dir> has app/ and site/)
import fs from "fs";
import path from "path";

const [dir, ...scenes] = process.argv.slice(2);
// Points of slack: layout boxes must match closely; text widths depend on font rendering.
const BOX = 1.5;
const TEXT = /\.(who|title|excerpt|time|foot|line)$|^detail\.pos$|^badge\.|^pills?\b/;
const textSlack = (w) => Math.max(3, w * 0.06);

const read = (side, scene) => JSON.parse(fs.readFileSync(path.join(dir, side, `${scene}.json`), "utf8"));
let total = 0;
const sections = scenes.map((scene) => {
  const app = read("app", scene).frames, site = read("site", scene).frames;
  const rows = [];
  for (const key of [...new Set([...Object.keys(app), ...Object.keys(site)])].sort(natural)) {
    const a = app[key], s = site[key];
    if (!a || !s) { rows.push({ key, a, s, why: a ? "missing on the site" : "only on the site" }); continue; }
    const d = a.map((v, i) => Math.round((s[i] - v) * 10) / 10);
    // A pill after the first sits wherever the text widths before it put it.
    const after = /^pill\.[1-9]/.test(key) ? 3 : BOX;
    const slack = [after, BOX, TEXT.test(key) ? textSlack(a[2]) : BOX, TEXT.test(key) ? 3 : BOX];
    const off = ["x", "y", "width", "height"].filter((_, i) => Math.abs(d[i]) > slack[i]);
    if (off.length) rows.push({ key, a, s, d, why: off.map((k, i) => `${k} ${fmt(d[["x", "y", "width", "height"].indexOf(k)])}`).join(", ") });
  }
  total += rows.length;
  return { scene, rows };
});

function natural(a, b) { return a.localeCompare(b, "en", { numeric: true }); }
function fmt(v) { return (v > 0 ? "+" : "") + v; }
const box = (f, cls) => f ? `<div class="${cls}" style="left:${f[0]}px;top:${f[1]}px;width:${f[2]}px;height:${f[3]}px"></div>` : "";

const html = `<!doctype html><meta charset="utf-8"><title>Dispatch drift</title>
<style>
  body { font: 13px/1.4 -apple-system, sans-serif; margin: 24px; color: #1d1d1f; }
  h1 { font-size: 20px; } h2 { font-size: 15px; margin: 32px 0 8px; } .ok { color: #2f9e72; } .bad { color: #d62e2e; }
  .pair { display: flex; gap: 24px; align-items: flex-start; } .shot { position: relative; box-shadow: 0 0 0 1px #ddd; }
  .shot img { display: block; } .shot p { margin: 0 0 4px; color: #6e6e73; font-weight: 600; }
  .mark { position: absolute; outline: 1.5px solid #d62e2e; background: rgba(214,46,46,.08); pointer-events: none; }
  .shot .frame { position: relative; }
  table { border-collapse: collapse; margin-top: 10px; } td, th { padding: 3px 10px 3px 0; text-align: left; font-variant-numeric: tabular-nums; }
  td:first-child { font-family: ui-monospace, Menlo, monospace; }
</style>
<h1>App vs website demo: ${total ? `<span class="bad">${total} difference${total === 1 ? "" : "s"}</span>` : `<span class="ok">matches</span>`}</h1>
<p>Frames are in points from the panel's top-left. The app is rendered from site/demo-data.json in demo mode; the site is the same scene in headless Chromium.</p>
${sections.map(({ scene, rows }) => `
  <h2>${scene} ${rows.length ? `<span class="bad">· ${rows.length}</span>` : `<span class="ok">· matches</span>`}</h2>
  <div class="pair">
    <div class="shot"><p>App</p><div class="frame"><img src="app/${scene}.png" width="${read("app", scene).width}">${rows.map((r) => box(r.a, "mark")).join("")}</div></div>
    <div class="shot"><p>Website</p><div class="frame"><img src="site/${scene}.png" width="${read("site", scene).width}">${rows.map((r) => box(r.s, "mark")).join("")}</div></div>
  </div>
  ${rows.length ? `<table><tr><th>Part</th><th>Difference (site − app)</th><th>App</th><th>Site</th></tr>
    ${rows.map((r) => `<tr><td>${r.key}</td><td>${r.why}</td><td>${r.a?.join(", ") ?? "—"}</td><td>${r.s?.join(", ") ?? "—"}</td></tr>`).join("")}</table>` : ""}`).join("")}`;
fs.writeFileSync(path.join(dir, "report.html"), html);

for (const { scene, rows } of sections) {
  console.log(`${rows.length ? "✗" : "✓"} ${scene}${rows.length ? `: ${rows.length}` : ""}`);
  for (const r of rows) console.log(`    ${r.key}  ${r.why}`);
}
console.log(total ? `\n${total} difference${total === 1 ? "" : "s"}. Report: ${path.join(dir, "report.html")}` : "\nThe website demo matches the app.");
process.exit(total ? 1 : 0);
