#!/usr/bin/env bash
# Builds the desktop installers for the current OS WITHOUT printing tool output.
# This repository is public while the source is private, and compiler output (file paths,
# code excerpts in errors) would be world-readable. Output goes to a log file instead; if
# LOG_KEY is set, the log is encrypted for owner-only debugging, then the plain log is removed.
#
# Paths are relative to the current directory (the workspace).
# Env: SRC_DIR (source checkout), OUT_DIR (installers), TAURI_ARGS (e.g. "--bundles deb,rpm"),
#      LOG_FILE (scratch log), ENC_DIR + LOG_KEY (optional encrypted log), TARGET_DIR (default target)
set -uo pipefail
: "${SRC_DIR:?}" "${OUT_DIR:?}" "${TAURI_ARGS:?}" "${LOG_FILE:?}"
root="$(pwd)"
OUT_ABS="$root/$OUT_DIR"; LOG_ABS="$root/$LOG_FILE"; ENC_ABS="${ENC_DIR:+$root/$ENC_DIR}"
mkdir -p "$OUT_ABS"; : >"$LOG_ABS"

finish() {
  local code=$?
  if [[ -n "${LOG_KEY:-}" && -n "$ENC_ABS" ]]; then
    mkdir -p "$ENC_ABS"
    if openssl enc -aes-256-cbc -pbkdf2 -salt -in "$LOG_ABS" -out "$ENC_ABS/build-log.enc" -pass env:LOG_KEY; then
      echo "full build log encrypted (owner-only artifact)"
    else
      echo "warning: could not encrypt the build log"
    fi
  fi
  rm -f "$LOG_ABS"
  exit "$code"
}
trap finish EXIT

step() {
  local name="$1"; shift
  if "$@" >>"$LOG_ABS" 2>&1; then
    echo "ok: $name"
  else
    echo "::error::step failed: $name (tool output withheld; this repository's logs are public)"
    return 1
  fi
}

cd "$SRC_DIR" || { echo "::error::source directory missing"; exit 1; }
step "install UI dependencies" npm --prefix ui ci --ignore-scripts --no-audit --no-fund || exit 1
# shellcheck disable=SC2086  # TAURI_ARGS is a fixed list of flags from the workflow file
step "build installers" node ui/node_modules/@tauri-apps/cli/tauri.js build --ci $TAURI_ARGS || exit 1

count=0
while IFS= read -r -d '' f; do
  cp "$f" "$OUT_ABS/" && count=$((count + 1))
done < <(find "${TARGET_DIR:-target}" -type f -path '*/release/bundle/*' \
           \( -name '*.deb' -o -name '*.rpm' -o -name '*.exe' -o -name '*.dmg' \) -print0)
if [[ "$count" -eq 0 ]]; then
  echo "::error::no installers were produced"
  exit 1
fi
echo "collected $count installer(s):"
for f in "$OUT_ABS"/*; do printf '  %s (%s bytes)\n' "$(basename "$f")" "$(wc -c <"$f" | tr -d ' ')"; done
