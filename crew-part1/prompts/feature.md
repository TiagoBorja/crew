---
name: feature
description: Run the full delivery pipeline for a new feature from a description, from intake to report. Use for new user-visible functionality that needs analysis, a plan, tests, review gates and docs.
agent: orchestrator
argument_hint: <feature description and acceptance criteria>
---

Deliver the following feature through the full crew pipeline.

Feature request:

$ARGUMENTS

Work through these stages in order and state which stage you are in:
1. **Intake.** Restate the objective, scope, out-of-scope items and acceptance criteria. If anything is unclear or untestable, stop with STATUS: BLOCKED and ask specific questions.
2. **Analyse.** Read `.crew/context.md` and `.crew/learnings.md` when present. Identify affected modules, dependencies, risks and existing code to reuse (skill:search-first).
3. **Plan.** Produce an ordered task list with owners, file scopes and acceptance checks (skill:planning-blueprint). Record design decisions that are hard to reverse (skill:adr). Show the plan and wait for my confirmation before implementing unless the change is trivial.
4. **Implement.** Test first (skill:tdd-workflow): failing test, then code, then green. Delegate with the HANDOFF format; keep file scopes disjoint when work runs in parallel.
5. **Review gates.** Run the code-quality, security and any relevant QA, database or contract gates on the diff. Every gate must return VERDICT: PASS. On FAIL, fix and re-run the gate (at most three loops, then report BLOCKED).
6. **Docs.** Update documentation and the changelog for user-visible changes.
7. **Report.** Summarise stages, agents used, evidence (commands and outcomes), verdicts and open items.

Rules: follow the crew guardrails. Do not push, deploy, delete outside the change, or write to external systems without my explicit approval. Verify with real command output before claiming PASS (skill:verification-loop).
