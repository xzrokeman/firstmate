#!/usr/bin/env node
// Async-supersession driver for the omp sessionstart retry (commit 13c10b7):
// attempt 1 starts a real bash that emits PARTIAL stdout then the script's
// inner exec fails asynchronously in a way bash surfaces as 127 AFTER output
// (partial stdout) - and, critically, we add a variant where attempt 1's bash
// is exec-broken so Node fires "error" (EACCES-style) then "close" code -2,
// the superseded-attempt sequence the round-4 review verified as settling
// {failed} pre-fix. Attempt 2 must still deliver its digest.
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { pathToFileURL } from "node:url";

const root = process.env.TESTROOT;
const logPath = path.join(root, "shim-log");
const realBash = process.env.REALBASH;
const scenario = process.env.SCENARIO;

Object.defineProperty(process, "platform", { value: "win32" });
fs.rmSync(logPath, { force: true });

const shimDir = path.join(root, "shim");
fs.mkdirSync(shimDir, { recursive: true });

if (scenario === "error-then-close") {
  // bash exists and is executable, so spawn does NOT throw, but its shebang
  // interpreter is missing: libuv execs the interpreter -> ENOENT arrives as
  // an async "error" event followed by "close" code -2 (the review's
  // verified sequence). No bash-invoked log line possible.
  fs.writeFileSync(path.join(shimDir, "bash"), "#!/nonexistent-interpreter-for-eftype\n", { mode: 0o755 });
} else {
  process.exit(2);
}

const handlers = new Map();
const pi = { on(event, handler) { handlers.set(event, handler); }, sendMessage() {} };
const extension = await import(`${pathToFileURL(process.env.EXT).href}?superseded=${Date.now()}`);
extension.default(pi);
const ctx = { sessionManager: { getSessionId: () => "async-supersede" } };

handlers.get("session_start")({ type: "session_start" }, ctx);
const before = await handlers.get("before_agent_start")({}, ctx);
const message = before && before.message ? before.message : null;
console.log(JSON.stringify({
  gotMessage: Boolean(message),
  customType: message ? message.customType : null,
  content: message ? message.content : null,
}, null, 2));
