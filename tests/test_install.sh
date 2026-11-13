#!/bin/sh
# Tests for install.sh: scopes, targets, manifest, idempotency, edited-file
# protection, managed blocks, dry-run, update, uninstall, link, exit codes.
# Everything runs against tests/fixtures/good with a temp HOME and temp projects.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)

W=$(mktemp -d "${TMPDIR:-/tmp}/crew-t-install.XXXXXX")
trap 'rm -rf "$W"' EXIT
export HOME="$W/home"
mkdir -p "$HOME"
S=$W/src
cp -R "$here/fixtures/good" "$S"
echo 0.0.0-test > "$S/VERSION"

n=0
failed=0
ok() { n=$((n + 1)); echo "ok $n - $1"; }
nok() { n=$((n + 1)); failed=1; echo "not ok $n - $1"; }
check() { # desc command... : passes when the command succeeds
    d=$1
    shift
    if "$@"; then ok "$d"; else nok "$d"; fi
}

inst() { # args : runs the installer, sets rc, output in $W/out and $W/err
    set +e
    CREW_SRC=$S sh "$repo/install.sh" "$@" > "$W/out" 2> "$W/err"
    rc=$?
    set -e
}

fresh_home() { rm -rf "$HOME"; mkdir -p "$HOME"; }

digest() { # dir : content digest of every file below dir
    (cd "$1" && find . -type f | LC_ALL=C sort | while IFS= read -r f; do
        printf '%s ' "$f"
        cksum < "$f"
    done)
}

# shellcheck disable=SC2329 # called indirectly through check
only_skips() { ! grep -qv '^skip ' "$W/out"; }
# shellcheck disable=SC2329 # called indirectly through check
has_all() { # file... : all exist
    for f in "$@"; do [ -e "$f" ] || { echo "missing: $f" >&2; return 1; }; done
}
# shellcheck disable=SC2329 # called indirectly through check
same_file() { cmp -s "$1" "$2"; }

# ---- global install, all targets --------------------------------------------

inst --global
check "global install exits 0" test "$rc" = 0
check "global install creates crew home files" has_all \
    "$HOME/.crew/AGENTS.md" "$HOME/.crew/guardrails.md" "$HOME/.crew/config" "$HOME/.crew/learnings.md" \
    "$HOME/.crew/VERSION" "$HOME/.crew/manifest.json" "$HOME/.crew/agents/alpha-worker.md" \
    "$HOME/.crew/agents/beta-gate.md" "$HOME/.crew/skills/sample-skill/SKILL.md"
check "global install creates Claude files" has_all \
    "$HOME/.claude/agents/alpha-worker.md" "$HOME/.claude/agents/beta-gate.md" \
    "$HOME/.claude/skills/sample-skill/SKILL.md" "$HOME/.claude/commands/crew/sample-prompt.md" "$HOME/.claude/CLAUDE.md"
check "global install creates Codex files" has_all \
    "$HOME/.codex/AGENTS.md" "$HOME/.codex/skills/sample-skill/SKILL.md" \
    "$HOME/.codex/prompts/sample-prompt.md" "$HOME/.codex/config.toml"

man=$HOME/.crew/manifest.json
check "manifest has the expected envelope" sh -c "head -n 1 '$man' | grep -q '^{\"version\":\"0.0.0-test\",\"entries\":\[\$' && tail -n 1 '$man' | grep -q '^\]}\$'"
bad=0
tab=$(printf '\t')
awk '/^\{"path":/ {
    n = split($0, a, "\""); p = ""; s = ""; k = ""
    for (i = 1; i < n; i++) { if (a[i] == "path") p = a[i + 2]; if (a[i] == "sha256") s = a[i + 2]; if (a[i] == "kind") k = a[i + 2] }
    printf "%s\t%s\t%s\n", p, s, k }' "$man" > "$W/entries"
while IFS="$tab" read -r p s k; do
    if [ "$k" = file ]; then
        [ "$(shasum -a 256 < "$p" | awk '{ print $1 }')" = "$s" ] || { echo "sha mismatch: $p" >&2; bad=1; }
    else
        [ -e "$p" ] || bad=1
    fi
done < "$W/entries"
check "manifest entries match files on disk" test "$bad" = 0
check "manifest has block entries for the three managed blocks" test "$(grep -c '"kind":"block"' "$man")" = 3
check "manifest has no entry for user-owned config" test "$(grep -c '/.crew/config"' "$man")" = 0

# ---- idempotency ------------------------------------------------------------

before=$(digest "$HOME")
marker=$W/marker
touch "$marker"
sleep 1
inst --global
check "second run exits 0" test "$rc" = 0
check "second run reports only skip actions" only_skips
check "second run changes no bytes" test "$before" = "$(digest "$HOME")"
check "second run touches no file (mtime)" test -z "$(find "$HOME" -type f -newer "$marker")"

