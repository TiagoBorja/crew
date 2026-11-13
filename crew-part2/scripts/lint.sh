#!/bin/sh
# lint.sh - source linter for crew content.
#
# Usage: lint.sh [ROOT]     (default ROOT: the repository containing this script)
#
# Prints "file:line: rule: message" and exits 1 if any L-rule fails.
# W-rules are warnings and do not change the exit code.
# Missing optional directories (agents/, skills/, ...) are simply skipped.
#
# Rules: L01 frontmatter, L02 fields, L03 names, L04 descriptions,
# L05 enums, L06 agent sections, L07 references, L08 AGENTS.md tables,
# L09 sizes, L10 guardrail names, L11 text hygiene, L12 script headers,
# L13 gate output, W01 mcp without tools for a read-only agent.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
ROOT=${1:-$here/..}
if [ ! -d "$ROOT" ]; then
    echo "lint: not a directory: $ROOT" >&2
    exit 2
fi
ROOT=$(cd "$ROOT" && pwd)
cd "$ROOT"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/crewlint.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
trap 'exit 2' INT TERM HUP
OUT=$TMP/out
: > "$OUT"

TAB=$(printf '\t')
CR=$(printf '\r')

emit() { printf '%s:%s: %s: %s\n' "$1" "$2" "$3" "$4" >> "$OUT"; }

