// Adds the glyphs Spanish needs to the two pixel fonts the game ships with.
//
// Neither FatPixelFont nor PixulBrush was drawn with any accented character in
// it, so a Spanish string rendered with them comes out full of holes. Rather
// than fall back to a smooth system font for those few characters -- which in
// a game drawn entirely from 1px cells looks like a rendering bug -- the marks
// are drawn here on the same 128-unit grid the fonts already snap to, and
// welded onto copies of the letters underneath them.
//
// Both fonts turned out to make that easy: every contour is a closed polygon
// of on-curve points and every point sits on the grid, so a new glyph is just
// the base glyph's polygons plus a handful of rectangles.
//
//   node tools/patch_fonts.js            rewrite assets/fonts/*.ttf in place
//   node tools/patch_fonts.js --check    report coverage, write nothing
//
// The patched fonts are committed, so this only needs running if the marks
// themselves need redrawing.

const fs = require('fs');
const path = require('path');

const UNIT = 128;                 // one drawn pixel, in font units, in both fonts
const ROOT = path.join(__dirname, '..');

// ------------------------------------------------------------------ reading --

const u8 = (b, o) => b.readUInt8(o);
const u16 = (b, o) => b.readUInt16BE(o);
const i16 = (b, o) => b.readInt16BE(o);
const u32 = (b, o) => b.readUInt32BE(o);

function parse(file) {
  const b = fs.readFileSync(file);
  const t = {};
  const numTables = u16(b, 4);
  for (let i = 0; i < numTables; i++) {
    const o = 12 + i * 16;
    t[b.toString('ascii', o, o + 4)] = {off: u32(b, o + 8), len: u32(b, o + 12)};
  }
  const F = {b, t, file};
  F.upem = u16(b, t.head.off + 18);
  F.indexToLoc = i16(b, t.head.off + 50);
  F.numGlyphs = u16(b, t.maxp.off + 4);
  F.numH = u16(b, t.hhea.off + 34);
  F.loca = [];
  for (let i = 0; i <= F.numGlyphs; i++) {
    F.loca.push(F.indexToLoc ? u32(b, t.loca.off + i * 4) : u16(b, t.loca.off + i * 2) * 2);
  }

  F.cmap = new Map();
  const cm = t.cmap.off;
  for (let i = 0, n = u16(b, cm + 2); i < n; i++) {
    const o = cm + 4 + i * 8;
    if (u16(b, o) !== 3 || u16(b, o + 2) !== 1) continue;
    const sub = cm + u32(b, o + 4);
    if (u16(b, sub) !== 4) continue;
    const segX2 = u16(b, sub + 6);
    const endO = sub + 14, startO = endO + segX2 + 2;
    const deltaO = startO + segX2, rangeO = deltaO + segX2;
    for (let s = 0; s < segX2 / 2; s++) {
      const end = u16(b, endO + s * 2), start = u16(b, startO + s * 2);
      const delta = i16(b, deltaO + s * 2), ro = u16(b, rangeO + s * 2);
      if (start === 0xffff) continue;
      for (let c = start; c <= end; c++) {
        let g;
        if (ro === 0) {
          g = (c + delta) & 0xffff;
        } else {
          g = u16(b, rangeO + s * 2 + ro + (c - start) * 2);
          if (g !== 0) g = (g + delta) & 0xffff;
        }
        if (g) F.cmap.set(c, g);
      }
    }
  }

  F.metrics = g => ({
    adv: u16(b, t.hmtx.off + (g < F.numH ? g * 4 : (F.numH - 1) * 4)),
    lsb: g < F.numH ? i16(b, t.hmtx.off + g * 4 + 2)
                    : i16(b, t.hmtx.off + F.numH * 4 + (g - F.numH) * 2),
  });
  return F;
}

