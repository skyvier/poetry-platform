// Wires RevealCore to the poem page: input, rendering, scrolling. Started by
// unlock.js once the poem has been decrypted into the page.
window.startReveal = function () {
  var poem = document.getElementById('poem');
  if (!poem) return;
  var core = window.RevealCore;
  var items = Array.prototype.slice.call(poem.children);
  var kinds = items.map(function (el) { return el.classList.contains('break') ? 'break' : 'line'; });
  var end = document.getElementById('poem-end');
  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var n = 0;

  function render(prev) {
    var count = core.visibleCount(kinds, n);
    items.forEach(function (el, i) { el.classList.toggle('on', i < count); });
    document.body.classList.toggle('started', n > 0);
    end.classList.toggle('on', core.isDone(kinds, n));
    if (n > prev && count > 0) keepInView(core.isDone(kinds, n) ? end : items[count - 1]);
  }

  function keepInView(el) {
    var rect = el.getBoundingClientRect();
    var margin = window.innerHeight * 0.2;
    if (rect.bottom > window.innerHeight - margin) {
      window.scrollBy({ top: rect.bottom - window.innerHeight + margin, behavior: reduceMotion ? 'auto' : 'smooth' });
    }
  }

  function step(to) {
    var prev = n;
    n = to;
    if (n !== prev) render(prev);
  }

  document.addEventListener('click', function (e) {
    if (e.target.closest('a')) return;
    step(core.next(kinds, n));
  });

  document.addEventListener('keydown', function (e) {
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    if (e.target.closest && e.target.closest('a') && e.key === 'Enter') return;
    switch (e.key) {
      case ' ': case 'Enter': case 'ArrowDown': case 'ArrowRight':
        e.preventDefault(); step(core.next(kinds, n)); break;
      case 'ArrowLeft': case 'Backspace':
        e.preventDefault(); step(core.back(n)); break;
    }
  });
};
