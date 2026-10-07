#!/usr/bin/env bash
# Checks Scripts/release.sh's version arithmetic: `bash Tests/scripts/release-version-test.sh`
set -euo pipefail
source "$(dirname "$0")/../../Scripts/release.sh"

failures=0
check() {
  local got
  got=$(bump_version "$1" "$2")
  if [ "$got" = "$3" ]; then
    echo "ok   bump_version '$1' $2 → $got"
  else
    echo "FAIL bump_version '$1' $2 → $got (expected $3)"
    failures=$((failures + 1))
  fi
}

check ""        patch 1.0.0   # first release, whatever the bump
check ""        major 1.0.0
check v1.0.0    patch 1.0.1
check v1.0.9    patch 1.0.10  # numeric, not lexical
check v1.4.2    minor 1.5.0
check v1.4.2    major 2.0.0
check v10.20.30 patch 10.20.31
exit "$failures"