# ---- edited-file protection -------------------------------------------------

edited=$HOME/.claude/agents/alpha-worker.md
echo "my edit" >> "$edited"
cp "$edited" "$W/edited.copy"
inst --global
check "edited file: exit 3" test "$rc" = 3
check "edited file: original kept" same_file "$edited" "$W/edited.copy"
check "edited file: .crew-new written" test -f "$edited.crew-new"
check "edited file: conflict reported" grep -q "^conflict $edited\$" "$W/out"
rm -f "$edited.crew-new"
rm -f "$edited"
inst --global
check "deleted file is re-created" test "$rc" = 0 -a -f "$edited"

# ---- managed blocks, user content, uninstall --------------------------------

fresh_home
mkdir -p "$HOME/.claude" "$HOME/.codex"
printf '# my notes\n\nkeep this line\n' > "$HOME/.claude/CLAUDE.md"
printf 'plain agents text\n' > "$HOME/.codex/AGENTS.md"
printf 'model = "x"\n\n[profiles.mine]\nmodel = "y"\n' > "$HOME/.codex/config.toml"
cp "$HOME/.claude/CLAUDE.md" "$W/o.claude"
cp "$HOME/.codex/AGENTS.md" "$W/o.agents"
cp "$HOME/.codex/config.toml" "$W/o.toml"
inst --global
check "install next to user content exits 0" test "$rc" = 0
# shellcheck disable=SC2329 # called indirectly through check
head_matches() { # original installed
    sz=$(wc -c < "$1" | tr -d ' ')
    head -c "$sz" "$2" | cmp -s - "$1"
}
check "CLAUDE.md: user content before block is byte-identical" head_matches "$W/o.claude" "$HOME/.claude/CLAUDE.md"
check "AGENTS.md: user content before block is byte-identical" head_matches "$W/o.agents" "$HOME/.codex/AGENTS.md"
check "config.toml: user content before block is byte-identical" head_matches "$W/o.toml" "$HOME/.codex/config.toml"
check "blocks are delimited by markers" sh -c "grep -c '^<!-- crew:begin -->\$' '$HOME/.claude/CLAUDE.md' | grep -q '^1\$' && grep -c '^# crew:end\$' '$HOME/.codex/config.toml' | grep -q '^1\$'"

inst --uninstall --global
check "uninstall exits 0" test "$rc" = 0
check "uninstall restores CLAUDE.md" same_file "$W/o.claude" "$HOME/.claude/CLAUDE.md"
check "uninstall restores AGENTS.md" same_file "$W/o.agents" "$HOME/.codex/AGENTS.md"
check "uninstall restores config.toml" same_file "$W/o.toml" "$HOME/.codex/config.toml"
left=$(cd "$HOME" && find . -type f | LC_ALL=C sort | tr '\n' ' ')
check "uninstall leaves only user files, config and learnings" test "$left" = "./.claude/CLAUDE.md ./.codex/AGENTS.md ./.codex/config.toml ./.crew/config ./.crew/learnings.md "
check "uninstall removes the emptied directories" test ! -d "$HOME/.claude/agents" -a ! -d "$HOME/.codex/prompts"

fresh_home
inst --global
inst --uninstall --global
left=$(cd "$HOME" && find . -type f | LC_ALL=C sort | tr '\n' ' ')
check "uninstall deletes files crew created itself" test "$left" = "./.crew/config ./.crew/learnings.md "

# ---- foreign profile, malformed markers -------------------------------------

fresh_home
mkdir -p "$HOME/.codex"
printf '[profiles.crew-fast]\nmodel = "mine"\n' > "$HOME/.codex/config.toml"
cp "$HOME/.codex/config.toml" "$W/o.toml"
inst --global
check "foreign crew profile: exit 3" test "$rc" = 3
check "foreign crew profile: config.toml untouched" same_file "$W/o.toml" "$HOME/.codex/config.toml"
check "foreign crew profile: conflict reported" grep -q "^conflict $HOME/.codex/config.toml\$" "$W/out"
check "foreign crew profile: other files still installed" test -f "$HOME/.codex/prompts/sample-prompt.md"

fresh_home
mkdir -p "$HOME/.claude"
printf 'top\n<!-- crew:begin -->\nno end marker\n' > "$HOME/.claude/CLAUDE.md"
cp "$HOME/.claude/CLAUDE.md" "$W/o.claude"
inst --global --target claude
check "begin without end: exit 3" test "$rc" = 3
check "begin without end: file untouched" same_file "$W/o.claude" "$HOME/.claude/CLAUDE.md"
printf '<!-- crew:begin -->\na\n<!-- crew:end -->\n<!-- crew:begin -->\nb\n<!-- crew:end -->\n' > "$HOME/.claude/CLAUDE.md"
cp "$HOME/.claude/CLAUDE.md" "$W/o.claude"
inst --global --target claude
check "duplicated markers: exit 3 and file untouched" sh -c "test $rc = 3 && cmp -s '$W/o.claude' '$HOME/.claude/CLAUDE.md'"