// Returns contours as arrays of {x, y}. Both fonts are all-on-curve polygons;
// anything else would need real curve handling and is refused rather than
// silently mangled.
function readGlyph(F, g) {
  const b = F.b;
  const s = F.t.glyf.off + F.loca[g], e = F.t.glyf.off + F.loca[g + 1];
  if (s >= e) return [];
  const nc = i16(b, s);
  if (nc < 0) throw new Error('glyph ' + g + ' of ' + F.file + ' is composite');
  let o = s + 10;
  const ends = [];
  for (let i = 0; i < nc; i++) { ends.push(u16(b, o)); o += 2; }
  const npts = nc ? ends[nc - 1] + 1 : 0;
  o += 2 + u16(b, o);                                    // skip instructions

  const flags = [];
  while (flags.length < npts) {
    const f = u8(b, o++);
    flags.push(f);
    if (f & 8) { let r = u8(b, o++); while (r-- > 0) flags.push(f); }
  }
  const read = (shortBit, sameBit) => {
    const out = [];
    let v = 0;
    for (let i = 0; i < npts; i++) {
      const f = flags[i];
      if (f & shortBit) { const d = u8(b, o++); v += (f & sameBit) ? d : -d; }
      else if (!(f & sameBit)) { v += i16(b, o); o += 2; }
      out.push(v);
    }
    return out;
  };
  const xs = read(2, 16), ys = read(4, 32);

  const contours = [];
  let start = 0;
  for (let i = 0; i < nc; i++) {
    const pts = [];
    for (let j = start; j <= ends[i]; j++) {
      if (!(flags[j] & 1)) throw new Error('glyph ' + g + ' of ' + F.file + ' has off-curve points');
      pts.push({x: xs[j], y: ys[j]});
    }
    contours.push(pts);
    start = ends[i] + 1;
  }
  return contours;
}

// ------------------------------------------------------------------ writing --

function writeGlyph(contours) {
  if (!contours.length) return Buffer.alloc(0);
  const pts = [].concat(...contours);
  const xs = pts.map(p => p.x), ys = pts.map(p => p.y);

  const head = Buffer.alloc(10 + contours.length * 2 + 2);
  head.writeInt16BE(contours.length, 0);
  head.writeInt16BE(Math.min(...xs), 2);
  head.writeInt16BE(Math.min(...ys), 4);
  head.writeInt16BE(Math.max(...xs), 6);
  head.writeInt16BE(Math.max(...ys), 8);
  let n = 0;
  contours.forEach((c, i) => { n += c.length; head.writeUInt16BE(n - 1, 10 + i * 2); });
  head.writeUInt16BE(0, 10 + contours.length * 2);       // no instructions

  // Deltas are emitted uncompressed (no flag repeats, no short forms). These
  // glyphs are a few dozen points each; the bytes saved are not worth the
  // extra shape of the encoder.
  const flags = Buffer.alloc(pts.length, 0x01);          // all points on-curve
  const coords = Buffer.alloc(pts.length * 4);
  let o = 0, prev = 0;
  for (const p of pts) { coords.writeInt16BE(p.x - prev, o); o += 2; prev = p.x; }
  prev = 0;
  for (const p of pts) { coords.writeInt16BE(p.y - prev, o); o += 2; prev = p.y; }

  return Buffer.concat([head, flags, coords]);
}

function checksum(buf) {
  let sum = 0;
  const padded = buf.length % 4 ? Buffer.concat([buf, Buffer.alloc(4 - buf.length % 4)]) : buf;
  for (let i = 0; i < padded.length; i += 4) sum = (sum + padded.readUInt32BE(i)) >>> 0;
  return sum;
}

