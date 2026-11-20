// Generates the Tuklas Rizal launcher / PWA icons from a single vector
// description, so every density stays pixel-consistent.
//
// Emblem: dark forest-green background (#0B3B17) with a centred gold (#F4C430)
// badge holding a dark globe and magnifying glass.
//
// Run from `mobile_app/`:  node tool/generate_launcher_icon.mjs
import { deflateSync } from 'node:zlib';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const FOREST = [0x0b / 255, 0x3b / 255, 0x17 / 255];
const GOLD = [0xf4 / 255, 0xc4 / 255, 0x30 / 255];
const MASTER = 1024;

/* ------------------------------------------------------------------ PNG ---- */
const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return table;
})();

function crc32(buf) {
  let crc = 0xffffffff;
  for (let i = 0; i < buf.length; i++) {
    crc = CRC_TABLE[(crc ^ buf[i]) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const out = Buffer.alloc(data.length + 12);
  out.writeUInt32BE(data.length, 0);
  out.write(type, 4, 'ascii');
  data.copy(out, 8);
  out.writeUInt32BE(crc32(out.subarray(4, 8 + data.length)), 8 + data.length);
  return out;
}

function encodePng(width, height, rgba) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // RGBA
  const raw = Buffer.alloc((width * 4 + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (width * 4 + 1)] = 0; // no filter
    Buffer.from(rgba.buffer, rgba.byteOffset + y * width * 4, width * 4).copy(
      raw,
      y * (width * 4 + 1) + 1,
    );
  }
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

/* --------------------------------------------------------------- raster ---- */
// Signed distance helpers all work in pixels and return pixel distances, so a
// coverage of `0.5 - d` gives one-pixel-wide analytic antialiasing.
const circle = (cx, cy, r) => (x, y) => Math.hypot(x - cx, y - cy) - r;
const ring = (cx, cy, r, hw) => (x, y) => Math.abs(Math.hypot(x - cx, y - cy) - r) - hw;

const ellipseRing = (cx, cy, rx, ry, hw) => (x, y) => {
  const dx = x - cx;
  const dy = y - cy;
  const f = (dx / rx) ** 2 + (dy / ry) ** 2;
  const grad = 2 * Math.hypot(dx / (rx * rx), dy / (ry * ry));
  if (grad < 1e-6) return -hw; // exact centre: inside the stroke band
  return Math.abs(f - 1) / grad - hw;
};

const capsule = (x1, y1, x2, y2, hw) => (x, y) => {
  const vx = x2 - x1;
  const vy = y2 - y1;
  const len2 = vx * vx + vy * vy;
  const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, ((x - x1) * vx + (y - y1) * vy) / len2));
  return Math.hypot(x - (x1 + t * vx), y - (y1 + t * vy)) - hw;
};

function paint(canvas, size, color, dist) {
  const [r, g, b] = color;
  for (let y = 0; y < size; y++) {
    const py = y + 0.5;
    const row = y * size * 4;
    for (let x = 0; x < size; x++) {
      const d = dist(x + 0.5, py);
      if (d >= 0.5) continue;
      const cov = d <= -0.5 ? 1 : 0.5 - d;
      const i = row + x * 4;
      const da = canvas[i + 3];
      const na = cov + da * (1 - cov);
      canvas[i] = (r * cov + canvas[i] * da * (1 - cov)) / na;
      canvas[i + 1] = (g * cov + canvas[i + 1] * da * (1 - cov)) / na;
      canvas[i + 2] = (b * cov + canvas[i + 2] * da * (1 - cov)) / na;
      canvas[i + 3] = na;
    }
  }
}

/**
 * Draws the emblem inside a gold badge of radius `badgeR` (normalised units).
 * Geometry was laid out for a 0.315 badge radius and scales with it.
 */
