// Checks the locale files against the keys the code actually asks for.
//
//   node tools/check_locales.js
//
// Reports three things:
//   * keys the code looks up that English does not define -- these show up
//     in-game as the raw key, so they are bugs;
//   * keys English defines that nothing looks up -- dead weight, or a typo at
//     one end or the other;
//   * keys English has and another language does not -- those fall back to
//     English, so a screen comes out half translated.
//
// Keys built at runtime ('a11y.enemy.' .. key) cannot be seen by a text scan,
// so the prefixes they are built from are listed below and matched loosely.

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');

const SOURCES = [];
for (const dir of ['.', 'accessibility']) {
  for (const f of fs.readdirSync(path.join(ROOT, dir))) {
    if (f.endsWith('.lua')) SOURCES.push(path.join(dir, f));
  }
}

// Key families the code assembles at runtime rather than writing out in full.
const DYNAMIC = [
  /^char\./, /^class\./, /^passive\./, /^tutorial\./,
  /^a11y\.enemy\./, /^a11y\.group\./, /^a11y\.sound\./, /^a11y\.sector\./,
  /^a11y\.position\./, /^a11y\.guide\./, /^a11y\.help\./,
  /^a11y\.wall\./, /^a11y\.expand\./,
  /\.(one|many)$/,
];

function keysUsed() {
  const used = new Set();
  for (const rel of SOURCES) {
    const src = fs.readFileSync(path.join(ROOT, rel), 'utf8');
    for (const m of src.matchAll(/\bT\('([^']+)'/g)) used.add(m[1]);
    for (const m of src.matchAll(/\bloc\.(?:get|table)\('([^']+)'/g)) used.add(m[1]);
    for (const m of src.matchAll(/\bloc\.count\([^,]+,\s*'([^']+)'/g)) {
      used.add(m[1] + '.one');
      used.add(m[1] + '.many');
    }
    for (const m of src.matchAll(/\bdescribe\.count\([^,]+,\s*'([^']+)'/g)) {
      used.add(m[1] + '.one');
      used.add(m[1] + '.many');
    }
    // string constants that are locale keys handed on to T() elsewhere
    for (const m of src.matchAll(/'(a11y\.[a-z_0-9]+(?:\.[a-z_0-9]+)+)'/g)) used.add(m[1]);
    for (const m of src.matchAll(/'(ui\.guide\.[a-z_]+)'/g)) used.add(m[1]);
  }
  return used;
}

function load(code) {
  const file = path.join(ROOT, 'locales', code + '.lua');
  const src = fs.readFileSync(file, 'utf8');
  const keys = new Set();
  const values = new Map();
  for (const m of src.matchAll(/^\s*\[(['"])(.+?)\1\]\s*=\s*(['"])([\s\S]*?)\3,\s*$/gm)) {
    keys.add(m[2]);
    values.set(m[2], m[4]);
  }
  // table-valued entries have no single string value, but their key still counts
  for (const m of src.matchAll(/^\s*\[(['"])(.+?)\1\]\s*=/gm)) keys.add(m[2]);

  // A key written twice is not an error to Lua: the later one silently wins and
  // the earlier one is dead weight that still reads like the truth. Worth
  // saying out loud, since the two can disagree.
  const seen = new Set();
  keys.duplicates = [];
  for (const m of src.matchAll(/^\s*\[(['"])(.+?)\1\]\s*=/gm)) {
    if (seen.has(m[2])) keys.duplicates.push(m[2]);
    seen.add(m[2]);
  }

  keys.values_by_key = values;
  return keys;
}

// {1}, {2}, ... a translation has to use every number the English one does, or
// whatever the game passed in that slot vanishes from the sentence.
function placeholders(s) {
  return new Set([...s.matchAll(/\{(\d+)\}/g)].map(m => m[1]));
}

const en = load('en');

// A prefix the code concatenates onto ('a11y.enemy.') is not a key, and neither
// is the stem of a counted pair, whose real keys are the .one and .many forms.
const used = new Set([...keysUsed()].filter(k =>
  !/\.\.|\.$/.test(k) && !en.has(k + '.one')));
const others = fs.readdirSync(path.join(ROOT, 'locales'))
  .filter(f => f.endsWith('.lua') && f !== 'en.lua')
  .map(f => f.replace(/\.lua$/, ''));

let problems = 0;

for (const [code, set] of [['en', en], ...others.map(c => [c, load(c)])]) {
  if (set.duplicates.length) {
    problems += set.duplicates.length;
    console.log(code + '.lua defines ' + set.duplicates.length + ' key(s) more than once:');
    for (const k of [...new Set(set.duplicates)]) console.log('  ' + k);
  }
}

const missing = [...used].filter(k => !en.has(k)).sort();
if (missing.length) {
  problems += missing.length;
  console.log('asked for but not in en.lua (' + missing.length + '):');
  for (const k of missing) console.log('  ' + k);
}

const unused = [...en].filter(k => !used.has(k) && !DYNAMIC.some(r => r.test(k))).sort();
if (unused.length) {
  console.log('in en.lua but never asked for (' + unused.length + '):');
  for (const k of unused) console.log('  ' + k);
}

for (const code of others) {
  const other = load(code);
  const gaps = [...en].filter(k => !other.has(k)).sort();
  const extra = [...other].filter(k => !en.has(k)).sort();
  if (gaps.length) {
    problems += gaps.length;
    console.log(code + '.lua is missing ' + gaps.length + ' key(s):');
    for (const k of gaps.slice(0, 40)) console.log('  ' + k);
    if (gaps.length > 40) console.log('  ... and ' + (gaps.length - 40) + ' more');
  }
  if (extra.length) {
    problems += extra.length;
    console.log(code + '.lua has ' + extra.length + ' key(s) English does not:');
    for (const k of extra) console.log('  ' + k);
  }

  const slots = [];
  for (const [k, enText] of en.values_by_key) {
    const otherText = other.values_by_key.get(k);
    if (otherText === undefined) continue;
    const a = placeholders(enText), b = placeholders(otherText);
    const lost = [...a].filter(n => !b.has(n));
    const invented = [...b].filter(n => !a.has(n));
    if (lost.length || invented.length) {
      slots.push('  ' + k + (lost.length ? ' drops {' + lost.join('} {') + '}' : '') +
        (invented.length ? ' invents {' + invented.join('} {') + '}' : ''));
    }
  }
  if (slots.length) {
    problems += slots.length;
    console.log(code + '.lua has ' + slots.length + ' placeholder mismatch(es):');
    for (const s of slots) console.log(s);
  }

  if (!gaps.length && !extra.length && !slots.length) {
    console.log(code + '.lua: complete (' + other.size + ' keys)');
  }
}

console.log(problems ? problems + ' problem(s)' : 'locales look consistent (' + en.size + ' keys)');
process.exit(problems ? 1 : 0);
