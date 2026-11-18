#!/usr/bin/env bash
# Whether a version may be published, before the release workflow uploads it:
# - it looks like a version (0.5.6, 1.0, 0.1-alpha);
# - its commit is on main (a release is a merge into main);
# - the changelog at that commit starts with the version's entry ("## <version>");
# - the TOC still leaves its version to the packager (@project-version@).
# The commit is the tag of that name, or the one given, for a version not
# tagged yet. Reads the files at the commit, not in the working tree. Prints
# every problem and exits with 1 if there is any.
#
#   bash .github/scripts/verify-release.sh 0.5.5
#   bash .github/scripts/verify-release.sh 0.5.6 HEAD
set -u

version="${1:-}"
if [ -z "$version" ]; then
	echo "usage: verify-release.sh <version> [<commit>]" >&2
	exit 2
fi
ref="${2:-$version}"

problems=0
fail() {
	echo "verify-release: $*" >&2
	problems=$((problems + 1))
}

if ! printf '%s\n' "$version" | grep -Eq '^[0-9]+(\.[0-9]+)+(-[0-9A-Za-z.]+)?$'; then
	fail "\"${version}\" does not look like a version"
fi

if ! commit=$(git rev-parse --verify -q "${ref}^{commit}"); then
	echo "verify-release: no such tag or commit: $ref" >&2
	exit 1
fi

if ! git rev-parse --verify -q origin/main >/dev/null; then
	git fetch -q --no-tags origin main:refs/remotes/origin/main || fail "cannot fetch origin/main"
fi
if ! git merge-base --is-ancestor "$commit" origin/main 2>/dev/null; then
	fail "$ref ($commit) is not on main"
fi

heading=$(git show "${commit}:CHANGELOG.md" 2>/dev/null | tr -d '\r' | sed -n 's/^## //p' | head -n 1)
if [ "$heading" != "$version" ]; then
	fail "the changelog's first entry is \"${heading}\", not \"${version}\""
fi

if ! git show "${commit}:Lootoman.toc" 2>/dev/null | tr -d '\r' | grep -q '^## Version: @project-version@$'; then
	fail "the TOC's version is not left to the packager (## Version: @project-version@)"
fi

if [ "$problems" -gt 0 ]; then
	exit 1
fi
echo "verify-release: $version ($commit) is ready to publish"
