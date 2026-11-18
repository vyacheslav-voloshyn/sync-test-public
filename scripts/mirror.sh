#!/usr/bin/env bash
# Fast-forwards the private main and tags to the public ones. Never forces:
# a private main with commits the public one lacks is an error to look at.
set -euo pipefail
pub=${PUBLIC_REMOTE:-public}
priv=${PRIVATE_REMOTE:-private}

git fetch --quiet --tags "$pub" main
git fetch --quiet "$priv" main
if ! git merge-base --is-ancestor "$priv/main" "$pub/main"; then
  echo "refused: the private main has commits the public main lacks:" >&2
  git log --oneline "$pub/main..$priv/main" >&2
  exit 1
fi
git push --quiet "$priv" "refs/remotes/$pub/main:refs/heads/main"
git push --quiet "$priv" --tags
echo "private main = $(git rev-parse --short "$pub/main")"
