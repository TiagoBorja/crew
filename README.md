# crew

crew is a personal, project-agnostic multi-agent framework for AI coding
tools. It ships 39 role-based agents, 17 skills and 6 entry prompts, written
once as neutral markdown and rendered by `install.sh` into the native formats
of Claude Code and Codex CLI. Any other tool that reads `AGENTS.md` can use the
same roles inline. Agents are stack-neutral; project facts live in
`.crew/context.md`.

crew is not related to CrewAI.

Status: 0.1.0. The Claude Code and Codex CLI integrations have not yet
been verified against the real tools (see `CHANGELOG.md`).

## Quick start

```
git clone <this repository> crew && cd crew
./install.sh --dry-run          # see what would happen, write nothing
./install.sh --global           # install to ~/.crew, ~/.claude, ~/.codex
cd your-project
/path/to/crew/install.sh --project   # optional: project-level install
crew doctor                     # check installed files and tools
```

Put `bin/crew` on your `PATH` to use the `crew` command.

## Install

`install.sh` is POSIX `sh` plus `awk`, makes no network calls, lints the source
first and refuses to write if the source is invalid. Re-running it is
idempotent: the second run only reports `skip`.

| Flag | Meaning |
|---|---|
| `--global` | Install to user-level paths (default). |
| `--project [DIR]` | Install to project `DIR` (default: current directory). |
| `--target T` | `claude`, `codex` or `all`. Default: `DEFAULT_TARGET` in `~/.crew/config`, else `all`. |
| `--dry-run` | Print every planned action, write nothing. |
| `--update` | Re-render; keep edited files; remove files that left the source. |
| `--uninstall` | Remove crew files and managed blocks listed in the manifest. |
| `--link` | Symlink pure-copy files (skills) to the source, for developing crew. |
| `--help` | Print usage. |

Printed actions: `create`, `update`, `skip`, `conflict`, `remove`, `keep`.

A file you edited is never overwritten: the new version is written next to it as
`<file>.crew-new` and the run ends with a conflict. Content outside the managed
blocks (`<!-- crew:begin -->` / `<!-- crew:end -->` in markdown, `# crew:begin` /
`# crew:end` in TOML) is never touched.

Exit codes: 0 ok, 1 error, 2 usage, 3 conflicts, 4 missing utility, 5 invalid source.

What is installed (project scope uses the same layout under the project; Codex
skills, prompts and profiles are global only):

| Item | Location |
|---|---|
| crew home | `~/.crew/` (`AGENTS.md`, `guardrails.md`, `agents/`, `skills/`, `config`, `learnings.md`, `manifest.json`, `VERSION`) |
| Claude Code | `~/.claude/agents/`, `~/.claude/skills/`, `~/.claude/commands/crew/`, managed block in `~/.claude/CLAUDE.md` |
| Codex | managed block in `~/.codex/AGENTS.md`, `~/.codex/skills/`, `~/.codex/prompts/`, profiles in `~/.codex/config.toml` |
| Project | `.crew/context.md` and `.crew/learnings.md` (created once, commit them) |

The installer prints a hint to ignore the rendered `.claude/agents/`,
`.claude/skills/`, `.claude/commands/crew/` and `.crew/agents/` in a project; it
never edits your `.gitignore`.

## Usage

### Claude Code

Agents are installed as subagents, so the main session (or the `orchestrator`)
delegates to them natively with a HANDOFF block and can run independent work in
parallel. Entry prompts are slash commands: `/crew:feature`, `/crew:bugfix`,
`/crew:review`, `/crew:refactor`, `/crew:tdd`, `/crew:onboard`.

### Codex and other AGENTS.md-aware tools

- Inline: the instructions block tells the session to read
  `.crew/agents/<name>.md` (or `~/.crew/agents/<name>.md`), announce
  `ROLE: <name>`, finish that role with its `STATUS` line, then switch roles.
  Work is sequential.
- Isolated: `crew run <agent> "<task>"` starts a fresh non-interactive session
  for one agent. Use it for gate agents so the review is independent of the
  author's context.

## The `crew` CLI

```
crew run <agent> "<task>" [--tier fast|standard|deep] [--engine codex|claude] [--cwd DIR] [--dry-run]
crew list      agents with tier, gate and description
crew doctor    installed files vs manifest, tools on PATH, versions
crew version
crew help
```

`crew run <agent> -` reads a full HANDOFF block from stdin. Agents are looked up
in `./.crew/agents` (or `--cwd`) first, then `~/.crew/agents`. The engine
defaults to `RUN_ENGINE` in `~/.crew/config`. Exit codes of `crew run`: 0 pass,
1 fail, 2 usage, 3 blocked, 4 no STATUS line, 127 engine missing.

