import { nanoid } from "nanoid";

export interface LogEntry {
  ts: Date;
  turn: number;
  event: string;
}

export interface RunState {
  runId: string;
  role: string;
  task: string;
  startedAt: Date;
  status: "running" | "completed" | "cancelled" | "error" | "max_turns_reached";
  controller: AbortController;
  logs: LogEntry[];
}

const MAX_LOG_ENTRIES = 500;
const runs = new Map<string, RunState>();

export function createRun(role: string, task: string): string {
  const runId = nanoid(8);
  runs.set(runId, {
    runId,
    role,
    task,
    startedAt: new Date(),
    status: "running",
    controller: new AbortController(),
    logs: [],
  });
  return runId;
}

export function appendLog(runId: string, turn: number, event: string): void {
  const state = runs.get(runId);
  if (!state) return;
  if (state.logs.length >= MAX_LOG_ENTRIES) state.logs.shift();
  state.logs.push({ ts: new Date(), turn, event });
}

export function cancelRun(runId: string): boolean {
  const state = runs.get(runId);
  if (!state) return false;
  if (state.status !== "running") return false;
  state.controller.abort();
  state.status = "cancelled";
  return true;
}

export function getState(runId: string): RunState | undefined {
  return runs.get(runId);
}

export function listRuns(): RunState[] {
  return [...runs.values()].sort((a, b) => b.startedAt.getTime() - a.startedAt.getTime());
}

export function updateStatus(runId: string, status: RunState["status"]): void {
  const state = runs.get(runId);
  if (state) state.status = status;
}

/** Only for use in tests. */
export function _resetForTests(): void {
  runs.clear();
}
