---
name: rocm-copyright-bump
description: >
  Check and bump copyright years in debian/copyright.
metadata:
  author: "Igor Luppi <igor.luppi@gmail.com>"
---

# Check and bump copyright years in debian/copyright

Scan upstream source files for copyright year headers and update
`debian/copyright` if newer years are found.

## Step 1 — Read current debian/copyright

Note the current upstream copyright year range (e.g. `2014-2023`) from the
`Files: *` stanza.

## Step 2 — Find the newest copyright year in upstream sources

```bash
grep -r "Copyright\|copyright" \
  --include="*.cc" --include="*.c" --include="*.h" \
  --include="*.cpp" --include="*.hpp" --include="*.py" \
  --include="*.sh" --include="*.cmake" --include="License*" \
  --exclude-dir=debian --exclude-dir=.git \
  . 2>/dev/null
```

Also run a broader year-pattern search to catch files that may use non-standard
copyright phrasing (like `©`):

```bash
grep -r "202[0-9]" \
  --exclude-dir=debian --exclude-dir=.git \
  -l . 2>/dev/null | xargs grep -l "Copyright\|copyright\|©" 2>/dev/null
```

Then for each matching file, extract the year to find the highest one present.

## Step 3 — Compare and decide

- If the newest year found in upstream sources is **greater** than the end year
  in `debian/copyright` → update the range end year.
- If it matches or is older → no change needed, report that copyright is up to date.
- Do **not** bump speculatively. Only update if upstream source files explicitly
  carry the newer year in a copyright notice.

## Step 4 — Update debian/copyright if needed

Update only the `Copyright:` line in the `Files: *` stanza:

```
Copyright: <start>-<new-end>, Advanced Micro Devices, Inc.
```

Leave all other lines (license text, `debian/*` stanza, etc.) untouched.

## Step 5 — Check debian/* copyright contributors

Extract all contributor names and emails from `debian/changelog`:

```bash
grep -E "^ --" debian/changelog | sort -u
```

Read the `Files: debian/*` stanza in `debian/copyright` and list the names
currently credited there.

For each contributor found in the changelog, check whether their name or email
appears in the `debian/*` copyright line. Report the findings clearly, e.g.:

> "Found in changelog: Alice <alice@example.com>, Bob <bob@example.com>"
> "In debian/copyright debian/*: Alice <alice@example.com> ✓, Bob <bob@example.com> ✗ missing"

For each missing contributor, ask the user:

> "Bob <bob@example.com> has commits in debian/changelog but is not credited
> in the debian/* copyright stanza. Should I add them with the year range of
> their changelog entries?"

- If the user says **yes**: add the contributor to the `Copyright:` line of
  the `Files: debian/*` stanza, using the year(s) from their changelog entries.
- If the user says **no / skip**: note it and move on — do not add without
  confirmation, as the user may know the contribution is trivial or already
  covered.

Do not add yourself (Claude) or bots as copyright holders.

## Step 6 — Run lrc (license reconciliation)

```bash
lrc
```

`lrc` exits **0** when clean, **non-zero** (typically 3) when mismatches exist.

Show the full output to the user. If the exit code is non-zero or any mismatch
lines appear (lines of the form `<d/copyright-license> | <licensecheck-license>
<filename>`), **stop and do not suggest a commit** until all mismatches are
resolved.

For each mismatch, determine whether the debian/copyright stanza is wrong (most
common) or licensecheck is misidentifying the file:

- **Khronos vs Expat/MIT**: Khronos headers use the MIT template but with
  "Materials" instead of "Software". licensecheck reports them as "Khronos".
  If debian/copyright says Expat/MIT for these files, add a dedicated stanza
  with `License: Khronos` placed *after* any broad `Files: *` or `Files:
  opencl/*` stanza (last-match-wins in DEP-5).
- **Apache-2 vs Khronos**: similarly, some Khronos LICENSE files look like
  Apache — check the actual file header.

After editing debian/copyright to fix all mismatches, re-run `lrc` and confirm
it exits 0 before proceeding.

## Step 7 — Report

State clearly:
- Which files contained the newest copyright year and what year it was
- Whether `debian/copyright` was updated or was already correct

If an update was made, suggest a commit message. Use a generic description
without listing contributor names — e.g.:

- Upstream year bump only:
  ```
  d/copyright: update upstream copyright year to <new-end>
  ```

- New contributors added only:
  ```
  d/copyright: include new contributors in debian/* stanza
  ```

- Both:
  ```
  d/copyright: update copyright year and include new contributors
  ```
