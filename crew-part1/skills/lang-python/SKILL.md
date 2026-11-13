---
name: lang-python
description: Packaging, virtual environments, typing, testing and tooling for Python projects, framework-neutral. Use when working in a Python codebase, setting up or running its tests and linters, or reviewing Python for common pitfalls.
tags: [python, language]
---

# Python projects

Check `.crew/context.md`, `pyproject.toml`, CI config and the README for the real setup before running anything.

## Detect the setup
- Packaging and environment manager: `pyproject.toml` (with `[tool.poetry]`, `[tool.uv]`, `[tool.hatch]`, setuptools, etc.), `requirements*.txt`, `Pipfile`, `setup.cfg`, `tox.ini`, `noxfile.py`. Use the tool the project already uses; do not introduce another.
- Python version: `requires-python`, `.python-version`, CI matrix. Avoid syntax or stdlib features newer than the minimum supported version.
- Always work inside a virtual environment (`python -m venv .venv`, or the manager's own). Never install into the system interpreter. Keep `.venv` out of version control.
- Layout: `src/<package>/` vs flat; make sure tests import the installed or editable package the way users will.

## Commands (adapt to the project)
| Task | Typical command |
|---|---|
| create env | `python -m venv .venv` then activate it |
| install (editable + dev) | `pip install -e ".[dev]"` or the manager's sync command |
| tests | `python -m pytest` |
| one test | `python -m pytest path/test_x.py::test_name -x` |
| lint | `ruff check .` (or flake8 / pylint as configured) |
| format check | `ruff format --check .` or `black --check .` |
| type-check | `mypy .` or `pyright` as configured |

Prefer `python -m <tool>` so the tool matches the active interpreter.

## Typing
- Add type hints to public functions and data structures; follow the project's strictness level and do not weaken it to silence errors.
- Use modern forms available at the minimum version (`list[str]`, `X | None`); otherwise `typing` equivalents.
- Prefer `dataclasses`, `TypedDict`, `Protocol` and `enum` over untyped dicts and magic strings. Use `Literal` for small closed sets.
- `Any` is a last resort; narrow with `isinstance` or validate at boundaries.
- Do not use `# type: ignore` without a specific error code and a reason.

## Testing
- pytest is the mainstream default; match what the project uses (`unittest` also works with pytest).
- Test files `test_*.py`; functions named by behaviour. Use fixtures for setup, `parametrize` for input tables, `tmp_path` for files, `monkeypatch` for environment and attributes.
- Assert exceptions with `pytest.raises(..., match=...)`; floats with `pytest.approx`.
- Keep unit tests free of network, real clocks and shared state; inject time and randomness or freeze them.
- Mark slow or integration tests with markers and run them separately if the project does so.
- Coverage is a signal, not proof (skill:tdd-workflow).

## Idioms
- Context managers (`with`) for files, locks, connections. `pathlib.Path` instead of string paths.
- Comprehensions and generators for transformations; avoid building big lists needlessly.
- f-strings for formatting; lazy `%`-style arguments for logging calls (`logger.info("id=%s", id)`).
- Raise specific exceptions; chain with `raise ... from err`. Never use bare `except:`.
- Small functions, explicit returns, no global mutable state.
- Use `if __name__ == "__main__":` guards or console-script entry points for executables.

## Pitfalls
- Mutable default arguments (`def f(x=[])`); use `None` and create inside.
- Late-binding closures in loops; shadowing built-ins (`id`, `list`, `type`).
- Naive `datetime` objects; use timezone-aware values and store UTC.
- Comparing with `is` for values (only for `None`/singletons); float equality.
- Catching exceptions too broadly and hiding failures.
- `subprocess` with `shell=True` and untrusted input; unsafe `pickle`, `yaml.load` without a safe loader, `eval`.
- Import cycles and side effects at import time.
- Text encoding: open files with an explicit `encoding="utf-8"`.
- Blocking calls inside async code; forgetting to `await` coroutines.
- Unpinned or unreviewed dependencies; mismatch between declared and installed versions. Use a lock file or constraints when the project has one.

## Reporting
State the Python version, environment used, and the commands run with outcomes (skill:verification-loop).
