#!/usr/bin/env bash
# Publishes a MacNet release from HEAD of main:
#
#   make release              # patch: 1.0.0 → 1.0.1 (the first release is 1.0.0)
#   make release BUMP=minor   # 1.0.1 → 1.1.0
#   make release BUMP=major   # 1.1.0 → 2.0.0
#
# The version comes from the last vX.Y.Z tag, so a release never needs a
# version-bump commit — and this script creates no commits at all. Commit your
# work first. Release notes come from RELEASE_NOTES=/path/to/notes.md if given
# (keep it outside the repository: the tree must be clean), otherwise from the
# commit subjects since the previous release.
#
# Set DRY_RUN=1 to run the checks and print the next version without
# building, tagging or publishing anything.
set -euo pipefail

REPO="nisarganag/MacNet"

die() { echo "release: $*" >&2; exit 1; }

# bump_version <last tag or empty> <patch|minor|major> → next version.
bump_version() {
  local last=$1 bump=$2 major minor patch
  if [ -z "$last" ]; then
    echo "1.0.0"
    return
  fi
  IFS=. read -r major minor patch <<< "${last#v}"
  case "$bump" in
    major) echo "$((major + 1)).0.0" ;;
    minor) echo "$major.$((minor + 1)).0" ;;
    patch) echo "$major.$minor.$((patch + 1))" ;;
  esac
}

# tag_and_push <tag> <version>: tags HEAD and pushes main and the tag in one
# atomic push. If the push is rejected (no credentials, network), the local
# tag is deleted again — otherwise the retry would refuse to run, reporting
# HEAD as "already released" although nothing was published.
tag_and_push() {
  local tag=$1 version=$2
  git tag -a "$tag" -m "MacNet $version"
  if ! git push --atomic origin main "$tag"; then
    git tag -d "$tag" >/dev/null
    die "pushing $tag failed; removed the local tag. Fix the problem and run make release again"
  fi
}

main() {
  cd "$(dirname "$0")/.."
  BUMP="${1:-patch}"

  case "$BUMP" in
    patch|minor|major) ;;
    *) die "BUMP must be patch, minor or major (got '$BUMP')" ;;
  esac

  [ -z "$(git status --porcelain)" ] || die "the working tree has uncommitted changes; commit them first"
  branch=$(git rev-parse --abbrev-ref HEAD)
  [ "$branch" = "main" ] || die "releases are cut from main (currently on '$branch')"
  gh auth status >/dev/null 2>&1 || die "gh isn't logged in; run: gh auth login"
  git fetch --quiet --tags origin
  if git rev-parse --verify --quiet origin/main >/dev/null; then
    [ "$(git rev-list --count HEAD..origin/main)" = "0" ] || die "main is behind origin/main; pull first"
  fi

  last=$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)
  if [ -n "$last" ] && [ "$(git rev-list -n1 "$last")" = "$(git rev-parse HEAD)" ]; then
    die "HEAD is already released as $last; commit something new first"
  fi

  next=$(bump_version "$last" "$BUMP")
  tag="v$next"
  echo "release: ${last:-no previous release} → $tag"
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "release: dry run; nothing built, tagged or published"
    exit 0
  fi

  notes=$(mktemp)
  trap 'rm -f "$notes"' EXIT
  if [ -n "${RELEASE_NOTES:-}" ]; then
    cp "$RELEASE_NOTES" "$notes"
  else
    {
      echo "## What's changed"
      echo
      if [ -n "$last" ]; then
        git log --no-merges --pretty='- %s' "$last..HEAD"
      else
        git log --no-merges --pretty='- %s'
      fi
    } > "$notes"
  fi

  make test
  # One make invocation, so the bundle is built once and shared by all three.
  make VERSION="$next" dmg zip install

  tag_and_push "$tag" "$next"
  gh release create "$tag" "dist/MacNet-$next.dmg" "dist/MacNet-$next.zip" \
    --repo "$REPO" --title "MacNet $next" --notes-file "$notes" \
    || die "$tag is pushed but creating the GitHub release failed; rerun: gh release create $tag dist/MacNet-$next.dmg dist/MacNet-$next.zip --repo $REPO"
  echo "release: published https://github.com/$REPO/releases/tag/$tag"
}

# Sourcing the file (as the tests do) defines bump_version without releasing.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
