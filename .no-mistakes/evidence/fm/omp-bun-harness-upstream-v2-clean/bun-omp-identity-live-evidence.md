# Live evidence: Bun-hosted omp harness identification (target 1c298a8f)

Host: macOS (Darwin 25.6.0), real Bun-hosted omp install: `/Users/xzrokeman/.bun/bin/omp`
is a `#!/usr/bin/env bun` script, omp/18.14.1, Bun 1.4.4.

## 1. Regression pair on the SAME live Bun-hosted omp process

A real `omp --mode rpc` primary (spawned by the credentialed e2e, lab kept) ran as
`comm=bun`, `args: bun /Users/xzrokeman/.bun/bin/omp --mode rpc ...`, pid 50720.

```
# base commit 043d8344 code, extracted to a temp dir, run against pid 50720:
$ $BASE/bin/fm-harness.sh ancestry 50720
(empty output — harness not identified; this is the read-only-session bug)

# target commit code (this worktree):
$ bin/fm-harness.sh ancestry 50720
args omp
```

## 2. Session lock names the Bun-hosted omp process

Kept e2e lab state (`.omp-live-e2e.50594`, removed after inspection):

```
$ cat project/state/.lock
50720
$ ps -p 50720 -o pid=,comm=,args=
50720 bun bun /Users/xzrokeman/.bun/bin/omp --mode rpc --no-session --cwd .../project ...
$ ls project/state/.session-start-complete
.session-start-complete          (session start completed)
$ grep -c "SESSION START" rpc.log
5                                 (digest was delivered into model context)
```

The lock was acquired and names the bun process — before this change the lock was
refused permanently and the session stayed read-only.

## 3. Adversarial real-bun argv scenarios (target code, live processes)

```
decoy pid=58548 comm=bun | flattened args: bun /tmp/fm-bun-adv.EqBnev/omp tools/task.js
A) spaced single argv element '/omp tools/task.js' verdict: comm claude (no omp verdict — fail closed)
B) real harness under spaced dir 'My Tools/omp' verdict: args omp
C) unknown bun option '--watch' verdict: comm claude (no omp verdict — refused)
D) raw fm_process_argv stream of the decoy (NUL shown as |):
bun|/tmp/fm-bun-adv.EqBnev/omp tools/task.js|
```

(A) A single argv element containing a space flattens to a fake `/tmp/.../omp` token in
`ps` output but is NOT re-split: no omp identity is manufactured. (B) A genuine harness
script named `omp` under a directory with a space keeps its basename and is identified.
(C) An unrecognized Bun option fails closed. (D) The macOS KERN_PROCARGS2 reader
(python3 ctypes, with the new slack/retry loop) returns the argv boundary intact.

## 4. Portable regression suites (real processes)

```
$ bash tests/fm-omp-harness.test.sh          # rc=0, all assertions ok
$ bash tests/fm-session-lock-ancestry.test.sh # rc=0, all assertions ok
```

Both suites spawn real native and Bun-named processes, exercise lock acquisition, an
inherited CLAUDECODE=1 marker, and live spaced-path proofs through the real argv
readers (/proc cmdline on Linux, KERN_PROCARGS2 on macOS).

## 5. Credentialed e2e: model-driven stages blocked by provider drift (not the change)

`FM_OMP_LIVE_E2E=1 FM_OMP_LIVE_MODEL='kimi-cn/kimi-k3.1-pro' bash tests/fm-omp-primary-live-e2e.test.sh`
(run 3x) consistently fails its stage-1 model-reply assertion: the assistant message
arrives with EMPTY content. Isolation probe — bare `omp --mode rpc` in an empty temp
dir with NO firstmate code, prompt "Reply with the single word: hello":

```
--- assistant text:            (empty)
--- message_end content: []    (empty assistant message)
```

kimi-cn/kimi-k3.1-pro on omp 18.14.1 returns empty assistant content even without
firstmate installed, so the e2e's model-driven stages (watcher arm, successor, guard
continuation — none of which this change touches) could not be exercised on this host.
The documented passing run used omp/18.13.1. Every assertion about THIS change's
surface (extension load, digest in context, lock naming the bun process, ancestry
`args omp`) passed before the model-dependent assertion.
