#!/bin/sh
# Tests for scripts/lint.sh: repo is clean, good fixture is clean, every bad
# fixture fails with the rule id encoded in its directory name.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
lint=$repo/scripts/lint.sh
fx=$here/fixtures

W=$(mktemp -d "${TMPDIR:-/tmp}/crew-t-lint.XXXXXX")
trap 'rm -rf "$W"' EXIT
export HOME="$W/home"
mkdir -p "$HOME"

n=0
failed=0
ok() { n=$((n + 1)); echo "ok $n - $1"; }
nok() { n=$((n + 1)); failed=1; echo "not ok $n - $1"; }

run() { # root ; sets rc, output in $W/out
    set +e
    sh "$lint" "$1" > "$W/out" 2> "$W/err"
    rc=$?
    set -e
}

# expect_rule DESC ROOT RULE : lint must exit 1 and report RULE
expect_rule() {
    run "$2"
    if [ "$rc" = 1 ] && grep -q ": $3: " "$W/out"; then ok "$1"; else nok "$1 (rc=$rc)"; fi
}

run "$repo"
if [ "$rc" = 0 ]; then ok "lint passes on the repository"; else nok "lint passes on the repository"; cat "$W/out" "$W/err"; fi

run "$fx/good"
if [ "$rc" = 0 ] && [ ! -s "$W/out" ]; then ok "good fixture is clean"; else nok "good fixture is clean"; cat "$W/out"; fi

mkdir "$W/empty"
run "$W/empty"
if [ "$rc" = 0 ]; then ok "empty root is accepted"; else nok "empty root is accepted"; fi

run "$W/does-not-exist"
if [ "$rc" = 2 ]; then ok "missing root is a usage error"; else nok "missing root is a usage error (rc=$rc)"; fi

run "$fx/warn/W01-mcp-readonly"
if [ "$rc" = 0 ] && grep -q ': W01: ' "$W/out"; then ok "W01 is a warning, exit 0"; else nok "W01 is a warning, exit 0 (rc=$rc)"; fi

for d in "$fx"/bad/*/; do
    name=$(basename "$d")
    rule=${name%%-*}
    expect_rule "bad fixture $name reports $rule" "$d" "$rule"
done

# output format: file:line: rule: message
run "$fx/bad/L03-name-mismatch"
if grep -Eq '^agents/bad-agent\.md:[0-9]+: L03: ' "$W/out"; then ok "output format file:line: rule: message"; else nok "output format"; fi

# --- cases generated at run time ---
mk() { rm -rf "$W/case"; cp -R "$fx/good" "$W/case"; }

mk
{
    cat "$fx/good/AGENTS.md"
    i=0
    while [ "$i" -lt 600 ]; do printf 'padding padding padding padding padding\n'; i=$((i + 1)); done
} > "$W/case/AGENTS.md"
expect_rule "L09 AGENTS.md size limit" "$W/case" L09

mk
{
    sed '$d' "$fx/good/agents/alpha-worker.md"
    i=0
    while [ "$i" -lt 400 ]; do printf 'padding padding padding padding padding\n'; i=$((i + 1)); done
} > "$W/case/agents/alpha-worker.md"
expect_rule "L09 agent body size limit" "$W/case" L09

mk
{
    sed '$d' "$fx/good/skills/sample-skill/SKILL.md"
    i=0
    while [ "$i" -lt 600 ]; do printf 'padding padding padding padding padding\n'; i=$((i + 1)); done
} > "$W/case/skills/sample-skill/SKILL.md"
expect_rule "L09 skill body size limit" "$W/case" L09

mk
printf 'a\tb\n' >> "$W/case/guardrails/10-approval.md"
expect_rule "L11 tab in markdown" "$W/case" L11

mk
printf 'crlf line\r\n' >> "$W/case/guardrails/10-approval.md"
expect_rule "L11 CR line ending" "$W/case" L11

mk
printf 'no newline at end' >> "$W/case/guardrails/10-approval.md"
expect_rule "L11 missing trailing newline" "$W/case" L11

mk
printf 'bad \377 byte\n' >> "$W/case/guardrails/10-approval.md"
if command -v iconv >/dev/null 2>&1; then
    expect_rule "L11 invalid UTF-8" "$W/case" L11
else
    ok "L11 invalid UTF-8 (skipped: no iconv)"
fi

mk
rm -rf "$W/case/skills/sample-skill"
expect_rule "L08 skills table lists a missing skill" "$W/case" L08

mk
mkdir "$W/case/skills/extra-skill"
printf -- '---\nname: extra-skill\ndescription: Use when extra.\n---\nbody\n' > "$W/case/skills/extra-skill/SKILL.md"
expect_rule "L08 skill missing from table" "$W/case" L08

mk
mkdir "$W/case/skills/no-file"
expect_rule "L01 skill directory without SKILL.md" "$W/case" L01

mk
sed 's/^name: sample-skill/name: Sample_Skill/' "$fx/good/skills/sample-skill/SKILL.md" > "$W/case/skills/sample-skill/SKILL.md"
expect_rule "L03 skill name must be kebab-case" "$W/case" L03

mk
sed 's/^agent: alpha-worker/agent: nobody/' "$fx/good/prompts/sample-prompt.md" > "$W/case/prompts/sample-prompt.md"
expect_rule "L07 prompt agent must resolve" "$W/case" L07

mk
sed 's/^gate: false/gate: maybe/' "$fx/good/agents/alpha-worker.md" > "$W/case/agents/alpha-worker.md"
expect_rule "L05 gate must be a bool" "$W/case" L05

mk
sed 's/^capabilities:.*/capabilities: [edit, edit]/' "$fx/good/agents/alpha-worker.md" > "$W/case/agents/alpha-worker.md"
expect_rule "L05 duplicate capability and read required" "$W/case" L05

mk
sed 's/^tier: fast/tier: fast\ntier: deep/' "$fx/good/agents/alpha-worker.md" > "$W/case/agents/alpha-worker.md"
expect_rule "L01 duplicate key" "$W/case" L01

mk
sed '/^reads_only/d' "$fx/good/agents/alpha-worker.md" > "$W/case/agents/alpha-worker.md"
expect_rule "L02 missing reads_only" "$W/case" L02

mk
sed 's/^# alpha-worker/# someone-else/' "$fx/good/agents/alpha-worker.md" > "$W/case/agents/alpha-worker.md"
expect_rule "L06 H1 must match the name" "$W/case" L06

mk
rm -rf "$W/case/scripts"
mkdir "$W/case/scripts"
printf '#!/bin/sh\necho no strict mode\n' > "$W/case/scripts/x.sh"
expect_rule "L12 set -eu required" "$W/case" L12

echo "1..$n"
exit "$failed"
