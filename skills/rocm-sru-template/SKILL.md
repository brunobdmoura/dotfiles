---
name: rocm-sru-template
description: Generate a first-iteration Ubuntu SRU bug description for a ROCm package version bump. Use when preparing a Launchpad SRU for a ROCm package, or when the user asks to write an SRU, SRU description, or SRU bug body. Accepts an optional upstream diff/patch as argument.
---

## Inputs

- `$ARGUMENTS` — optional: one or more of the following, pasted together or as file paths:
  - A patch/diff describing upstream changes from old version to new
  - The output of an autopkgtest run (detected by lines like `autopkgtest [` or `PASSED`/`FAILED` counts)

If autopkgtest output is provided, paste it verbatim into the Test Plan section item 3 instead of the `<TBD>` placeholder.

Derive **package name**, **old upstream version**, and **new upstream version** from `debian/changelog` (compare the first two distinct upstream version entries).

## Step 1 — Gather packaging context

Read `debian/changelog`:
- New upstream version (e.g. `7.2.3`)
- Previous upstream version (e.g. `7.1.1`)
- Any packaging-only changes listed (d/rules, d/tests, d/watch, etc.)

Read `debian/tests/` to list available autopkgtest names.

Check for `debian/*.symbols` — note whether it exists and will be checked.

## Step 2 — Analyse upstream changes

**If `$ARGUMENTS` provided:** use that diff as primary source of truth.

**If not provided:** find the upstream import commits via:

```bash
git log --oneline
```

Then diff the upstream source (excluding debian/):

```bash
git diff <old-upstream-commit>..<new-upstream-commit> -- . ':!debian'
```

If the diff is large, focus on:
- `CHANGELOG.md` / `CHANGES` at repo root
- `*.cmake`, `CMakeLists.txt`
- Public headers (`*.h`, `*.hpp`)

Categorise changes:
- Bug fixes (correctness, crashes, regressions)
- Performance changes
- API additions or removals
- CMake/build infrastructure changes
- Documentation-only changes

## Step 3 — Check ABI/API

```bash
git diff <old-upstream-commit>..<new-upstream-commit> -- '*.h' '*.hpp'
```

If `debian/*.symbols` exists, note that it should be verified unchanged with `dpkg-gensymbols`.

## Step 4 — Calibrate scope

Read both reference examples before writing:

- See: references/rocblas-large.md  ← detailed multi-fix SRU
- See: references/hipblas-small.md  ← pure version bump, minimal prose

Match the depth of the output to what actually changed:
- Pure upstream bump with no functional changes → short (hipblas style)
- Real named fixes with symptoms and code paths → detailed (rocblas style)
- Do not pad a simple bump into a long SRU

## Step 5 — Compose the SRU description

Output all four sections. Fill what is known; mark unknowns with `<TBD>`:

```
[ Impact ]

<One paragraph per significant upstream change, or one short paragraph
for a pure bump. End with reverse-dependency sentence if relevant.>

[ Test Plan ]

1. Build:
   - sbuild or dpkg-buildpackage succeeds.
   - dpkg --compare-versions confirms the new version is greater.
   <If .symbols exists:>
   - Run dpkg-gensymbols; confirm no symbols added/removed/changed.
2. Installability:
   - apt install <binary package(s)>.
   - Confirm reverse dependencies remain installable without rebuild.
3. Autopkgtest:
   - Run autopkgtest suite (<list test names from debian/tests/>).
   - All tests pass.
   <If autopkgtest output was provided in $ARGUMENTS, paste it here verbatim,
   indented. Otherwise write: "Output: <TBD — paste autopkgtest run results here>">

[ Where problems could occur ]

<Pure bump: one short paragraph — risk limited to infrastructure issues.>
<Real fixes: one bullet per fix with observable symptom if behaviour
changed at an edge case.>

[ Other Info ]

 * <ABI/symbols status.>
 * This update is part of the coordinated ROCm <version> stack release.
 * PPA: <TBD>
 * Upstream version comparison:
   https://github.com/ROCm/<repo>/compare/rocm-<old>...rocm-<new>
 * Target: <if specified in $ARGUMENTS use that; otherwise default to "resolute 26.04 LTS">
```

## Step 6 — Save and print

Save to `../<package>-sru-<timestamp>.md` (one level above the package repo):

```bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
cat > ../<package>-sru-$TIMESTAMP.md << 'EOF'
<full SRU text>
EOF
echo "Saved to ../<package>-sru-$TIMESTAMP.md"
```

Print the full text to the conversation so the user can copy it directly, then report the saved file path.
