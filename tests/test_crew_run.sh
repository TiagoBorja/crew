#!/bin/sh
# Tests for bin/crew: --dry-run output per agent kind, exit-code mapping through
# stub engines on PATH, agent lookup, list, doctor, version, usage errors.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
crew=$repo/bin/crew

W=$(mktemp -d "${TMPDIR:-/tmp}/crew-t-run.XXXXXX")
trap 'rm -rf "$W"' EXIT
export HOME="$W/home"
mkdir -p "$HOME" "$W/proj" "$W/stubs"
unset CREW_HOME
S=$W/src
cp -R "$here/fixtures/good" "$S"
echo 0.0.0-test > "$S/VERSION"

n=0
failed=0
ok() { n=$((n + 1)); echo "ok $n - $1"; }
nok() { n=$((n + 1)); failed=1; echo "not ok $n - $1"; }
check() { d=$1; shift; if "$@"; then ok "$d"; else nok "$d"; fi; }
# shellcheck disable=SC2329 # called indirectly through check
has() { grep -q -- "$2" "$1"; }
# shellcheck disable=SC2329 # called indirectly through check
hasnt() { ! grep -q -- "$2" "$1"; }

CREW_SRC=$S sh "$repo/install.sh" --global > "$W/inst.out" 2>&1 || { cat "$W/inst.out"; echo "Bail out! install failed"; exit 1; }

# stub engines: record arguments and stdin, print $STUB_OUT
for e in codex claude; do
    cat > "$W/stubs/$e" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$STUB_LOG.args"
cat > "$STUB_LOG.stdin"
cat "$STUB_OUT"
exit "${STUB_RC:-0}"
EOF
    chmod +x "$W/stubs/$e"
done
export STUB_LOG="$W/stub" STUB_OUT="$W/stub.out"
PATH=$W/stubs:$PATH

run() { # args... : runs crew, sets rc, output in $W/out and $W/err
    set +e
    sh "$crew" "$@" > "$W/out" 2> "$W/err" < /dev/null
    rc=$?
    set -e
}
say() { printf '%s\n' "$@" > "$STUB_OUT"; }

# ---- dry-run ----------------------------------------------------------------

run run beta-gate "review the change" --dry-run
check "dry-run gate (codex): exit 0" test "$rc" = 0
check "dry-run gate: tier profile and read-only sandbox" has "$W/out" '^command: codex exec --profile crew-standard --sandbox read-only -$'
check "dry-run gate: prompt has guardrails, agent file and handoff" sh -c "grep -q 'Never print secrets' '$W/out' && grep -q '^# beta-gate' '$W/out' && grep -q '^HANDOFF\$' '$W/out' && grep -q '^to: beta-gate\$' '$W/out' && grep -q '^objective: review the change\$' '$W/out'"
check "dry-run did not start the engine" test ! -e "$STUB_LOG.args"

run run alpha-worker "add a thing" --dry-run
check "dry-run worker (codex): fast profile, no sandbox flag" has "$W/out" '^command: codex exec --profile crew-fast -$'
check "dry-run worker: no read-only sandbox" hasnt "$W/out" 'sandbox'

run run beta-gate "review" --engine claude --dry-run
check "dry-run gate (claude): model and read-only tools" sh -c "grep -q '^model: sonnet\$' '$W/out' && grep -q -- '--allowedTools \"Read,Grep,Glob\"' '$W/out'"
check "dry-run gate (claude): no edit tools" hasnt "$W/out" 'Edit'
run run alpha-worker "work" --engine claude --dry-run
check "dry-run worker (claude): haiku and edit tools" sh -c "grep -q '^model: haiku\$' '$W/out' && grep -q -- '--allowedTools \"Read,Grep,Glob,Edit,Write,Bash\"' '$W/out'"

printf 'CLAUDE_MODEL_FAST=my-small-model\nRUN_ENGINE=claude\n' > "$HOME/.crew/config"
run run alpha-worker "work" --dry-run
check "config: RUN_ENGINE and model are honoured" sh -c "grep -q '^engine: claude\$' '$W/out' && grep -q '^model: my-small-model\$' '$W/out'"
run run alpha-worker "work" --engine codex --dry-run
check "--engine overrides config" has "$W/out" '^engine: codex$'
rm "$HOME/.crew/config"

