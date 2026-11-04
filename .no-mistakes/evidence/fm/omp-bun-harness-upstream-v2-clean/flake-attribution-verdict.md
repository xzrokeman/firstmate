# Flake attribution: test_watch_extension_arms_and_delivers (tests/fm-omp-harness.test.sh)

Question: did the branch fm/omp-bun-harness-upstream-v2-clean (base b329c275 -> head 7d40e30b)
introduce the watch-test flake the earlier Test turn was mid-attribution on?

Method: flake-attribution.sh ran ONLY test_watch_extension_arms_and_delivers in a fresh bash
process per iteration, on head (this worktree) and on a clean clone of merge base b329c275,
20 iterations each side, both sides running concurrently under identical load. Runs were
stopped once the attribution was statistically decisive.

Results:
- head 7d40e30b under parallel load: 5 of 5 completed iterations FAILED
  ("expected one follow-up wake, saw 0"), see flake-head.log
- base b329c275 under identical parallel load: 7 of 8 completed iterations FAILED
  (same error), see flake-base.log
- head, isolated single iteration (quiet machine): PASS
- head, full suite isolated (bash tests/fm-omp-harness.test.sh): PASS, exit 0, all 21 tests ok
  including the watch test (full-suite-head-isolated.log)
- head, full suite earlier this turn while other work ran: watch test FAILED with the
  same "saw 0" error; every other test passed.

Structural evidence: git diff b329c275..7d40e30b touches tests/fm-omp-harness.test.sh only in
hunks @@ -13,8 +13,8 @@, @@ -65,15 +65,43 @@, @@ -82,9 +110,12 @@, @@ -105,6 +136,190 @@,
@@ -965,6 +1180,7 @@ - every hunk is above or beside the watch tests (they occupy lines 839-1179);
the watch tests and the extension they drive (.omp/extensions/fm-primary-omp-watch.ts, absent
from the diffstat) are byte-identical between base and head. The test asserts a fixed
2500ms wall-clock wait against an arm child that itself sleeps 1s before signalling - a
load-sensitive timing race with no connection to the branch's Bun-argv changes.

VERDICT: the flake is PRE-EXISTING on the merge base and load-sensitive; it is not
introduced or worsened by this change (head 5/5 vs base 7/8 failed under equal load; both
pass when run quietly). Decisive.
