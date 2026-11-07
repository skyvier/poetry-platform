// Decrypts the built site with the browser's crypto code. Run after a build,
// with SITE_PASSPHRASE set; skipped otherwise.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { deriveRawKey, importKey, open, b64ToBytes } = require('../js/crypto-core.js');

const site = path.join(__dirname, '..', '_site');
const pass = process.env.SITE_PASSPHRASE;
const skip = !pass || !fs.existsSync(site) ? 'needs SITE_PASSPHRASE and a built _site' : false;

const pages = skip ? [] : fs.readdirSync(site, { recursive: true })
  .filter(f => f.endsWith('index.html'))
  .map(f => path.join(site, f));

const parse = html => ({
  salt: html.match(/data-salt="([^"]+)"/)[1],
  iterations: Number(html.match(/data-iterations="(\d+)"/)[1]),
  sealed: JSON.parse(html.match(/<script type="application\/json" id="sealed">(.*?)<\/script>/s)[1]),
});

test('every page decrypts with the passphrase, and only after it', { skip }, async () => {
  assert.ok(pages.length > 1);
  const { salt, iterations } = parse(fs.readFileSync(pages[0], 'utf8'));
  const key = await importKey(await deriveRawKey(pass, b64ToBytes(salt), iterations));
  for (const file of pages) {
    const html = fs.readFileSync(file, 'utf8');
    assert.doesNotMatch(html, /class="line"|poem-list/, `${file} leaks content`);
    const page = JSON.parse(await open(key, parse(html).sealed));
    assert.match(page.html, file.endsWith(`_site${path.sep}index.html`) ? /poem-list/ : /class="line"/);
  }
});

test('a wrong passphrase opens nothing', { skip }, async () => {
  const p = parse(fs.readFileSync(pages[0], 'utf8'));
  const key = await importKey(await deriveRawKey(pass + 'x', b64ToBytes(p.salt), p.iterations));
  assert.strictEqual(await open(key, p.sealed), null);
});