function drawBadge(canvas, size, badgeR) {
  const s = size;
  const k = badgeR / 0.315;
  const u = (v) => (0.5 + (v - 0.5) * k) * s;
  const px = (v) => v * k * s;

  const globeC = u(0.3985);
  const lensC = u(0.5565);

  paint(canvas, size, GOLD, circle(u(0.5), u(0.5), px(0.315)));

  // Globe: outer circle plus one vertical and one horizontal meridian.
  paint(canvas, size, FOREST, ring(globeC, globeC, px(0.112), px(0.0115)));
  paint(canvas, size, FOREST, ellipseRing(globeC, globeC, px(0.052), px(0.112), px(0.0085)));
  paint(canvas, size, FOREST, ellipseRing(globeC, globeC, px(0.112), px(0.050), px(0.0085)));

  // Gold lens interior so the magnifier reads clearly over the globe.
  paint(canvas, size, GOLD, circle(lensC, lensC, px(0.104)));
  paint(canvas, size, FOREST, ring(lensC, lensC, px(0.086), px(0.013)));
  paint(canvas, size, FOREST, capsule(u(0.6135), u(0.6135), u(0.6965), u(0.6965), px(0.017)));
}

/* ------------------------------------------------------------- variants ---- */
function renderSquare(badgeR) {
  const canvas = new Float64Array(MASTER * MASTER * 4);
  paint(canvas, MASTER, FOREST, circle(MASTER / 2, MASTER / 2, MASTER)); // full bleed
  drawBadge(canvas, MASTER, badgeR);
  return canvas;
}

function renderRound(badgeR) {
  const canvas = new Float64Array(MASTER * MASTER * 4);
  paint(canvas, MASTER, FOREST, circle(MASTER / 2, MASTER / 2, MASTER / 2 - 1));
  drawBadge(canvas, MASTER, badgeR);
  return canvas;
}

function renderTransparent(badgeR) {
  const canvas = new Float64Array(MASTER * MASTER * 4);
  drawBadge(canvas, MASTER, badgeR);
  return canvas;
}

/* -------------------------------------------------------------- resample -- */
function resample(master, src, dst) {
  const out = new Uint8Array(dst * dst * 4);
  const scale = src / dst;
  for (let y = 0; y < dst; y++) {
    const y0 = y * scale;
    const y1 = (y + 1) * scale;
    for (let x = 0; x < dst; x++) {
      const x0 = x * scale;
      const x1 = (x + 1) * scale;
      let r = 0, g = 0, b = 0, a = 0, n = 0;
      for (let sy = Math.floor(y0); sy < Math.ceil(y1); sy++) {
        for (let sx = Math.floor(x0); sx < Math.ceil(x1); sx++) {
          const i = (sy * src + sx) * 4;
          const al = master[i + 3];
          r += master[i] * al;
          g += master[i + 1] * al;
          b += master[i + 2] * al;
          a += al;
          n++;
        }
      }
      const o = (y * dst + x) * 4;
      if (a > 0) {
        out[o] = Math.round((r / a) * 255);
        out[o + 1] = Math.round((g / a) * 255);
        out[o + 2] = Math.round((b / a) * 255);
      }
      out[o + 3] = Math.round((a / n) * 255);
    }
  }
  return out;
}

/* ----------------------------------------------------------------- write -- */
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

function writeIcon(relativePath, master, size) {
  const path = join(ROOT, relativePath);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, encodePng(size, size, resample(master, MASTER, size)));
  console.log(`${relativePath} (${size}px)`);
}

// Legacy square icon: full-bleed forest green, badge comfortably inside.
const square = renderSquare(0.315);
// Legacy round icon: the launcher masks to a circle anyway; keep corners clear.
const round = renderRound(0.295);
// Adaptive foreground: 108dp canvas, the emblem stays inside the 66dp safe zone.
const foreground = renderTransparent(0.295);
// Maskable PWA icon: full-bleed green, badge inside the 80% safe circle.
const maskable = renderSquare(0.255);

const densities = [
  ['mdpi', 1],
  ['hdpi', 1.5],
  ['xhdpi', 2],
  ['xxhdpi', 3],
  ['xxxhdpi', 4],
];

for (const [density, factor] of densities) {
  const base = `android/app/src/main/res/mipmap-${density}`;
  writeIcon(`${base}/ic_launcher.png`, square, Math.round(48 * factor));
  writeIcon(`${base}/ic_launcher_round.png`, round, Math.round(48 * factor));
  writeIcon(`${base}/ic_launcher_foreground.png`, foreground, Math.round(108 * factor));
}

writeIcon('web/icons/Icon-192.png', square, 192);
writeIcon('web/icons/Icon-512.png', square, 512);
writeIcon('web/icons/Icon-maskable-192.png', maskable, 192);
writeIcon('web/icons/Icon-maskable-512.png', maskable, 512);
writeIcon('web/favicon.png', square, 64);
