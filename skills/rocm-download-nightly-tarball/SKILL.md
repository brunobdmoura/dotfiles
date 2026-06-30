---
name: rocm-download-nightly-tarball
description: Downloads a versioned tarball from the nightly branch for the current library.
---

## Context

This skill is stored at `/home/<$USER>/.copilot/skills/rocm-download-nightly-tarball/`.
It is invoked from **other package repositories** on this machine (e.g. `~/sandbox/rocm-hipamd`).
The **cwd when this skill runs is the parent sandbox directory** that contains the package directory as a subdirectory
(e.g. `~/sandbox/`, with `~/sandbox/rocm-hipamd/` being the package dir).

The snapshot script used by this skill is located at:

```
/home/<$USER>/.copilot/skills/rocm-download-nightly-tarball/script/snapshot.sh
```

Its full documentation is at:

```
/home/<$USER>/.copilot/skills/rocm-download-nightly-tarball/script/snapshot.md
```

Store the script's directory path as **snapshot_path**:

```
<snapshot_path> = /home/<$USER>/.copilot/skills/rocm-download-nightly-tarball/script
```

Read both files before proceeding so you understand all flags and behaviours.

## User Inputs

**package_name** — provided as an argument to this skill. This is both the Debian package name and
the name of its subdirectory inside the sandbox (e.g. `rocm-hipamd`).

## Derived Inputs

**monorepo** — read from `<package_name>/debian/watch` (relative to cwd), on the line starting with `https://github.com/ROCm/`.
Extract the repo name (e.g. `rocm-libraries` or `rocm-systems`). If the value is anything other than those two,
warn the user and ask for next steps before continuing.

**new_version** — defaults to `7.2.14`. Always prompt the user to confirm or override this value before running.

## Steps

Run these steps in order. After each shell command, check the exit code and report any error before continuing.

### Step 1 — Generate the conf file

For the snapshot script to run it needs a `.conf` file. Read `<package_name>/debian/watch` to check whether
the package declares additional gbp components (look for lines referencing sub-projects or `orig-<name>` tarballs).
If any exist, derive their names as **first_module_name**, **second_module_name**, etc.

Write the conf file at `<package_name>.conf` (i.e. a sibling of the package directory, directly under the sandbox).
Store its absolute path as **package_conf_path**.

```sh
UPSTREAM_URL="https://github.com/ROCm/<monorepo>.git"
UPSTREAM_REF="develop"
MAIN_SUBDIR="projects/<package_name>"
COMPONENTS="<first_module_name>:projects/<first_module_name> <second_module_name>:projects/<second_module_name>"
# ^ If no extra modules exist, set COMPONENTS="" (empty string)
COMPRESSION="xz"
SEP="~"
# DEBIAN_BRANCH="debian/experimental"   # else taken from debian/gbp.conf
```

### Step 2 — Execute the snapshot script

Move into the package directory and run the snapshot script:

```bash
cd <package_name>
bash <snapshot_path>/snapshot.sh \
  -c <package_conf_path> create -u <new_version>
```

If the output contains errors mentioning `gbp`, `pristine-tar`, or GPG/signing failures, report them to the user
and re-execute adding `--no-import`:

```bash
bash <snapshot_path>/snapshot.sh \
  -c <package_conf_path> create -u <new_version> --no-import
```

## Done

Print a summary containing:
- The name(s) of the generated tarball(s)
- File size of each tarball
- Total time elapsed
- Whether `--no-import` was used
- Contents of the generated `.conf` file
