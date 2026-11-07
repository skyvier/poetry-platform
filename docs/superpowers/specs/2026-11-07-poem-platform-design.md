# Poem platform — design

*kirjaimia, jotka jätän piirtämättä* — a small static site for sharing my own
poems with friends. Each poem reveals itself one line at a time, paced by the
reader.

## Goals

- Friends open a shared link and read poems in a beautiful, quiet setting.
- The reveal is the experience: one line per tap, rising out of a soft blur.
- Adding a poem means dropping a plain-text file into a folder and pushing.
- The poem's exact shape (leading indentation, stanza breaks) is preserved.

Non-goals: logins, comments, analytics, in-browser editing, a CMS.

## Decisions

| Topic | Decision |
|---|---|
| Access | Public static site; poems readable only with a shared passphrase (client-side encryption). |
| Pacing | Reader-advanced, one line per input. |
| Authoring | Plain-text files in `poems/`, one poem per file. |
| Visual style | "Paper": cream background, Cormorant Garamond, blur-rise reveal. |
| Entry point | Quiet table of contents; each poem on its own page. |
| Generator | Hakyll, with a custom plain-text compiler (no Pandoc for poems). |
| Toolchain | Nix flake dev shell (GHC + hakyll from nixpkgs), cabal. |
| Hosting | GitHub Pages via a GitHub Actions workflow using Nix; public repository holding only ciphertext. |
| UI language | Finnish. |

## Content model

```
poems/
  01.txt
  02.txt
  order.txt          # optional; one slug per line, top to bottom
```

- **Slug** = filename without extension. URL is `/<slug>/`. Slugs are neutral
  (numbers) because filenames are not encrypted.
- **Title**: if the first line is `# <title>`, that is the title and the line
  is not part of the poem. Otherwise the title is the slug with `-` replaced by
  spaces. An empty `# ` line falls back to the slug-derived title.
- **Lines**: every line kept verbatim, including leading spaces. Trailing
  whitespace is stripped. Leading and trailing blank lines of the poem are
  dropped.
- **Stanzas**: one or more consecutive blank lines form a single stanza break.
- **Encoding**: UTF-8.
- **Order**: poems listed in `order.txt` first, in that order; remaining poems
  follow alphabetically by slug. Blank lines in `order.txt` are ignored.

### Build errors (fail loudly)

- `order.txt` names a slug with no matching poem file.
- A poem file has no poem lines (empty, or only a title).

## Pages

### Contents (`/`)

- Site title "kirjaimia, jotka jätän piirtämättä" (a single constant in
  `site.hs`).
- Centred list of poem titles linking to `/<slug>/`.
- Titles fade in with a gentle stagger on load; the only animation there.

### Poem (`/<slug>/`)

- Shows the title; a faint hint "napauta tai paina välilyöntiä" fades in and
  out after a moment.
- Poem markup: every line is an element; leading whitespace becomes an
  `--indent` column count (tab = 4) rendered as `1ch` per column, so cascades
  keep their monospace-editor shape. Stanza breaks are spacer elements.
- Link previews show only the site title and a generic description.

### Reveal behaviour (JavaScript)

- **Advance**: click/tap anywhere, Space, Enter, ↓, →. Reveals the next line.
- **Back**: ←, Backspace. Hides the last revealed line.
- Stanza spacers are revealed together with the line that follows them; they
  never consume an input.
- Line animation: opacity 0→1, translateY 6px→0, blur 3px→0 over ~1.1s.
  Rapid input never queues or drops: each input changes state immediately and
  the CSS transition takes care of the rest.
- If a newly revealed line falls below the viewport, scroll smoothly to it.
- After the last line: ornament ❦ fades in, then links **← sisällys** and
  **seuraava →** (next poem by order; omitted on the last poem).
- Reload restarts from the beginning.

## Encryption

Goal: friends with the passphrase can read; nobody else can, including
readers of the public repository.

- **In the repository**: `poems/**` is encrypted with git-crypt. CI unlocks
  with the `GIT_CRYPT_KEY` secret (base64 key file).
- **On the site**: each page body (poem or contents list) is rendered, then
  sealed as JSON `{title, html}` with AES-256-GCM (random 12-byte IV per page,
  tag appended). The key is PBKDF2-HMAC-SHA256 (600 000 iterations) of the
  passphrase and a public, stable salt in `crypto-salt`. The page shell holds
  only the site title, salt, iteration count and ciphertext.
- **Passphrase at build time**: `$SITE_PASSPHRASE`, else a git-ignored
  `.passphrase` file; the build fails without one. CI uses the
  `SITE_PASSPHRASE` secret.
- **In the browser**: `unlock.js` tries a remembered key (localStorage, the
  derived key tied to the salt — never the passphrase). Otherwise it shows a
  passphrase field in the paper style; a wrong passphrase clears the field and
  says “väärä salasana”. On success the key is remembered, the content is
  inserted, and the reveal starts.
- Pages carry `noindex`.
- Threat model: protects against strangers, crawlers and repository readers;
  not against a friend passing the passphrase on. A weak passphrase can be
  guessed offline from the public ciphertext, so it should be a long phrase.

### Fallbacks and accessibility

- No JavaScript: a note that the poems need JavaScript.
- `prefers-reduced-motion`: plain short opacity fade, no blur or movement.
- Screen readers: hidden lines use visual hiding only (opacity), so the whole
  poem stays in the accessibility tree.

## Code structure

```
flake.nix              dev shell + package
poems-platform.cabal   executable `site`, library `Poem` + `Seal`, test suite
src/Poem.hs            pure parser: text -> Poem {title, stanzas}; ordering
src/Seal.hs            PBKDF2 + AES-256-GCM, WebCrypto-compatible
crypto-salt            public salt (hex)
site.hs                Hakyll rules, compilers, contexts
templates/             default.html, locked.html, index.html, poem.html
css/style.css          paper style + reveal states
js/reveal-core.js      pure state logic (next/back/end), testable in Node
js/reveal.js           DOM wiring, input, scrolling
js/crypto-core.js      WebCrypto counterpart of Seal, testable in Node
js/unlock.js           passphrase screen, remembered key
test/PoemSpec.hs       parser and ordering tests
test/SealSpec.hs       PBKDF2 and AES-GCM published test vectors
test/*.test.js         reveal core, crypto core, built-site decryption
.github/workflows/deploy.yml
```

`Poem` has no Hakyll dependency, so it can be tested on its own.
`reveal-core.js` has no DOM dependency.

## Testing

- **Parser** (Haskell, hspec): indentation preserved; blank-line runs collapse
  to one break; leading/trailing blanks dropped; `# title` handling incl.
  empty title; Finnish characters; trailing whitespace stripped; empty poem is
  an error.
- **Ordering**: listed first, rest alphabetical; unknown slug is an error.
- **Reveal core** (`node --test`): next/back bounds, spacers revealed with the
  following line, end state.
- **Crypto**: both implementations checked against the same published
  PBKDF2 and NIST GCM vectors; after a build, every page is decrypted with the
  browser code (`sealed-site.test.js`) and checked for plaintext leaks.
- **End to end**: build with the real poems; open a poem in a browser, check
  wrong and right passphrase and the remembered key, step through, verify
  the indented cascade and the end-of-poem links on
  desktop and ~400px width.

## Migration of existing poems

Existing poems were imported into `poems/` with numbered slugs and `# title`
lines. Git history was rewritten so no plaintext poem was ever committed.
