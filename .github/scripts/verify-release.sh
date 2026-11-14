#!/usr/bin/env bash
# Whether a tag may be published, before the release workflow uploads it:
# - its commit is on main (a release is a merge of develop into main);
# - the changelog at the tag starts with that tag's entry ("## <tag>");
# - the TOC still leaves its version to the packager (@project-version@).
# Reads the files at the tag, not in the working tree. Prints every problem
# and exits with 1 if there is any.
#
#   bash .github/scripts/verify-release.sh 0.5.5
set -u

tag="${1:-}"
if [ -z "$tag" ]; then
	echo "usage: verify-release.sh <tag>" >&2
	exit 2
fi

problems=0
fail() {
	echo "verify-release: $*" >&2
	problems=$((problems + 1))
}

if ! commit=$(git rev-parse --verify -q "${tag}^{commit}"); then
	echo "verify-release: no such tag or commit: $tag" >&2
	exit 1
fi

if ! git rev-parse --verify -q origin/main >/dev/null; then
	git fetch -q --no-tags origin main:refs/remotes/origin/main || fail "cannot fetch origin/main"
fi
if ! git merge-base --is-ancestor "$commit" origin/main 2>/dev/null; then
	fail "$tag ($commit) is not on main"
fi

heading=$(git show "${commit}:CHANGELOG.md" 2>/dev/null | tr -d '\r' | sed -n 's/^## //p' | head -n 1)
if [ "$heading" != "$tag" ]; then
	fail "the changelog's first entry is \"${heading}\", not \"${tag}\""
fi

if ! git show "${commit}:Lootoman.toc" 2>/dev/null | tr -d '\r' | grep -q '^## Version: @project-version@$'; then
	fail "the TOC's version is not left to the packager (## Version: @project-version@)"
fi

if [ "$problems" -gt 0 ]; then
	exit 1
fi
echo "verify-release: $tag is ready to publish"