doc_program() {
    cat <<'AWK_EOF'
function err(n, rule, msg) { printf "%s:%d: %s: %s\n", file, n, rule, msg }
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function inset(set, w) { return index(set, " " w " ") > 0 }

BEGIN {
    if (kind == "agent") { req = "name description tier capabilities gate reads_only"; opt = "" }
    else if (kind == "skill") { req = "name description"; opt = "tags" }
    else { req = "name description"; opt = "agent argument_hint" }
    nreq = split(req, reqa, " ")
    allowed = " " req " " opt " "
    nexp = split("Role|When to use|Inputs|Process|Output|Done when", expsec, "|")
    expset = "|Role|When to use|Inputs|Process|Output|Done when|"
    st = 0; infence = 0; seenfirst = 0; nk = 0; ns = 0; nh1 = 0; cursec = 0
}

# one frontmatter line
function fmline(l, n,    c, k, v) {
    if (l ~ /^[ \t]/) { err(n, "L01", "indented line: multi-line values are not allowed"); return }
    if (l ~ /^-( |$)/) { err(n, "L01", "block-style list item: use a flow list [a, b]"); return }
    if (l !~ /^[a-z][a-z0-9_]*:/) { err(n, "L01", "expected 'key: value'"); return }
    c = index(l, ":")
    k = substr(l, 1, c - 1)
    v = trim(substr(l, c + 1))
    if (k in seen) { err(n, "L01", "duplicate key '" k "'"); return }
    seen[k] = n
    keys[++nk] = k
    if (v == "") { err(n, "L01", "empty value for '" k "' (block-style or multi-line values are not allowed)"); return }
    if (v ~ /^[|>]/) { err(n, "L01", "block scalars are not allowed for '" k "'"); return }
    if (v ~ /^\[/) {
        if (v !~ /\]$/) { err(n, "L01", "unterminated flow list for '" k "'"); return }
        islist[k] = 1
    }
    val[k] = v
}

function endfm(    i, k, nm, d, inner, m, c, capn) {
    fmend = NR
    for (i = 1; i <= nk; i++) {
        k = keys[i]
        if (!inset(allowed, k)) err(seen[k], "L02", "unknown field '" k "'")
    }
    for (i = 1; i <= nreq; i++)
        if (!(reqa[i] in seen)) err(fmend, "L02", "missing field '" reqa[i] "'")

    if ("name" in val) {
        nm = val["name"]
        if (nm !~ /^[a-z0-9]+(-[a-z0-9]+)*$/) err(seen["name"], "L03", "name '" nm "' is not kebab-case")
        else if (nm != expect) err(seen["name"], "L03", "name '" nm "' does not match '" expect "'")
    }
    if ("description" in val) {
        d = val["description"]
        if (length(d) > 300) err(seen["description"], "L04", "description longer than 300 characters")
        if (kind != "prompt" && index(d, "Use when") == 0 && index(d, "Use for") == 0)
            err(seen["description"], "L04", "description must say when to use it ('Use when' or 'Use for')")
    }
    if (kind == "skill" && ("tags" in val) && !("tags" in islist))
        err(seen["tags"], "L05", "tags must be a flow list")
    if (kind == "prompt" && ("agent" in val) && !inset(agents, val["agent"]))
        err(seen["agent"], "L07", "unknown agent '" val["agent"] "'")
    if (kind != "agent") return

    if (("tier" in val) && val["tier"] != "fast" && val["tier"] != "standard" && val["tier"] != "deep")
        err(seen["tier"], "L05", "tier must be fast, standard or deep")
    if (("gate" in val) && val["gate"] != "true" && val["gate"] != "false")
        err(seen["gate"], "L05", "gate must be true or false")
    if (("reads_only" in val) && val["reads_only"] != "true" && val["reads_only"] != "false")
        err(seen["reads_only"], "L05", "reads_only must be true or false")
    gate = val["gate"]
    if ("capabilities" in val) {
        if (!("capabilities" in islist)) err(seen["capabilities"], "L05", "capabilities must be a flow list")
        else {
            inner = trim(substr(val["capabilities"], 2, length(val["capabilities"]) - 2))
            if (inner == "") err(seen["capabilities"], "L05", "capabilities must not be empty")
            else {
                capn = split(inner, ca, ",")
                for (i = 1; i <= capn; i++) {
                    c = trim(ca[i])
                    if (!inset(" read search edit shell web mcp ", c))
                        err(seen["capabilities"], "L05", "unknown capability '" c "'")
                    else if (c in capseen)
                        err(seen["capabilities"], "L05", "duplicate capability '" c "'")
                    capseen[c] = 1
                }
                if (!("read" in capseen)) err(seen["capabilities"], "L05", "capabilities must include read")
                if (val["reads_only"] == "true" && ("edit" in capseen))
                    err(seen["capabilities"], "L05", "reads_only: true forbids the edit capability")
                if (val["reads_only"] == "true" && ("mcp" in capseen))
                    err(seen["capabilities"], "W01", "mcp is unavailable to a reads_only agent in Claude")
            }
        }
    }
}

# list "skill:<name>" and "`agent:<name>`" references
function refs(l, n,    s, nm, pre) {
    s = l
    while (match(s, /skill:[a-z0-9][a-z0-9-]*/)) {
        pre = (RSTART > 1) ? substr(s, RSTART - 1, 1) : ""
        nm = substr(s, RSTART + 6, RLENGTH - 6)
        s = substr(s, RSTART + RLENGTH)
        if (pre ~ /[A-Za-z0-9]/) continue
        sub(/-+$/, "", nm)
        if (!inset(skills, nm)) err(n, "L07", "unknown skill '" nm "'")
    }
    s = l
    while (match(s, /`agent:[a-z0-9][a-z0-9-]*`/)) {
        nm = substr(s, RSTART + 7, RLENGTH - 8)
        s = substr(s, RSTART + RLENGTH)
        if (!inset(agents, nm)) err(n, "L07", "unknown agent '" nm "'")
    }
}

function body(l, n) {
    refs(l, n)
    if (kind != "agent") return
    if (!infence && l ~ /^# /) {
        nh1++
        if (nh1 == 1) { h1text = trim(substr(l, 3)); h1line = n }
        else err(n, "L06", "more than one H1")
        seenfirst = 1
        return
    }
    if (!infence && l ~ /^## /) {
        ns++
        secname[ns] = trim(substr(l, 4)); secline[ns] = n
        cursec = ns
        seenfirst = 1
        return
    }
    if (l !~ /^[ \t]*$/) {
        if (!seenfirst) { err(n, "L06", "first content line must be '# " expect "'"); seenfirst = 1 }
        if (cursec > 0) {
            nonblank[cursec]++
            if (secname[cursec] == "Output") outtxt = outtxt l "\n"
        }
    }
    if (l ~ /^(```|~~~)/) infence = !infence
}

function endbody(    i, j, s, p, last, bad) {
    if (kind != "agent") return
    if (nh1 == 0) err(NR, "L06", "missing '# " expect "' heading")
    else if (h1text != expect) err(h1line, "L06", "H1 must be '# " expect "'")
    bad = 0
    for (i = 1; i <= ns; i++) {
        s = secname[i]
        if (index(expset, "|" s "|") == 0) { err(secline[i], "L06", "unexpected section '## " s "'"); bad = 1 }
        else {
            cnt[s]++
            if (cnt[s] > 1) { err(secline[i], "L06", "duplicate section '## " s "'"); bad = 1 }
        }
    }
    for (j = 1; j <= nexp; j++)
        if (!(expsec[j] in cnt)) { err(NR, "L06", "missing section '## " expsec[j] "'"); bad = 1 }
    if (!bad) {
        for (i = 1; i <= ns; i++)
            if (secname[i] != expsec[i]) { err(secline[i], "L06", "section '## " secname[i] "' is out of order (expected '## " expsec[i] "')"); break }
    }
    for (i = 1; i <= ns; i++)
        if (nonblank[i] == 0) err(secline[i], "L06", "section '## " secname[i] "' is empty")
    if (gate == "true" && index(outtxt, "VERDICT:") == 0) {
        s = 1
        for (i = 1; i <= ns; i++) if (secname[i] == "Output") s = secline[i]
        err(s, "L13", "gate agent must mention 'VERDICT:' in its ## Output section")
    }
}

{
    if (NR == 1) {
        if ($0 != "---") { err(1, "L01", "frontmatter missing: first line must be ---"); st = 9; next }
        st = 1
        next
    }
    if (st == 9) next
    if (st == 1) {
        if ($0 == "---") { st = 2; endfm(); next }
        fmline($0, NR)
        next
    }
    body($0, NR)
}

END {
    if (st == 0) err(1, "L01", "empty file")
    if (st == 1) err(NR, "L01", "frontmatter is not closed by a --- line")
    if (st == 2) endbody()
}
AWK_EOF
}

table_program() {
    cat <<'AWK_EOF'
/^## / { insec = ($0 == "## " sec); if (insec) { found = 1; row = 0 }; next }
insec && /^\|/ {
    row++
    if (row == 1) next
    if ($0 ~ /^\|[ :|-]*$/) next
    n = split($0, c, "|")
    nm = c[2]
    gsub(/^[ \t`]+|[ \t`]+$/, "", nm)
    print NR, nm
}
END { if (!found) print 0, "!missing" }
AWK_EOF
}

doc_program > "$TMP/doc.awk"
table_program > "$TMP/table.awk"

# ---- collect names ----------------------------------------------------------

agent_names=" "
for f in agents/*.md; do
    [ -f "$f" ] || continue
    b=${f##*/}
    agent_names="$agent_names${b%.md} "
done
skill_names=" "
for d in skills/*/; do
    [ -d "$d" ] || continue
    b=${d%/}
    b=${b##*/}
    skill_names="$skill_names$b "
done

lint_doc() { # kind file expected-name
    awk -v kind="$1" -v file="$2" -v expect="$3" \
        -v agents="$agent_names" -v skills="$skill_names" \
        -f "$TMP/doc.awk" "$2" >> "$OUT"
}

body_bytes() {
    awk 'NR == 1 && $0 == "---" { fm = 1; next }
         fm && $0 == "---" { fm = 0; next }
         !fm { print }' "$1" | wc -c | tr -d ' '
}

# ---- agents, skills, prompts: L01-L07, L09, L13 -----------------------------

for f in agents/*.md; do
    [ -f "$f" ] || continue
    b=${f##*/}
    lint_doc agent "$f" "${b%.md}"
    sz=$(body_bytes "$f")
    [ "$sz" -le 12288 ] || emit "$f" 1 L09 "agent body is $sz bytes (limit 12288)"
done

for d in skills/*/; do
    [ -d "$d" ] || continue
    b=${d%/}
    b=${b##*/}
    f=${d}SKILL.md
    if [ ! -f "$f" ]; then
        emit "${d%/}" 1 L01 "missing SKILL.md"
        continue
    fi
    lint_doc skill "$f" "$b"
    sz=$(body_bytes "$f")
    [ "$sz" -le 20480 ] || emit "$f" 1 L09 "skill body is $sz bytes (limit 20480)"
done

for f in prompts/*.md; do
    [ -f "$f" ] || continue
    b=${f##*/}
    lint_doc prompt "$f" "${b%.md}"
done

# ---- AGENTS.md: L08, L09 ----------------------------------------------------

check_table() { # section actual-names label
    awk -v sec="$1" -f "$TMP/table.awk" AGENTS.md > "$TMP/rows"
    listed=" "
    while read -r ln nm; do
        if [ "$nm" = "!missing" ]; then
            emit AGENTS.md 1 L08 "missing '## $1' section"
            return 0
        fi
        case $listed in
            *" $nm "*) emit AGENTS.md "$ln" L08 "$3 '$nm' listed twice" ;;
        esac
        listed="$listed$nm "
        case $2 in
            *" $nm "*) ;;
            *) emit AGENTS.md "$ln" L08 "$3 '$nm' is listed but has no source" ;;
        esac
    done < "$TMP/rows"
    for nm in $2; do
        case $listed in
            *" $nm "*) ;;
            *) emit AGENTS.md 1 L08 "$3 '$nm' exists but is missing from the '## $1' table" ;;
        esac
    done
}

if [ -f AGENTS.md ]; then
    sz=$(wc -c < AGENTS.md | tr -d ' ')
    [ "$sz" -lt 16384 ] || emit AGENTS.md 1 L09 "AGENTS.md is $sz bytes (limit < 16384)"
    check_table Roster "$agent_names" agent
    check_table Skills "$skill_names" skill
fi

# ---- guardrails: L10 --------------------------------------------------------

seen_nn=" "
for f in guardrails/*; do
    [ -e "$f" ] || continue
    b=${f##*/}
    if printf '%s\n' "$b" | grep -Eq '^[0-9]{2}-[a-z0-9-]+\.md$'; then
        nn=${b%%-*}
        case $seen_nn in
            *" $nn "*) emit "$f" 1 L10 "duplicate guardrail number $nn" ;;
        esac
        seen_nn="$seen_nn$nn "
    else
        emit "$f" 1 L10 "guardrail file name must match NN-topic.md"
    fi
done

# ---- text hygiene: L11 ------------------------------------------------------

: > "$TMP/mdlist"
for f in ./*.md; do
    if [ -f "$f" ]; then printf '%s\n' "${f#./}" >> "$TMP/mdlist"; fi
done
find guardrails agents prompts skills -type f -name '*.md' 2>/dev/null >> "$TMP/mdlist" || true

: > "$TMP/shlist"
for f in scripts/*.sh tests/*.sh install.sh bin/crew .githooks/*; do
    if [ -f "$f" ]; then printf '%s\n' "$f" >> "$TMP/shlist"; fi
done

hygiene() { # file is_markdown
    f=$1
    [ -s "$f" ] || return 0
    if grep -q "$CR" "$f"; then
        emit "$f" "$(grep -n "$CR" "$f" | head -n 1 | cut -d: -f1)" L11 "CR found: LF line endings required"
    fi
    if [ -n "$(tail -c 1 "$f")" ]; then
        emit "$f" "$(wc -l < "$f" | tr -d ' ')" L11 "missing trailing newline"
    fi
    if command -v iconv >/dev/null 2>&1; then
        iconv -f UTF-8 -t UTF-8 "$f" >/dev/null 2>&1 || emit "$f" 1 L11 "not valid UTF-8"
    fi
    if [ "$2" = 1 ] && grep -q "$TAB" "$f"; then
        emit "$f" "$(grep -n "$TAB" "$f" | head -n 1 | cut -d: -f1)" L11 "tab character in markdown"
    fi
}

while IFS= read -r f; do
    if [ -n "$f" ]; then hygiene "$f" 1; fi
done < "$TMP/mdlist"

# ---- scripts: L11 (no tab rule), L12 ----------------------------------------

while IFS= read -r f; do
    [ -n "$f" ] || continue
    hygiene "$f" 0
    first=$(head -n 1 "$f")
    [ "$first" = "#!/bin/sh" ] || emit "$f" 1 L12 "first line must be #!/bin/sh"
    grep -q 'set -eu' "$f" || emit "$f" 1 L12 "script must contain 'set -eu'"
done < "$TMP/shlist"

# ---- report -----------------------------------------------------------------

errors=$(grep -c ': L[0-9][0-9]: ' "$OUT" || true)
warnings=$(grep -c ': W[0-9][0-9]: ' "$OUT" || true)
[ ! -s "$OUT" ] || cat "$OUT"
echo "lint: $errors error(s), $warnings warning(s)" >&2
[ "$errors" -eq 0 ] || exit 1
exit 0
