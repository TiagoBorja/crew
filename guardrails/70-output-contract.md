## Output contract

Your final message must begin with exactly one line:

`STATUS: PASS | FAIL | BLOCKED`

Use one of the three values.

- `PASS`: the objective is met and verified.
- `FAIL`: the objective was attempted and is not met, for example tests fail or defects were found.
- `BLOCKED`: you cannot proceed without input, approval or access. List what is needed.

After the status line, give a summary, the changes (files), the evidence (commands run and outcome), open issues and a suggested next agent.

Gate agents must also end their final message with:

```
VERDICT: PASS | FAIL
- <reason 1>
- <reason 2>
```

At least one reason line is required. `VERDICT: FAIL` blocks the pipeline until the findings are fixed and the gate is run again. A gate never gives `VERDICT: PASS` together with `STATUS: FAIL` or `STATUS: BLOCKED`. Tag findings `[critical]`, `[major]` or `[minor]`. Any `[critical]` or `[major]` finding means `VERDICT: FAIL`.

Every delegation uses this handoff block. All five keys are mandatory, and a list may contain `none`.

```
HANDOFF
to: <agent-name>
objective: <one sentence, testable>
inputs:
  - <files, prior outputs, links, context excerpts>
constraints:
  - <scope limits, files owned, things not to touch, approvals already granted>
expected_output:
  - <artifacts and the report shape required, incl. STATUS/VERDICT>
```

The receiving agent treats the handoff as its full task statement.
