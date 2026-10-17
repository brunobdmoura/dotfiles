---
name: rocm-patches-refresh
description: >
  Refresh and audit patches after a new upstream version.
metadata:
  author: "Igor Luppi <igor.luppi@gmail.com>"
---

# Refresh and audit patches after a new upstream version

Run this command **after** the new upstream tarball has been imported but
**before** committing a patch refresh. It does two things in sequence:

1. **Drop analysis** — assess each patch for obsolescence against the new upstream.
2. **Apply and fix** — drive `quilt push -a` to a clean, zero-fuzz result.

The goal is a committed `debian/patches/` where every patch still applies
cleanly, every surviving patch is still necessary, and `quilt push -a` produces
zero fuzz and zero rejects.

---

## Step 1 — Clean quilt state

Pop all applied patches so the source tree is at bare upstream:

```bash
quilt pop -a 2>&1 || true
```

Verify the series file exists:

```bash
cat debian/patches/series
```

If the series is empty or `debian/patches/` has no `.patch` files, report and
stop — nothing to do.

---

## Step 2 — Upstream changelog review

Before reading individual patches, build context on what actually changed in
this upstream version. This directly informs the drop analysis in Step 3.

### 2a — Changelog/release notes in the source tree

Look for changelog files shipped by upstream:

```bash
find . -maxdepth 3 \( -name 'CHANGELOG*' -o -name 'CHANGES*' \
  -o -name 'RELEASE*' -o -name 'NEWS*' -o -name 'HISTORY*' \) \
  -not -path './debian/*' -not -path './.git/*' | sort
```

If found, read the section corresponding to the new version and extract:
- Bug fixes (signal: patches fixing those bugs may be droppable)
- Behaviour changes (signal: patches adjusting that behaviour may conflict)
- Build system changes (signal: cmake/make patches may need updating)

### 2b — GitHub release page (if accessible)

Read `debian/watch` to get the upstream GitHub repository URL.

If the URL is a GitHub repo (e.g. `github.com/ROCm/<repo>`), fetch the release
notes for the new version tag:

```bash
gh release view <tag> --repo ROCm/<repo> 2>&1 || true
```

Or if `gh` is not authenticated, note the URL and ask the user to paste the
relevant section:

> "Could not fetch GitHub release notes automatically. If you have them handy,
> paste the relevant section now — otherwise I'll rely on the source tree only."

### 2c — Summary

Produce a brief digest before moving to patch analysis:

```
Upstream 7.2.4 changes relevant to patches:
  - Fixed roc-obj help text (→ 0014 may be droppable)
  - Refactored hip-config-amd.cmake build variables (→ 0026 may need update)
  - No changes to memory barrier code (→ 0017 likely still needed)
  - (No changelog file found in source tree; based on source inspection only)
```

This digest is for human review — do not automatically mark patches as drop
candidates based solely on it. Use it as a guide for Step 3.

---

## Step 3 — Drop analysis (read before touching quilt)

For each patch in `debian/patches/series` (in order), read:
- The full DEP-3 header (everything before the first `---` line)
- The actual diff hunks (the files it touches and what it changes)

For each patch, make a **keep / investigate / drop** determination:

### Always keep (no upstream fix possible)
- `Forwarded: not-needed` patches that are Debian/Ubuntu layout fixes,
  packaging glue, or distribution-specific behaviour — upstream will never
  take these. Mark **keep** and move on.

### Check against upstream (may be droppable)
For patches with `Forwarded: no` or a forwarded URL:

1. Read the patch diff to understand exactly what it changes (which lines, in
   which files).
2. Open the corresponding file(s) in the *new* upstream source tree and check
   whether the patched region already incorporates the fix.
   - If the fix is present verbatim or functionally → mark **drop candidate**.
   - If the file was restructured and the patch no longer applies to the same
     region, read the new code to decide if the fix is still needed → mark
     **investigate**.
   - If the code is unchanged and the fix is still absent → mark **keep**.

3. For patches that mention an upstream bug, PR, or commit in their `Bug:` or
   `Origin:` field: check whether that PR/commit is referenced in
   `debian/changelog` upstream entries or in any `CHANGELOG`/`CHANGES` file in
   the source tree (if present).

Report findings before making any changes:

```
Patch drop analysis:
  keep        : 0001-dotdots.patch (layout fix, not-needed)
  keep        : 0009-default-to-hip-platform-amd.patch (upstream unchanged)
  drop candidate : 0014-fix-roc-obj-help.patch (fix already in upstream 7.2.4)
  investigate : 0021-dont-change-default-c-cxx-flags.patch (region refactored)
```

For each **drop candidate**, show the user a diff of what the patch does vs
what upstream now has, and ask:

> "`0014-fix-roc-obj-help.patch` — upstream 7.2.4 already includes this fix.
> Drop it? (yes / no / show-diff)"

For each **investigate** patch, show the relevant upstream code and ask the
user to decide.

If the user confirms a drop:
- Remove the patch file.
- Remove its entry from `debian/patches/series`.
- Note the dropped patch for the commit message.

Do not drop any patch without explicit user confirmation.

---

## Step 4 — Apply patches one by one

Push patches one at a time so failures are isolated immediately:

```bash
quilt push 2>&1
```

Repeat for each patch in series order. For each result:

### Clean apply
> "`0001-dotdots.patch` applied cleanly — no action needed."

### Fuzz
Quilt applied the patch but with offset fuzz — the surrounding context shifted.
This means the patch is stale but still correct.

```bash
quilt refresh 2>&1
```

Report the refresh:
> "`0009-default-to-hip-platform-amd.patch` applied with fuzz — refreshed."

### Reject (patch does not apply)
Show the reject output and open the `.rej` file(s):

```bash
cat <file>.rej
```

Then read the current state of the target file near the failed hunk. Determine:

- **Upstream fixed the area differently**: the patch may be droppable (go back
  to Step 3 analysis for this patch). Ask the user.
- **Context shifted significantly**: edit the patch with `quilt edit <file>`,
  apply the fix to the current code, then `quilt refresh`.
- **Upstream restructured the file**: may require deeper investigation. Show
  the user the new file structure and ask how to proceed.

Never leave a reject file (`.rej`) in the tree. Either the patch is fixed,
dropped, or the user explicitly decides to defer it (and you must note the
deferral prominently).

---

## Step 5 — Final clean verification

Once all patches in series are pushed:

```bash
quilt pop -a 2>&1 && quilt push -a 2>&1
```

The output must show no fuzz warnings and no rejects. If anything appears,
return to Step 3 for the offending patch.

---

## Step 6 — Suggest commits

Based on what changed, suggest one or more commits (keep them separate):

**If patches were refreshed (fuzz fixed, no logic change):**
```
d/p: refresh patches against <upstream-version>
```

**If a patch was dropped:**
```
d/p: drop <patch-name> (fixed upstream in <version>)
```

**If a patch needed logic edits to apply:**
```
d/p: update <patch-name> for <upstream-version> changes
```

Dropped patches and refreshed patches go in separate commits so the history
is readable. Logic edits go in their own commit per patch if the change is
non-trivial.

---

## Step 7 — Handoff note

Remind the user:

> "Patches are clean. Run `/rocm-patches-checks` next to audit DEP-3 headers
> (Last-Update, Forwarded, etc.) on the patches that changed."
