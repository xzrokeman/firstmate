#!/usr/bin/env bash
# flake-attribution.sh <repo-dir> <iterations> <logfile>
# Runs only test_watch_extension_arms_and_delivers from tests/fm-omp-harness.test.sh,
# <iterations> times, in a fresh bash process each time, and records pass/fail counts.
set -u
repo=$1; iters=$2; log=$3
pass=0; failc=0
for i in $(seq 1 "$iters"); do
  driver="$repo/tests/.tmp-watch-flake-driver.sh"
  { sed '/^test_detection_anchored_name_and_marker_precedence$/,$d' "$repo/tests/fm-omp-harness.test.sh"
    echo 'test_watch_extension_arms_and_delivers'
  } > "$driver"
  out="$log.run.$i"
  if (cd "$repo" && bash tests/.tmp-watch-flake-driver.sh) >"$out" 2>&1; then
    pass=$((pass + 1)); rm -f "$out"
  else
    failc=$((failc + 1))
    { echo "--- iteration $i FAILED ---"; tail -30 "$out"; } >> "$log"
    rm -f "$out"
  fi
  rm -f "$driver"
done
echo "RESULT repo=$repo pass=$pass fail=$failc of $iters" | tee -a "$log"
