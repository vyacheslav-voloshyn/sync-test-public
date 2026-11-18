#!/usr/bin/env bash
# Lands a reviewed pull request of the private repository on the public main
# as one commit, then fast-forwards the private main to it.
#
#   scripts/land.sh <pr-number>
#
# Run it from a clone with two remotes, "public" and "private". The person
# running it must be allowed to push to the public main (a ruleset bypass).
#
# LAND_DENY       extended regex refused in the commit message. Keep the real
#                 list out of this public tree: export it from a private file.
# REQUIRE_APPROVAL=0  skips the approved-review check (single-account tests).
# LAND_PAUSE=<s>  sleeps before the push, to test a public main that moves.
set -euo pipefail

pr=${1:?usage: land.sh <pr-number>}
pub=${PUBLIC_REMOTE:-public}
priv=${PRIVATE_REMOTE:-private}
deny=${LAND_DENY:-'[A-Z]{2,}-[0-9]+|\.internal\b'}
here=$(dirname "$0")

slug() { git remote get-url "$1" | sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##'; }
repo=$(slug "$priv")
field() { gh pr view "$pr" -R "$repo" --json "$1" -q ".$1"; }

[ "$(field state)" = OPEN ] || { echo "PR #$pr is not open" >&2; exit 1; }
if [ "${REQUIRE_APPROVAL:-1}" != 0 ] && [ "$(field reviewDecision)" != APPROVED ]; then
  echo "PR #$pr is not approved" >&2; exit 1
fi

title=$(field title)
branch=$(field headRefName)

# The squash commit carries the title only: the PR body and the review stay private.
if grep -Eq "$deny" <<<"$title"; then
  echo "refused: the title matches LAND_DENY: $(grep -Eo "$deny" <<<"$title" | head -1)" >&2
  exit 1
fi

for attempt in 1 2 3; do
  git fetch --quiet "$pub" main
  git fetch --quiet "$priv" "$branch"
  base=$(git rev-parse "$pub/main")
  head=$(git rev-parse "$priv/$branch")

  if ! tree=$(git merge-tree --write-tree --name-only "$base" "$head"); then
    files=$(sed 1d <<<"$tree" | sed '/^$/,$d')
    gh pr comment "$pr" -R "$repo" --body "Land refused: this branch conflicts with the public main in:

$(sed 's/^/- `/; s/$/`/' <<<"$files")

Rebase it onto the public main and land again." >/dev/null
    echo "refused: conflicts with public main in: $files" >&2
    exit 1
  fi
  [ "$tree" != "$(git rev-parse "$base^{tree}")" ] || { echo "PR #$pr changes nothing on public main" >&2; exit 1; }

  author=$(git log --reverse --format='%an%x09%ae' "$base..$head" | head -1)
  commit=$(GIT_AUTHOR_NAME=${author%%$'\t'*} GIT_AUTHOR_EMAIL=${author##*$'\t'} \
    git commit-tree "$tree" -p "$base" -m "$title")

  # The PR branch gets the exact commit that lands, so GitHub marks the PR merged
  # once the private main contains it, and private CI has run on that very SHA.
  git push --quiet --force "$priv" "$commit:refs/heads/$branch"
  sleep "${LAND_PAUSE:-0}"
  if git push --quiet "$pub" "$commit:refs/heads/main"; then
    "$here/mirror.sh"
    for _ in 1 2 3 4 5; do
      [ "$(field state)" = MERGED ] && { echo "landed PR #$pr as $commit"; exit 0; }
      sleep 2
    done
    echo "landed $commit, but GitHub does not show PR #$pr as merged" >&2
    exit 1
  fi
  echo "public main moved during attempt $attempt; retrying" >&2
done
echo "gave up after 3 attempts" >&2
exit 1
