#!/bin/sh
# Tests for scripts/check-terms.sh using scratch repositories only.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
real=$repo/scripts/check-terms.sh

W=$(mktemp -d "${TMPDIR:-/tmp}/crew-t-ct.XXXXXX")
trap 'rm -rf "$W"' EXIT
export HOME=$W/home
mkdir -p "$HOME"
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1

n=0
failed=0
ok() { n=$((n + 1)); echo "ok $n - $1"; }
nok() { n=$((n + 1)); failed=1; echo "not ok $n - $1"; }

# expect_rc DESC WANTED_RC CMD...
expect_rc() {
    desc=$1 want=$2
    shift 2
    set +e
    "$@" > "$W/out" 2> "$W/err"
    rc=$?
    set -e
    if [ "$rc" = "$want" ]; then ok "$desc"; else nok "$desc (rc=$rc want=$want)"; fi
}

copy=$real
printf '# test list\nacmesecret\nmy.host@\n' > "$W/list"
export CREW_DENYLIST_FILE="$W/list"

# scratch repo
R=$W/repo
mkdir -p "$R"
cd "$R"
git init -q .
git config user.name "Test User"
git config user.email "test@example.com"

# --- usage ---
expect_rc "unknown flag is a usage error" 2 sh "$copy" --bogus
expect_rc "--message needs a file" 2 sh "$copy" --message
expect_rc "--message with missing file" 2 sh "$copy" --message "$W/nope"
expect_rc "--encode is gone" 2 sh "$copy" --encode

# --- term list sources ---
echo "hello acmesecret" > a.txt
git add a.txt
expect_rc "no list: only secret patterns run" 0 env -u CREW_DENYLIST_FILE sh "$copy" --staged
grep -q 'no term list' "$W/err" && ok "no list is reported" || nok "no list is reported"
mkdir -p "$HOME/.crew"
cp "$W/list" "$HOME/.crew/denylist"
expect_rc "default list in ~/.crew/denylist is used" 1 env -u CREW_DENYLIST_FILE sh "$copy" --staged
rm -f "$HOME/.crew/denylist"
echo "hello" > a.txt
git add a.txt

# --- clean content ---
expect_rc "clean staged content passes" 0 sh "$copy" --staged
git commit -q -m "first commit"
expect_rc "clean --all passes" 0 sh "$copy" --all
expect_rc "clean --history passes" 0 sh "$copy" --history
expect_rc "default mode passes on clean repo" 0 sh "$copy"

# --- token matching ---
printf 'the AcmeSecret is here\n' > b.txt
git add b.txt
expect_rc "staged hit, case-insensitive" 1 sh "$copy" --staged
if grep -q '^b.txt:1: term-id 1$' "$W/out" && ! grep -qi acmesecret "$W/out" "$W/err"; then
    ok "hit line format, term not echoed"
else
    nok "hit line format, term not echoed"
fi
printf 'xacmesecretx and acmesecrets\n' > b.txt
git add b.txt
expect_rc "term inside a longer word is not a hit" 0 sh "$copy" --staged
printf 'acmesecret-v2\n' > b.txt
git add b.txt
expect_rc "hyphen is a token boundary" 1 sh "$copy" --staged
printf 'mail me: user@my.host@example.org\n' > b.txt
git add b.txt
expect_rc "terms with @ match as substrings" 1 sh "$copy" --staged
git rm -q -f --cached b.txt
rm -f b.txt

# --- path names ---
mkdir sub
echo ok > sub/acmesecret.txt
git add sub
expect_rc "staged path name hit" 1 sh "$copy" --staged
grep -q '^sub/acmesecret.txt:0: term-id 1$' "$W/out" && ok "path hit reported at line 0" || nok "path hit reported at line 0"
git rm -q -f --cached sub/acmesecret.txt
rm -rf sub

# --- unreadable list ---
expect_rc "unreadable list file is an error" 2 env CREW_DENYLIST_FILE="$W/missing" sh "$copy" --staged

