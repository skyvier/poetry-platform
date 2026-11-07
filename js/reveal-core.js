// Pure reveal state. A poem is a list of item kinds ('line' | 'break'); the
// state is how many lines are revealed. Stanza breaks never take a step: they
// appear together with the line that follows them.
(function (root) {
  function lineCount(kinds) {
    return kinds.filter(function (k) { return k === 'line'; }).length;
  }

  // Number of leading items visible when n lines are revealed.
  function visibleCount(kinds, n) {
    if (n <= 0) return 0;
    var seen = 0;
    for (var i = 0; i < kinds.length; i++) {
      if (kinds[i] === 'line' && ++seen === n) return i + 1;
    }
    return kinds.length;
  }

  function next(kinds, n) { return Math.min(n + 1, lineCount(kinds)); }
  function back(n) { return Math.max(n - 1, 0); }
  function isDone(kinds, n) { return n >= lineCount(kinds); }

  var api = { lineCount: lineCount, visibleCount: visibleCount, next: next, back: back, isDone: isDone };
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.RevealCore = api;
})(this);
