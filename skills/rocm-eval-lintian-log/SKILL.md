---
name: rocm-eval-lintian-log
description: >
  Analyzes a specified Lintian log file passed as an argument, filters out known false-positives or acceptable warnings, investigates the root cause of the remaining issues within the debian/ directory, and suggests actionable fixes.
metadata:
  author: "Bruno Bernardo de Moura <bruno.bdmoura@gmail.com>"
---

# Context

The log files are generated using `lintian -EviI` on various Debian package artifacts (`.ddeb`, `.deb`, `.changes`, `.dsc`, `.udeb`).

The format of the log files is divided into sections as follows:
```txt
# .ddeb deb files:
[Lintian output for deb files...]

# .changes files:
[Lintian output for changes files...]

# .dsc files:
[Lintian output for dsc files...]

# .udeb files:
[Lintian output for udeb files...]
```
*(Note: If no files of a specific extension were found, the section will state "No .[EXT] files found in the upper directory.")*

## Inputs
- `$LOG_PATH` - The absolute or relative file path to the Lintian log to be investigated.

## Step 1 — Validate Environment
1. **Verify Log File:** Check if `$LOG_PATH` exists and is readable. If it does not exist, halt execution and inform the user.
2. **Verify Workspace:** Confirm that the current working directory contains a `debian/` directory. If it does not, warn the user that you cannot investigate the source of the Lintian warnings and ask how to proceed.

## Step 2 — Filter Known/Acceptable Warnings
Read and parse the `$LOG_PATH` file. If the following Lintian tags are present, group them into an "Ignored Warnings" summary. Inform the user that these were detected but deliberately skipped as they do not require fixing in this context:
- `package-contains-no-arch-dependent-files`
*(You may silently skip informational Lintian output that does not represent a warning or error).*

## Step 3 — Investigate Actionable Warnings
For all remaining Lintian warnings (Errors `E:`, Warnings `W:`, Info `I:`, Pedantic `P:`), investigate the root cause by cross-referencing the warning with the package source code.
1. Group the remaining warnings by the Debian file they likely originate from.
2. Inspect the relevant files in the `debian/` directory:
   - **`debian/control`**: For missing dependencies, description issues, or maintainer formatting.
   - **`debian/changelog`**: For distribution, versioning, or syntax errors.
   - **`debian/copyright`**: For missing licenses, unlisted source files, or formatting issues.
   - **`debian/rules`**: For build flags, missing hardening, or incorrect installation paths.
   - **`debian/watch`**: For upstream tarball fetching errors.
3. *Optional Agent Tip:* If a Lintian tag is ambiguous, run `lintian-info --tags <tag-name>` in the terminal to gather more context on what the tag means and how Debian expects it to be fixed.

## Step 4 — Propose Actionable Fixes
Present your findings to the user clearly and systematically. For each actionable warning (or group of related warnings):
1. **State the Warning:** Briefly mention the Lintian tag and what it means.
2. **Explain the Cause:** Explain *why* it triggered based on your investigation of the `debian/` directory.
3. **Suggest the Fix:** Provide the exact modification required to fix the issue. Use diffs, code blocks, or specific line-replacement instructions for the relevant `debian/*` files.
4. **Do Not Auto-Commit:** Only suggest the changes; do not execute file writes or git commits unless explicitly instructed by the user.

