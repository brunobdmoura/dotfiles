---
name: specfy
description: Write or refresh a project's SPEC.md, an agent-first design spec (contracts, state, control flow, invariants, verify commands) built from the current session, the repo's files and git history. Use when asked to spec, specfy, document the design, or create/update SPEC.md.
---

# specfy

Produce `SPEC.md` at the project root: a design spec that **agents** use as
their primary map of the project, and that humans can still read. Every
statement in it must be checkable against the code.

The spec describes what the project **is** (as implemented), the contracts
between its parts, the tradeoffs it makes and what is still open. It is not
a tutorial, a README or a changelog.

## Ground rules

- **Facts are looked up, decisions are asked.** Never ask the user for
  something the repo, git history or the current session can answer. Only
  intent, status, ownership, rationale and open questions go to the user.
- **The code wins.** When docs, the session and the code disagree, the spec
  follows the code and flags the disagreement (§4 or §5 of the spec).
- **No invention.** If a fact can't be found and the user doesn't know,
  write `TBD:` with what is missing; never guess.
- **Don't commit** unless the user asks. Only `SPEC.md` is written.

## Workflow

### 1. Gather what's already known

Read, without sub-agents (cheap, and the main agent needs it):

- the **current session**: decisions taken, runs and their results, designs
  agreed with the user (e.g. through the grilling skill). These are first-class
  sources; cite the resulting code, not the conversation;
- `git log --oneline -30`, `git status`, the top-level tree;
- `README*`, `AGENTS.md` / `CLAUDE.md` / similar agent instructions, `docs/`,
  agent skill/instruction files (e.g. `.agents/skills/`, `.claude/skills/`,
  `.opencode/`) and their procedures, CI configs;
- an existing `SPEC.md` (any case). If present, this run is in **update
  mode** (step 4b).

### 2. Survey the code (parallel sub-agents)

Launch 3-5 `explore` sub-agents **in one message**, one per area, sized to
the project (merge or drop areas that don't apply). Give each the project's
top-level layout and tell it to return **facts only**, as bullet lists with
`path` + symbol references, no prose and no opinions:

| Area | Ask for |
|---|---|
| Entry points & control flow | every entry point (CLIs, scripts, services, jobs); the order components run in; branches, retries, resume/skip logic; where it stops for humans or agents |
| Component contracts | per component: inputs (args, flags, files, env, state keys read), outputs (files, artifacts, state keys written), side effects (network, containers, pushes, uploads), exit codes and their meaning, failure/stop conditions |
| State, config & env | state files and every key (who writes, who reads, values); config files and their keys; every env var and default |
| CI / automation / deployment | workflows, jobs, triggers, inputs, secrets, environments, artifacts and retention, what runs unattended |
| Tests & verification | test suites, linters, how to run them, what a successful run looks like |

Thoroughness: "very thorough" for contracts and state, "medium" otherwise.
Do not duplicate their work while they run; read anything they flag as
ambiguous once they report.

### 3. Ask only about gaps

Collect what the code can't answer, typically:

- purpose, users, non-goals;
- status (implemented / partial / planned) per area;
- owner and audience;
- **why** a tradeoff was made (the code shows *what*);
- known risks and open questions not written down anywhere.

Ask them with the **grilling** skill's format (numbered questions, each with
your recommended answer, the whole frontier in one round, later rounds for
dependent questions). If an interactive question tool is available, offer it.
Skip this step entirely if there are no gaps. In update mode, only ask about
what changed or is newly unclear.

### 4a. Write (new spec)

Fill the layout below. Size sections to the project: drop a subsection that
doesn't apply rather than writing "N/A", but keep the section numbers of the
remaining ones stable.

### 4b. Merge (existing spec)

- **Keep:** the existing headings and numbering, owner, and human-written
  prose (purpose, tradeoffs, open questions, rationale).
- **Change human prose only when the code contradicts it**, and list each
  such change in the summary to the user.
- **Refresh:** contracts, tables, state keys, references, diagrams, status.
- **Add** the agent-first sections (§0, §6) if missing, without renumbering
  existing sections (append or use the next free number).
- Mark resolved open questions as resolved (with where), don't delete them
  silently.
- Bump `Last updated`.

### 5. Verify before finishing

Run checks with real commands, fix every failure, re-run:

