// Decrypts the page with a remembered key, or asks for the passphrase once.
(function () {
  var locked = document.getElementById('locked');
  var sealedEl = document.getElementById('sealed');
  if (!locked || !sealedEl) return;

  var core = window.CryptoCore;
  var sealed = JSON.parse(sealedEl.textContent);
  var salt = locked.dataset.salt;
  var iterations = Number(locked.dataset.iterations);
  var form = document.getElementById('unlock');
  var input = document.getElementById('passphrase');
  var status = document.getElementById('unlock-status');
  var siteTitle = document.title;
  var STORE = 'poem-key';

  // The derived key (not the passphrase) is kept per browser. It is tied to
  // the salt, so a new salt or passphrase simply asks again.
  function remembered() {
    try {
      var s = JSON.parse(localStorage.getItem(STORE));
      return s && s.salt === salt ? core.b64ToBytes(s.key) : null;
    } catch (e) { return null; }
  }
  function remember(raw) {
    try { localStorage.setItem(STORE, JSON.stringify({ salt: salt, key: core.bytesToB64(raw) })); } catch (e) {}
  }
  function forget() {
    try { localStorage.removeItem(STORE); } catch (e) {}
  }

  function tryKey(raw) {
    return core.importKey(raw).then(function (key) { return core.open(key, sealed); });
  }

  function show(text) {
    var page = JSON.parse(text);
    document.getElementById('content').innerHTML = page.html;
    if (page.title) document.title = page.title + ' · ' + siteTitle;
    locked.remove();
    if (window.startReveal) window.startReveal();
  }

  function ask() {
    locked.classList.add('asking');
    form.hidden = false;
    input.focus();
  }

  function fail() {
    status.textContent = 'väärä salasana';
    input.disabled = false;
    input.value = '';
    input.focus();
    form.classList.remove('shake');
    void form.offsetWidth; // restart the animation
    form.classList.add('shake');
  }

  var cached = remembered();
  (cached ? tryKey(cached) : Promise.resolve(null)).then(function (text) {
    if (text) return show(text);
    if (cached) forget();
    ask();
  });

  form.addEventListener('submit', function (e) {
    e.preventDefault();
    status.textContent = 'avataan…';
    input.disabled = true;
    var raw;
    core.deriveRawKey(input.value, core.b64ToBytes(salt), iterations)
      .then(function (r) { raw = r; return tryKey(r); })
      .then(function (text) {
        if (!text) return fail();
        remember(raw);
        show(text);
      });
  });
})();
