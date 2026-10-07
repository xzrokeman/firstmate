#!/usr/bin/env bash
# Probe: with the successor watcher FROZEN (SIGSTOP) and a stale beacon, does
# the real fm-turnend-guard.sh return rc=2? Mirrors the live e2e stage 3
# fixture without model tokens.
set -u
W=/home/xzrokeman/.no-mistakes/worktrees/24c5f70e9d6d/01M4AXTZ3KMD7CB9GSHPPJ2VGE
ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-guardprobe.XXXXXX")
trap 'rm -rf "$ROOT"; for p in "${PIDS[@]:-}"; do kill -CONT "$p" 2>/dev/null; kill -TERM "$p" 2>/dev/null; done' EXIT
mkdir -p "$ROOT/home/state" "$ROOT/home/config"
# project checkout = the worktree itself (guard scripts run from a real checkout)
PROJECT="$W"
export FM_HOME="$ROOT/home"
STATE="$FM_HOME/state"
# In-flight tasks and a stale beacon:
touch "$STATE/omp-e2e.meta"
sleep 600 &
WPID=$!
PIDS=($WPID)
mkdir -p "$STATE/.watch.lock"
printf '%s\n' "$WPID" > "$STATE/.watch.lock/pid"
fm_pid_identity() { printf '%s\n' "$(ps -p "$1" -o lstart= 2>/dev/null)"; }
touch "$STATE/.last-watcher-beat"
sleep 25
FM_GUARD_GRACE=20 bash "$PROJECT/bin/fm-turnend-guard.sh" <<'PAYLOAD'
{"stop_hook_active":false,"session_id":"probe"}
PAYLOAD
echo "guard_rc=$?"