`--tier` (or a `tier:` line in the HANDOFF) runs an agent on another tier than
its default. Gate agents can be raised but never lowered.

## Cost routing

Run the orchestrator on your strongest model and let it hand the work down.
It keeps intake, routing and judgement for itself and sends each stage to the
cheapest tier that can do it well:

| tier | Claude default | typical work |
|---|---|---|
| fast | haiku | mechanical, fully specified changes, search, summaries |
| standard | sonnet | normal implementation, refactors, most reviews, docs |
| deep | opus | design choices, unclear defects, security, migrations |

A weak result (FAIL, no STATUS line, output that misses the handoff) is retried
once on the next tier up, and the stage log records every tier and escalation.
Gate agents never run below their default tier. In Codex, inline roles share
the session model, so the orchestrator uses `crew run <agent> - --tier <tier>`
for any stage that should run cheaper. Change which model each tier maps to in
`~/.crew/config`.

## Roster

Tiers (fast, standard, deep) map to models, see Configuration. Gates return a
`VERDICT`.

### Pipeline

| Agent | Purpose |
|---|---|
| orchestrator | Entry point for multi-step work: plans the route, sends handoffs, enforces gates, assembles the result. |
| architect | System design, trade-offs, interface and technology decisions, ADRs. |
| planner | Turns an objective into ordered tasks with owners, file scopes and acceptance checks. |
| analyser | Impact analysis: affected modules, callers, data, tests and blast radius. |
| implementer | Test-first implementation of one assigned task inside its file scope. |
| code-quality-reviewer | Gate on maintainability, readability, structure and test quality. |
| security-reviewer | Gate on vulnerabilities, secrets, injection, authorisation and unsafe dependencies. |
| deployer | Runs a deployment the user explicitly approved, with smoke test and rollback plan. |
| session-reporter | Factual report of a run: stages, evidence, verdicts, open items, proposed learnings. |

### Engineering

| Agent | Purpose |
|---|---|
| backend | Server-side handlers, services, jobs and integrations, test-first. |
| frontend | UI components, state, styling and accessibility, test-first. |
| database | Schemas, reversible migrations, queries and backfills. |
| database-reviewer | Gate on migrations, queries and schema changes: data safety, locking, performance. |
| code-reviewer | General on-request review of a diff or ref range, with a verdict. |
| build-fixer | Gets a broken build, type-check or lint step green with minimal edits. |
| refactor-cleaner | Removes dead code and duplication with behaviour unchanged. |
| silent-failure-hunter | Finds swallowed errors, misleading fallbacks and lost context. |
| performance-optimizer | Profiles and fixes latency, memory, query and bundle-size problems. |
| dependency-auditor | Audits dependencies for vulnerabilities, licences, pinning and staleness. |
| docs | READMEs, API docs, ADRs, changelogs and runbooks that match the code. |
| tdd-guide | Writes the failing test first and enforces red, green, refactor. |
| test-automation | Fixtures, helpers, test data, CI test configuration, flaky-test repair. |
| contract-testing | Gate on API and event contract compatibility between producers and consumers. |
| qa-functional | Gate: runs unit and functional tests and checks acceptance criteria. |
| qa-integration-e2e | Gate: runs integration and end-to-end tests against real components. |
| qa-performance | Gate: checks performance budgets and benchmarks against a baseline. |
| work-item-creator | Epics, stories and tasks with acceptance criteria, as markdown. |
| debugger | Diagnoses a failure to its root cause without fixing it. |
| ac-checker | Gate: verifies each acceptance criterion against the running result with evidence. |

### Domain

| Agent | Purpose |
|---|---|
| ai-ml | LLM or ML integration: prompts, structured output, evals, cost control. |
| api-designer | API and event contracts: schemas, errors, pagination, versioning. |
| privacy-compliance | Consent, retention, erasure, audit logging, privacy impact notes (not legal advice). |
| devsecops | CI/CD, container and infrastructure-as-code hardening, secret scanning. |
| localization | Translation keys, message formats, locale formatting, right-to-left. |
| rag | Retrieval-augmented generation: ingestion, chunking, embeddings, retrieval quality. |
| search | Full-text search: mappings, queries, facets, ranking, autocomplete, relevance tests. |
| analytics | Event taxonomy, tracking plan and consent-aware instrumentation. |
| notifications | Email, push, SMS and in-app notifications: templates, delivery, preferences, retries. |

### Setup

