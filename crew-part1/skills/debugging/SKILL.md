---
name: debugging
description: Systematic path from a failure to a confirmed root cause: reproduce, isolate, hypothesise, bisect, confirm. Use when something fails, behaves unexpectedly, a test is red for unknown reasons, or before proposing a fix.
tags: [debugging, process]
---

# Debugging

Goal: a confirmed root cause with evidence, then the smallest fix. Do not fix by guessing.

## 1. Define the failure
- Write the expected behaviour and the actual behaviour in one sentence each.
- Capture the exact error text, stack trace, inputs, environment, version or commit, and when it started.
- Ask what changed recently: code, dependencies, configuration, data, infrastructure.

## 2. Reproduce
- Find the shortest reliable reproduction: a command, a request, or a failing test. Record it.
- If it is intermittent, run it in a loop and under varying conditions (parallelism, order, timing, load) to learn what raises the failure rate.
- If it cannot be reproduced, gather more evidence (logs, state dumps) instead of theorising. Say so in the report.
- Turn the reproduction into an automated failing test as early as possible (skill:tdd-workflow).

## 3. Isolate
- Shrink the input and the code path until removing anything makes the failure disappear.
- Determine which side of each boundary is wrong: client or server, caller or callee, code or data, app or environment. Check values at the boundary.
- Read the actual error before anything else; read the first error in a cascade, not the last.
- Read the real source and docs of the library involved instead of recalling from memory.

## 4. Hypothesise
- List two or three candidate causes, ranked by likelihood and by cost to test.
- For each, state a prediction: "if this is the cause, then X will be observed". Design the cheapest check that could disprove it.
- Change one thing at a time. Record each experiment and result.

## 5. Bisect
- **History:** use `git bisect` (with a scripted test) to find the first bad commit when it used to work.
- **Input:** halve the input or configuration set repeatedly.
- **Code:** disable or stub half of a pipeline to see which half carries the failure.
- **Environment:** compare a working and a failing environment, option by option, version by version.

## 6. Observe, do not assume
- Add temporary, targeted logging or use a debugger or tracer; print the values you are assuming. Remove temporary instrumentation afterwards.
- Check the assumptions that "cannot be wrong": the file actually loaded, the configuration actually in effect, the branch actually deployed, the cache actually cleared.
- Never log secrets or personal data while debugging.

## 7. Confirm root cause
A root cause is confirmed when you can explain the full chain from cause to symptom and a targeted change makes the symptom disappear and reverting it brings the symptom back. A fix that works for unknown reasons is not a confirmed cause.

## 8. Fix and prevent
- Make the smallest change addressing the cause, not the symptom. Keep the regression test.
- Look for the same defect pattern elsewhere and note it (do not widen scope without asking).
- Run the full verification sequence (skill:verification-loop).

## Stop rules
- After three failed hypotheses on the same failure, stop, summarise what was ruled out, and ask for input or escalate.
- If diagnosis needs access you lack (production, credentials, other systems), report BLOCKED and list exactly what is needed.

## Report template
```
Symptom: <expected vs actual>
Reproduction: <command or test>
Root cause: <explanation> (confirmed | probable | unknown)
Evidence: <observations, experiments>
Ruled out: <hypotheses and how>
Suggested fix: <smallest change> ; risk: <what could break>
```
