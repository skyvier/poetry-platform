const test = require('node:test');
const assert = require('node:assert');
const { deriveRawKey, importKey, open, b64ToBytes, bytesToB64 } = require('../js/crypto-core.js');

const hex = h => Uint8Array.from(h.match(/../g).map(b => parseInt(b, 16)));
const toHex = u => Buffer.from(u).toString('hex');

test('PBKDF2-SHA256 matches the published vector', async () => {
  const raw = await deriveRawKey('password', new TextEncoder().encode('salt'), 2);
  assert.strictEqual(toHex(raw), 'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43');
});

test('opens the NIST AES-256-GCM vector (ciphertext || tag)', async () => {
  const key = await importKey(new Uint8Array(32));
  const sealed = { iv: bytesToB64(new Uint8Array(12)),
                   ct: bytesToB64(hex('cea7403d4d606b6e074ec5d3baf39d18d0d1c8a799996bf0265b98b5d48ab919')) };
  // 16 zero bytes decode to 16 NUL characters.
  assert.strictEqual(await open(key, sealed), '\0'.repeat(16));
});

test('returns null for a wrong key', async () => {
  const key = await importKey(new Uint8Array(32).fill(1));
  const sealed = { iv: bytesToB64(new Uint8Array(12)), ct: bytesToB64(hex('530f8afbc74536b9a963b4f1c4cb738b')) };
  assert.strictEqual(await open(key, sealed), null);
});

test('base64 round-trips bytes', () => {
  const bytes = Uint8Array.from([0, 1, 254, 255, 128]);
  assert.deepStrictEqual(b64ToBytes(bytesToB64(bytes)), bytes);
});
