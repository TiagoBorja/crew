#!/bin/sh
# install.sh - renders crew content for Claude Code and Codex.
#
# Usage: install.sh [--global | --project [DIR]] [--target claude|codex|all]
#                   [--dry-run] [--update] [--uninstall] [--link] [--help]
#
# POSIX sh + awk only. No network. Reads the crew source tree next to this
# script (override with CREW_SRC, meant for tests). Exit codes: 0 ok, 1 error,
# 2 usage, 3 conflicts, 4 missing utility, 5 invalid source.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
SRC=${CREW_SRC:-$HERE}
DRY=0
LINK=0
MODE=install
SCOPE=global
PROJ=
TARGET=
GFLAG=0
PFLAG=0
CONFLICTS=0
TN=0

usage() {
    cat <<'EOF'
Usage: install.sh [options]

  --global             install to user-level paths (default)
  --project [DIR]      install to project DIR (default: current directory)
  --target T           claude | codex | all (default: DEFAULT_TARGET in ~/.crew/config, else all)
  --dry-run            print every planned action, write nothing
  --update             re-render; keep edited files; remove files that left the source
  --uninstall          remove crew files and managed blocks listed in the manifest
  --link               symlink pure-copy files (skills) to the source, for developing crew
  --help               this text

Actions printed: create, update, skip, conflict, remove, keep.
Exit codes: 0 ok, 1 error, 2 usage, 3 conflicts, 4 missing utility, 5 invalid source.
EOF
}

die() {
    code=$1
    shift
    echo "install.sh: $*" >&2
    exit "$code"
}

# ---- arguments --------------------------------------------------------------

while [ $# -gt 0 ]; do
    case $1 in
        --global) GFLAG=1 ;;
        --project)
            PFLAG=1
            if [ $# -gt 1 ] && [ "${2#-}" = "$2" ]; then
                PROJ=$2
                shift
            fi
            ;;
        --target)
            [ $# -gt 1 ] || die 2 "--target needs a value"
            TARGET=$2
            shift
            ;;
        --target=*) TARGET=${1#--target=} ;;
        --dry-run) DRY=1 ;;
        --update) ;;
        --uninstall) MODE=uninstall ;;
        --link) LINK=1 ;;
        --help | -h)
            usage
            exit 0
            ;;
        *) die 2 "unknown argument: $1 (see --help)" ;;
    esac
    shift
done
if [ "$GFLAG" = 1 ] && [ "$PFLAG" = 1 ]; then die 2 "--global and --project are mutually exclusive"; fi
if [ "$PFLAG" = 1 ]; then SCOPE=project; fi
case $TARGET in
    "" | claude | codex | all) ;;
    *) die 2 "invalid --target '$TARGET' (claude, codex or all)" ;;
esac

# ---- environment ------------------------------------------------------------

for u in awk cp mv mkdir rm rmdir ln cmp find sort cat wc tr mktemp dirname head tail grep; do
    command -v "$u" >/dev/null 2>&1 || die 4 "missing required utility: $u"
done
if command -v sha256sum >/dev/null 2>&1; then
    SHA=sha256sum
elif command -v shasum >/dev/null 2>&1; then
    SHA=shasum
else
    die 4 "missing required utility: shasum or sha256sum"
fi

