#!/usr/bin/env bash
# Drive the omp sessionstart retry regression scenarios against the real omp
# extension module from the worktree. Disposable; lives only in evidence.
set -u
W=/home/xzrokeman/.no-mistakes/worktrees/24c5f70e9d6d/01M4AXTZ3KMD7CB9GSHPPJ2VGE
EVID=/home/xzrokeman/.no-mistakes/evidence/01M4AXTZ3KMD7CB9GSHPPJ2VGE
REAL_BASH=/bin/bash
NODE=$(command -v node)

for scenario in superseded-noent acc-reset-partial exit127-refuse; do
  ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-supersession.XXXXXX")
  mkdir -p "$ROOT/bin" "$ROOT/state" "$ROOT/.omp/extensions" "$ROOT/.pi/extensions/lib"
  cp "$W/.omp/extensions/fm-primary-turnend-guard.ts" "$ROOT/.omp/extensions/"
  cp "$W/.pi/extensions/lib/fm-operational-input.ts" "$ROOT/.pi/extensions/lib/"
  EXT_PATH="$ROOT/.omp/extensions/fm-primary-turnend-guard.ts"

  # The helper the session-start hook runs: emits a digest line (used by
  # attempt 2 after the shim's first-attempt refusal).
  cat >"$ROOT/bin/fm-sessionstart-run.sh" <<'SH'
#!/bin/bash
printf 'sessionstart:%s\n' "$FM_DIGEST_TAG"
SH
  # The operational-input helper: encode + kind contracts mirroring the repo's
  # fake helper shape.
  cat >"$ROOT/bin/fm-operational-input.sh" <<'SH'
#!/bin/bash
input=$(cat)
case "$1" in
  kind) printf 'not-operational\n' ;;
  encode) printf 'encoded:%s:%s\n' "$2" "$input" ;;
esac
SH
  chmod +x "$ROOT/bin/"*.sh

  out=$(TESTROOT="$ROOT" \
    SCENARIO="$scenario" \
    REAL_BASH="$REAL_BASH" REALBASH="$REAL_BASH" \
    EXT="$EXT_PATH" \
    FM_HOME="$ROOT" \
    FM_ROOT_OVERRIDE="$ROOT" \
    FM_WINDOWS_SHELL_LOG="$ROOT/shim-log" \
    FM_OPERATIONAL_INPUT_SCRIPT="$ROOT/bin/fm-operational-input.sh" \
    FM_DIGEST_TAG="attempt-two-digest" \
    PATH="$ROOT/shim-$scenario:$PATH" \
    "$NODE" "$EVID/supersession-driver.mjs" 2>&1)
  status=$?
  echo "=== scenario: $scenario (status $status)"
  printf '%s\n' "$out"
  echo "--- shim log:"
  cat "$ROOT/shim-log" 2>/dev/null
  echo "--- counts:"; cat "$ROOT/counts"/* 2>/dev/null
  rm -rf "$ROOT"
done
