---
name: e2e-testing
description: Stable selectors, test data, waiting strategy and flake control for end-to-end and browser tests. Use when writing, reviewing or debugging end-to-end tests, or when e2e tests are slow or flaky.
tags: [testing, e2e]
---

# End-to-end testing

## Scope
- E2E tests cover a few critical user journeys end to end (sign in, core purchase or creation flow, key integrations). Everything else belongs in faster unit and integration tests.
- Each test is one journey with one clear outcome. Keep them short and independent.

## Selectors
- Prefer, in order: accessible role and name, label text, dedicated test attributes (for example `data-testid`), then stable semantic attributes.
- Avoid selectors tied to layout or styling: deep CSS paths, nth-child indexes, auto-generated class names, visible copy that marketing will change.
- Agree on test-id naming with the frontend and keep it stable; treat it as a contract.
- Scope queries within a container instead of scanning the whole page.

## Waiting strategy
- Never use fixed sleeps. Wait for a condition: element visible or enabled, network request finished, route changed, text present.
- Use the framework's auto-waiting assertions and set explicit timeouts for slow steps instead of a global large timeout.
- Wait for the specific signal that the app is ready (response to a known request, a loaded indicator disappearing), not for "network idle" in general.
- Retries belong on assertions that poll, not on whole tests, except as a documented temporary measure.

## Test data
- Each test creates the data it needs (through an API or seed helper) and does not depend on data left by other tests or on a shared mutable account.
- Use unique identifiers per run (timestamp or random suffix) to avoid collisions in parallel runs.
- Clean up after, or run against disposable environments reset between runs.
- Use dedicated test accounts and fake data. Never use real personal data or production credentials; load credentials from the environment.
- Log in through a programmatic path or reuse saved authentication state, except in the one test that covers login itself.

## Isolation and environment
- Tests must run in any order and in parallel. No shared state between tests.
- Control nondeterminism: freeze or inject time, stub third-party services (payments, email, maps) at the network boundary, seed random values.
- Run against a clean, known build. Pin browser versions in CI.
- Never run destructive or mutating e2e tests against production.

## Flake control
1. When a test fails intermittently, record the failure and fix it the same day; flakes erode trust.
2. Capture evidence on failure: screenshot, trace or video, console and network logs.
3. Common causes: race between action and render, shared data, time dependence, animations, order dependence, resource limits in CI, unmocked external service.
4. Reproduce by running the test repeatedly (a loop of 20 to 50 runs) and in parallel.
5. Fix the cause. Quarantining is allowed only with a ticket, an owner and a deadline, and the test must be tracked as skipped, not silently removed.

## Design for maintainability
- Page or component helper objects for repeated flows; keep assertions in the test, not hidden in helpers.
- Name tests by user outcome: `user can reset password with a valid email`.
- Keep the suite fast: parallelise, share setup via API, avoid UI steps that are not the point of the test.
- Include accessibility checks on key pages where tooling supports it.

## Reporting
State which journeys were covered, the command and environment, pass/fail counts, flaky tests observed, and artifacts (trace, screenshots) for failures.