HOME=${HOME:-}
case $HOME in
    /*) ;;
    *) die 2 "HOME must be an absolute path" ;;
esac
[ -d "$HOME" ] || die 2 "HOME is not a directory: $HOME"
[ -d "$SRC" ] || die 2 "source is not a directory: $SRC"
SRC=$(cd "$SRC" && pwd)

if [ "$SCOPE" = project ]; then
    [ -n "$PROJ" ] || PROJ=$(pwd)
    [ -d "$PROJ" ] || die 2 "project directory does not exist: $PROJ"
    PROJ=$(cd "$PROJ" && pwd -P)
fi
for p in "$HOME" "$PROJ"; do
    case $p in
        *\"* | *\\*) die 2 "paths containing quotes or backslashes are not supported: $p" ;;
    esac
done

CREW_HOME=$HOME/.crew
CFG=$CREW_HOME/config
MANIFEST=$CREW_HOME/manifest.json
if [ "$SCOPE" = global ]; then
    SCOPE_ID=global
    CLAUDE_DIR=$HOME/.claude
    CLAUDE_MD=$HOME/.claude/CLAUDE.md
    CODEX_MD=$HOME/.codex/AGENTS.md
else
    SCOPE_ID=project:$PROJ
    CLAUDE_DIR=$PROJ/.claude
    CLAUDE_MD=$PROJ/CLAUDE.md
    CODEX_MD=$PROJ/AGENTS.md
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/crewinst.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
trap 'exit 1' INT TERM HUP
OLDMAN=$TMP/man.old
NEWMAN=$TMP/man.new
: > "$NEWMAN"

# ---- small helpers ----------------------------------------------------------

MANLIB='function fld(l, k,   i, r) { i = index(l, "\"" k "\":\""); if (!i) return ""; r = substr(l, i + length(k) + 4); return substr(r, 1, index(r, "\"") - 1) }'

act() { printf '%s %s\n' "$1" "$2"; }

sha_of() {
    if [ "$SHA" = sha256sum ]; then sha256sum < "$1"; else shasum -a 256 < "$1"; fi | awk '{ print $1 }'
}

mf() { printf '%s\n' "$1" | awk "$MANLIB"' { print fld($0, "'"$2"'") }'; }

man_line() { awk -v p="$1" "$MANLIB"' fld($0, "path") == p { print; exit }' "$OLDMAN"; }

write_file() { # src dest : atomic copy
    mkdir -p "${2%/*}"
    cp "$1" "$2.crew-tmp"
    mv -f "$2.crew-tmp" "$2"
}

next_tmp() {
    TN=$((TN + 1))
    NT=$TMP/r.$TN
}

record() { # path sha kind scope target [created]
    cr=
    if [ -n "${6:-}" ]; then cr=',"created":"1"'; fi
    printf '{"path":"%s","sha256":"%s","version":"%s","scope":"%s","target":"%s","kind":"%s"%s}\n' \
        "$1" "$2" "$VERSION" "$4" "$5" "$3" "$cr" >> "$NEWMAN"
}

keep_old() { # path : conflict leaves the previous manifest entry alone
    ko=$(man_line "$1")
    if [ -n "$ko" ]; then printf '%s\n' "$ko" >> "$NEWMAN"; fi
}

prune_dirs() { # path : remove emptied parent directories below HOME/PROJ
    pd=${1%/*}
    while [ -n "$pd" ] && [ "$pd" != "$HOME" ] && [ "$pd" != "$PROJ" ] && [ "$pd" != / ]; do
        rmdir "$pd" 2>/dev/null || break
        pd=${pd%/*}
    done
}

cfg_get() { # key default
    if [ -f "$CFG" ]; then
        awk -v k="$1" -v d="$2" '
            /^[ \t]*#/ { next }
            { i = index($0, "="); if (!i) next
              key = substr($0, 1, i - 1); gsub(/[ \t]/, "", key)
              if (key != k) next
              v = substr($0, i + 1); sub(/[ \t]+#.*$/, "", v); sub(/^[ \t]+/, "", v); sub(/[ \t\r]+$/, "", v)
              val = v; found = 1 }
            END { if (found) print val; else print d }' "$CFG"
    else
        printf '%s\n' "$2"
    fi
}

cfg_val() { # key default : validated value, never empty
    cv=$(cfg_get "$1" "$2")
    [ -n "$cv" ] || cv=$2
    case $cv in
        *[!A-Za-z0-9._:/@-]*) die 2 "invalid value for $1 in $CFG" ;;
    esac
    printf '%s\n' "$cv"
}

cfg_opt() { # key : validated value, may be empty
    cv=$(cfg_get "$1" "")
    case $cv in
        *[!A-Za-z0-9._:/@-]*) die 2 "invalid value for $1 in $CFG" ;;
    esac
    printf '%s\n' "$cv"
}

warn_unknown_keys() {
    [ -f "$CFG" ] || return 0
    awk '
        BEGIN { n = split("CLAUDE_MODEL_FAST CLAUDE_MODEL_STANDARD CLAUDE_MODEL_DEEP CODEX_MODEL_FAST CODEX_MODEL_STANDARD CODEX_MODEL_DEEP CODEX_EFFORT_FAST CODEX_EFFORT_STANDARD CODEX_EFFORT_DEEP DEFAULT_TARGET RUN_ENGINE", a, " ")
                for (i = 1; i <= n; i++) known[a[i]] = 1 }
        /^[ \t]*#/ || /^[ \t]*$/ { next }
        { i = index($0, "="); key = (i ? substr($0, 1, i - 1) : $0); gsub(/[ \t]/, "", key)
          if (!(key in known)) print "install.sh: warning: unknown config key: " key > "/dev/stderr" }' "$CFG"
}

default_config() {
    cat <<'EOF'
# crew configuration. Plain KEY=VALUE lines, never executed.
# Models used when rendering Claude Code agents, per tier.
CLAUDE_MODEL_FAST=haiku
CLAUDE_MODEL_STANDARD=sonnet
CLAUDE_MODEL_DEEP=opus
# Codex models per tier. Empty means: let Codex pick its own default.
CODEX_MODEL_FAST=
CODEX_MODEL_STANDARD=
CODEX_MODEL_DEEP=
CODEX_EFFORT_FAST=low
CODEX_EFFORT_STANDARD=medium
CODEX_EFFORT_DEEP=high
# Which tools the installer targets by default: claude | codex | all
DEFAULT_TARGET=all
# Engine used by "crew run": codex | claude
RUN_ENGINE=codex
EOF
}

# ---- source reading and rendering ------------------------------------------

fm_get() { # file key
    awk -v k="$2" '
        NR == 1 && $0 == "---" { fm = 1; next }
        fm && $0 == "---" { exit }
        fm { i = index($0, ":")
             if (i && substr($0, 1, i - 1) == k) {
                 v = substr($0, i + 1); sub(/^[ \t]+/, "", v); sub(/[ \t\r]+$/, "", v); print v; exit } }' "$1"
}

fm_body() {
    awk 'NR == 1 && $0 == "---" { fm = 1; next }
         fm && $0 == "---" { fm = 0; next }
         !fm { print }' "$1"
}

yaml_scalar() {
    printf '%s\n' "$1" | awk '
        BEGIN { sq = sprintf("%c", 39); dq = sprintf("%c", 34); bs = sprintf("%c", 92) }
        { s = $0; c = substr(s, 1, 1); need = (s == "")
          if (c != "" && (index("[]{}&*!|>%@`#?-:,", c) > 0 || index(sq dq, c) > 0)) need = 1
          if (index(s, ": ") || index(s, " #") || substr(s, length(s)) == ":") need = 1
          if (need) {
              o = ""
              for (i = 1; i <= length(s); i++) { ch = substr(s, i, 1); if (ch == bs || ch == dq) o = o bs; o = o ch }
              s = dq o dq }
          print s }'
}

map_tools() { # capabilities reads_only separator
    awk -v caps="$1" -v ro="$2" -v sep="$3" '
        BEGIN { gsub(/[\[\],]/, " ", caps); n = split(caps, c, " "); for (i = 1; i <= n; i++) has[c[i]] = 1
                split("read:Read search:Grep search:Glob edit:Edit edit:Write shell:Bash web:WebFetch web:WebSearch", m, " ")
                for (i = 1; i <= 8; i++) {
                    split(m[i], kv, ":")
                    if (!(kv[1] in has) || (kv[2] in seen)) continue
                    if (ro == "true" && (kv[2] == "Edit" || kv[2] == "Write")) continue
                    seen[kv[2]] = 1; out = out (out == "" ? "" : sep) kv[2] }
                print out }'
}

tier_model() { # tier
    case $1 in
        fast) printf '%s\n' "$CL_FAST" ;;
        standard) printf '%s\n' "$CL_STD" ;;
        *) printf '%s\n' "$CL_DEEP" ;;
    esac
}

contract_text() { # gate reads_only
    printf '%s\n' '## Contract'
    printf '%s\n' 'Follow the crew guardrails in ~/.crew/guardrails.md.'
    # shellcheck disable=SC2016 # backticks are literal text in the output
    printf '%s\n' 'Start your final message with `STATUS: PASS|FAIL|BLOCKED`.'
    # shellcheck disable=SC2016 # backticks are literal text in the output
    if [ "$1" = true ]; then printf '%s\n' 'End with `VERDICT: PASS|FAIL` and at least one reason line.'; fi
    if [ "$2" = true ]; then printf '%s\n' 'You must not modify files.'; fi
}

render_claude_agent() { # source-file out
    ra_name=$(fm_get "$1" name)
    ra_caps=$(fm_get "$1" capabilities)
    ra_ro=$(fm_get "$1" reads_only)
    ra_omit=0
    case $ra_caps in
        *mcp*) if [ "$ra_ro" != true ]; then ra_omit=1; fi ;;
    esac
    {
        printf '%s\n' '---'
        printf 'name: %s\n' "$ra_name"
        printf 'description: %s\n' "$(yaml_scalar "$(fm_get "$1" description)")"
        if [ "$ra_omit" = 0 ]; then printf 'tools: %s\n' "$(map_tools "$ra_caps" "$ra_ro" ', ')"; fi
        printf 'model: %s\n' "$(tier_model "$(fm_get "$1" tier)")"
        printf '%s\n' '---'
        printf '<!-- generated by crew %s from agents/%s.md; do not edit -->\n' "$VERSION" "$ra_name"
        fm_body "$1"
        printf '\n'
        contract_text "$(fm_get "$1" gate)" "$ra_ro"
    } > "$2"
}

render_neutral_agent() { # source-file out
    {
        cat "$1"
        printf '\n'
        contract_text "$(fm_get "$1" gate)" "$(fm_get "$1" reads_only)"
    } > "$2"
}

render_prompt() { # source-file out
    rp_hint=$(fm_get "$1" argument_hint)
    rp_agent=$(fm_get "$1" agent)
    [ -n "$rp_agent" ] || rp_agent=orchestrator
    {
        printf '%s\n' '---'
        printf 'description: %s\n' "$(yaml_scalar "$(fm_get "$1" description)")"
        if [ -n "$rp_hint" ]; then printf 'argument-hint: %s\n' "$(yaml_scalar "$rp_hint")"; fi
        printf '%s\n' '---'
        # shellcheck disable=SC2016 # backticks are literal text in the output
        printf 'Act as the `%s` agent.\n\n' "$rp_agent"
        fm_body "$1"
    } > "$2"
}

render_skill_md() { # source-file out : drops the tags key
    awk 'NR == 1 && $0 == "---" { fm = 1; print; next }
         fm && $0 == "---" { fm = 0; print; next }
         fm && /^tags:/ { next }
         { print }' "$1" > "$2"
}

# ---- writing files and blocks (edited-file protection) --------

put_file() { # dest content scope target [link-source]
    pf_dest=$1
    pf_src=$2
    pf_scope=$3
    pf_tgt=$4
    pf_link=${5:-}
    pf_new=$(sha_of "$pf_src")
    pf_mode=copy
    if [ "$LINK" = 1 ] && [ -n "$pf_link" ] && cmp -s "$pf_src" "$pf_link"; then pf_mode="link"; fi

    if [ ! -e "$pf_dest" ] && [ ! -L "$pf_dest" ]; then
        act create "$pf_dest"
        put_do
        record "$pf_dest" "$pf_new" file "$pf_scope" "$pf_tgt"
        return 0
    fi
    pf_cur=$(sha_of "$pf_dest" 2>/dev/null) || pf_cur=
    pf_isln=copy
    if [ -L "$pf_dest" ]; then pf_isln="link"; fi
    pf_old=$(mf "$(man_line "$pf_dest")" sha256)
    if [ "$pf_cur" = "$pf_new" ] && [ "$pf_isln" = "$pf_mode" ]; then
        act skip "$pf_dest"
        record "$pf_dest" "$pf_new" file "$pf_scope" "$pf_tgt"
    elif [ -n "$pf_old" ] && { [ "$pf_cur" = "$pf_old" ] || [ "$pf_cur" = "$pf_new" ] || [ -z "$pf_cur" ]; }; then
        act update "$pf_dest"
        put_do
        record "$pf_dest" "$pf_new" file "$pf_scope" "$pf_tgt"
    else
        act conflict "$pf_dest"
        CONFLICTS=1
        if [ "$DRY" = 0 ]; then cp "$pf_src" "$pf_dest.crew-new"; fi
        keep_old "$pf_dest"
    fi
}

put_do() {
    [ "$DRY" = 0 ] || return 0
    if [ "$pf_mode" = link ]; then
        mkdir -p "${pf_dest%/*}"
        ln -s "$pf_link" "$pf_dest.crew-tmp"
        mv -f "$pf_dest.crew-tmp" "$pf_dest"
    else
        write_file "$pf_src" "$pf_dest"
    fi
}

put_once() { # dest content : created once, never overwritten, not in manifest
    if [ -e "$1" ]; then
        act skip "$1"
        return 0
    fi
    act create "$1"
    if [ "$DRY" = 0 ]; then write_file "$2" "$1"; fi
}

block_info() { # file begin end -> none | one | bad
    awk -v b="$2" -v e="$3" '
        $0 == b { if (inb) bad = 1; inb = 1; nb++; next }
        $0 == e { if (!inb) bad = 1; inb = 0; ne++; next }
        END { if (inb || nb > 1 || ne > 1) bad = 1
              if (bad) print "bad"; else if (nb == 1) print "one"; else print "none" }' "$1"
}

block_inner() { # file begin end
    awk -v b="$2" -v e="$3" '
        $0 == e && inb { exit }
        inb { print }
        $0 == b { inb = 1 }' "$1"
}

foreign_profiles() { # toml file: a crew profile table outside the markers
    awk -v b='# crew:begin' -v e='# crew:end' '
        $0 == b { inb = 1; next }
        $0 == e { inb = 0; next }
        !inb && /^[ \t]*\[[ \t]*profiles\.crew-/ { found = 1 }
        END { exit(found ? 0 : 1) }' "$1"
}

block_markers() { # style -> sets BB BE
    if [ "$1" = toml ]; then
        BB='# crew:begin'
        BE='# crew:end'
    else
        BB='<!-- crew:begin -->'
        BE='<!-- crew:end -->'
    fi
}

block_conflict() { # file
    act conflict "$1"
    CONFLICTS=1
    keep_old "$1"
}

put_block() { # file content scope target style
    pb_file=$1
    pb_content=$2
    pb_scope=$3
    pb_tgt=$4
    block_markers "$5"
    pb_new=$(sha_of "$pb_content")
    pb_tmp=$TMP/blk.new
    if [ ! -e "$pb_file" ]; then
        act create "$pb_file"
        if [ "$DRY" = 0 ]; then
            { printf '%s\n' "$BB"; cat "$pb_content"; printf '%s\n' "$BE"; } > "$pb_tmp"
            write_file "$pb_tmp" "$pb_file"
        fi
        record "$pb_file" "$pb_new" block "$pb_scope" "$pb_tgt" 1
        return 0
    fi
    if [ "$5" = toml ] && foreign_profiles "$pb_file"; then
        block_conflict "$pb_file"
        return 0
    fi
    pb_created=$(mf "$(man_line "$pb_file")" created)
    case $(block_info "$pb_file" "$BB" "$BE") in
        bad) block_conflict "$pb_file" ;;
        none)
            act update "$pb_file"
            if [ "$DRY" = 0 ]; then
                {
                    cat "$pb_file"
                    if [ -n "$(tail -c 1 "$pb_file")" ]; then printf '\n'; fi
                    if [ -s "$pb_file" ]; then printf '\n'; fi
                    printf '%s\n' "$BB"; cat "$pb_content"; printf '%s\n' "$BE"
                } > "$pb_tmp"
                write_file "$pb_tmp" "$pb_file"
            fi
            record "$pb_file" "$pb_new" block "$pb_scope" "$pb_tgt"
            ;;
        one)
            block_inner "$pb_file" "$BB" "$BE" > "$TMP/blk.cur"
            if cmp -s "$TMP/blk.cur" "$pb_content"; then
                act skip "$pb_file"
            else
                act update "$pb_file"
                if [ "$DRY" = 0 ]; then
                    awk -v b="$BB" -v e="$BE" -v cf="$pb_content" '
                        $0 == b && !done { print; while ((getline l < cf) > 0) print l; close(cf); skip = 1; next }
                        skip { if ($0 == e) { print; skip = 0; done = 1 } ; next }
                        { print }' "$pb_file" > "$pb_tmp"
                    write_file "$pb_tmp" "$pb_file"
                fi
            fi
            record "$pb_file" "$pb_new" block "$pb_scope" "$pb_tgt" "$pb_created"
            ;;
    esac
}

put_tree() { # srcdir destdir scope target : skill directory
    (cd "$1" && find . -type f | LC_ALL=C sort) > "$TMP/tree.list"
    while IFS= read -r rel; do
        rel=${rel#./}
        next_tmp
        if [ "$rel" = SKILL.md ]; then
            render_skill_md "$1/$rel" "$NT"
        else
            cp "$1/$rel" "$NT"
        fi
        put_file "$2/$rel" "$NT" "$3" "$4" "$1/$rel"
        rm -f "$NT"
    done < "$TMP/tree.list"
}

# ---- removal (uninstall and stale files) ------------------------------------

strip_block() { # file begin end out : drops markers, content and one preceding blank line
    awk -v b="$2" -v e="$3" '
        function flush() { if (held) { print ""; held = 0 } }
        $0 == b { held = 0; skip = 1; next }
        skip { if ($0 == e) skip = 0; next }
        $0 == "" { flush(); held = 1; next }
        { flush(); print }
        END { flush() }' "$1" > "$4"
}

remove_block() { # line strict
    rb_path=$(mf "$1" path)
    if [ ! -e "$rb_path" ]; then
        act skip "$rb_path"
        return 0
    fi
    case $rb_path in
        *.toml) block_markers toml ;;
        *) block_markers md ;;
    esac
    case $(block_info "$rb_path" "$BB" "$BE") in
        none) act skip "$rb_path" ;;
        bad)
            act conflict "$rb_path"
            CONFLICTS=1
            printf '%s\n' "$1" >> "$NEWMAN"
            ;;
        one)
            strip_block "$rb_path" "$BB" "$BE" "$TMP/blk.out"
            if [ "$(mf "$1" created)" = 1 ] && ! grep -q '[^[:space:]]' "$TMP/blk.out"; then
                act remove "$rb_path (managed block, file created by crew)"
                if [ "$DRY" = 0 ]; then
                    rm -f "$rb_path"
                    prune_dirs "$rb_path"
                fi
            else
                act remove "$rb_path (managed block)"
                if [ "$DRY" = 0 ]; then write_file "$TMP/blk.out" "$rb_path"; fi
            fi
            ;;
    esac
}

remove_entry() { # manifest-line strict
    re_path=$(mf "$1" path)
    if [ "$(mf "$1" kind)" = block ]; then
        remove_block "$1"
        return 0
    fi
    if [ ! -e "$re_path" ] && [ ! -L "$re_path" ]; then
        act skip "$re_path"
        return 0
    fi
    re_ok=0
    if [ -L "$re_path" ]; then
        re_ok=1
    elif [ "$(sha_of "$re_path")" = "$(mf "$1" sha256)" ]; then
        re_ok=1
    fi
    if [ "$re_ok" = 1 ]; then
        act remove "$re_path"
        if [ "$DRY" = 0 ]; then
            rm -f "$re_path"
            prune_dirs "$re_path"
        fi
    elif [ "$2" = strict ]; then
        act conflict "$re_path"
        CONFLICTS=1
        printf '%s\n' "$1" >> "$NEWMAN"
    else
        act keep "$re_path"
    fi
}

# ---- manifest ---------------------------------------------------------------

load_manifest() {
    : > "$OLDMAN"
    if [ -f "$MANIFEST" ]; then
        awk '/^\{"path":/ { sub(/,[ \t]*$/, ""); print }' "$MANIFEST" > "$OLDMAN"
    fi
}

in_domains() { # selects (or, with -v, excludes) old entries in DOMAINS
    awk -v sel="$DOMAINS" -v inv="$1" "$MANLIB"'
        { m = (index(sel, " " fld($0, "scope") "|" fld($0, "target") " ") > 0)
          if (m == (inv == "in")) print }' "$OLDMAN"
}

write_manifest() {
    in_domains out > "$TMP/man.kept"
    cat "$TMP/man.kept" "$NEWMAN" | awk "$MANLIB"'
        { l[fld($0, "path")] = $0 }
        END { for (p in l) print l[p] }' | LC_ALL=C sort > "$TMP/man.all"
    if [ ! -s "$TMP/man.all" ]; then
        if [ -f "$MANIFEST" ]; then
            act remove "$MANIFEST"
            if [ "$DRY" = 0 ]; then
                rm -f "$MANIFEST"
                prune_dirs "$MANIFEST"
            fi
        fi
        return 0
    fi
    awk -v v="$VERSION" '
        BEGIN { print "{\"version\":\"" v "\",\"entries\":[" }
        { a[NR] = $0 }
        END { for (i = 1; i <= NR; i++) print a[i] (i < NR ? "," : ""); print "]}" }' "$TMP/man.all" > "$TMP/man.json"
    if [ -f "$MANIFEST" ] && cmp -s "$TMP/man.json" "$MANIFEST"; then
        act skip "$MANIFEST"
    elif [ -f "$MANIFEST" ]; then
        act update "$MANIFEST"
        if [ "$DRY" = 0 ]; then write_file "$TMP/man.json" "$MANIFEST"; fi
    else
        act create "$MANIFEST"
        if [ "$DRY" = 0 ]; then write_file "$TMP/man.json" "$MANIFEST"; fi
    fi
}

remove_selected() { # strict|lenient : entries of OLDMAN in DOMAINS and not in NEWMAN
    awk -v sel="$DOMAINS" "$MANLIB"'
        FILENAME == ARGV[1] { n[fld($0, "path")] = 1; next }
        index(sel, " " fld($0, "scope") "|" fld($0, "target") " ") > 0 && !(fld($0, "path") in n) { print }' \
        "$NEWMAN" "$OLDMAN" > "$TMP/stale"
    while IFS= read -r line; do
        remove_entry "$line" "$1"
    done < "$TMP/stale"
}

# ---- install phases ---------------------------------------------------------

read_version() {
    VERSION=
    if [ -f "$SRC/VERSION" ]; then
        VERSION=$(head -n 1 "$SRC/VERSION" | tr -d ' \r')
    elif [ -f "$HERE/VERSION" ]; then
        VERSION=$(head -n 1 "$HERE/VERSION" | tr -d ' \r')
    fi
    case $VERSION in
        "" | *[!A-Za-z0-9.+-]*) VERSION=0.0.0 ;;
    esac
}

validate_source() {
    [ -f "$SRC/AGENTS.md" ] || die 5 "source invalid: AGENTS.md is missing in $SRC"
    ng=0
    for g in "$SRC"/guardrails/*.md; do
        if [ -f "$g" ]; then ng=$((ng + 1)); fi
    done
    [ "$ng" -gt 0 ] || die 5 "source invalid: no guardrails/*.md in $SRC"
    if [ -f "$HERE/scripts/lint.sh" ]; then
        if ! sh "$HERE/scripts/lint.sh" "$SRC" > "$TMP/lint.out" 2>&1; then
            cat "$TMP/lint.out" >&2
            die 5 "source failed lint; nothing written"
        fi
    fi
}

load_config() {
    CL_FAST=$(cfg_val CLAUDE_MODEL_FAST haiku)
    CL_STD=$(cfg_val CLAUDE_MODEL_STANDARD sonnet)
    CL_DEEP=$(cfg_val CLAUDE_MODEL_DEEP opus)
    CX_MFAST=$(cfg_opt CODEX_MODEL_FAST)
    CX_MSTD=$(cfg_opt CODEX_MODEL_STANDARD)
    CX_MDEEP=$(cfg_opt CODEX_MODEL_DEEP)
    CX_EFAST=$(cfg_val CODEX_EFFORT_FAST low)
    CX_ESTD=$(cfg_val CODEX_EFFORT_STANDARD medium)
    CX_EDEEP=$(cfg_val CODEX_EFFORT_DEEP high)
    warn_unknown_keys
}

build_contents() {
    : > "$TMP/guardrails.md"
    gfirst=1
    for g in "$SRC"/guardrails/*.md; do
        [ -f "$g" ] || continue
        if [ "$gfirst" = 0 ]; then printf '\n' >> "$TMP/guardrails.md"; fi
        cat "$g" >> "$TMP/guardrails.md"
        gfirst=0
    done
    {
        printf '%s\n' '@~/.crew/AGENTS.md' '@~/.crew/guardrails.md'
        if [ "$SCOPE" = project ]; then printf '%s\n' '@.crew/context.md' '@.crew/learnings.md'; fi
        printf '%s\n' '@~/.crew/learnings.md'
    } > "$TMP/claude.block"
    {
        cat "$SRC/AGENTS.md"
        printf '\n'
        cat "$TMP/guardrails.md"
        printf '\n'
        # shellcheck disable=SC2016 # backticks are literal text in the output
        printf '%s\n' '- Project context: `.crew/context.md` (read first when present)'
        # shellcheck disable=SC2016 # backticks are literal text in the output
        printf '%s\n' '- Project learnings: `.crew/learnings.md`'
        # shellcheck disable=SC2016 # backticks are literal text in the output
        printf '%s\n' '- Personal learnings: `~/.crew/learnings.md`'
        # shellcheck disable=SC2016 # backticks are literal text in the output
        printf '%s\n' '- Agent definitions: `.crew/agents/` (project) or `~/.crew/agents/`'
    } > "$TMP/codex.block"
    bsz=$(wc -c < "$TMP/codex.block" | tr -d ' ')
    if [ "$bsz" -ge 32768 ]; then die 5 "Codex AGENTS.md block is $bsz bytes (limit < 32768); nothing written"; fi
    printf '%s\n' "$VERSION" > "$TMP/version"
    printf '# Learnings\n' > "$TMP/learnings"
    codex_profiles > "$TMP/codex.toml"
}

codex_profiles() {
    printf '[profiles.crew-fast]\n'
    if [ -n "$CX_MFAST" ]; then printf 'model = "%s"\n' "$CX_MFAST"; fi
    printf 'model_reasoning_effort = "%s"\n\n' "$CX_EFAST"
    printf '[profiles.crew-standard]\n'
    if [ -n "$CX_MSTD" ]; then printf 'model = "%s"\n' "$CX_MSTD"; fi
    printf 'model_reasoning_effort = "%s"\n\n' "$CX_ESTD"
    printf '[profiles.crew-deep]\n'
    if [ -n "$CX_MDEEP" ]; then printf 'model = "%s"\n' "$CX_MDEEP"; fi
    printf 'model_reasoning_effort = "%s"\n\n' "$CX_EDEEP"
    printf '[profiles.crew-readonly]\nsandbox_mode = "read-only"\n'
}

context_template() {
    cat <<'EOF'
# Project context
## Summary
<one paragraph: what the project does, who uses it>
## Stack
- languages / versions:
- frameworks:
- datastores:
- infra / runtime:
## Commands
- install:
- build:
- test:
- test (single):
- lint / format:
- run locally:
## Conventions
- layout:
- naming:
- testing style:
- branching / commits:
## No-go areas
- <paths or systems agents must not touch without approval>
## Environments
- <name>: <purpose>, <access rules>   (no hostnames with credentials, no secrets)
## Relevant skills
- skill:<name>
EOF
}

install_skills() { # destroot scope target
    for d in "$SRC"/skills/*/; do
        [ -d "$d" ] || continue
        sn=${d%/}
        sn=${sn##*/}
        put_tree "${d%/}" "$1/$sn" "$2" "$3"
    done
}

