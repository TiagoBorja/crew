#!/bin/sh
# Optional smoke test: one real "crew run session-reporter" per available engine.
# Runs only with CREW_SMOKE=1 and claude and/or codex on PATH. It renders the
# real source into a temp HOME (your real home is only read, never written) and
# points bin/crew at it through CREW_HOME. It uses your normal engine login.
# Codex needs the crew-* profiles in your own ~/.codex/config.toml
# (install.sh --global --target codex); without them that engine is skipped.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)

if [ "${CREW_SMOKE:-0}" != 1 ]; then
    echo "ok 1 - smoke # SKIP set CREW_SMOKE=1 to run"
    echo "1..1"
    exit 0
fi
if ! command -v claude >/dev/null 2>&1 && ! command -v codex >/dev/null 2>&1; then
    echo "ok 1 - smoke # SKIP neither claude nor codex on PATH"
    echo "1..1"
    exit 0
fi

REAL_HOME=$HOME
W=$(mktemp -d "${TMPDIR:-/tmp}/crew-t-smoke.XXXXXX")
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/home" "$W/proj"
HOME=$W/home sh "$repo/install.sh" --global > "$W/install.out" 2>&1 || { cat "$W/install.out"; echo "Bail out! install failed"; exit 1; }

n=0
failed=0
for engine in claude codex; do
    n=$((n + 1))
    if ! command -v "$engine" >/dev/null 2>&1; then
        echo "ok $n - $engine # SKIP not on PATH"
        continue
    fi
    if [ "$engine" = codex ] && ! grep -q 'profiles.crew-fast' "$REAL_HOME/.codex/config.toml" 2>/dev/null; then
        echo "ok $n - codex # SKIP no crew profiles in your ~/.codex/config.toml"
        continue
    fi
    set +e
    HOME=$REAL_HOME CREW_HOME=$W/home/.crew sh "$repo/bin/crew" run session-reporter "say hello" \
        --engine "$engine" --cwd "$W/proj" > "$W/$engine.out" 2> "$W/$engine.err" < /dev/null
    rc=$?
    set -e
    if grep -Eq '^STATUS: (PASS|FAIL|BLOCKED)[[:space:]]*$' "$W/$engine.out"; then
        echo "ok $n - $engine returned a STATUS line (exit $rc)"
    else
        echo "not ok $n - $engine returned no STATUS line (exit $rc)"
        failed=1
    fi
done
echo "1..$n"
exit "$failed"
