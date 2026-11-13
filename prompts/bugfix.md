---
name: bugfix
description: Fix a defect by reproducing it with a failing test, finding the root cause, fixing minimally, verifying and reviewing. Use for bug reports, regressions and unexpected behaviour with a known symptom.
agent: orchestrator
argument_hint: <bug description, steps to reproduce, expected vs actual>
---

Fix the following defect.

Bug report:

$ARGUMENTS

Procedure:
1. **Intake.** State the expected and the actual behaviour, and what is known about environment and version. If the report cannot be acted on, stop with STATUS: BLOCKED and list what is needed.
2. **Reproduce.** Find the shortest reliable reproduction and turn it into a failing automated test. Show the test failing for the right reason. If it cannot be reproduced, say so and report the evidence gathered instead of guessing.
3. **Diagnose.** Find the confirmed root cause, not just the symptom (skill:debugging). Hand this to the debugger when the cause is not obvious. Look for the same pattern elsewhere and note it without widening scope.
4. **Fix.** Make the smallest change that fixes the cause. Keep the regression test. No drive-by refactors.
5. **Verify.** Run the new test, the surrounding suite, lint and type checks, and run the real scenario where possible (skill:verification-loop). Quote the outcomes.
6. **Review.** Run the code-quality gate, plus the security gate if input handling, authentication or data access was touched. Fix findings and re-run gates until VERDICT: PASS (max three loops).
7. **Report.** Give root cause, fix, tests added, evidence, risks and any related issues found.

Rules: follow the crew guardrails. No pushes, deploys or external writes without my explicit approval. Report BLOCKED rather than weakening or skipping tests.
