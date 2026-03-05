import { describe, it, expect, beforeEach } from "vitest";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { registerRunManagementTools } from "../src/tools/run-management.js";
import {
  createRun,
  appendLog,
  updateStatus,
  _resetForTests,
} from "../src/state/run-registry.js";

function makeServer() {
  const server = new McpServer({ name: "test", version: "0.0.1" });
  registerRunManagementTools(server);
  return server;
}

async function callTool(server: McpServer, name: string, args: Record<string, unknown>) {
  // @ts-expect-error: accessing internal tool registry for testing
  const handler = server._registeredTools[name]?.handler;
  if (!handler) throw new Error(`Tool "${name}" not registered`);
  return handler(args, {});
}

beforeEach(() => {
  _resetForTests();
});

describe("list_runs", () => {
  it("returns message when no runs exist", async () => {
    const server = makeServer();
    const result = await callTool(server, "list_runs", {});
    expect(result.content[0].text).toContain("No runs");
  });

  it("lists all runs with role, status, and task", async () => {
    createRun("developer", "Fix the bug in auth module");
    createRun("reviewer", "Review pull request #42");
    const server = makeServer();
    const result = await callTool(server, "list_runs", {});
    const text = result.content[0].text as string;
    expect(text).toContain("developer");
    expect(text).toContain("reviewer");
    expect(text).toContain("running");
  });
});

describe("get_run_logs", () => {
  it("returns error for unknown run ID", async () => {
    const server = makeServer();
    const result = await callTool(server, "get_run_logs", { run_id: "unknown" });
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("No run found");
  });

  it("returns message when run has no logs yet", async () => {
    const id = createRun("developer", "task");
    const server = makeServer();
    const result = await callTool(server, "get_run_logs", { run_id: id });
    expect(result.content[0].text).toContain("no log entries");
  });

  it("returns formatted timeline of log entries", async () => {
    const id = createRun("developer", "task");
    appendLog(id, 1, "Reading src/foo.ts");
    appendLog(id, 2, "Writing src/bar.ts");
    const server = makeServer();
    const result = await callTool(server, "get_run_logs", { run_id: id });
    const text = result.content[0].text as string;
    expect(text).toContain("T1");
    expect(text).toContain("Reading src/foo.ts");
    expect(text).toContain("T2");
    expect(text).toContain("Writing src/bar.ts");
  });
});

describe("cancel_run", () => {
  it("returns error for unknown run ID", async () => {
    const server = makeServer();
    const result = await callTool(server, "cancel_run", { run_id: "unknown" });
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("No run found");
  });

  it("returns message when run is already finished", async () => {
    const id = createRun("developer", "task");
    updateStatus(id, "completed");
    const server = makeServer();
    const result = await callTool(server, "cancel_run", { run_id: id });
    expect(result.content[0].text).toContain("already completed");
  });

  it("cancels a running run and reports last action", async () => {
    const id = createRun("developer", "Fix auth bug");
    appendLog(id, 1, "Reading src/auth.ts");
    appendLog(id, 2, "Writing src/auth.ts");
    const server = makeServer();
    const result = await callTool(server, "cancel_run", { run_id: id });
    const text = result.content[0].text as string;
    expect(text).toContain("cancelled");
    expect(text).toContain("Writing src/auth.ts");
  });
});