function buildCmap(map) {
  // One format 4 subtable under (3, 1). Every codepoint involved is in the BMP.
  const codes = [...map.keys()].sort((a, b) => a - b);
  const segs = [];
  for (const c of codes) {
    const last = segs[segs.length - 1];
    if (last && c === last.end + 1) {
      last.end = c;
      last.glyphs.push(map.get(c));
    } else {
      segs.push({start: c, end: c, glyphs: [map.get(c)]});
    }
  }
  // Collapse a segment to a delta when its glyph ids run consecutively, which
  // is the common case and keeps the id array empty for most of them.
  for (const s of segs) {
    if (s.glyphs.every((g, i) => g === s.glyphs[0] + i)) {
      s.delta = (s.glyphs[0] - s.start) & 0xffff;
      s.glyphs = null;
    }
  }
  segs.push({start: 0xffff, end: 0xffff, delta: 1, glyphs: null});

  const segCount = segs.length;
  let idLen = 0;
  for (const s of segs) if (s.glyphs) idLen += s.glyphs.length;

  const sub = Buffer.alloc(14 + segCount * 8 + 2 + idLen * 2);
  sub.writeUInt16BE(4, 0);
  sub.writeUInt16BE(sub.length, 2);
  sub.writeUInt16BE(0, 4);
  sub.writeUInt16BE(segCount * 2, 6);
  const p2 = Math.pow(2, Math.floor(Math.log2(segCount)));
  sub.writeUInt16BE(p2 * 2, 8);
  sub.writeUInt16BE(Math.log2(p2), 10);
  sub.writeUInt16BE(segCount * 2 - p2 * 2, 12);

  const endO = 14, startO = endO + segCount * 2 + 2;
  const deltaO = startO + segCount * 2, rangeO = deltaO + segCount * 2;
  let idCursor = 0;
  segs.forEach((s, i) => {
    sub.writeUInt16BE(s.end, endO + i * 2);
    sub.writeUInt16BE(s.start, startO + i * 2);
    const delta = s.delta || 0;
    sub.writeInt16BE(delta > 32767 ? delta - 65536 : delta, deltaO + i * 2);
    if (s.glyphs) {
      // Offset in bytes from this entry to where the segment's ids begin.
      sub.writeUInt16BE((segCount - i) * 2 + idCursor * 2, rangeO + i * 2);
      s.glyphs.forEach((g, j) => sub.writeUInt16BE(g, rangeO + segCount * 2 + (idCursor + j) * 2));
      idCursor += s.glyphs.length;
    } else {
      sub.writeUInt16BE(0, rangeO + i * 2);
    }
  });
  sub.writeUInt16BE(0, startO - 2);                      // reservedPad

  const header = Buffer.alloc(12);
  header.writeUInt16BE(0, 0);
  header.writeUInt16BE(1, 2);
  header.writeUInt16BE(3, 4);
  header.writeUInt16BE(1, 6);
  header.writeUInt32BE(12, 8);
  return Buffer.concat([header, sub]);
}

function buildFont(tables) {
  const tags = Object.keys(tables).sort();
  const numTables = tags.length;
  const p2 = Math.pow(2, Math.floor(Math.log2(numTables)));
  const dir = Buffer.alloc(12 + numTables * 16);
  dir.writeUInt32BE(0x00010000, 0);
  dir.writeUInt16BE(numTables, 4);
  dir.writeUInt16BE(p2 * 16, 6);
  dir.writeUInt16BE(Math.log2(p2), 8);
  dir.writeUInt16BE(numTables * 16 - p2 * 16, 10);

  const parts = [dir];
  let offset = dir.length;
  tags.forEach((tag, i) => {
    const body = tables[tag];
    const o = 12 + i * 16;
    dir.write(tag, o, 4, 'ascii');
    dir.writeUInt32BE(checksum(body), o + 4);
    dir.writeUInt32BE(offset, o + 8);
    dir.writeUInt32BE(body.length, o + 12);
    parts.push(body);
    const pad = (4 - body.length % 4) % 4;
    if (pad) parts.push(Buffer.alloc(pad));
    offset += body.length + pad;
  });

  const font = Buffer.concat(parts);
  // checkSumAdjustment is defined over the whole file with its own field zeroed,
  // which it already is at this point.
  const headOff = dir.readUInt32BE(12 + tags.indexOf('head') * 16 + 8);
  font.writeUInt32BE((0xB1B0AFBA - checksum(font)) >>> 0, headOff + 8);
  return font;
}

// ------------------------------------------------------------------- shapes --

// A filled cell, given in grid units. TrueType fills by non-zero winding, so
// overlapping rectangles wound the same way merge cleanly and a mark can be
// described as however many blocks read best.
function rect(x0, y0, x1, y1) {
  const u = v => Math.round(v * UNIT);
  return [{x: u(x0), y: u(y1)}, {x: u(x1), y: u(y1)}, {x: u(x1), y: u(y0)}, {x: u(x0), y: u(y0)}];
}

function shift(contours, dx, dy) {
  return contours.map(c => c.map(p => ({x: p.x + dx * UNIT, y: p.y + dy * UNIT})));
}

const bbox = contours => {
  const pts = [].concat(...contours);
  return {
    x0: Math.min(...pts.map(p => p.x)), x1: Math.max(...pts.map(p => p.x)),
    y0: Math.min(...pts.map(p => p.y)), y1: Math.max(...pts.map(p => p.y)),
  };
};

