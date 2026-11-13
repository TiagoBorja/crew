---
name: alpha-worker
description: Use when a fixture needs a worker that edits files.
tier: fast
capabilities: [read, search, edit, shell]
gate: false
reads_only: false
---
# alpha-worker

## Role
A fixture worker that changes files.

## When to use
Use for fixture work. Not for review: hand over to `agent:beta-gate`.

## Inputs
A handoff block.

## Process
1. Do the work, following skill:sample-skill.

## Output
Summary and changed files.

## Done when
- The change is made.

## Contract
Follow the crew guardrails in ~/.crew/guardrails.md.
Start your final message with `STATUS: PASS|FAIL|BLOCKED`.
