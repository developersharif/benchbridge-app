#!/usr/bin/env bash
# Fails unless the .app inside every .dmg in a directory is Developer-ID signed, accepted by
# Gatekeeper as notarized, and has a stapled ticket. Guards against a missing Apple secret
# silently producing an unsigned build. Prints only pass/fail (this repository's logs are public).
#
# Usage: verify-macos-signing.sh <dir-with-dmgs>      (macOS only)
set -uo pipefail
dir="${1:?usage: verify-macos-signing.sh <dir>}"
[[ "$(uname -s)" == "Darwin" ]] || { echo "::error::must run on macOS"; exit 1; }

shopt -s nullglob
dmgs=("$dir"/*.dmg)
[[ ${#dmgs[@]} -gt 0 ]] || { echo "::error::no .dmg found in $dir"; exit 1; }

fail=0
for dmg in "${dmgs[@]}"; do
  mnt="$(mktemp -d)"
  if ! hdiutil attach "$dmg" -nobrowse -readonly -mountpoint "$mnt" >/dev/null 2>&1; then
    echo "::error::could not mount $(basename "$dmg")"; rmdir "$mnt"; fail=1; continue
  fi
  apps=("$mnt"/*.app)
  if [[ ${#apps[@]} -ne 1 ]]; then
    echo "::error::expected exactly one .app in $(basename "$dmg")"; fail=1
  else
    app="${apps[0]}"
    check() { # name, command...
      local name="$1"; shift
      if "$@" >/dev/null 2>&1; then echo "ok: $name"; else echo "::error::macOS signing check failed: $name"; fail=1; fi
    }
    check "codesign verify (deep, strict)" codesign --verify --deep --strict "$app"
    check "Gatekeeper accepts app (notarized Developer ID)" spctl --assess --type execute "$app"
    check "notarization ticket stapled" xcrun stapler validate "$app"
  fi
  hdiutil detach "$mnt" >/dev/null 2>&1 || hdiutil detach -force "$mnt" >/dev/null 2>&1
  rmdir "$mnt" 2>/dev/null
done
exit "$fail"
