import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { listRuns, getState, cancelRun } from "../state/run-registry.js";

function formatAge(date: Date): string {
  const s = Math.floor((Date.now() - date.getTime()) / 1000);
  if (s < 60) return `${s}s`;
  if (s < 3600) return `${Math.floor(s / 60)}m`;
  return `${Math.floor(s / 3600)}h`;
}

export function registerRunManagementTools(server: McpServer): void {
  server.tool(
    "list_runs",
    "List all agent runs for this session (active and completed)",
    {},
    () => {
      const runs = listRuns();
      if (runs.length === 0) {
        return { content: [{ type: "text" as const, text: "No runs in this session." }] };
      }
      const lines = runs.map(
        (r) =>
          `${r.runId} | ${r.role.padEnd(12)} | ${r.status.padEnd(18)} | ${formatAge(r.startedAt).padStart(4)} | ${r.task.slice(0, 60)}`,
      );
      return { content: [{ type: "text" as const, text: lines.join("\n") }] };
    },
  );

  server.tool(
    "get_run_logs",
    "Get the activity log for an agent run",
    { run_id: z.string().describe("Run ID from list_runs or invoke_agent result") },
    ({ run_id }) => {
      const state = getState(run_id);
      if (!state) {
        return {
          content: [{ type: "text" as const, text: `No run found with ID "${run_id}".` }],
          isError: true,
        };
      }
      if (state.logs.length === 0) {
        return {
          content: [{ type: "text" as const, text: `Run ${run_id} has no log entries yet.` }],
        };
      }
      const startMs = state.startedAt.getTime();
      const lines = state.logs.map((entry) => {
        const elapsed = Math.floor((entry.ts.getTime() - startMs) / 1000);
        const mm = String(Math.floor(elapsed / 60)).padStart(2, "0");
        const ss = String(elapsed % 60).padStart(2, "0");
        return `[${mm}:${ss}] T${entry.turn}  ${entry.event}`;
      });
      return { content: [{ type: "text" as const, text: lines.join("\n") }] };
    },
  );

  server.tool(
    "cancel_run",
    "Cancel a currently running agent",
    { run_id: z.string().describe("Run ID to cancel") },
    ({ run_id }) => {
      const state = getState(run_id);
      if (!state) {
        return {
          content: [{ type: "text" as const, text: `No run found with ID "${run_id}".` }],
          isError: true,
        };
      }
      if (state.status !== "running") {
        return {
          content: [{ type: "text" as const, text: `Run ${run_id} is already ${state.status}.` }],
        };
      }
      const lastLog = state.logs[state.logs.length - 1];
      cancelRun(run_id);
      const lines = [
        `Run ${run_id} (${state.role}) cancelled after turn ${lastLog?.turn ?? 0}.`,
        lastLog ? `Last action: ${lastLog.event}` : "",
      ].filter(Boolean);
      return { content: [{ type: "text" as const, text: lines.join("\n") }] };
    },
  );
}
