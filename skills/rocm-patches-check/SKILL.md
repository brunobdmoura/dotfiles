---
name: rocm-patches-check
description: >
  Check DEP-3 patch headers after patches are finalised.
metadata:
  author: "Igor Luppi <igor.luppi@gmail.com>"
---

# Check DEP-3 patch headers after patches are finalised

Run this command **after** all patches for the current bump have been refreshed
and committed. It uses the git history of the current bump to determine which
patches changed, applies `Last-Update` automatically, and audits DEP-3
compliance on every modified or new patch.

## Step 1 — Identify the bump boundary in git

Find the upstream version from `debian/changelog` (first stanza, e.g. `7.2.4`).

Then find the commit that imported the new upstream tarball — it is typically
titled `New upstream version X.Y.Z` or is the oldest commit in the current
branch that touches `debian/changelog` with the current version. Use:

```bash
git log --oneline
```

Identify the boundary commit (the last commit *before* the current bump work
started). Everything from that boundary up to HEAD is "this bump".

Ask the user to confirm if the boundary is ambiguous:

> "I'll treat commits from `<short-hash> <subject>` to HEAD as this bump.
> Is that correct?"

## Step 2 — Find modified and new patches

Using the boundary identified in Step 1, get all patches touched in this bump:

```bash
git diff <boundary>..HEAD --name-only -- debian/patches/
```

Classify each file:
- **New**: patch file not present in `<boundary>` (`git show <boundary>:debian/patches/<file>` fails)
- **Modified**: present in both boundary and HEAD but with different content
- **Deleted**: present in boundary but gone at HEAD (note it, no further action)

Also find patches touched in the bump but where the diff is *only* in the
DEP-3 header (i.e. no actual hunk content changed) — these should still get
`Last-Update` updated since the header itself is part of the committed patch.

Report a summary before proceeding:

> "New patches: 0026-fix-hip-clang-root-for-debian-layout.patch"
> "Modified patches: 0009-default-to-hip-platform-amd.patch, 0017-..."
> "Deleted patches: (none)"
> "Unchanged patches: (not checked for DEP-3 in this run)"

## Step 3 — Apply Last-Update automatically

For every **new** or **modified** patch identified in Step 2, set
`Last-Update:` to today's date (`YYYY-MM-DD`).

Rules:
- If `Last-Update:` is already present and correct (today's date), skip.
- If `Last-Update:` is present but stale, update it in-place.
- If `Last-Update:` is missing entirely, add it after the `Forwarded:` line
  (or after `Author:` if `Forwarded:` is also missing).

Do **not** modify `Last-Update` on unchanged patches.

Apply all changes and report each one:

> "0026-fix-hip-clang-root-for-debian-layout.patch — Last-Update set to 2026-06-11"
> "0009-default-to-hip-platform-amd.patch — Last-Update updated 2026-04-01 → 2026-06-11"

## Step 4 — DEP-3 audit on new and modified patches

For each new and modified patch, read the header block (everything before the
first `---` line) and check for the following fields:

| Field | Required? | Notes |
|---|---|---|
| `Description:` | Yes | First line = short summary; continuation lines indented with one space |
| `Author:` or `From:` | Yes | Name and email; `From:` in git-format-patch style is equivalent |
| `Forwarded:` | Yes | One of: `not-needed`, `no`, or a URL to upstream discussion |
| `Last-Update:` | Yes | `YYYY-MM-DD` format — handled in Step 3 |
| `Origin:` | If applicable | URL to source/PR/commit; `vendor` for packaging-only patches |
| `Bug:` / `Bug-Ubuntu:` | If applicable | Only when the patch fixes a known bug |
| `Applied-Upstream:` | If applicable | Only when the patch was merged upstream |

**Reference template:**

```
Description: Short summary of what the patch does
 Long explanation of the issue being fixed.
 .
 Additional context if needed.
Author: Firstname Lastname <email@example.com>
Origin: https://url-to-source-or-pull-request
Bug-Ubuntu: https://bugs.launchpad.net/bugs/XXXXXXX
Forwarded: not-needed | no | https://url-to-upstream-discussion
Last-Update: 2026-06-11
---
```

For **existing patches** that are merely refreshed (hunk offsets updated, no
logic change): their existing headers are usually fine — only `Last-Update`
needs updating (done in Step 3). Skip deep DEP-3 audit for these unless a
field is clearly wrong.

For **new patches**: perform a full audit. Do not guess values for `Author`,
`Origin`, `Bug`, or `Forwarded` — show the current header and ask the user:

> "0026-fix-hip-clang-root-for-debian-layout.patch is new and missing:
> `Forwarded:`. Value? (`not-needed` / `no` / upstream URL)"

For `Forwarded: not-needed` vs `Forwarded: no`:
- Use `not-needed` when the patch is Debian/Ubuntu-specific and will never be
  forwarded upstream (layout fixes, packaging-only changes).
- Use `no` when the patch could/should go upstream but hasn't been forwarded yet.

Report all findings clearly:

> "0026-fix-hip-clang-root-for-debian-layout.patch — OK (after Last-Update fix)"
> "0009-default-to-hip-platform-amd.patch — OK"
> "0017-fix-memory-barriers-for-arm64-and-ppc64.patch — missing: Description long body"

## Step 5 — Suggest commit

If any patches were modified by this command (Last-Update additions/updates,
header fixes), suggest a commit covering all of them:

```
d/p: update DEP-3 Last-Update fields after patch refresh
```

If new patches had headers added or fixed, use:

```
d/p: add DEP-3 headers to <patch-name>
```

If both, suggest them as a single combined commit unless the changes are on
different patches that were already committed separately — in that case suggest
amending or rebasing.

## Step 6 — Final summary

Print a table:

| Patch | Status | Last-Update | DEP-3 |
|---|---|---|---|
| 0009-default-to-hip-platform-amd.patch | modified | updated | OK |
| 0026-fix-hip-clang-root-for-debian-layout.patch | new | set | OK |
| ... | | | |
