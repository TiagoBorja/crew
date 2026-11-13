#!/bin/sh
# check-terms.sh - forbidden-term and secret scanner.
#
# Scans file contents, file paths, commit messages and commit identities for
# terms from a local list and for a few generic secret patterns. Hits are
# printed as "path:line: term-id N"; the term itself is never echoed.
#
# Usage:
#   check-terms.sh                 same as --all --history
#   check-terms.sh --staged        staged contents and paths (pre-commit)
#   check-terms.sh --message FILE  one commit message (commit-msg)
#   check-terms.sh --all           all tracked contents and paths
#   check-terms.sh --history       messages and identities of every commit
#
# Terms: plain text, one per line, '#' comments allowed, read from the file
# named by CREW_DENYLIST_FILE, or ~/.crew/denylist when that is unset. Keep the
# list outside the repository. Without a list only the secret patterns run.
#
# Exit codes: 0 clean, 1 hits found, 2 usage or environment error.
set -eu

usage() {
    cat >&2 <<'USAGE_EOF'
usage: check-terms.sh [--staged] [--all] [--history] [--message FILE]
With no mode, runs --all --history.
USAGE_EOF
    exit 2
}

scan_program() {
    cat <<'AWK_EOF'
function isal(c) { return (c ~ /^[a-z0-9]$/) }

# whole-token occurrence: neighbours must not be [a-z0-9]
function has_token(line, t,    off, pos, p, tl, b, a) {
    tl = length(t)
    off = 0
    while ((pos = index(substr(line, off + 1), t)) > 0) {
        p = off + pos
        b = (p == 1) ? "" : substr(line, p - 1, 1)
        a = substr(line, p + tl, 1)
        if (!isal(b) && !isal(a)) return 1
        off = p
    }
    return 0
}

# does s contain a match of re at least minlen long?
function runs(s, re, minlen) {
    while (match(s, re)) {
        if (RLENGTH >= minlen) return 1
        s = substr(s, RSTART + 1)
    }
    return 0
}

BEGIN {
    nt = 0
    while ((getline tl < tf) > 0) {
        i = index(tl, "\t")
        if (i == 0) continue
        nt++
        ids[nt] = substr(tl, 1, i - 1)
        terms[nt] = substr(tl, i + 1)
        sub_only[nt] = (terms[nt] ~ /[@.]/)
    }
    close(tf)
    pk = "-----" "BEGIN [A-Z ]*PRIVATE KEY" "-----"
}

{
    lineno = NR + off
    low = tolower($0)
    for (i = 1; i <= nt; i++) {
        if (sub_only[i]) hit = (index(low, terms[i]) > 0)
        else hit = has_token(low, terms[i])
        if (hit) printf "%s:%d: term-id %s\n", name, lineno, ids[i]
    }
    if ($0 ~ pk) printf "%s:%d: pattern-id 1\n", name, lineno
    if (runs($0, "AKIA[0-9A-Z]+", 20)) printf "%s:%d: pattern-id 2\n", name, lineno
    if (runs($0, "ghp_[A-Za-z0-9]+", 40)) printf "%s:%d: pattern-id 3\n", name, lineno
    if (runs($0, "xox[baprs]-", 5)) printf "%s:%d: pattern-id 4\n", name, lineno
}
AWK_EOF
}

# ---- argument parsing -------------------------------------------------------

want_staged=0
want_all=0
want_history=0
msg_file=
nmodes=0

while [ $# -gt 0 ]; do
    case $1 in
        --staged) want_staged=1; nmodes=$((nmodes + 1)) ;;
        --all) want_all=1; nmodes=$((nmodes + 1)) ;;
        --history) want_history=1; nmodes=$((nmodes + 1)) ;;
        --message)
            [ $# -ge 2 ] || usage
            msg_file=$2
            nmodes=$((nmodes + 1))
            shift
            ;;
        *) usage ;;
    esac
    shift
done

if [ "$nmodes" -eq 0 ]; then
    want_all=1
    want_history=1
fi

if [ -n "$msg_file" ] && [ ! -f "$msg_file" ]; then
    echo "check-terms: message file not found: $msg_file" >&2
    exit 2
fi

if [ "$want_staged" = 1 ] || [ "$want_all" = 1 ] || [ "$want_history" = 1 ]; then
    if ! root=$(git rev-parse --show-toplevel 2>/dev/null); then
        echo "check-terms: not inside a git repository" >&2
        exit 2
    fi
    cd "$root"
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/crewterms.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
trap 'exit 2' INT TERM HUP

TERMS=$TMP/terms
HITS=$TMP/hits
PROG=$TMP/scan.awk
: > "$HITS"
scan_program > "$PROG"

# ---- term list --------------------------------------------------------------

list=${CREW_DENYLIST_FILE:-$HOME/.crew/denylist}
if [ -n "${CREW_DENYLIST_FILE:-}" ] && [ ! -r "$list" ]; then
    echo "check-terms: cannot read CREW_DENYLIST_FILE" >&2
    exit 2
fi

if [ -r "$list" ]; then
    tr -d '\r' < "$list" | awk '
        /^[ \t]*#/ { next }
        { t = tolower($0); gsub(/^[ \t]+|[ \t]+$/, "", t)
          if (t != "") printf "%d\t%s\n", ++n, t }' > "$TERMS"
else
    : > "$TERMS"
fi

if [ ! -s "$TERMS" ]; then
    echo "check-terms: no term list; checking secret patterns only" >&2
fi

# ---- scanning ---------------------------------------------------------------

# scan NAME LINE_OFFSET  (text on stdin; hits appended to $HITS)
scan() {
    LC_ALL=C awk -v tf="$TERMS" -v name="$1" -v off="$2" -f "$PROG" >> "$HITS"
}

# scan_paths LISTFILE : every listed path is scanned by name and by blob content
scan_paths() {
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        printf '%s\n' "$p" | scan "$p" -1
        git show ":$p" > "$TMP/blob" 2>/dev/null || continue
        grep -qI '' "$TMP/blob" 2>/dev/null || continue
        scan "$p" 0 < "$TMP/blob"
    done < "$1"
}

if [ "$want_staged" = 1 ]; then
    git -c core.quotepath=off diff --cached --name-only --diff-filter=ACMR > "$TMP/list"
    scan_paths "$TMP/list"
fi

if [ "$want_all" = 1 ]; then
    git -c core.quotepath=off ls-files > "$TMP/list"
    scan_paths "$TMP/list"
fi

if [ -n "$msg_file" ]; then
    msg_name=$msg_file
    scan "$msg_name" 0 < "$msg_file"
fi

if [ "$want_history" = 1 ]; then
    git log --all --format='%H' > "$TMP/commits" 2>/dev/null || : > "$TMP/commits"
    while IFS= read -r h; do
        [ -n "$h" ] || continue
        s=$(printf '%s' "$h" | cut -c1-7)
        git log -1 --format='%B' "$h" | scan "$s:message" 0
        git log -1 --format='%an' "$h" | scan "$s:author-name" 0
        git log -1 --format='%ae' "$h" | scan "$s:author-email" 0
        git log -1 --format='%cn' "$h" | scan "$s:committer-name" 0
        git log -1 --format='%ce' "$h" | scan "$s:committer-email" 0
    done < "$TMP/commits"
fi

if [ -s "$HITS" ]; then
    cat "$HITS"
    n=$(wc -l < "$HITS" | tr -d ' ')
    echo "check-terms: $n hit(s)" >&2
    exit 1
fi
exit 0
