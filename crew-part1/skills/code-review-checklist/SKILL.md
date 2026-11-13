---
name: code-review-checklist
description: Checklist for reviewing a diff for correctness, clarity, tests, error handling, naming and size, with severity tags. Use when reviewing a change, self-reviewing before handoff, or writing review findings.
tags: [review, quality]
---

# Code review checklist

## How to review
1. Understand intent first: read the task, description or commit messages. Decide what the change is supposed to do.
2. Look at the whole diff shape (`--stat`) before the details. Is the size reasonable? Is anything unexpected touched?
3. Read tests first; they state the intended behaviour. Then read the code against them.
4. Run the build and tests when you can (see skill:verification-loop). Review without running is a stated limitation.
5. Report findings with file and line, what is wrong, why it matters, and a suggested fix.

## Severity tags
- `[critical]` data loss, security hole, crash on a main path, broken build. Blocks.
- `[major]` incorrect behaviour in a realistic case, missing error handling, missing tests for new logic, breaking compatibility. Blocks.
- `[minor]` readability, naming, small duplication, style inside project conventions. Does not block.
- `[nit]` taste. Optional; keep rare.
Any critical or major finding means the review verdict is FAIL.

## Correctness
- Does the code do what the task says, including edge cases: empty, null, zero, one, many, maximum, duplicates, unicode, time zones?
- Off-by-one errors, wrong comparison operators, inverted conditions, integer overflow, floating-point equality.
- Concurrency: shared mutable state, races, ordering assumptions, missing locks or transactions, non-idempotent retries.
- Resource handling: files, connections, streams and timers closed on all paths.
- Behaviour on the unhappy path: what happens when a dependency fails or is slow?

## Error handling
- No swallowed exceptions or empty catch blocks; no fallback that hides a real failure.
- Errors carry context (what failed, which input id) without leaking secrets or personal data.
- Errors propagate to a layer that can handle them; user-facing messages are safe and useful.

## Tests
- New behaviour has tests; a bug fix has a regression test that failed before.
- Tests assert outcomes, are deterministic and independent, and are named by behaviour.
- Edge and error cases are covered, not only the happy path.
- No tests disabled or weakened without a reason in the diff.

## Design and clarity
- Names reveal intent; no misleading names, no abbreviations that need a legend.
- Functions do one thing; deep nesting and long parameter lists are flagged.
- Comments explain why, not what; no stale or commented-out code.
- Follows existing patterns and layering; no new abstraction without a second use.
- Public interfaces: backward compatibility, validation at boundaries, documented behaviour.

## Size and scope
- One concern per change. Unrelated formatting, renames or refactors are called out and should be split.
- Large diffs: ask for a split, or review by commit.

## Security and operations quick scan
- Untrusted input validated; no string-built queries or commands; secrets not in code or logs. For depth use skill:security-checklist.
- New configuration documented; migrations safe (skill:database-migrations); logging not noisy or sensitive.

## Output shape
List findings ordered by severity. For each: tag, location, problem, impact, suggested fix. End with a short summary of what was checked, what was not, and the verdict.
