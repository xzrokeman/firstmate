# Flake attribution, FINAL: test_watch_extension_arms_and_delivers (tests/fm-omp-harness.test.sh)

Question (operator decision, repair turn): did branch fm/omp-bun-harness-upstream-v2-clean
(base b329c275 -> head 7d40e30b) introduce the watch-test flake? Decisive verdict with counts.

Method: flake-attribution.sh ran ONLY test_watch_extension_arms_and_delivers in a fresh bash
process per iteration, on head (this worktree) and on a clean clone of merge base b329c275,
20 iterations per side, both sides running concurrently under identical load (round 2).
Plus isolated full-suite runs of `bash tests/fm-omp-harness.test.sh` on both sides.

## Counts

| Run                                           | Head 7d40e30b        | Base b329c275         |
|-----------------------------------------------|----------------------|-----------------------|
| Round 1, heavy parallel load, single test     | 0/5 pass (5 fail)    | 1/8 pass (7 fail)     |
| Round 2, two concurrent loops, single test    | 20/20 pass (0 fail)  | 19/20 pass (1 fail)   |
| Round 1, isolated full suite                  | PASS (20 ok)         | -                     |
| Round 2, isolated full suite, attempt 1       | FAIL at watch test   | -                     |
| Round 2, isolated full suite, attempt 2       | PASS (20 ok, exit 0) | -                     |
| Round 2, isolated full suite                  | -                    | PASS (19 ok, exit 0)  |

Every failure on BOTH sides has the identical signature:
"expected one follow-up wake, saw 0" from the watch extension contract check.
In round 2 the single observed failure was on the BASE, not the head.
Logs: flake2-head.log, flake2-base.log (round 2); flake-head.log, flake-base.log (round 1);
full-suite-head-repair.log (failed attempt), full-suite-head-repair-rerun.log,
full-suite-base-repair.log.

Structural evidence (unchanged from round 1): the watch tests
(tests/fm-omp-harness.test.sh lines 839-1179) and the extension they drive
(.omp/extensions/fm-primary-omp-watch.ts) are byte-identical between base and head;
every branch hunk in the test file is above or beside the watch tests. The test asserts a
fixed 2500ms wall-clock wait against an arm child that itself sleeps 1s before signalling -
a load-sensitive timing race with no connection to the branch's Bun-argv changes.

## VERDICT

The flake is PRE-EXISTING on the merge base and load-sensitive; it is NOT introduced or
worsened by this change. Across 40 fresh-process single-test iterations under matched load
(head 20/20 pass, base 19/20 pass) plus round-1 heavy-load runs (head 5 fail / base 7 fail),
both sides fail with the same signature under load and pass when quiet. Decisive.
