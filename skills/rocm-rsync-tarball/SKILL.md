---
name: rocm-rsync-tarball
description: >
  Sync upstream tarball into the package tree. Args: <version>
argument-hint: '<version>'
metadata:
  author: "Igor Luppi <igor.luppi@gmail.com>"
---

# Sync upstream tarball into the package tree

Extract the orig tarball for a given version and rsync it into the current
package repository, preserving the `debian/` directory and `.git/`.

## Inputs

- `$ARGUMENTS` — required: `<version>` (e.g. `7.2.3`)

Derive the **package name** from `debian/changelog` (first line).

The expected tarball path is `../<package>_<version>+dfsg.orig.tar.xz` (try with `+dfsg` suffix and `.xz` extension first, then fall back to `.gz`). If neither exists, stop and tell the user to run `uscan --download-version <version>` first.

## Step 1 — Identify components

Read `debian/watch` and check for `Component:` stanzas beyond the primary one.
Each component has a name (e.g. `Component: origami`) and corresponds to:
- A tarball: `../<package>_<version>+dfsg.orig-<component>.tar.xz`
- A target directory inside the package tree: `./<component>/`

Collect the component names — they must be excluded from the main rsync and
each handled separately afterwards.

For most packages there are no components and this list will be empty.

## Step 2 — Extract main tarball to /tmp

```bash
mkdir -p /tmp/<package>-<version>
tar -xf ../<tarball> -C /tmp/<package>-<version>
```

If extraction fails, stop and report the error.

## Step 3 — Verify extraction level (main tarball)

```bash
ls /tmp/<package>-<version>/
```

- If there is **one inner directory** and no source files at the top level,
  set `SRC=/tmp/<package>-<version>/<inner-dir>/`.
- If source files are already at the top level,
  set `SRC=/tmp/<package>-<version>/`.

Always confirm the correct level before syncing — a wrong source path will
either do nothing or wipe the repo.

## Step 4 — rsync main tarball

Exclude `/.git`, `/debian`, and each component directory so they are not
overwritten or deleted by the main sync.

```bash
rsync -avHP --delete \
  --exclude=/.git \
  --exclude=/debian \
  [--exclude=/<component> ...] \
  <SRC> .
```

**Anchor all excludes with a leading `/`** so they only match at the top level
of the transfer root. Without anchoring, a pattern like `--exclude=hip` would
silently skip any path component named `hip` at any depth (e.g.
`hipamd/include/hip/`), causing hard-to-debug `dpkg-source` failures.

## Step 5 — Handle each component

For every component collected in Step 1, repeat the extract → verify → rsync
cycle. Each component is synced into its own subdirectory inside the package
tree (`./<component>/`). Since you are targeting a subdirectory rather than the
full package root, only include the excludes that apply to what is actually
inside the component tarball:

```bash
mkdir -p /tmp/<package>-<version>-<component>
tar -xf ../<package>_<version>+dfsg.orig-<component>.tar.xz \
    -C /tmp/<package>-<version>-<component>
ls /tmp/<package>-<version>-<component>/
```

Determine the inner directory the same way as Step 3, then rsync:

```bash
rsync -avHP --delete \
  <SRC-component> ./<component>/
```

## Step 6 — Report

Show `git status` so the user can review what changed.

## Step 7 — Offer to commit

Ask the user: "Should I commit this as `New upstream version <version>`?"

If yes, stage all modified/deleted/new files (excluding `debian/` and `.git/`)
and commit with:

```
New upstream version <version>
```
