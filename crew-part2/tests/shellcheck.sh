#!/bin/sh
# Runs shellcheck -s sh on every script, if shellcheck is installed.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "ok 1 - shellcheck # SKIP shellcheck not installed"
    echo "1..1"
    exit 0
fi

cd "$repo"
list=$(mktemp "${TMPDIR:-/tmp}/crew-sc.XXXXXX")
trap 'rm -f "$list"' EXIT
for f in scripts/*.sh tests/*.sh install.sh bin/crew .githooks/*; do
    if [ -f "$f" ]; then echo "$f" >> "$list"; fi
done

n=0
failed=0
while IFS= read -r f; do
    n=$((n + 1))
    if shellcheck -s sh "$f"; then
        echo "ok $n - shellcheck $f"
    else
        failed=1
        echo "not ok $n - shellcheck $f"
    fi
done < "$list"
echo "1..$n"
exit "$failed"
