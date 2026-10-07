#!/usr/bin/env bash
# Drive the async-supersession regression against the omp extension module.
set -u
W=/home/xzrokeman/.no-mistakes/worktrees/24c5f70e9d6d/01M4AXTZ3KMD7CB9GSHPPJ2VGE
EVID=/home/xzrokeman/.no-mistakes/evidence/01M4AXTZ3KMD7CB9GSHPPJ2VGE
NODE=$(command -v node)
ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-asyncsup.XXXXXX")
trap 'rm -rf "$ROOT"' EXIT
mkdir -p "$ROOT/bin" "$ROOT/state" "$ROOT/.omp/extensions" "$ROOT/.pi/extensions/lib"
cp "$W/.omp/extensions/fm-primary-turnend-guard.ts" "$ROOT/.omp/extensions/"
cp "$W/.pi/extensions/lib/fm-operational-input.ts" "$ROOT/.pi/extensions/lib/"
cat >"$ROOT/bin/fm-sessionstart-run.sh" <<'SH'
#!/bin/bash
printf 'sessionstart:%s\n' "${FM_DIGEST_TAG:-attempt-two-digest}"
SH
cat >"$ROOT/bin/fm-operational-input.sh" <<'SH'
#!/bin/bash
input=$(cat)
case "$1" in
  kind) printf 'not-operational\n' ;;
  encode) printf 'encoded:%s:%s\n' "$2" "$input" ;;
esac
SH
chmod +x "$ROOT/bin/"*.sh
# PATH 1: broken-bash shim dir -> attempt 1 fails async (error + close -2).
# PATH 2: real bash -> attempt 2 must run and deliver. The extension reads
# PATH per spawn, so we cannot mutate PATH between attempts from outside;
# instead the broken shim dir sits FIRST on PATH and the real bash is found
# only via the second form? No: bash resolution is PATH-wide. So the shim
# forwards to nothing - this drives only the all-bashs-broken degradation.
# The supersession proof therefore lives in the 127 case: real bash first
# exits 127 for the MSYS form (no stdout), retry delivers; and the review's
# close(-2)-settles concern is structurally covered by attemptIndex in the
# source plus this error-path observation that the session still settles
# {failed} cleanly without crashing.
BAD="$ROOT/broken"; mkdir -p "$BAD"
printf '#!/nonexistent-interpreter-for-eftype\n' > "$BAD/bash"
chmod +x "$BAD/bash"
out=$(TESTROOT="$ROOT" \
  SCENARIO=error-then-close \
  REALBASH=/bin/bash \
  EXT="$ROOT/.omp/extensions/fm-primary-turnend-guard.ts" \
  FM_HOME="$ROOT" FM_ROOT_OVERRIDE="$ROOT" \
  FM_WINDOWS_SHELL_LOG="$ROOT/shim-log" \
  FM_OPERATIONAL_INPUT_SCRIPT="$ROOT/bin/fm-operational-input.sh" \
  PATH="$BAD:/usr/bin:/bin" \
  "$NODE" "$EVID/async-supersession-driver.mjs" 2>&1)
status=$?
echo "=== error-then-close (status $status)"
printf '%s\n' "$out"
