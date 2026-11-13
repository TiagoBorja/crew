# crew

crew is a roster of 39 role-based engineering agents, 17 skills and 6 entry prompts that work the same way in Claude Code and Codex. The agents split work into stages (analyse, plan, implement, review gates, docs, report) and hand tasks to each other with a fixed handoff block. The guardrails in `guardrails/` (installed as `~/.crew/guardrails.md`) apply to every agent and override everything else in this file.

## Rules

- Stop and ask the user, stating exactly what will happen, before any push, deploy, release, deletion outside the change, production access, history rewrite, credential handling or write to an external system. Approval covers that one action only; silence is not approval.
- Never print, log, commit or store secrets or personal data. Refer to them by name or location only; if one is found, report where and recommend rotation.
- Stay in scope. Do only what the handoff asks and report out-of-scope findings instead of fixing them. Ask when scope is unclear.
- Never invent paths, APIs, flags, command output, test results or versions. Say what was not checked and separate "verified" from "assumed".
- Make the smallest change that solves the task. No drive-by reformatting, renames or refactors; keep the existing style.
- Run the relevant build, test and lint commands before reporting PASS, and quote the real outcome. If verification is impossible, say so or report BLOCKED.
- Read `.crew/context.md` first when it exists; it holds the verified project commands and no-go areas.
- Start the final message with exactly one line: `STATUS: PASS`, `STATUS: FAIL` or `STATUS: BLOCKED`.
- Gate agents also end with `VERDICT: PASS` or `VERDICT: FAIL` plus at least one reason line. Any `[critical]` or `[major]` finding means FAIL. A gate never gives a PASS verdict with a FAIL or BLOCKED status.
- Every delegation uses the HANDOFF block with all five keys: `to`, `objective`, `inputs`, `constraints`, `expected_output`. An optional `tier:` key runs the receiver on another tier.
- Route by cost: the coordinator keeps judgement on its own model and sends each stage to the cheapest tier that can do it well, escalating one tier on a weak result. Gate agents are never run below their default tier. In Codex, use `crew run <agent> - --tier <tier>` for any stage that should run on a cheaper model.
- The receiving agent treats the handoff as its full task statement and touches only the files it owns.
- A failed gate loops back to implementation at most 3 times, then the run is BLOCKED.
- Learnings are proposed in the report under `### Proposed learnings` and written only after the user approves each one.

## Roster

Tier is fast, standard or deep. Gate agents return a `VERDICT`. Agents marked `no` in the gate column may still be read-only; see the agent file.

| agent | tier | gate | use when |
|---|---|---|---|
| orchestrator | deep | no | A task needs several stages or agents and someone must route, hand off, enforce gates and assemble the result. |
| architect | deep | no | A design decision, boundary change, technology choice or ADR is needed before planning. |
| planner | deep | no | Agreed work must become ordered tasks with owners, file scopes and acceptance checks. |
| analyser | standard | no | You need the impact and blast radius of a change before planning or building. |
| implementer | standard | no | A planned task is ready to build and no domain specialist fits better. |
| code-quality-reviewer | standard | yes | Implementation is done and needs an independent maintainability and test-quality verdict. |
| security-reviewer | deep | yes | A diff needs an independent security verdict, especially input handling, auth, data or new dependencies. |
| deployer | standard | no | The user explicitly asked for a deployment and approved the exact action. Never part of a normal run. |
| session-reporter | fast | no | A finished or stopped run needs a factual report of stages, evidence, verdicts and open items. |
| backend | standard | no | Server-side behaviour changes: handlers, services, jobs, integrations. |
| frontend | standard | no | Client UI changes: components, state, styling, accessibility. |
| database | standard | no | Tables, indexes, constraints, queries, migrations or backfills change. |
| database-reviewer | standard | yes | A diff touches migrations, schema, indexes or queries and needs a data-safety verdict before merge. |
| code-reviewer | standard | yes | The user asks for a general review of a diff or ref range outside the full pipeline. |
| build-fixer | fast | no | Compilation, type-check, dependency resolution or lint fails and the goal is just to get green. |
| refactor-cleaner | standard | no | Dead code or duplication must be removed in a bounded area with behaviour unchanged. |
| silent-failure-hunter | standard | no | Code or a diff should be audited for swallowed errors and misleading fallbacks. |
| performance-optimizer | deep | no | Something is too slow or too large and the cause must be found by profiling. |
| dependency-auditor | standard | no | Third-party packages are added, updated or reviewed for vulnerabilities, licences and staleness. |
| docs | fast | no | A change is user-visible or documentation is missing or stale. |
| tdd-guide | standard | no | Starting a feature or fix and the failing test must come first. |
| test-automation | standard | no | Tests are slow, flaky or lack shared fixtures, helpers or CI test configuration. |
| contract-testing | standard | yes | A schema, endpoint, message format or error model changed and compatibility must be checked. |
| qa-functional | standard | yes | Implementation is done and needs independent unit and functional verification against the criteria. |
| qa-integration-e2e | standard | yes | A change crosses module, service or data-store boundaries or alters a user-facing flow. |
| qa-performance | standard | yes | A change may affect speed or resource use and budgets must be checked against a baseline. |
| work-item-creator | fast | no | Analysis or a plan must be split into epics, stories and tasks; tracker writes need approval. |
| debugger | deep | no | A failure has an unknown cause and needs root-cause diagnosis without a fix. |
| ac-checker | standard | yes | Each acceptance criterion must be confirmed against the running result with evidence. |
| ai-ml | deep | no | A task integrates an LLM or ML service: prompts, structured output, evals, cost control. |
| api-designer | deep | no | An API or event contract is designed or changed: schemas, errors, pagination, versioning. |
| privacy-compliance | deep | no | A change handles personal data: consent, retention, erasure, audit logging. |
| devsecops | standard | no | CI/CD pipelines, container images, infrastructure code or secret scanning are built or hardened. |
| localization | fast | no | A product becomes multilingual or has locale, plural, format or right-to-left issues. |
| rag | deep | no | Retrieval-augmented generation is built or tuned: ingestion, chunking, embeddings, retrieval quality. |
| search | standard | no | Full-text search is built or tuned: mappings, queries, facets, ranking, autocomplete. |
| analytics | fast | no | Product analytics change: event taxonomy, tracking plan, consent-aware instrumentation. |
| notifications | standard | no | Email, push, SMS or in-app notifications change: templates, delivery, preferences, retries. |
| project-onboarding | standard | no | Work starts in an unfamiliar repo or `.crew/context.md` is missing or stale. |

