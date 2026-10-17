---
name: rocm-investigate-log
description: Analyzes a specified build or error log file within a ROCm Debian package repository, identifies the root cause of failures, and proposes concrete fixes.
metadata:
  author: "Bruno Bernardo de Moura <bruno.bdmoura@gmail.com>"
---

## Inputs
- `$LOG_PATH` - The file path to the log to be investigated.

## Step 1 — Validate Environment and Gather Context

1. **Verify the Log File:** Check if the file at `$LOG_PATH` exists and is readable. If not, inform the user and halt execution.
2. **Verify the Directory Structure:**
   - Confirm you are currently inside a `deb_<lib_name>` directory that contains a nested `<lib_name>` directory.
   - If you are not in the correct directory, prompt the user with the current working directory path and ask for instructions on how to proceed.
3. **Verify Packaging Context:**
   - Navigate into the `<lib_name>` directory.
   - Verify it is a Debian package source repository by checking for the existence of a `debian/` folder.
4. **Gather Git Context:** Run standard git commands (e.g., `git status`, `git log -1`) inside `<lib_name>` to understand the current branch, uncommitted changes, and the latest commit context.

## Step 2 — Analyze the Log File

1. Read the contents of `$LOG_PATH`.
2. Parse the log specifically looking for common build failure indicators, such as:
   - CMake configuration errors (e.g., missing dependencies).
   - Compiler errors (e.g., C++ syntax errors, missing headers).
   - Linker errors (e.g., undefined references).
   - `dpkg-buildpackage` or `dh` sequence failures.
3. Extract the primary error message and the surrounding lines for context.

## Step 3 — Correlate Error with Source and Packaging

1. Based on the error found in Step 2, investigate the relevant files inside the `<lib_name>` directory.
2. If it is a missing dependency or version conflict, inspect `debian/control`.
3. If it is a configuration or build flag issue, inspect `debian/rules` and `CMakeLists.txt`.
4. If it is a source code error, check if existing patches in `debian/patches/` are failing to apply, or if a new patch is required for the upstream source.

## Step 4 — Propose Changes

1. **Never Consider Locally Built Packages:** the `$LOG_PATH` file should always be considered as generated on a remote machine, so attempting to check local files for caching and environment variables should be disconsidered.
2. **Explain the Root Cause:** Provide a clear, concise explanation of the error discovered in the log.
3. **Propose a Solution:** Outline the exact steps or code changes needed to fix the issue (e.g., modifying `Build-Depends` in `debian/control`, adding a new compiler flag in `debian/rules`, or generating a new quilt patch).
4. **Draft the Fix:** Show the user the exact diff or file modifications required.
5. **Do Not Commit:** Present the findings and proposed fixes to the user for review. Do not commit or execute the changes automatically.
