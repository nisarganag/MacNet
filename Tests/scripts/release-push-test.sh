#!/usr/bin/env bash
# A rejected push must not leave the release tag behind — otherwise the retry
# is refused as "already released" although nothing was published.
# Run: `bash Tests/scripts/release-push-test.sh`
set -uo pipefail
source "$(dirname "$0")/../../Scripts/release.sh"
set +e   # the script enables errexit; these checks need to see failures

log=$(mktemp)
trap 'rm -f "$log"' EXIT
push_result=1
# Stands in for git: records every call, and fails pushes when asked to.
git() {
  echo "$*" >> "$log"
  [ "$1" = push ] && return "$push_result"
  return 0
}

failures=0
expect() {
  if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; failures=$((failures + 1)); fi
}

( tag_and_push v9.9.9 9.9.9 ) 2>/dev/null
status=$?
expect "rejected push exits non-zero" '[ "$status" -ne 0 ]'
expect "main and the tag go up in one atomic push" 'grep -qx "push --atomic origin main v9.9.9" "$log"'
expect "rejected push deletes the local tag" 'grep -qx "tag -d v9.9.9" "$log"'

: > "$log"
push_result=0
( tag_and_push v9.9.9 9.9.9 ) 2>/dev/null
status=$?
expect "accepted push succeeds" '[ "$status" -eq 0 ]'
expect "accepted push keeps the tag" '! grep -q "tag -d" "$log"'
exit "$failures"
