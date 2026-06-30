---
name: store-context
description: Summarizes and saves the context, decisions, and key data of the current discussion to a local hidden markdown file.
---

# Store the context of the current discussion

Extract and synthesize the critical information from the current discussion to ensure continuity in future sessions. Do not dump the raw transcript; create a highly scannable summary.

## File Naming & Location
- **Base Name:** Extract the base name of the current working directory.
- **Date Format:** Use `YYYY-MM-DD`.
- **Filename:** Save the file as `.<directory_name>_<date>.md` in the current directory.
- **Behavior:** If the file already exists for today, append the new information under a new timestamped heading, or elegantly update the existing sections.

## Required Output Structure
The generated markdown file must include the following sections:

### 1. Session Objective
A 1-2 sentence summary of what we are trying to achieve in this discussion.

### 2. Key Decisions & Findings
- Bullet points of agreed-upon approaches.
- Root causes of bugs discovered.
- Important logic or architectural choices.

### 3. Artifacts & Data
- Relevant tables, statistics, or environment variables.
- Crucial file paths or terminal commands used.
- *Note: Do not include massive code blocks. Note the file name and the high-level change instead.*

### 4. Next Steps
- Unresolved issues.
- Tasks to tackle in the next session.
