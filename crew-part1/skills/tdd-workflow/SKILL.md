---
name: tdd-workflow
description: Red-green-refactor loop with test naming rules and a definition of what counts as proof. Use when implementing or changing behaviour test-first, or when deciding whether a test really proves something.
tags: [testing, process]
---

# TDD workflow

## The loop
1. **Red.** Write one test that describes the next small behaviour. Run it. It must fail, and it must fail for the expected reason (assertion on missing behaviour, not a typo or import error).
2. **Green.** Write the least code that makes that test pass. Hard-coding is allowed if a second test will force generalisation.
3. **Refactor.** With all tests green, clean up names, duplication and structure. Run the tests again after every refactor step. Never change behaviour and structure in the same step.
4. Repeat with the next behaviour. Commit at green points.

## Choosing the next test
- Start with the simplest case (empty input, single item, happy path), then edge cases, then error paths.
- One behaviour per test. If the test name needs "and", split it.
- Prefer testing through the public interface. Test internals only when they carry real logic that is hard to reach otherwise.
- For a defect: first write a test that reproduces it and fails. Only then fix.

## Naming
Name tests after behaviour, not methods. A reader should learn the rule from the name alone.
- Pattern: `<unit> <does something> when <condition>`, adapted to the language's convention.
- Good: `rejects_order_when_quantity_is_zero`, `returns_empty_list_for_unknown_user`.
- Bad: `test1`, `testProcess`, `works`.

## Structure of a test
- Arrange, act, assert, in that order, visibly separated.
- One logical assertion focus. Several asserts on one result are fine; several unrelated actions are not.
- No logic (loops, conditionals) in tests. No dependence on test order, wall-clock time, random values or network unless injected and controlled.
- Use fixtures and builders for setup; keep the data that matters to the assertion visible in the test itself.

## What counts as proof
A change is proven only when all of these hold:
- A test failed before the change and passes after it (you saw both outcomes).
- The test would fail if the behaviour were removed or broken (check by briefly reverting or mutating the code when in doubt).
- The full relevant suite passes, not just the new test.
- The test asserts an observable result, not merely that code ran without throwing.

Not proof: a test that was never seen failing, a test with no assertions, a test that mocks the very thing under test, coverage numbers alone, "it works on my run" without recorded output.

## Test doubles
- Prefer real objects and in-memory fakes. Use mocks at true boundaries (network, clock, filesystem, third-party services).
- Do not assert on call counts or order unless that interaction is the behaviour.
- A test that needs many mocks signals a design problem; consider simplifying the unit.

## Common pitfalls
- Writing several tests before any code, then getting lost. Keep the loop short.
- Making a test pass by editing the test. Only change a test when the requirement changed, and say so.
- Skipping the refactor step, which lets duplication accumulate.
- Flaky tests: fix or quarantine with a note immediately; never ignore.

## Report
When done, quote: the failing run (test name and failure message), the passing run, and the command used. See skill:verification-loop for the full sequence.
