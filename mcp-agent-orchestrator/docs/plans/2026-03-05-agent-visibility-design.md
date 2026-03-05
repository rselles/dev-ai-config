# Agent Visibility & Control Design

_2026-03-05_

## Problem

`invoke_agent` is a black box. Callers see nothing until it finishes — no indication of what the agent is doing turn by turn, no way to stop a runaway agent, and no structured account of what happened after it completes.

## Goals

1. Live narrative feed of agent activity (per tool call, human-readable)
2. Queryable log buffer per run, replayable after completion
3. Manual cancel via a new MCP tool
4. Automatic guardrails that abort the agent on policy violation
5. Structured end summary on the `invoke_agent` result

---

## Architecture

Five areas of change, all additive. No existing tool signatures change.

```
MCP Client (Claude Code)
  invoke_agent  ──► progress notifications (live, per tool call)
  cancel_run    ──► AbortController signal
  get_run_logs  ──► log buffer query
  list_runs     ──► active/recent run list

New:   src/state/run-registry.ts
       src/tools/run-management.ts
Changed: executor.ts, tool-handlers.ts, invoke-agent.ts, tools/index.ts
```

---

## Component Designs

### RunRegistry (`src/state/run-registry.ts`)

Singleton `Map<runId, RunState>`. Created on module load, lives for the server session.

```ts
interface RunState {
  runId: string;
  role: string;
  task: string;
  startedAt: Date;
  status: "running" | "completed" | "cancelled" | "error" | "max_turns_reached";
  controller: AbortController;
  logs: LogEntry[];           // ring buffer, capped at 500 entries
}

interface LogEntry {
  ts: Date;
  turn: number;
  event: string;              // human-readable
}
```

API:
- `createRun(role, task) → runId`
- `appendLog(runId, turn, event) → void`
- `cancelRun(runId) → boolean`
- `getState(runId) → RunState | undefined`
- `listRuns() → RunState[]`  (all runs, newest first)

Completed/cancelled runs remain in the map for the session lifetime so logs stay queryable.

---

### Executor changes (`src/agents/executor.ts`)

`RunAgentOptions` gains two fields:

```ts
runId: string;
signal: AbortSignal;
onLog: (turn: number, event: string) => void;  // replaces onProgress
```

Per-turn loop:
1. Check `signal.aborted` at top of each turn — exit with status `"cancelled"`
2. Pass `signal` to `chatCompletion` (fetch supports AbortSignal natively)
3. Call `onLog` at each meaningful moment (see event string table below)

Guardrail logic lives in the executor:

| Guardrail | Trigger | Behaviour |
|-----------|---------|-----------|
| Consecutive errors | 3 tool calls in a row return an error string | Abort, log guardrail message, status `"error"` |
| Sandbox violation | `resolveSafe` throws | Abort immediately, log guardrail message |
| Blocklisted command | `exec_command` arg matches blocklist pattern | Abort before execution, log guardrail message |
| Max turns without finish | Loop exhausts | Returns `"max_turns_reached"`, logs guardrail message |

Default blocklist patterns (env-configurable): `rm -rf`, `git push`, `curl`, `wget`, `nc`, `eval`.

Event strings fired via `onLog`:

| Moment | String |
|--------|--------|
| Turn start | `"Turn 2/10 — thinking..."` |
| `read_file` | `"Reading src/executor.ts"` |
| `write_file` | `"Writing src/tools/index.ts"` |
| `exec_command` | `"Running: npm test"` |
| `update_shared_state` | `"Updating shared state: PLAN.md"` |
| `finish` | `"Finished — \"summary text\""` |
| Guardrail hit | `"Guardrail: 3 consecutive errors — aborting"` |
| Cancelled | `"Cancelled by caller after turn 2"` |

---

### invoke-agent.ts changes

Before calling `runAgent`:
1. `registry.createRun(role, task)` → `runId`
2. Pull `controller` from the new run state
3. Provide `onLog` implementation:
   - `registry.appendLog(runId, turn, event)`
   - `extra.sendNotification(...)` with the event string as `message`

`invoke_agent` result format:

```
Status: success | Turns: 3/10 | Run ID: abc123

Finished — "Removed unnecessary async/await from registerAllTools"

Files modified:
  - src/tools/index.ts
  - src/index.ts
```

---

### New MCP tools (`src/tools/run-management.ts`)

**`list_runs`** — no params
Returns all session runs, newest first:
```
abc123 | developer | running       | 14s  | Fix issue #11 from code-review.md
def456 | reviewer  | completed     | 3m   | Review auth module
```

**`get_run_logs(run_id)`**
Returns the log buffer formatted as a timeline:
```
[00:00] T1  Reading src/tools/index.ts
[00:01] T1  Reading src/index.ts
[00:03] T2  Writing src/tools/index.ts
[00:04] T2  Writing src/index.ts
[00:05] T3  Finished — "Removed unnecessary async/await"
```

**`cancel_run(run_id)`**
Aborts the run, returns:
```
Run abc123 (developer) cancelled after turn 2.
Last action: Writing src/index.ts
```

---

## Testing Plan

**`tests/run-registry.test.ts`**
- `createRun` returns unique ID with `"running"` status
- `appendLog` stores entries, caps at 500
- `cancelRun` sets status `"cancelled"` and calls `controller.abort()`
- `cancelRun` on unknown ID returns false
- `listRuns` returns all runs newest-first

**`tests/guardrails.test.ts`**
- Consecutive errors: 3 error tool results → status `"error"`, guardrail log entry present
- Blocklisted command: `exec_command` with `"rm -rf /"` → aborted before execution
- Max turns: loop exhausts without `finish` → `"max_turns_reached"` with guardrail log entry
- Sandbox violation: `write_file` with `"../../etc/passwd"` → aborted

**`tests/run-management.test.ts`**
- `list_runs` returns formatted text for all runs
- `get_run_logs` returns formatted timeline
- `cancel_run` on active run returns confirmation with last action
- `cancel_run` on unknown ID returns error text

**`tests/executor.test.ts`** (extended)
- `onLog` receives correct event strings in correct order
