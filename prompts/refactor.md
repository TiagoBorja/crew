---
name: refactor
description: Behaviour-preserving cleanup of a given area, removing dead code and duplication in small verified steps. Use when code needs tidying without changing what it does.
agent: refactor-cleaner
argument_hint: <files, module or area to clean up, and the goal>
---

Clean up the following area without changing its behaviour.

Area and goal:

$ARGUMENTS

Procedure:
1. **Baseline.** Read `.crew/context.md` when present. Run the relevant tests, lint and type checks first and record the results. If coverage of the area is weak, add characterisation tests that pin current behaviour before touching code. Stop and report if the baseline is already failing.
2. **Find candidates.** Locate unused code (confirm with searches for references, including dynamic and reflective use, tests and configuration), duplication, overly long or deeply nested functions, and misleading names. List what you intend to change and what you will leave alone.
3. **Change in small steps.** One kind of change per step, running the tests after each. Do not mix refactoring with behaviour changes, dependency upgrades or reformatting of untouched code. Keep public interfaces stable unless I agree otherwise.
4. **Verify.** Run the full relevant suite, lint and type checks and quote the results (skill:verification-loop). Compare with the baseline: nothing that passed before may fail now.
5. **Report.** List each change and why it is safe, files touched, evidence, anything suspicious you found but did not change, and a suggested reviewer gate.

Rules: stay inside the stated area. Deleting files, branches or data beyond the dead code in scope needs my approval. Do not push or commit unless I ask.
