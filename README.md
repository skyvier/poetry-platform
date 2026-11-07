# kirjaimia, jotka jätän piirtämättä

Poems, revealed one line at a time, readable only with a shared passphrase.
Design: `docs/superpowers/specs/2026-11-07-poem-platform-design.md`.

## Writing

Add a plain-text file to `poems/`, e.g. `poems/10.txt`, starting with a
`# title` line. Filenames are visible in the public repository and in URLs, so
keep them neutral (numbers). Indentation and blank lines are kept. List slugs
(filenames without `.txt`) in `poems/order.txt` to order the contents page;
unlisted poems follow alphabetically.

## Secrets

- **Poems in git** are encrypted with git-crypt. On a new machine, after
  cloning: `git-crypt unlock /path/to/poetry-platform.git-crypt.key`.
  Keep that key file backed up; without it the repository copy of the poems
  cannot be read.
- **The site passphrase** is read from `$SITE_PASSPHRASE` or a git-ignored
  `.passphrase` file. The build fails without it.
- GitHub Actions uses the repository secrets `GIT_CRYPT_KEY` (base64 of the
  key file) and `SITE_PASSPHRASE`.

Changing the passphrase: update the `SITE_PASSPHRASE` secret and push. Friends
will be asked for the new passphrase on their next visit.

## Building

```sh
nix develop
cabal run site -- watch      # live preview at http://localhost:8000
cabal run site -- build      # output in _site/
cabal run site -- rebuild    # after changing site.hs, templates, src/ or the passphrase
cabal test && node --test test/*.test.js
```

Pushing to `main` deploys to GitHub Pages.
