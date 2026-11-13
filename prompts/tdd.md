---
name: tdd
description: Implement a small unit of behaviour test-first with strict red, green, refactor steps. Use for a well-defined function, class or endpoint where the behaviour can be described as examples.
agent: tdd-guide
argument_hint: <the behaviour to implement, with example inputs and outputs>
---

Implement the following behaviour test-first.

Behaviour:

$ARGUMENTS

Procedure (follow skill:tdd-workflow):
1. Read `.crew/context.md` when present to learn the test command and conventions, and look at neighbouring tests to match style. Search for existing code to reuse first (skill:search-first).
2. List the cases you will cover: simplest case, edge cases, error cases. Share the list briefly.
3. For each case in turn:
   - **Red:** write one test, run it, and show that it fails for the expected reason.
   - **Green:** write the least code that passes, run the tests and show they pass.
   - **Refactor:** tidy with all tests green, re-running after each step.
4. Run the whole relevant suite plus lint and type checks and quote the results (skill:verification-loop).
5. Report the tests written, the files changed, the red and green evidence, and any behaviour you were unsure about.

Constraints: touch only the files needed for this unit. Do not change existing tests to make them pass unless the requirement changed, and say so if it did. If the behaviour is ambiguous, ask instead of guessing.