# ---- dry-run ----------------------------------------------------------------

fresh_home
inst --dry-run
check "dry-run exits 0" test "$rc" = 0
check "dry-run prints create actions" grep -q "^create $HOME/.claude/agents/alpha-worker.md\$" "$W/out"
check "dry-run writes nothing" test -z "$(find "$HOME" -mindepth 1)"
inst --global
echo "x" >> "$HOME/.claude/agents/beta-gate.md"
before=$(digest "$HOME")
inst --dry-run --update
after=$(digest "$HOME")
check "dry-run on an existing install reports conflicts, changes nothing" test "$rc" = 3 -a "$before" = "$after"
inst --dry-run --uninstall
check "dry-run uninstall changes nothing" test "$before" = "$(digest "$HOME")"

# ---- project install --------------------------------------------------------

fresh_home
P=$W/proj
mkdir -p "$P"
P=$(cd "$P" && pwd -P)
inst --project "$P" --target claude
check "project claude: exit 0" test "$rc" = 0
check "project claude: files in the project" has_all \
    "$P/.claude/agents/alpha-worker.md" "$P/.claude/skills/sample-skill/SKILL.md" \
    "$P/.claude/commands/crew/sample-prompt.md" "$P/CLAUDE.md" "$P/.crew/context.md" "$P/.crew/learnings.md"
check "project claude: no user-level Claude files" test ! -e "$HOME/.claude"
check "project claude: shared crew home exists" has_all "$HOME/.crew/guardrails.md" "$HOME/.crew/manifest.json"
check "project CLAUDE.md imports project context and learnings" sh -c "grep -q '^@.crew/context.md\$' '$P/CLAUDE.md' && grep -q '^@.crew/learnings.md\$' '$P/CLAUDE.md'"
check "project install hints at .gitignore" grep -q '\.gitignore' "$W/err"
echo "mine" > "$P/.crew/context.md"
inst --project "$P" --target claude
check "project context.md is never overwritten" test "$(cat "$P/.crew/context.md")" = mine
check "project second run: only skips" only_skips

inst --project "$P" --target codex
check "project codex: exit 0" test "$rc" = 0
check "project codex: AGENTS.md block and .crew/agents" has_all "$P/AGENTS.md" "$P/.crew/agents/alpha-worker.md" "$P/.crew/agents/beta-gate.md"
check "project codex: nothing written under ~/.codex" test ! -e "$HOME/.codex"
check "project codex: agents carry the contract" grep -q 'STATUS: PASS|FAIL|BLOCKED' "$P/.crew/agents/alpha-worker.md"

inst --uninstall --project "$P"
check "project uninstall: exit 0" test "$rc" = 0
check "project uninstall: project files gone, project-owned files kept" sh -c "test ! -e '$P/.claude' && test ! -e '$P/CLAUDE.md' && test ! -e '$P/AGENTS.md' && test ! -e '$P/.crew/agents' && test -f '$P/.crew/context.md'"
check "project uninstall: shared crew home kept" test -f "$HOME/.crew/guardrails.md"

# ---- update removes files that left the source ------------------------------

fresh_home
cat > "$S/agents/gamma-extra.md" <<'EOF'
---
name: gamma-extra
description: Use when a fixture needs a temporary extra agent.
tier: deep
capabilities: [read, mcp]
gate: false
reads_only: false
---
# gamma-extra

## Role
Temporary.

## When to use
Use for tests. Not for review: use `agent:beta-gate`.

## Inputs
A handoff.

## Process
1. Nothing.

## Output
Nothing.

## Done when
- Never.
EOF
cp "$S/AGENTS.md" "$W/AGENTS.orig"
awk '{ print } /^\| `beta-gate`/ { print "| `gamma-extra` | deep | no | temporary |" }' "$W/AGENTS.orig" > "$S/AGENTS.md"
inst --global
check "extra agent installed" has_all "$HOME/.claude/agents/gamma-extra.md" "$HOME/.crew/agents/gamma-extra.md"
check "agent with mcp and not read-only gets no tools line" sh -c "! grep -q '^tools:' '$HOME/.claude/agents/gamma-extra.md'"
check "tier deep maps to the configured model" grep -q '^model: opus$' "$HOME/.claude/agents/gamma-extra.md"
rm "$S/agents/gamma-extra.md"
cp "$W/AGENTS.orig" "$S/AGENTS.md"
inst --update --global
check "update: exit 0" test "$rc" = 0
check "update removes files that left the source" test ! -e "$HOME/.claude/agents/gamma-extra.md" -a ! -e "$HOME/.crew/agents/gamma-extra.md"
check "update keeps current files" test -f "$HOME/.claude/agents/alpha-worker.md"
check "update drops stale manifest entries" test "$(grep -c gamma-extra "$HOME/.crew/manifest.json")" = 0

