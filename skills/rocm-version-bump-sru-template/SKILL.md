---
name: rocm-version-bump-sru-template
description: Generates a standardized Launchpad SRU bug template for a package version bump.
---

# Generate Launchpad SRU Template

Create a Stable Release Update (SRU) bug description template for updating a package to a new upstream version.

## Inputs
- **Target Version:** The new version to be bumped to (passed as an argument, e.g., 7.2.3).
- **Previous Version:** Infer from the current workspace context, or use a placeholder if unknown.
- **Package Name:** Infer from the current directory or workspace context.

## Output Format
Generate the template exactly using the following structure and guidelines. Do not use markdown headings (`#`) for the Launchpad section titles;
use the literal bracketed text (e.g., `[Impact]`).
The output should be also saved on a file located in `/tmp/<Package Name>_<Target Version>_sru_template.md`.

[Impact]

* This is a new upstream release of the package to version **<Target Version>**.
* Explain briefly why this version bump is necessary (e.g., fixing specific bugs, adding required hardware support, aligning with a larger stack update like ROCm).
* Detail the core impact this update has on the users and the system.

[Test Plan]

* Describe the testing methodology used to verify this version bump.
* Mention that the package builds successfully from source.
* Detail any upstream test suites or integration tests that are run.
* Include the results of the autopkgtests in the code block below:

[Where problems could occur]

* Identify specific risks associated with updating this library from the previous version to <Target Version>.
* List any reverse dependencies that could be affected by API/ABI changes.
* Describe the worst-case scenario if the package introduces regressions (e.g., build failures in dependent packages, runtime crashes for specific hardware).

[Other Info]

## Notes

The **Target Version** used as input will likely be the most recent entry on `debian/changelog`, since the SRU template will be generated
to enable the update to that version
