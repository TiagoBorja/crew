---
name: onboard
description: Inspect a repository and create or refresh .crew/context.md with its stack, commands, conventions and no-go areas. Use when starting work in a new project or when the project context is missing or stale.
agent: project-onboarding
argument_hint: <optional focus, subdirectory or notes about the project>
---

Create or refresh the project context file `.crew/context.md` for this repository.

Notes from the user (may be empty):

$ARGUMENTS

Procedure:
1. If `.crew/context.md` exists, read it and treat it as the starting point; keep correct entries and update stale ones. Read `.crew/learnings.md` too if present.
2. Inspect the repository: build and dependency files, lock files, CI configuration, container and infrastructure files, README and contributing docs, test layout, linter and formatter configuration, recent history (`git log --oneline -20`).
3. Fill every section of the context template: Summary, Stack, Commands (install, build, test, test single, lint/format, run locally), Conventions (layout, naming, testing style, branching and commits), No-go areas, Environments, Relevant skills (for example skill:lang-python or skill:docker, only those that apply).
4. Derive values from the repository only. Mark anything you could not confirm by running or reading as `(unverified)`. Where practical, run safe read-only commands (for example list scripts, print tool versions) to confirm them; do not run anything that deploys, deletes or touches external systems.
5. Never write secrets, credentials, personal data or hostnames with credentials into the file. Reference where configuration lives, not its values.
6. Propose up to five initial learnings under `### Proposed learnings` in your report. Do not write them to the learnings file until I approve them.
7. Report the file written, the commands you confirmed, the items left unverified and open questions.

Only create or edit `.crew/context.md`. Do not modify source files.
