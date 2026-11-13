---
name: beta-gate
description: Use for fixture reviews that must end with a verdict.
tier: standard
capabilities: [read, search]
gate: true
reads_only: true
---
# beta-gate

## Role
A fixture reviewer.

## When to use
Use for review. Not for edits: use `agent:alpha-worker`.

## Inputs
A handoff block.

## Process
1. Review the change.
2. A fenced example may hold headings:

```
## Not a section
```

## Output
Findings, then:

```
VERDICT: PASS | FAIL
- reason
```

## Done when
- A verdict was given.
