const test = require('node:test');
const assert = require('node:assert');
const { visibleCount, next, back, isDone, lineCount } = require('../js/reveal-core.js');

// line, line, break, line
const kinds = ['line', 'line', 'break', 'line'];

test('counts only lines as steps', () => {
  assert.strictEqual(lineCount(kinds), 3);
});

test('nothing visible before the first step', () => {
  assert.strictEqual(visibleCount(kinds, 0), 0);
});

test('reveals items up to and including the n-th line', () => {
  assert.strictEqual(visibleCount(kinds, 1), 1);
  assert.strictEqual(visibleCount(kinds, 2), 2);
});

test('a stanza break appears together with the following line', () => {
  assert.strictEqual(visibleCount(kinds, 3), 4);
});

test('next and back stay within bounds', () => {
  assert.strictEqual(next(kinds, 3), 3);
  assert.strictEqual(next(kinds, 0), 1);
  assert.strictEqual(back(0), 0);
  assert.strictEqual(back(2), 1);
});

test('done only after the last line', () => {
  assert.strictEqual(isDone(kinds, 2), false);
  assert.strictEqual(isDone(kinds, 3), true);
});