1. **Paths:** every path in backticks exists (`test -e`), except paths that
   are created at runtime, which must be described as such.
2. **Names:** every script, function, flag, env var, state key, exit code
   and config key named in the spec is found in the code (`rg -n`/grep).
3. **Line refs:** every `path:line` in §0's verify list points at the named
   symbol.
4. **Mermaid:** each block opens and closes, node ids are unique per block,
   every edge references defined nodes, labels with special characters are
   quoted.
5. **IDs:** section ids and `<a id>` anchors are unique; every `§N.M`
   cross-reference resolves.
6. **Tables:** each row has the header's column count.

Then show the user: the file path, a per-section summary (in update mode:
what changed, and any human prose changed because the code contradicted it),
and any remaining `TBD:` items.

## Spec layout

```markdown
# <project> — Design Spec

**Status:** <one paragraph: what is implemented, how it is driven>
**Last updated:** <YYYY-MM-DD>
**Owner:** <name (@handle)>

---

## 0. Agent quick reference <a id="s0"></a>
## 1. Purpose & Status <a id="s1"></a>
### 1.1 Inputs <a id="s1-1"></a>
### 1.2 Requirements <a id="s1-2"></a>
## 2. Overview <a id="s2"></a>
### 2.1 Control flow <a id="s2-1"></a>
### 2.2 Where things live <a id="s2-2"></a>
### 2.3 CI / automation <a id="s2-3"></a>
## 3. Contracts <a id="s3"></a>
### 3.1 State and config keys <a id="s3-1"></a>
## 4. Tradeoffs & Risks <a id="s4"></a>
## 5. Open Questions <a id="s5"></a>
## 6. Glossary <a id="s6"></a>
```

What each section holds:

| § | Content |
|---|---|
| 0 | **How to use this spec** (2-3 lines: which section answers what). **Section index** (id → one-line scope). **Invariants**: the project's hard rules as `MUST` / `MUST NOT` bullets, each with the code that enforces it (or "convention only"). **Verify**: commands to check the project works (tests, lint, a smoke run) and `path:line` pointers to the few most important places. |
| 1 | What the project does, for whom, and why it is split the way it is; non-goals. 1.1: every input (CLI args, flags, config files, env) as a table `Input \| Flag/key \| Default \| Notes`. 1.2: tools, access, credentials, resources, as a checklist. |
| 2 | 2.1: Mermaid `flowchart` of the main flow, including stop points (human gates, agent phases, failure exits). 2.2: Mermaid of components and external systems, plus a table `Path \| What \| Created by` (mark runtime-created paths). 2.3: jobs, triggers, inputs, secrets, artifacts, what runs without a human. |
| 3 | One table, one row per component/step: `# \| Component \| Inputs \| Outputs / side effects \| State set \| Exit codes \| Stops when`. 3.1: every state/config key: `Key \| Set by \| Read by \| Values`. Add 3.x subsections for protocols or file formats other components depend on. |
| 4 | Per tradeoff: the choice, the alternative, why, the cost, and the risk it leaves. Known risks with their mitigation (or "none yet"). |
| 5 | Numbered open questions: the question, the options, what blocks deciding, and the current default behaviour. Resolved ones stay, marked `Resolved: <where>`. |
| 6 | Every project-specific term, acronym and abbreviation: `Term \| Meaning \| Where defined`. |

## Writing rules (agent-first)

- **References:** `path` + symbol (`src/server/auth.py` → `verify_token`).
  Use `path:line` only in §0's Verify list; line numbers rot.
- **Rules** are `MUST` / `MUST NOT` / `SHOULD`, one per bullet, with the
  enforcing code or "convention only".
- **Facts go in tables**, prose only for rationale. One fact, one place;
  elsewhere cross-reference it (`see §3.1`).
- **Exact names:** literal flags, keys, exit codes, file names, in
  backticks, spelled as in the code.
- **Status per claim** when it varies: `(implemented)`, `(partial: …)`,
  `(planned)`.
- **Stable ids:** never renumber existing sections in update mode; every
  heading carries an `<a id>` anchor.
- **No marketing tone**, no "simply", no future promises outside §5.
- Write for a reader with no session context: expand acronyms in §6 and
  don't refer to "the conversation" or "earlier".
