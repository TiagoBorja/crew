---
name: git-workflow
description: Branching, commit message and small-commit habits, safe rebasing, and rules that forbid history rewrites and pushes without approval. Use when creating branches, committing, preparing a change for review, or resolving conflicts.
tags: [git, process]
---

# Git workflow

## Ground rules
- Never `git push` (any form), force-push, rewrite shared history, delete branches or tags outside the current change without explicit user approval. State exactly what will happen and wait.
- Never commit secrets, local config, build output or large generated files. Check `git status` and `git diff --staged` before each commit.
- Do not change git configuration or hooks unless asked. Never bypass hooks (`--no-verify`) without approval.
- Prefer commands that cannot lose work. Before anything destructive, confirm there is nothing uncommitted you would destroy.

## Branches
- Work on a short-lived branch off the project's main line; do not commit directly to the main branch unless the project's convention says so.
- Name: `<type>/<short-kebab-summary>`, e.g. `feature/export-csv`, `fix/null-user-lookup`, `chore/update-linter`. Follow the project convention if different.
- One concern per branch. Keep branches small enough to review in one sitting.

## Commits
- Small, self-contained, buildable commits. Each should pass the tests on its own where practical.
- Stage deliberately (`git add -p` or named paths), not blindly with `-A`.
- Message format:
  ```
  <type>: <imperative summary, 50-72 chars>

  <optional body: why this change, what was considered, side effects>
  ```
  Types commonly used: feat, fix, refactor, test, docs, chore, build, ci, perf.
- Subject says what; body says why. Do not describe the diff line by line.
- Reference an issue id when the project uses them. Match existing history style (`git log --oneline -20`).
- Separate mechanical changes (formatting, renames, moves) from behavioural ones.

## Staying current
- Inspect before integrating: `git fetch`, then `git log --oneline HEAD..origin/<main>` and `git diff HEAD...origin/<main> --stat`.
- On an unshared local branch, rebasing onto the main line is fine for a linear history. On a shared branch, merge instead, or ask.
- Abort a confused operation with `git rebase --abort` / `git merge --abort` rather than improvising.

## Resolving conflicts
1. List conflicted files (`git status`). Open each and understand both sides; do not pick one blindly.
2. Keep the intent of both changes. Run build and tests after resolving.
3. Never leave conflict markers; search for `<<<<<<<` before committing.

## Undoing safely
- Unstage: `git restore --staged <path>`.
- Discard a local edit: only after confirming it is yours and unwanted; `git restore <path>`.
- Undo a published commit: `git revert <sha>` (new commit), not reset.
- Fix the last unpushed commit: `git commit --amend` is acceptable only if it is unpushed and yours.
- Lost something? `git reflog` shows where HEAD has been.

## Before handing off
- `git status` clean except intended files; `git diff` read through once.
- Tests and lint run (see skill:verification-loop).
- Summarise the commits made. Pushing and opening a review request are left to the user unless they approved them.