install_agents() { # destdir scope target neutral|claude
    for f in "$SRC"/agents/*.md; do
        [ -f "$f" ] || continue
        next_tmp
        if [ "$4" = claude ]; then render_claude_agent "$f" "$NT"; else render_neutral_agent "$f" "$NT"; fi
        put_file "$1/${f##*/}" "$NT" "$2" "$3"
        rm -f "$NT"
    done
}

install_prompts() { # destdir scope target
    for f in "$SRC"/prompts/*.md; do
        [ -f "$f" ] || continue
        next_tmp
        render_prompt "$f" "$NT"
        put_file "$1/${f##*/}" "$NT" "$2" "$3"
        rm -f "$NT"
    done
}

install_core() {
    put_file "$CREW_HOME/AGENTS.md" "$SRC/AGENTS.md" global core "$SRC/AGENTS.md"
    put_file "$CREW_HOME/guardrails.md" "$TMP/guardrails.md" global core
    put_file "$CREW_HOME/VERSION" "$TMP/version" global core
    install_agents "$CREW_HOME/agents" global core neutral
    install_skills "$CREW_HOME/skills" global core
    if [ ! -f "$CFG" ]; then default_config > "$TMP/config.default"; fi
    put_once "$CFG" "$TMP/config.default"
    put_once "$CREW_HOME/learnings.md" "$TMP/learnings"
}