# ---- config -----------------------------------------------------------------

fresh_home
inst --global
printf 'CLAUDE_MODEL_STANDARD=opus\nCODEX_MODEL_FAST=small-model\nMYSTERY=1\n' > "$HOME/.crew/config"
cp "$HOME/.crew/config" "$W/config.mine"
inst --global
check "config is never overwritten" same_file "$W/config.mine" "$HOME/.crew/config"
check "config: model override reaches Claude agents" grep -q '^model: opus$' "$HOME/.claude/agents/beta-gate.md"
check "config: Codex model line appears when set" grep -q '^model = "small-model"$' "$HOME/.codex/config.toml"
check "config: unknown key warns, does not fail" sh -c "test $rc = 0 && grep -q 'unknown config key: MYSTERY' '$W/err'"
printf 'DEFAULT_TARGET=codex\n' > "$HOME/.crew/config"
rm -rf "$HOME/.claude"
inst --global
check "config: DEFAULT_TARGET is the default --target" test ! -e "$HOME/.claude/agents"

# ---- --link -----------------------------------------------------------------

fresh_home
echo "extra resource" > "$S/skills/sample-skill/checklist.txt"
inst --global --link
check "--link: pure-copy skill files are symlinks to the source" test -L "$HOME/.claude/skills/sample-skill/checklist.txt"
check "--link: SKILL.md with tags is rendered, not linked" test ! -L "$HOME/.claude/skills/sample-skill/SKILL.md"
check "--link: rendered agents stay real files" test ! -L "$HOME/.claude/agents/alpha-worker.md"
inst --global --link
check "--link: second run is idempotent" only_skips
inst --global
check "dropping --link converts symlinks back to copies" test ! -L "$HOME/.claude/skills/sample-skill/checklist.txt" -a "$rc" = 0
inst --uninstall --global
check "uninstall after --link leaves the source intact" test -f "$S/skills/sample-skill/checklist.txt"
rm "$S/skills/sample-skill/checklist.txt"

# ---- uninstall keeps edited files -------------------------------------------

fresh_home
inst --global
echo "edit" >> "$HOME/.claude/agents/alpha-worker.md"
inst --uninstall --global
check "uninstall keeps an edited file and exits 3" test "$rc" = 3 -a -f "$HOME/.claude/agents/alpha-worker.md"
check "uninstall reports the kept file" grep -q "^conflict $HOME/.claude/agents/alpha-worker.md\$" "$W/out"

# ---- exit codes -------------------------------------------------------------

fresh_home
inst --bogus
check "unknown flag: exit 2" test "$rc" = 2
inst --target nonsense
check "invalid target: exit 2" test "$rc" = 2
inst --global --project
check "--global with --project: exit 2" test "$rc" = 2
inst --project "$W/does-not-exist"
check "missing project directory: exit 2" test "$rc" = 2
inst --help
check "--help: exit 0 and usage" sh -c "test $rc = 0 && grep -q -- '--uninstall' '$W/out'"

cp "$S/agents/alpha-worker.md" "$W/alpha.orig"
awk 'NR == 2 { print "surprise: 1" } { print }' "$W/alpha.orig" > "$S/agents/alpha-worker.md"
inst --global
check "lint failure: exit 5" test "$rc" = 5
check "lint failure: nothing written" test -z "$(find "$HOME" -mindepth 1)"
cp "$W/alpha.orig" "$S/agents/alpha-worker.md"

awk 'BEGIN { for (i = 0; i < 1500; i++) print "Filler guardrail sentence number " i " that only exists to make the block large." }' > "$S/guardrails/30-big.md"
inst --global
check "oversized Codex block: exit 5, nothing written" sh -c "test $rc = 5 && test -z \"\$(find '$HOME' -mindepth 1)\""
rm "$S/guardrails/30-big.md"

inst --global
check "restored source installs again" test "$rc" = 0

PATH_SAVE=$PATH
mkdir "$W/emptybin"
set +e
PATH=$W/emptybin CREW_SRC=$S /bin/sh "$repo/install.sh" --global > "$W/out" 2> "$W/err"
rc=$?
set -e
PATH=$PATH_SAVE
check "missing utilities: exit 4" test "$rc" = 4

echo "1..$n"
exit "$failed"