printf 'objective from stdin\n' > "$W/handoff.txt"
set +e
sh "$crew" run alpha-worker - --dry-run < "$W/handoff.txt" > "$W/out" 2> "$W/err"
rc=$?
set -e
check "task '-' takes the handoff from stdin" sh -c "test $rc = 0 && grep -q '^objective from stdin\$' '$W/out' && ! grep -q '^to: alpha-worker\$' '$W/out'"

# ---- tier override ----------------------------------------------------------

run run alpha-worker "work" --tier deep --dry-run
check "--tier raises a worker" sh -c "grep -q '^command: codex exec --profile crew-deep -\$' '$W/out' && grep -q '^default_tier: fast\$' '$W/out'"
run run alpha-worker "work" --tier standard --engine claude --dry-run
check "--tier picks the claude model" has "$W/out" '^model: sonnet$'
run run beta-gate "review" --tier deep --dry-run
check "--tier raises a gate" has "$W/out" 'crew-deep --sandbox read-only'
run run beta-gate "review" --tier fast --dry-run
check "--tier never lowers a gate: exit 2" test "$rc" = 2
run run alpha-worker "work" --tier huge --dry-run
check "invalid --tier: exit 2" test "$rc" = 2
printf 'HANDOFF\nto: alpha-worker\ntier: standard\nobjective: x\n' > "$W/handoff.txt"
set +e
sh "$crew" run alpha-worker - --dry-run < "$W/handoff.txt" > "$W/out" 2> "$W/err"
rc=$?
set -e
check "tier: line in the handoff is used" sh -c "test $rc = 0 && grep -q 'crew-standard' '$W/out' && grep -q '^tier: standard\$' '$W/out'"
set +e
sh "$crew" run alpha-worker - --tier deep --dry-run < "$W/handoff.txt" > "$W/out" 2> "$W/err"
set -e
check "--tier wins over the handoff tier" has "$W/out" 'crew-deep'

# ---- agent lookup -----------------------------------------------------------

mkdir -p "$W/proj/.crew/agents"
sed 's/^tier: fast$/tier: deep/' "$HOME/.crew/agents/alpha-worker.md" > "$W/proj/.crew/agents/alpha-worker.md"
run run alpha-worker "x" --cwd "$W/proj" --dry-run
check "project agent overrides the user-level one" has "$W/out" 'crew-deep'
run run alpha-worker "x" --dry-run
check "without --cwd the user-level agent is used" has "$W/out" 'crew-fast'
run run no-such-agent "x" --dry-run
check "unknown agent: exit 2" test "$rc" = 2
run run ../etc/passwd "x" --dry-run
check "path-like agent name: exit 2" test "$rc" = 2

# ---- exit-code mapping through stub engines ---------------------------------

say 'noise' 'STATUS: PASS' 'done'
run run alpha-worker "do it"
check "STATUS: PASS -> 0" test "$rc" = 0
check "engine output is streamed to stdout" has "$W/out" '^done$'
check "codex receives the prompt on stdin and the profile in args" sh -c "grep -q '^HANDOFF\$' '$STUB_LOG.stdin' && grep -qx 'crew-fast' '$STUB_LOG.args' && grep -qx -- '-' '$STUB_LOG.args'"
say 'STATUS: FAIL'
run run alpha-worker "do it"
check "STATUS: FAIL -> 1" test "$rc" = 1
say 'STATUS: BLOCKED' '- need approval'
run run alpha-worker "do it"
check "STATUS: BLOCKED -> 3" test "$rc" = 3
say 'no status here'
run run alpha-worker "do it"
check "no STATUS line -> 4" test "$rc" = 4
# shellcheck disable=SC2016 # backticks are literal text in the stub output
say 'Start your final message with `STATUS: PASS|FAIL|BLOCKED`.'
run run alpha-worker "do it"
check "the contract text itself is not a STATUS line -> 4" test "$rc" = 4
say 'STATUS: PASS' 'VERDICT: PASS' '- ok'
run run beta-gate "review"
check "gate: STATUS PASS + VERDICT PASS -> 0" test "$rc" = 0
say 'STATUS: PASS' 'VERDICT: FAIL' '- [major] bug'
run run beta-gate "review"
check "gate: VERDICT: FAIL -> 1" test "$rc" = 1
say 'STATUS: PASS'
run run beta-gate "review"
check "gate: STATUS PASS without VERDICT -> 4" test "$rc" = 4
check "read-only agent: sandbox flag reaches codex" grep -qx 'read-only' "$STUB_LOG.args"
say 'STATUS: PASS'
STUB_RC=7
export STUB_RC
run run alpha-worker "do it"
unset STUB_RC
check "engine failure status does not override a valid STATUS" test "$rc" = 0
check "engine failure status is reported" has "$W/err" 'exited with status 7'