// 180 degrees about the middle of the glyph's own box, which is what an
// inverted question mark is. A rotation keeps the winding direction, so the
// counters stay counters.
function rotate180(contours) {
  const bb = bbox(contours);
  return contours.map(c => c.map(p => ({x: bb.x0 + bb.x1 - p.x, y: bb.y0 + bb.y1 - p.y})));
}

// Each font gets its own marks, because each font's idea of a drawn stroke is
// different: PixulBrush is a 6-cell lowercase whose marks are a couple of
// cells, FatPixelFont draws every letter at cap height in fat 4-cell strokes
// and needs marks to match.
//
// A mark sits `gap` cells above whatever letter it lands on rather than at a
// fixed height, which keeps it the same distance from an i's shortened stem as
// from an n's shoulder without either needing to be special-cased.
//
// The tilde is a notched bar rather than the obvious dotted diagonal: at four
// cells wide the diagonal is indistinguishable from the acute, and telling
// "ano" from "año" is the entire reason the glyph is here.
const MARKS = {
  PixulBrush: {
    gap: 1,
    acute: () => [rect(1, 1, 3, 2), rect(0, 0, 2, 1)],
    tilde: () => [rect(0, 1, 2, 2), rect(3, 1, 4, 2), rect(0, 0, 1, 1), rect(2, 0, 4, 1)],
    diaeresis: () => [rect(0, 0, 1, 2), rect(2, 0, 3, 2)],
  },
  FatPixelFont: {
    // Lowercase and uppercase are drawn at the same height in this font, so one
    // placement serves both, and its strokes are thick enough that a mark
    // touching the letter reads as part of it.
    gap: 0,
    acute: () => [rect(3, 2, 7, 4), rect(0, 0, 4, 2)],
    tilde: () => [rect(0, 2, 6, 4), rect(9, 2, 12, 4), rect(0, 0, 3, 2), rect(6, 0, 12, 2)],
    diaeresis: () => [rect(0, 0, 4, 4), rect(9, 0, 13, 4)],
  },
};

MARKS['PixulBrush-Mono'] = MARKS.PixulBrush;

// character, base letter, mark
const ACCENTED = [
  ['á', 'a', 'acute'], ['é', 'e', 'acute'], ['í', 'i', 'acute'],
  ['ó', 'o', 'acute'], ['ú', 'u', 'acute'], ['ü', 'u', 'diaeresis'],
  ['ñ', 'n', 'tilde'],
  ['Á', 'A', 'acute'], ['É', 'E', 'acute'], ['Í', 'I', 'acute'],
  ['Ó', 'O', 'acute'], ['Ú', 'U', 'acute'], ['Ü', 'U', 'diaeresis'],
  ['Ñ', 'N', 'tilde'],
];

const INVERTED = [['¿', '?'], ['¡', '!']];

const NEEDED = ACCENTED.map(a => a[0]).concat(INVERTED.map(a => a[0]));

// ----------------------------------------------------------------- patching --

