# Changelog

All notable changes to this project are recorded here.
The format follows Keep a Changelog; versions follow semantic versioning.

## [Unreleased]

### Added
- `ste` skill: house rules for Simplified Technical English; the docs, code-reviewer and session-reporter agents use it.
- Cost routing: the orchestrator sends each stage to the cheapest tier that fits, escalates one tier on a weak result and never lowers a gate.
- `crew run --tier fast|standard|deep` and an optional `tier:` key in the HANDOFF block.

## [0.1.0]

### Added
- 39 stack-neutral agents in four groups: pipeline, engineering, domain, setup.
- 17 skills and 6 entry prompts (`feature`, `bugfix`, `review`, `refactor`, `tdd`, `onboard`).
- Seven guardrails and the STATUS / VERDICT output contract with the HANDOFF block.
- `AGENTS.md` source with roster, delegation rules and paths.
- `install.sh` with `--global`, `--project`, `--target`, `--dry-run`, `--update`, `--uninstall`, `--link`; manifest, edited-file protection, managed blocks and exit codes 0-5.
- Renderers for Claude Code (subagents, skills, `/crew:<name>` commands, memory block) and Codex (instructions block, skills, prompts, profiles).
- `bin/crew` with `run`, `list`, `doctor`, `version`, `help`; inline and isolated (`crew run`) delegation.
- `~/.crew/config` tier-to-model overrides, `.crew/context.md` project context and `learnings.md` files.
- Source linter `scripts/lint.sh` (rules L01-L13, W01), secret and forbidden-term scanner `scripts/check-terms.sh`, commit hooks, test suite with fixtures and snapshots, optional smoke test, and CI on Linux and macOS.
- Repository skeleton: license, version file, ignore rules, readme.

### Known limitations
- The Claude Code and Codex CLI integrations are not yet verified against the real tools: Codex skills and prompts paths, `config.toml` profiles, `codex exec --profile --sandbox`, `claude -p --model --allowedTools --append-system-prompt`, `/crew:<name>` commands, and the Codex project-doc size limit.
- Smoke tests (`tests/smoke.sh`) only run with `CREW_SMOKE=1` and a real engine on `PATH`.