# --- built-in patterns (assembled at run time so this file stays clean) ---
k1=AKIA; k2=ABCDEFGHIJKLMNOP
printf 'key=%s%s\n' "$k1" "$k2" > e.txt
git add e.txt
expect_rc "access-key pattern" 1 sh "$copy" --staged
printf 'key=%sABC\n' "$k1" > e.txt
git add e.txt
expect_rc "short AKIA text is not a hit" 0 sh "$copy" --staged
g1=ghp_; g2=0123456789abcdefghijABCDEFGHIJ012345
printf 'tok=%s%s\n' "$g1" "$g2" > e.txt
git add e.txt
expect_rc "token pattern" 1 sh "$copy" --staged
printf 'tok=%s%s\n' "$(printf xox)b" "-123" > e.txt
git add e.txt
expect_rc "chat token pattern" 1 sh "$copy" --staged
d=$(printf -- '-----')
printf '%sBEGIN RSA PRIVATE KEY%s\n' "$d" "$d" > e.txt
git add e.txt
expect_rc "private key header pattern" 1 sh "$copy" --staged
git rm -q -f --cached e.txt
rm -f e.txt

# --- binary files are skipped, paths still checked ---
printf 'acmesecret\000binary\n' > f.bin
git add f.bin
expect_rc "binary content is skipped" 0 sh "$copy" --staged
git rm -q -f --cached f.bin
rm -f f.bin

# --- message mode ---
printf 'Add feature\n\nbody text\n' > "$W/m1"
printf 'Add feature for ACMESECRET\n' > "$W/m2"
expect_rc "clean message passes" 0 sh "$copy" --message "$W/m1"
expect_rc "message hit" 1 sh "$copy" --message "$W/m2"
grep -q "^$W/m2:1: term-id 1\$" "$W/out" && ok "message hit line format" || nok "message hit line format"

# --- history mode: message, author and committer ---
echo more >> a.txt
git add a.txt
git commit -q -m "mention acmesecret here"
expect_rc "history catches commit message" 1 sh "$copy" --history
grep -q ':message:1: term-id 1$' "$W/out" && ok "history message label" || nok "history message label"
expect_rc "--all alone ignores history" 0 sh "$copy" --all
git commit -q --amend -m "neutral message"
expect_rc "history clean after amend" 0 sh "$copy" --history
echo more >> a.txt
git add a.txt
git -c user.email=someone@acmesecret.example.com commit -q -m "identity test"
expect_rc "history catches author email" 1 sh "$copy" --history
grep -q ':author-email:1: term-id 1$' "$W/out" && ok "history author-email label" || nok "history author-email label"
git reset -q --hard HEAD~1
expect_rc "history clean after reset" 0 sh "$copy" --history

# --- not a repository ---
mkdir "$W/plain"
cd "$W/plain"
expect_rc "git modes outside a repo are errors" 2 sh "$copy" --all
expect_rc "--message works outside a repo" 0 sh "$copy" --message "$W/m1"

# --- hooks (run against the scratch repo) ---
cd "$R"
cp -r "$repo/.githooks" "$R/.githooks"
mkdir -p scripts
cp "$copy" scripts/check-terms.sh
git config core.hooksPath .githooks
echo "plain" > h.txt
git add h.txt scripts .githooks
if git commit -q -m "add hooks and file" > "$W/out" 2>&1; then ok "hooks accept a clean commit"; else nok "hooks accept a clean commit"; fi
echo "acmesecret" > h2.txt
git add h2.txt
if git commit -q -m "should fail" > "$W/out" 2>&1; then nok "pre-commit blocks a hit"; else ok "pre-commit blocks a hit"; fi
git rm -q -f --cached h2.txt
rm -f h2.txt
echo "more" >> h.txt
git add h.txt
if git commit -q -m "mentions acmesecret" > "$W/out" 2>&1; then nok "commit-msg blocks a hit"; else ok "commit-msg blocks a hit"; fi

echo "1..$n"
exit "$failed"