function patch(name) {
  const file = path.join(ROOT, 'assets', 'fonts', name + '.ttf');
  const F = parse(file);
  const marks = MARKS[name];
  if (!marks) throw new Error('no marks defined for ' + name);

  const glyphs = [];                                     // contours, indexed by glyph id
  const advances = [];
  for (let g = 0; g < F.numGlyphs; g++) {
    glyphs.push(readGlyph(F, g));
    advances.push(F.metrics(g).adv);
  }

  const cmap = new Map(F.cmap);
  const added = [];

  const add = (ch, contours, adv) => {
    cmap.set(ch.codePointAt(0), glyphs.length);
    glyphs.push(contours);
    advances.push(adv);
    added.push(ch);
  };

  for (const entry of ACCENTED) {
    const ch = entry[0], baseChar = entry[1], mark = entry[2];
    if (cmap.has(ch.codePointAt(0))) continue;
    const baseId = F.cmap.get(baseChar.codePointAt(0));
    if (baseId === undefined) { console.warn('  ' + name + ": no '" + baseChar + "' to build from"); continue; }

    let base = readGlyph(F, baseId).map(c => c.map(p => ({x: p.x, y: p.y})));
    // i keeps its dot everywhere except under a mark, which is the one place
    // the dot has to come off first. The dot is a contour floating clear above
    // everything else in the letter; a font that draws i in one piece has none
    // and is left alone.
    if (baseChar === 'i' || baseChar === 'j') {
      const rest = i => base.filter((_, j) => j !== i);
      const dot = base.findIndex((c, i) =>
        rest(i).length && rest(i).every(o => bbox([o]).y1 < bbox([c]).y0));
      if (dot >= 0) base = rest(dot);
    }

    const bb = bbox(base);
    const shape = marks[mark]();
    const sb = bbox(shape);
    // Centred over the letter, snapped back onto the grid so the mark's cells
    // stay aligned with the cells of everything around them.
    const dx = Math.round(((bb.x0 + bb.x1) / 2 - (sb.x0 + sb.x1) / 2) / UNIT);
    const dy = bb.y1 / UNIT + marks.gap;
    add(ch, base.concat(shift(shape, dx, dy)), F.metrics(baseId).adv);
  }

  for (const entry of INVERTED) {
    const ch = entry[0], baseChar = entry[1];
    if (cmap.has(ch.codePointAt(0))) continue;
    const baseId = F.cmap.get(baseChar.codePointAt(0));
    if (baseId === undefined) { console.warn('  ' + name + ": no '" + baseChar + "' to build from"); continue; }
    add(ch, rotate180(readGlyph(F, baseId)), F.metrics(baseId).adv);
  }

  if (!added.length) { console.log(name + ': already complete'); return; }

  const numGlyphs = glyphs.length;
  const glyfParts = [], loca = [];
  let off = 0;
  for (const contours of glyphs) {
    loca.push(off);
    const buf = writeGlyph(contours);
    const pad = (4 - buf.length % 4) % 4;
    glyfParts.push(buf);
    if (pad) glyfParts.push(Buffer.alloc(pad));
    off += buf.length + pad;
  }
  loca.push(off);

  const locaBuf = Buffer.alloc(loca.length * 4);
  loca.forEach((v, i) => locaBuf.writeUInt32BE(v, i * 4));

  const hmtx = Buffer.alloc(numGlyphs * 4);
  glyphs.forEach((contours, i) => {
    hmtx.writeUInt16BE(advances[i], i * 4);
    hmtx.writeInt16BE(contours.length ? bbox(contours).x0 : 0, i * 4 + 2);
  });

  const tables = {};
  for (const tag of Object.keys(F.t)) {
    tables[tag] = Buffer.from(F.b.slice(F.t[tag].off, F.t[tag].off + F.t[tag].len));
  }
  tables.glyf = Buffer.concat(glyfParts);
  tables.loca = locaBuf;
  tables.hmtx = hmtx;
  tables.cmap = buildCmap(cmap);
  tables.head.writeInt16BE(1, 50);                       // long loca offsets
  tables.head.writeUInt32BE(0, 8);                       // checkSumAdjustment
  tables.maxp.writeUInt16BE(numGlyphs, 4);
  tables.maxp.writeUInt16BE(Math.max(...glyphs.map(c => [].concat(...c).length)), 6);
  tables.maxp.writeUInt16BE(Math.max(...glyphs.map(c => c.length)), 8);
  tables.hhea.writeUInt16BE(numGlyphs, 34);              // one metric per glyph
  // post 2.0 carries a name for every glyph and would have to grow with them.
  // Nothing downstream reads glyph names, so it drops to 3.0 instead.
  const post = Buffer.alloc(32);
  tables.post.copy(post, 0, 0, 32);
  post.writeUInt32BE(0x00030000, 0);
  tables.post = post;

  const out = buildFont(tables);
  fs.writeFileSync(file, out);
  console.log(name + ': +' + added.length + ' glyphs (' + added.join(' ') + '), ' +
    F.numGlyphs + ' -> ' + numGlyphs + ' glyphs, ' + out.length + ' bytes');
}

const FONTS = ['FatPixelFont', 'PixulBrush', 'PixulBrush-Mono'];

if (process.argv.includes('--check')) {
  for (const name of FONTS) {
    const F = parse(path.join(ROOT, 'assets', 'fonts', name + '.ttf'));
    const missing = NEEDED.filter(c => !F.cmap.has(c.codePointAt(0)));
    console.log(name + ': ' + F.numGlyphs + ' glyphs, missing ' + (missing.join('') || '(none)'));
  }
} else {
  for (const name of FONTS) patch(name);
}