install_claude() {
    install_agents "$CLAUDE_DIR/agents" "$SCOPE_ID" claude claude
    install_skills "$CLAUDE_DIR/skills" "$SCOPE_ID" claude
    install_prompts "$CLAUDE_DIR/commands/crew" "$SCOPE_ID" claude
    put_block "$CLAUDE_MD" "$TMP/claude.block" "$SCOPE_ID" claude md
}

install_codex() {
    put_block "$CODEX_MD" "$TMP/codex.block" "$SCOPE_ID" codex md
    if [ "$SCOPE" = global ]; then
        install_skills "$HOME/.codex/skills" global codex
        install_prompts "$HOME/.codex/prompts" global codex
        put_block "$HOME/.codex/config.toml" "$TMP/codex.toml" global codex toml
    else
        install_agents "$PROJ/.crew/agents" "$SCOPE_ID" codex neutral
    fi
}

do_install() {
    read_version
    load_config
    validate_source
    build_contents
    DOMAINS=" global|core "
    case $TARGET in claude | all) DOMAINS="$DOMAINS$SCOPE_ID|claude " ;; esac
    case $TARGET in codex | all) DOMAINS="$DOMAINS$SCOPE_ID|codex " ;; esac
    load_manifest
    install_core
    case $TARGET in claude | all) install_claude ;; esac
    case $TARGET in codex | all) install_codex ;; esac
    if [ "$SCOPE" = project ]; then
        context_template > "$TMP/context.md"
        put_once "$PROJ/.crew/context.md" "$TMP/context.md"
        put_once "$PROJ/.crew/learnings.md" "$TMP/learnings"
    fi
    remove_selected lenient
    write_manifest
    if [ "$DRY" = 0 ]; then print_hints; fi
}