say 'STATUS: PASS'
run run alpha-worker "do it" --engine claude
check "claude engine: STATUS PASS -> 0" test "$rc" = 0
check "claude receives model, tools, system prompt and handoff" sh -c "grep -qx -- '-p' '$STUB_LOG.args' && grep -qx 'haiku' '$STUB_LOG.args' && grep -qx 'Read,Grep,Glob,Edit,Write,Bash' '$STUB_LOG.args' && grep -q 'Never print secrets' '$STUB_LOG.args' && grep -q 'objective: do it' '$STUB_LOG.args'"

# engine missing: only meaningful when the real CLI is not on the fallback PATH
rm "$W/stubs/codex"
if (PATH=/usr/bin:/bin; command -v codex > /dev/null 2>&1); then
    echo "ok $((n + 1)) - engine missing -> 127 # SKIP a real codex is installed"
    n=$((n + 1))
else
    set +e
    PATH=$W/stubs:/usr/bin:/bin sh "$crew" run alpha-worker "x" --engine codex > "$W/out" 2> "$W/err" < /dev/null
    rc=$?
    set -e
    check "engine missing -> 127" test "$rc" = 127
fi

# ---- usage ------------------------------------------------------------------

run
check "no arguments: exit 2" test "$rc" = 2
run frobnicate
check "unknown command: exit 2" test "$rc" = 2
run run
check "run without agent: exit 2" test "$rc" = 2
run run alpha-worker
check "run without task: exit 2" test "$rc" = 2
run run alpha-worker "x" --engine nope --dry-run
check "bad engine: exit 2" test "$rc" = 2
run run alpha-worker "x" --cwd "$W/nowhere" --dry-run
check "bad --cwd: exit 2" test "$rc" = 2
run run alpha-worker "x" --bogus
check "unknown run option: exit 2" test "$rc" = 2
run help
check "help: exit 0" test "$rc" = 0 -a -s "$W/out"

# ---- list, version, doctor --------------------------------------------------

run list
check "list shows agents with tier, gate and description" sh -c "grep -q '^alpha-worker .*fast .*false .*Use when' '$W/out' && grep -q '^beta-gate .*standard .*true .*Use for' '$W/out'"
run version
check "version prints the source version" sh -c "grep -q '^crew [0-9]' '$W/out'"

run doctor
check "doctor on a fresh install: exit 0" test "$rc" = 0
check "doctor reports matching manifest entries" has "$W/out" 'manifest entries match'
echo "edit" >> "$HOME/.claude/agents/alpha-worker.md"
run doctor
check "doctor detects drift: exit 1" test "$rc" = 1
check "doctor names the drifted file" has "$W/out" "drift.*alpha-worker.md"
rm "$HOME/.claude/agents/beta-gate.md"
run doctor
check "doctor detects missing files" has "$W/out" "missing: .*beta-gate.md"
rm -rf "$HOME/.crew"
run doctor
check "doctor without an install: exit 1" test "$rc" = 1

echo "1..$n"
exit "$failed"
