---
name: review
description: Review the current working-tree diff or a given ref range and report findings by severity with a gate verdict. Use before merging, after implementing a change, or when asked for a second pair of eyes.
agent: code-reviewer
argument_hint: <optional ref range, e.g. main..HEAD, or paths to focus on>
---

Review the change described below. This is a read-only task: do not modify files.

Target (empty means the current uncommitted and staged changes; otherwise a ref range, commit or paths):

$ARGUMENTS

Procedure:
1. Determine the diff: for an empty target use `git diff` and `git diff --staged`; for a range use `git diff <range>` and `git log` for its messages. Read the changed files in context, not only the hunks.
2. Establish intent from commit messages, task text and tests. If intent is unclear, say what you assumed.
3. Review using skill:code-review-checklist: correctness, error handling, tests, design and clarity, size and scope. Add a security scan per skill:security-checklist where untrusted input, credentials or data access are involved.
4. Run the build, tests and lint when feasible and quote the results (skill:verification-loop). If you could not run something, say so.
5. Report findings ordered by severity, each tagged `[critical]`, `[major]`, `[minor]` or `[nit]`, with file and line, the problem, its impact and a suggested fix.
6. End with a short summary of what was and was not checked, then the verdict block required by the output contract. Any critical or major finding means VERDICT: FAIL.

Do not post comments to any external system and do not push anything; present the findings here.