| Agent | Purpose |
|---|---|
| project-onboarding | Inspects a repository, writes `.crew/context.md`, proposes initial learnings. |

## Skills and prompts

Skills: `adr`, `api-design`, `code-review-checklist`, `database-migrations`,
`debugging`, `deep-research`, `docker`, `e2e-testing`, `git-workflow`,
`lang-java`, `lang-python`, `lang-typescript`, `planning-blueprint`,
`search-first`, `security-checklist`, `tdd-workflow`, `verification-loop`.

Prompts:

| Prompt | Purpose |
|---|---|
| feature | Full delivery pipeline for a new feature, from intake to report. |
| bugfix | Reproduce with a failing test, find the root cause, fix minimally, verify, review. |
| review | Review the working-tree diff or a ref range, findings by severity plus verdict. |
| refactor | Behaviour-preserving cleanup in small verified steps. |
| tdd | Test-first implementation of a small, well-defined unit. |
| onboard | Create or refresh `.crew/context.md` for the current repository. |

## Configuration, context and learnings

`~/.crew/config` is plain `KEY=VALUE` (never executed), created once and never
overwritten. Keys: `CLAUDE_MODEL_FAST|STANDARD|DEEP` (defaults haiku, sonnet,
opus), `CODEX_MODEL_FAST|STANDARD|DEEP` (empty: Codex default),
`CODEX_EFFORT_FAST|STANDARD|DEEP` (low, medium, high), `DEFAULT_TARGET`
(`all`) and `RUN_ENGINE` (`codex`). Edit it to override the tier mapping, then
run `install.sh --update` to re-render.

`.crew/context.md` holds a project's verified commands, conventions and no-go
areas; agents read it first. Create it with the `onboard` prompt or the
`project-onboarding` agent.

Learnings live in `.crew/learnings.md` (project) and `~/.crew/learnings.md`
(personal): one line per entry, at most 200, no secrets. Agents only propose
learnings under `### Proposed learnings`; one is written after you approve it.

## Output contract

Every final message starts with exactly one line: `STATUS: PASS`, `STATUS: FAIL`
or `STATUS: BLOCKED`. Gate agents also end with `VERDICT: PASS` or
`VERDICT: FAIL` and at least one reason line; any `[critical]` or `[major]`
finding means FAIL, and a gate never passes with a FAIL or BLOCKED status.
Delegations use a HANDOFF block with `to`, `objective`, `inputs`, `constraints`
and `expected_output`. A failed gate loops back to implementation at most 3 times,
then the run is BLOCKED.

## Guardrails

Sources are in `guardrails/` and installed as `~/.crew/guardrails.md`. They
apply to every agent and override everything else:

- approval: ask before push, deploy, release, deletion, production access, history rewrite, credential handling or external writes; approval covers one action;
- secrets: never print, log, commit or store secrets or personal data;
- scope: do only what the handoff asks, report the rest;
- honesty: never invent paths, flags, output or results; separate verified from assumed;
- minimal diffs: smallest change that solves the task;
- verification: run build, test and lint before reporting PASS and quote the outcome;
- output contract: the STATUS and VERDICT lines above.

## Development

```
scripts/lint.sh               # source linter (rules L01-L13, W01); exit 1 on L-rule failure
tests/run.sh                  # all tests: lint, install, render snapshots, crew run, check-terms
scripts/check-terms.sh --all  # secret and forbidden-term scan of tracked files
git config core.hooksPath .githooks   # once per clone
```

The pre-commit hook runs the term scan on staged changes and the linter;
the commit-msg hook scans the message. CI (`.github/workflows/ci.yml`) runs lint,
check-terms, tests and shellcheck (when installed) on Linux and macOS.
`tests/smoke.sh` runs a real `crew run` and only runs with `CREW_SMOKE=1` and
`claude` or `codex` on `PATH`.

`check-terms.sh` always checks for common secret patterns. To also block your
own terms (client names, internal hosts), list them one per line in
`~/.crew/denylist` or in the file named by `CREW_DENYLIST_FILE`. Keep that file
out of the repository.

## Uninstall

```
./install.sh --uninstall                    # global
./install.sh --uninstall --project DIR      # a project
```

Only files whose content still matches the manifest are removed; edited files
are reported and kept. `config`, `learnings.md` and `context.md` are yours.

## Supported versions

Version 0.1.0. The installer targets macOS and Linux (CI runs both) with POSIX
`sh` and `awk`. Claude Code and Codex CLI versions are not pinned; the
integrations have not yet been verified against real releases.

## License

MIT, see `LICENSE`.
