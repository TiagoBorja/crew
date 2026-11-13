---
name: adr
description: Architecture decision record template and criteria for when to write one. Use when a design choice is hard to reverse, affects several teams or components, or when someone will later ask why it was done this way.
tags: [architecture, documentation]
---

# Architecture decision records

An ADR captures one decision, its context and its consequences, so future readers can understand and revisit it.

## When to write one
Write an ADR when the decision:
- is costly or slow to reverse (data model, public contract, storage engine, framework or language choice, authentication scheme);
- crosses component or team boundaries, or sets a convention others must follow;
- has real alternatives that were considered and rejected;
- trades one quality against another (consistency vs availability, speed vs simplicity, build vs buy).

Do not write one for routine, easily reversible choices, naming, or anything the code and its comments already explain.

## Where and how
- Store in the repo, by convention `docs/adr/NNNN-short-title.md` (follow an existing location if the project has one). Numbers increase monotonically and are never reused.
- One decision per file. Keep it to one or two pages.
- Never delete an ADR. When a decision changes, write a new ADR that supersedes the old one and update the old status to `Superseded by NNNN`.
- Changes are reviewed like code.

## Template
```
# NNNN. <Decision title, as a short noun phrase>

- Status: Proposed | Accepted | Deprecated | Superseded by NNNN
- Date: YYYY-MM-DD
- Deciders: <roles or names>

## Context
<The problem, forces and constraints: requirements, scale, deadlines, existing system, team skills. Facts, not advocacy.>

## Options considered
1. <Option A> - pros, cons, cost
2. <Option B> - pros, cons, cost
3. Do nothing - consequences

## Decision
<What we will do, in one or two active sentences: "We will use ...".>

## Consequences
- Positive: <benefits>
- Negative: <costs, new risks, debt accepted>
- Follow-ups: <migration steps, monitoring, review date, how we will know it was wrong>
```

## Writing tips
- Lead with the context so that the decision reads as a conclusion.
- Include at least two real alternatives and why they lost; "do nothing" counts.
- State evidence: benchmarks, prototypes, links to issues. Mark claims you did not verify.
- Be honest about downsides. An ADR without negative consequences is suspect.
- Define the trigger for revisiting (for example: traffic above a level, a vendor change).

## Agent behaviour
- Propose an ADR draft and ask the user to confirm the decision; do not mark Status as Accepted on your own.
- Link the ADR from the plan (skill:planning-blueprint) and from docs that depend on it.
