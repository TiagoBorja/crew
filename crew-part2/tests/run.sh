#!/bin/sh
# Runs every tests/test_*.sh (and tests/shellcheck.sh), one shell per file.
# Prints each case's ok/not ok line and exits non-zero if anything failed.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
status=0
files=0
failed_files=""

for t in "$here"/test_*.sh "$here"/shellcheck.sh; do
    [ -f "$t" ] || continue
    files=$((files + 1))
    name=${t##*/}
    echo "# $name"
    if sh "$t"; then
        :
    else
        status=1
        failed_files="$failed_files $name"
    fi
done

if [ "$status" -eq 0 ]; then
    echo "# all $files test file(s) passed"
else
    echo "# FAILED:$failed_files"
fi
exit "$status"
