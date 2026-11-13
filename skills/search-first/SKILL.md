---
name: search-first
description: Look for existing code, libraries and patterns in the repo and ecosystem before writing anything new. Use when about to add a function, utility, dependency or abstraction, or when unsure how the codebase already solves something.
tags: [process, reuse]
---

# Search first

Writing new code is the most expensive way to solve a problem. Spend a few minutes looking before adding anything.

## Order of search
1. **This change's neighbourhood.** Read the files you are about to edit and their siblings. The pattern is often one directory away.
2. **The repository.** Search for names, synonyms and behaviours, not just exact identifiers:
   - the noun and the verb (`parse`, `format`, `validate`, `retry`, `paginate`);
   - similar error messages, config keys, routes or event names;
   - tests that exercise similar behaviour (they show intended usage);
   - shared directories: `utils`, `common`, `lib`, `shared`, `helpers`, `core`.
3. **History and docs.** Check README, docs, ADRs, `.crew/context.md`, `.crew/learnings.md` and recent commits touching the area (`git log -S<term>` and `git log --grep`).
4. **Already-declared dependencies.** Inspect the dependency manifest and lock file. The standard library or an existing dependency may already provide it.
5. **The ecosystem.** Only then consider a new library (see below).

## Search techniques
- Try several spellings and plurals; search case-insensitively.
- Search for callers of a similar function to see conventions.
- Search for the type or interface you would need to implement.
- Look at how the same problem is solved in another module and whether it can be generalised cheaply.

## Decision table
| Finding | Action |
|---|---|
| Exact match exists | Use it. Do not copy it. |
| Close match exists | Extend it minimally, with tests; or compose it. |
| Pattern exists, no helper | Follow the pattern in the same style. |
| Nothing in repo, stdlib covers it | Use the standard library. |
| Nothing, a library is needed | Evaluate it (below), then ask if adding a dependency is not already the project's norm. |
| Truly nothing | Write the smallest thing that works, in the right module, with tests. |

## Evaluating a new dependency
- Is it needed, or is the code about 20 lines? Prefer a few lines over a dependency.
- Maintenance: recent releases, open issues, bus factor. Licence compatible with the project. Size and transitive dependencies.
- Security: known advisories, install scripts. Fit with the project's language version and build tooling.
- Record the choice and the alternatives briefly in the plan or the change description. Verify package names from the registry or documentation; never invent them.

## Anti-patterns
- Reimplementing an existing helper because it was hard to find.
- Copy-pasting a block and tweaking it instead of reusing.
- Adding a second library for something the project already uses one for.
- Creating a new abstraction layer for a single use.

## Report
Say what was searched (terms, paths), what was found, and why the chosen action was taken. If you did not find something, say it is not found after those searches, not that it does not exist.
