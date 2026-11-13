---
name: verification-loop
description: Ordered build, test, lint and run sequence to execute before claiming a task is done, with rules for quoting evidence. Use when finishing any change, before reporting PASS, or when a gate needs proof.
tags: [process, quality]
---

# Verification loop

## Find the commands first
1. Read `.crew/context.md` (section Commands) when it exists.
2. Otherwise inspect build files, task runners, CI config and the README. Do not guess: if no command can be found, say so and ask or report BLOCKED.
3. Mark commands you could not confirm as unverified in the report.

## Sequence
Run from cheapest to most expensive, stopping at the first failure to fix it before continuing.
1. **Install / restore** dependencies only if the build needs it and the project's normal flow does so.
2. **Format / lint.** Run the project's linter and formatter check, limited to touched files when the tool allows.
3. **Type-check / compile.** Fail on warnings if the project does.
4. **Unit tests** for the touched area, then the whole unit suite.
5. **Integration / e2e tests** when the change crosses a boundary (database, network, UI flow).
6. **Run it.** For user-visible behaviour, start the application or call the function/endpoint and observe the real result. Tests passing is not the same as the feature working.
7. **Diff review.** Read your own diff: stray debug output, unrelated edits, leftover files, secrets, TODOs you introduced.

## Evidence rules
- Quote the actual command and the actual outcome (exit code, pass/fail counts, relevant error lines). Trim noise but never alter text.
- Never write "tests pass" without having run them in this session after the last edit.
- Re-run the whole sequence after any further edit; evidence from before the edit is stale.
- If a failure pre-exists on the base revision, show that (run it on a clean checkout) and report it as pre-existing, not as yours and not as hidden.
- If something could not be run (missing service, no credentials, no network), state exactly what was skipped and why. This makes the result BLOCKED or a flagged gap, never a silent PASS.

## Handling failures
- Read the first error, not the last. Fix root causes, not symptoms.
- Do not disable, skip or weaken a test to get green unless the requirement changed and you say so.
- After three failed attempts on the same failure, stop and report with what you tried. See skill:debugging.

## Report template
```
Commands run:
- <command> -> <exit code / summary line>
Not run:
- <command> -> <reason>
Observed behaviour:
- <what was seen when running the feature>
Result: all green | failures remain (list)
```