print_hints() {
    if [ "$SCOPE" = project ]; then
        echo "hint: add .claude/agents/, .claude/skills/, .claude/commands/crew/ and .crew/agents/ to the project's .gitignore" >&2
        case $TARGET in
            codex | all) echo "hint: Codex profiles, prompts and skills are global: run install.sh --global --target codex" >&2 ;;
        esac
    fi
    echo "crew $VERSION installed ($SCOPE_ID, target $TARGET)" >&2
}

do_uninstall() {
    read_version
    DOMAINS=" "
    case $TARGET in claude | all) DOMAINS="$DOMAINS$SCOPE_ID|claude " ;; esac
    case $TARGET in codex | all) DOMAINS="$DOMAINS$SCOPE_ID|codex " ;; esac
    if [ "$SCOPE" = global ] && [ "$TARGET" = all ]; then DOMAINS="${DOMAINS}global|core "; fi
    load_manifest
    if [ ! -s "$OLDMAN" ]; then
        echo "install.sh: nothing to uninstall (no manifest entries)" >&2
        return 0
    fi
    remove_selected strict
    write_manifest
}

[ -n "$TARGET" ] || TARGET=$(cfg_get DEFAULT_TARGET all)
case $TARGET in
    claude | codex | all) ;;
    *) die 2 "invalid DEFAULT_TARGET '$TARGET' in $CFG" ;;
esac

if [ "$MODE" = uninstall ]; then do_uninstall; else do_install; fi
if [ "$CONFLICTS" = 1 ]; then
    echo "install.sh: finished with conflicts (see 'conflict' lines; edited files kept)" >&2
    exit 3
fi
exit 0
