#!/bin/sh
# Renders tests/fixtures/good into temp directories and diffs the result
# against tests/snapshots/. UPDATE_SNAPSHOTS=1 regenerates the snapshots.
# Snapshots contain fixture output only, never the real roster.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
snap=$here/snapshots

W=$(mktemp -d "${TMPDIR:-/tmp}/crew-t-snap.XXXXXX")
trap 'rm -rf "$W"' EXIT
S=$W/src
cp -R "$here/fixtures/good" "$S"
echo 0.0.0-snapshot > "$S/VERSION"

n=0
failed=0
ok() { n=$((n + 1)); echo "ok $n - $1"; }
nok() { n=$((n + 1)); failed=1; echo "not ok $n - $1"; }

render() { # name scope-args... : renders into $W/<name>/{home,proj}
    rname=$1
    shift
    mkdir -p "$W/$rname/home" "$W/$rname/proj"
    HOME=$W/$rname/home CREW_SRC=$S sh "$repo/install.sh" "$@" > "$W/$rname.out" 2> "$W/$rname.err"
}

render global --global --target all
render project --project "$W/project/proj" --target all
# paths inside manifests differ per run; the manifest is covered by test_install.sh
rm -f "$W/global/home/.crew/manifest.json" "$W/project/home/.crew/manifest.json"

if [ "${UPDATE_SNAPSHOTS:-0}" = 1 ]; then
    rm -rf "$snap"
    mkdir -p "$snap"
    cp -R "$W/global/home" "$snap/global"
    cp -R "$W/project/proj" "$snap/project"
    echo "ok 1 - snapshots regenerated in tests/snapshots (review the diff before committing)"
    echo "1..1"
    exit 0
fi

compare() { # desc actual-dir expected-dir
    if [ ! -d "$3" ]; then
        nok "$1 (missing snapshot directory $3; run with UPDATE_SNAPSHOTS=1)"
    elif diff -r "$3" "$2" > "$W/diff" 2>&1; then
        ok "$1"
    else
        nok "$1"
        head -n 40 "$W/diff"
    fi
}

compare "global render matches snapshot (home tree)" "$W/global/home" "$snap/global"
compare "project render matches snapshot (project tree)" "$W/project/proj" "$snap/project"

has() { grep -q "$2" "$1"; }
claude_beta=$snap/global/.claude/agents/beta-gate.md
claude_alpha=$snap/global/.claude/agents/alpha-worker.md
if [ -d "$snap/global" ]; then
    if has "$claude_beta" '^tools: Read, Grep, Glob$'; then ok "claude: capabilities map to tools in table order"; else nok "claude: capabilities map to tools in table order"; fi
    if has "$claude_alpha" '^tools: Read, Grep, Glob, Edit, Write, Bash$'; then ok "claude: edit and shell map to Edit, Write, Bash"; else nok "claude: edit and shell map to Edit, Write, Bash"; fi
    if has "$claude_alpha" '^model: haiku$' && has "$claude_beta" '^model: sonnet$'; then ok "claude: tier maps to model"; else nok "claude: tier maps to model"; fi
    if has "$claude_beta" 'VERDICT: PASS|FAIL' && ! has "$claude_alpha" 'VERDICT:'; then ok "contract: VERDICT line only for gates"; else nok "contract: VERDICT line only for gates"; fi
    if has "$claude_beta" 'You must not modify files.' && ! has "$claude_alpha" 'must not modify'; then ok "contract: read-only line only for reads_only"; else nok "contract: read-only line only for reads_only"; fi
    if ! has "$snap/global/.claude/skills/sample-skill/SKILL.md" '^tags:'; then ok "claude: skill tags are stripped"; else nok "claude: skill tags are stripped"; fi
    # shellcheck disable=SC2016 # backticks are literal text in the expected output
    if has "$snap/global/.claude/commands/crew/sample-prompt.md" 'Act as the `alpha-worker` agent.' && has "$snap/global/.claude/commands/crew/sample-prompt.md" '^argument-hint: what to do$'; then ok "claude: prompt frontmatter and body"; else nok "claude: prompt frontmatter and body"; fi
    if has "$snap/global/.codex/config.toml" '^\[profiles.crew-readonly\]$' && has "$snap/global/.codex/config.toml" '^model_reasoning_effort = "high"$'; then ok "codex: profiles block"; else nok "codex: profiles block"; fi
    if ! has "$snap/global/.codex/config.toml" '^model = '; then ok "codex: empty model omits the model line"; else nok "codex: empty model omits the model line"; fi
fi

echo "1..$n"
exit "$failed"