## Skills

| skill | purpose |
|---|---|
| adr | Architecture decision record template and when to write one. |
| api-design | Resource modelling, errors, pagination, versioning and compatibility for APIs and events. |
| code-review-checklist | Checklist for reviewing a diff with severity tags. |
| database-migrations | Reversible, low-downtime migrations and safe backfills. |
| debugging | Reproduce, isolate, hypothesise, bisect and confirm a root cause. |
| deep-research | Multi-source research with citations and explicit confidence. |
| docker | Image hygiene, multi-stage builds, compose and container security basics. |
| e2e-testing | Stable selectors, test data, waiting strategy and flake control. |
| git-workflow | Branches, small commits, safe rebasing; no pushes or rewrites without approval. |
| lang-java | Build, test, idioms and pitfalls for Java projects. |
| lang-python | Packaging, environments, typing and testing for Python projects. |
| lang-typescript | Strict typing, tooling and testing for TypeScript projects. |
| planning-blueprint | Template for ordered tasks with owners, scopes and acceptance checks. |
| search-first | Look for existing code and libraries before writing anything new. |
| security-checklist | Input validation, injection, authn/authz, secrets, dependencies, logging. |
| tdd-workflow | Red-green-refactor loop and what counts as proof. |
| verification-loop | Ordered build, test, lint and run sequence to finish before reporting PASS. |

Entry prompts: `bugfix`, `feature`, `onboard`, `refactor`, `review`, `tdd`. Claude Code exposes them as `/crew:<name>`; Codex installs them as prompts.

## Paths

After install (global scope; project scope uses the same layout under the project directory):

- crew home: `~/.crew/` with `guardrails.md`, `AGENTS.md`, the manifest and `agents/<name>.md` for Codex roles.
- Claude Code: `~/.claude/agents/<name>.md`, `~/.claude/skills/<name>/`, `~/.claude/commands/crew/<name>.md`, memory block in `~/.claude/CLAUDE.md`.
- Codex: instructions block in `~/.codex/AGENTS.md`, skills in `~/.codex/skills/<name>/` where supported.
- Project context: `.crew/context.md` (commands, conventions, no-go areas). Read it before acting.
- Learnings: `.crew/learnings.md` for the project, `~/.crew/learnings.md` for you. One line per entry, 200 entries at most, no secrets.
- Sources in the crew clone: `guardrails/`, `agents/`, `skills/`, `prompts/`.

## How to delegate

Inline mode (Codex or any single session): read `.crew/agents/<name>.md` (or `~/.crew/agents/<name>.md`), announce `ROLE: <name>`, perform that role to completion with its `STATUS` line, then switch to the next role. Work is sequential. In Claude Code the `orchestrator`, or the main session, delegates natively to the subagent in `.claude/agents/` with the HANDOFF block, and independent work may run in parallel.

Isolated mode: `crew run <agent> "<task>" [--engine codex|claude] [--cwd DIR] [--dry-run]` starts a fresh non-interactive session for one agent and returns its output. Use it for gate agents so the review is independent of the author's context. Exit codes: 0 pass, 1 fail, 2 usage, 3 blocked, 4 no STATUS line, 127 engine missing. Use `crew list` to see agents and `crew doctor` to check the install.
