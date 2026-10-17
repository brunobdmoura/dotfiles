---
name: rocm-bump-debhelper-compat
description: >
  Bump the debhelper-compat level for a ROCm Debian package, apply applicable
  cleanup changes unlocked by the compat level, and commit each change separately.
---

# Bump debhelper-compat for a ROCm package

Bump the `debhelper-compat` level in `debian/control`, then check which
related cleanups that compat bump unlocks actually apply to this package.

Commit every applicable change separately, mirroring how debhelper-compat 14
was rolled out across hipify, hipblas-common, and rocminfo.

Derive the package name from the first line of `debian/changelog`.

The target debhelper-compat level defaults to **14** unless the user
specifies a different version.

## Step 0 — Verify the working tree is clean

Run:

    git status --short

If it reports anything at all, stop and tell the user.

This workflow creates several separate commits in sequence, and a dirty
working tree makes it impossible to distinguish pre-existing changes from
changes introduced by this compat bump.

## Step 1 — Read the current compat level

Look for the compat level in `debian/control` under `Build-Depends`:

    debhelper-compat (= <N>),

If `debian/compat` exists instead, indicating the legacy compat mechanism,
and there is no `debhelper-compat` build dependency, stop and tell the user.

This skill only handles the `debhelper-compat` build-dependency form.

Compare the current level with the target version.

- If the current version equals the target:
  - Skip the compat bump.
  - Still run all applicable cleanup checks.

- If the current version is greater than the target:
  - Stop and ask the user for confirmation.
  - Do not downgrade automatically.

- If the current version is lower than the target:
  - Continue with the bump.

## Step 2 — Bump debhelper-compat

Edit `debian/control`:

    -debhelper-compat (= <old>),
    +debhelper-compat (= <target>),

Commit this change immediately and separately:

    git add debian/control && \
    git commit -m "d/control: bump debhelper-compat to <target>"

## Step 3 — Check dh-sequence-single-binary

Check this on every run, independently of the compat version.

Count the `Package:` stanzas in `debian/control`.

If there is exactly one binary package and
`dh-sequence-single-binary` is not already listed in `Build-Depends`:

- Add `dh-sequence-single-binary` to the existing comma-separated
  `Build-Depends` list.
- Preserve the existing ordering and formatting style.
- Commit the change separately:

    git add debian/control && \
    git commit -m "d/control: add dh-sequence-single-binary"

If there is more than one binary package, or the dependency is already
present, skip this step silently.

## Step 4 — Check explicit ${misc:Depends}

Only perform this check when the target compat version is greater than or
equal to 14.

Starting with compat 14, `dh_gencontrol` automatically adds
`${misc:Depends}` to every binary package.

Search every binary package stanza in `debian/control` for explicit
`${misc:Depends}` entries under:

- `Depends:`
- `Pre-Depends:`

For every explicit occurrence:

- Remove the `${misc:Depends}` entry.
- Fix commas and continuation formatting as necessary.
- Ensure the dependency list remains syntactically valid.

If one or more entries were removed, commit separately:

    git add debian/control && \
    git commit -m "d/control: drop explicit \${misc:Depends}, applied automatically since compat <target>"

If none are found, skip silently.

## Step 5 — Check for an unneeded override_dh_dwz

Only perform this check when the target compat version is greater than or
equal to 14.

Compat 14 no longer runs `dh_dwz` by default.

Search `debian/rules` for a no-op override such as:

    # dwz does not support DWARF-5
    override_dh_dwz:
        :

Identify an `override_dh_dwz:` target whose recipe consists only of `:`.

If found:

- Remove the entire override block.
- Also remove the immediately preceding comment line if it explains why the
  override exists or why it is a no-op.
- Preserve all unrelated rules and formatting.

Commit separately:

    git add debian/rules && \
    git commit -m "d/rules: drop override_dh_dwz, unused since compat <target> no longer runs dh_dwz by default"

If no matching no-op override exists, skip silently.

## Step 6 — Report

At the end, show the commits created by this workflow using:

    git log --oneline

Clearly report:

- The package name derived from `debian/changelog`.
- The target compat version.
- Whether the compat version was bumped or was already current.
- Which optional cleanups were applied.
- Which checks were skipped because they were not applicable.
- The commits created.
