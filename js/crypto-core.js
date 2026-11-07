// WebCrypto counterpart of src/Seal.hs: PBKDF2-SHA256 key derivation and
// AES-256-GCM decryption of { iv, ct } payloads (base64; ct includes the tag).
(function (root) {
  var subtle = root.crypto.subtle;

  function b64ToBytes(s) {
    var bin = atob(s), out = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  }

  function bytesToB64(bytes) {
    var bin = '';
    for (var i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
    return btoa(bin);
  }

  // Raw 32-byte key, so it can be remembered between visits.
  function deriveRawKey(passphrase, salt, iterations) {
    return subtle.importKey('raw', new TextEncoder().encode(passphrase), 'PBKDF2', false, ['deriveBits'])
      .then(function (base) {
        return subtle.deriveBits({ name: 'PBKDF2', hash: 'SHA-256', salt: salt, iterations: iterations }, base, 256);
      })
      .then(function (bits) { return new Uint8Array(bits); });
  }

  function importKey(raw) {
    return subtle.importKey('raw', raw, 'AES-GCM', false, ['decrypt']);
  }

  // Resolves to the plaintext string, or null if the key does not fit.
  function open(key, sealed) {
    return subtle.decrypt({ name: 'AES-GCM', iv: b64ToBytes(sealed.iv) }, key, b64ToBytes(sealed.ct))
      .then(function (buf) { return new TextDecoder().decode(buf); },
            function () { return null; });
  }

  var api = { b64ToBytes: b64ToBytes, bytesToB64: bytesToB64, deriveRawKey: deriveRawKey, importKey: importKey, open: open };
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.CryptoCore = api;
})(typeof window !== 'undefined' ? window : globalThis);
