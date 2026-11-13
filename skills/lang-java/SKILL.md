---
name: lang-java
description: Build tools, testing, idioms and common pitfalls for Java projects, framework-neutral. Use when working in a Java codebase, choosing how to build or test it, or reviewing Java code for typical mistakes.
tags: [java, language]
---

# Java projects

Check `.crew/context.md` and the build files for the real versions and commands before relying on anything below.

## Detect the setup
- Build tool: `pom.xml` (Maven), `build.gradle` or `build.gradle.kts` (Gradle). Prefer the wrapper in the repo (`./mvnw`, `./gradlew`) over a global install.
- Java version: look at the toolchain or `maven.compiler.release` / `java.toolchain` settings, `.java-version`, `.tool-versions` or CI config. Do not use language features newer than the project's release level.
- Multi-module layout: find the module that owns the code and build it with the module selector rather than the whole tree when possible.

## Common commands (adapt to the project)
| Task | Maven | Gradle |
|---|---|---|
| compile | `./mvnw -q compile` | `./gradlew compileJava` |
| all tests | `./mvnw test` | `./gradlew test` |
| one class | `./mvnw -Dtest=FooTest test` | `./gradlew test --tests FooTest` |
| one method | `./mvnw -Dtest=FooTest#bar test` | `./gradlew test --tests FooTest.bar` |
| full verify | `./mvnw verify` | `./gradlew build` |
| dependency tree | `./mvnw dependency:tree` | `./gradlew dependencies` |

Integration tests commonly run in a separate phase or source set (`verify`, `integrationTest`); find out how the project names them.

## Testing
- JUnit 5 is the mainstream default; match what the project uses (JUnit 4 and TestNG still exist).
- Assertion libraries (AssertJ, Hamcrest) and Mockito are common; use what is already declared.
- Name test classes `<Unit>Test`, methods by behaviour. Use parameterised tests for input tables.
- Keep unit tests free of containers, network and clocks; inject `java.time.Clock` for time.
- For integration tests needing real services, use the project's existing mechanism (for example disposable containers) and clean up.
- Test exceptions with `assertThrows` and assert the message or type that matters.

## Idioms
- Prefer immutability: `final` fields, records (Java 16+) for data carriers, `List.of`/`Map.of` for fixed collections, defensive copies at boundaries.
- Use `Optional` for return values that may be absent; do not use it for fields or parameters.
- Try-with-resources for anything `AutoCloseable`.
- Use `java.time` (never `Date`/`Calendar` in new code); store instants in UTC.
- Streams for transformations; plain loops when clearer. Avoid side effects in stream lambdas.
- Use `enum`, sealed types and `switch` expressions (where the release allows) over stringly-typed code.
- Constructor injection; keep classes small; program to interfaces at real seams only.
- Use `BigDecimal` (with explicit scale and rounding mode) or integer minor units for money.

## Pitfalls
- `equals` without `hashCode` (or vice versa); mutable keys in hash maps.
- Comparing strings or boxed numbers with `==`; `Integer` cache surprises.
- Catching `Exception` or `Throwable` broadly; swallowing `InterruptedException` (restore the interrupt flag).
- `NullPointerException` from unboxing or unchecked returns; validate with `Objects.requireNonNull` at boundaries.
- Non-thread-safe shared state (`SimpleDateFormat`, plain `HashMap`, lazy singletons). Prefer immutable data or concurrent collections.
- Resource leaks: unclosed streams, executors never shut down, `Files.list` / `Files.walk` streams not closed.
- Time zones and default charset: pass `StandardCharsets.UTF_8` and explicit zones.
- Logging: use parameterised messages (`log.info("id={}", id)`), never string concatenation, never secrets or personal data.
- N+1 queries and unbounded result sets when using persistence layers; set page limits.
- `Thread.sleep` in tests; use latches, awaiting utilities or injected schedulers.
- Reflection or serialisation of untrusted input into arbitrary classes.

## Style and quality tooling
- Follow the project's formatter and static-analysis configuration (for example Checkstyle, Spotless, SpotBugs, Error Prone) when present; run them as part of verification (skill:verification-loop).
- Keep public API surface small; document nullability and thread-safety expectations.
- Dependency hygiene: keep versions managed in one place (BOM or version catalog); run the dependency audit step the project provides.

## Reporting
State the JDK and tool versions used, the exact commands run and their results.
