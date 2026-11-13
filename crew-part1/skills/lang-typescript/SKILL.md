---
name: lang-typescript
description: Strict typing, tooling, module and testing practices for TypeScript projects, framework-neutral. Use when working in a TypeScript or Node codebase, configuring tsconfig or linting, or reviewing TypeScript for typing and runtime pitfalls.
tags: [typescript, language]
---

# TypeScript projects

Confirm versions and scripts in `package.json`, `tsconfig*.json` and `.crew/context.md` before assuming anything.

## Detect the setup
- Package manager from the lock file: `package-lock.json` (npm), `yarn.lock`, `pnpm-lock.yaml`, `bun.lockb`. Use that one only; do not mix.
- Scripts: read the `scripts` section for build, test, lint, typecheck. Prefer these over invoking tools directly.
- Node version: `.nvmrc`, `.node-version`, `engines` field or CI config.
- Module system: `"type": "module"` and the `module` / `moduleResolution` settings decide import syntax and file extensions. Follow what exists.
- Monorepo: find the workspace root and the package that owns the code; run commands scoped to it.

## Commands (adapt to the project)
| Task | Typical command |
|---|---|
| install | `npm ci` (or the lock-file-matching equivalent) |
| type-check | `npx tsc --noEmit` |
| lint | `npx eslint .` |
| format check | `npx prettier --check .` |
| tests | `npm test` |
| one file | the runner's file filter, e.g. `npx vitest run path` or `npx jest path` |

## Strict typing
- Keep `"strict": true`. Valuable extras: `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noImplicitOverride`, `noFallthroughCasesInSwitch`. Do not loosen settings to make an error go away.
- No `any`. Use `unknown` for untrusted values and narrow with type guards or schema validation. Prefer precise types, generics and `satisfies` over assertions.
- Avoid non-null assertions (`!`) and `as` casts; if unavoidable, add a comment saying why it is safe.
- Model states with discriminated unions and exhaustive `switch` (use a `never` check) rather than optional flags.
- Use `readonly`, `as const` and `Readonly<T>` for data that should not change.
- Prefer `type` or `interface` consistently per project convention; use `interface` for extendable object shapes.
- Use `import type` for type-only imports where the config requires or encourages it.

## Runtime validation
Types vanish at runtime. Validate data at boundaries (HTTP bodies, environment, files, message queues, JSON parse) using the project's schema library or hand-written guards, and derive types from the schema where possible. `JSON.parse` returns `any`: assign to `unknown` first.

## Testing
- Use the runner already installed (Vitest, Jest, node:test, Mocha). Do not add a second one.
- Co-locate tests or follow the existing `__tests__` / `test` layout. Name by behaviour.
- Mock at the module or network boundary; prefer fakes over deep mocking. Use fake timers for time-dependent logic.
- Async tests must await or return the promise; assert rejections with the runner's matcher.
- Type-level tests (for example expecting compile errors) belong in the type-check step.

## Pitfalls
- Floating promises: always `await`, return, or explicitly handle; enable the lint rule for it.
- `==` vs `===`; truthiness checks on `0`, `""`, `NaN`; use `??` instead of `||` for defaults.
- Mutating arguments or shared objects; spread copies are shallow.
- `Object.keys` and `for...in` lose key types; sorting numbers without a comparator sorts as strings.
- Dates and time zones: use ISO strings or a vetted library; beware `new Date("YYYY-MM-DD")` parsing as UTC.
- Number precision for money or large ids: use integer minor units, `bigint` or strings.
- ESM/CJS interop: default-import mismatches, missing file extensions, `__dirname` unavailable in ESM.
- Enums: prefer string-literal unions or `as const` objects unless the project uses enums.
- Barrel files can create import cycles and slow builds.
- Catch clauses give `unknown`; narrow before reading `.message`.
- Type-only success: passing `tsc` does not prove runtime behaviour, so run the tests (skill:verification-loop).

## Dependencies and security
- Install exact lock-file versions in CI. Review new packages (skill:search-first), run `npm audit` or equivalent, and avoid install scripts you do not need.
- Never commit `.env` files; read configuration from the environment and validate it at startup.

## Reporting
State the Node and TypeScript versions, the scripts run and their outcomes.
