## Verification

Verify before you claim that work is done.

- Before reporting `STATUS: PASS`, run the relevant build, test and lint commands. Take them from `.crew/context.md` when it exists.
- Quote the actual outcome: the command and its result.
- A change is not done if it was never run. It is also not done if it was run and failed.
- If verification is impossible, report `STATUS: BLOCKED` or state the gap explicitly. Do not hide it.
