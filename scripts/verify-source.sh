#!/usr/bin/env bash
# Verifies the source checkout is exactly the requested commit AND that this commit
# is on the source repository's main branch (so arbitrary branches cannot be released).
# Env: SHA (requested commit), SRC_DIR (checkout, needs full history), GITHUB_OUTPUT (optional).
set -euo pipefail
: "${SHA:?SHA is required}" "${SRC_DIR:?SRC_DIR is required}"
fail() { echo "::error::$*"; exit 1; }

[[ "$SHA" =~ ^[0-9a-f]{40}$ ]] || fail "source_sha must be a full 40-character lowercase hex commit SHA"
cd "$SRC_DIR"
[[ "$(git rev-parse HEAD)" == "$SHA" ]] || fail "checked-out commit does not match source_sha"
git rev-parse --verify --quiet refs/remotes/origin/main >/dev/null \
  || fail "origin/main is missing from the source checkout (full history required)"
git merge-base --is-ancestor "$SHA" refs/remotes/origin/main \
  || fail "source_sha is not on the main branch of the source repository"

version="$(sed -n 's/^version = "\(.*\)"$/\1/p' Cargo.toml | head -n1)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] \
  || fail "could not read a valid version from the source Cargo.toml"

{ echo "sha=$SHA"; echo "version=$version"; } >>"${GITHUB_OUTPUT:-/dev/stdout}"
echo "source commit verified: on main, version $version"
