// Regression driver for the omp sessionstart retry fixes (commits 13c10b7 + f7cf1fe).
//
// Forces process.platform to "win32" so the omp extension routes every Bash
// helper through bash in unsupervised form, then drives the extension's real
// session_start -> before_agent_start path and asserts the recorded shim log
// and the delivered message body.
//
// Attempt discrimination uses a counter file like the repo test's WSL127
// fixture: the shim refuses ONLY the first invocation of each extension-owned
// script (the WSL-launcher contract) and hands off to the real bash after.
//
// Scenarios (SCENARIO env):
//   acc-reset-partial  — attempt 1's bash emits FIRST_ATTEMPT_RESIDUE on
//                        stdout then exits 127; the retry (commit f7cf1fe)
//                        must deliver only attempt 2's output: no residue in
//                        the final message content, and exactly 2 bash calls.
//   exit127-refuse     — attempt 1's bash refuses the MSYS-form script outright
//                        (127, empty output); the retry must succeed cleanly.
//   superseded-noent   — mirrors the async exec failure: the shim answers
//                        attempt 1 with an immediate 127 and no output while
//                        attempt 2 succeeds (close(-1)/error handling path is
//                        exercised by exit127 + the repo's degraded case; here
//                        we add the no-settle-while-retry race check via
//                        exactly-2-call invariant and no failed fallback).
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { pathToFileURL } from "node:url";

const root = process.env.TESTROOT;
const logPath = path.join(root, "shim-log");
const countDir = path.join(root, "counts");
const scenario = process.env.SCENARIO;
const realBash = process.env.REALBASH;

Object.defineProperty(process, "platform", { value: "win32" });
fs.rmSync(logPath, { force: true });
fs.rmSync(countDir, { recursive: true, force: true });
fs.mkdirSync(countDir, { recursive: true });

const shimDir = path.join(root, "shim-" + scenario);
fs.mkdirSync(shimDir, { recursive: true });

let firstAttemptFailureCode;
switch (scenario) {
  case "superseded-noent":
  case "exit127-refuse":
    firstAttemptFailureCode = 127;
    break;
  case "acc-reset-partial":
    firstAttemptFailureCode = 127;
    break;
  default:
    console.error("unknown SCENARIO: " + scenario);
    process.exit(2);
}

const body = `#!${realBash}
printf '%s\n' "bash-invoked:$*" >> "$FM_WINDOWS_SHELL_LOG"
script_name=$(basename "$1")
count_file="${countDir}/$script_name"
count=0
[ -f "$count_file" ] && count=$(cat "$count_file")
count=$((count + 1))
printf '%s\\n' "$count" > "$count_file"
if [ "$count" -eq 1 ]; then
${scenario === "acc-reset-partial" ? "  printf 'FIRST_ATTEMPT_RESIDUE'\n" : ""}${scenario === "exit127-refuse" ? "  printf 'bash: %s: No such file or directory\\n' \"$1\" >&2\n" : ""}  exit ${firstAttemptFailureCode}
fi
exec "$REAL_BASH" "$@"
`;
const shim = path.join(shimDir, "bash");
fs.writeFileSync(shim, body, { mode: 0o755 });

const handlers = new Map();
const pi = {
  on(event, handler) { handlers.set(event, handler); },
  sendMessage() {},
};
const extension = await import(
  `${pathToFileURL(process.env.EXT).href}?windows=${Date.now()}`
);
extension.default(pi);
const ctx = { sessionManager: { getSessionId: () => "supersession-test" } };

handlers.get("session_start")({ type: "session_start" }, ctx);
const before = await handlers.get("before_agent_start")({}, ctx);
const message = before && before.message ? before.message : null;
const shimLog = fs.existsSync(logPath) ? fs.readFileSync(logPath, "utf8") : "";
console.log(JSON.stringify({
  gotMessage: Boolean(message),
  customType: message ? message.customType : null,
  contentHasResidue: message ? message.content.includes("FIRST_ATTEMPT_RESIDUE") : null,
  content: message ? message.content : null,
  display: message ? message.display : null,
  detailsKind: message && message.details ? message.details.kind : null,
  bashCallCount: message || shimLog // count bash-invoked lines
    ? (shimLog.match(/^bash-invoked:/gm) || []).length
    : 0,
  shimLog: shimLog.trim(),
}, null, 2));
