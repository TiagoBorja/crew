---
name: planning-blueprint
description: Template for breaking work into ordered tasks with owners, file scopes, dependencies and acceptance checks. Use when planning a feature or fix before implementation, splitting work across agents, or reviewing a plan.
tags: [planning, process]
---

# Planning blueprint

A plan is useful when someone else can execute each task without asking questions. Keep it as small as the work allows.

## Before planning
1. Confirm the objective in one testable sentence and list acceptance criteria. If unclear, ask; do not plan around guesses.
2. Read `.crew/context.md` and the relevant code. Look for existing solutions first (skill:search-first).
3. Note constraints: no-go areas, deadlines, compatibility promises, approvals required.
4. For decisions with real trade-offs, record them separately (skill:adr) and link them.

## Plan template
```
# Plan: <title>
Objective: <one sentence>
Acceptance criteria:
- AC1: <observable, testable>
Out of scope: <explicit exclusions>
Assumptions / open questions: <list, mark unverified>
Risks: <risk -> mitigation>

## Tasks
### T1 <short title>
- Owner: <agent or person>
- Depends on: none | T<n>
- File scope: <paths this task may touch, and only these>
- Steps: <numbered, concrete>
- Acceptance check: <command or observation proving it done>
- Tests: <test to write first>
- Approval needed: none | <action>

## Order and parallelism
<which tasks can run in parallel (disjoint file scopes) and which are sequential>

## Verification
<commands for the final check; gates to run; manual checks>

## Rollback
<how to undo or disable if it goes wrong>
```

## Writing good tasks
- Each task is small: about one commit, one concern, one reviewer sitting. If it has "and", split it.
- Start with a walking skeleton or the riskiest part so surprises appear early.
- Put tests first inside each task (skill:tdd-workflow). Put migrations and contracts before the code that uses them.
- File scopes must not overlap between tasks that run in parallel. If they must overlap, make them sequential.
- Name concrete paths and symbols where known; mark guessed ones as unverified.
- Acceptance checks are commands or observable results, never "looks good".
- Include non-functional work when relevant: docs, changelog, logging, security checks, performance budgets.

## Sizing and risk
- Label each task S, M or L. Break up anything beyond L.
- Flag tasks that touch shared interfaces, data, security or deployment; they need review gates and possibly approval.
- State the confidence of the plan and what would change it.

## Presenting
- Show the plan to the user and get confirmation before implementation for non-trivial work.
- Keep the plan current: mark tasks done with the evidence, and record deviations and why.
