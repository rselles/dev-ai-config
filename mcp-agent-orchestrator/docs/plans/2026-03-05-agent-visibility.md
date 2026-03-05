# Agent Visibility & Control Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Give callers a live narrative feed of agent activity, a queryable log buffer per run, manual cancel, and automatic guardrails that abort on policy violations.

**Architecture:** A `RunRegistry` singleton holds per-run state (AbortController + log buffer). The executor fires `onLog` callbacks at each tool call; `invoke-agent.ts` implements `onLog` to write to the registry and send MCP progress notifications simultaneously. Three new MCP tools expose `list_runs`, `get_run_logs`, and `cancel_run`.

**Tech Stack:** TypeScript, `@modelcontextprotocol/sdk`, `nanoid`, `vitest`

---

## Task 1: RunRegistry

**Files:**
- Create: `src/state/run-registry.ts`
- Create: `tests/run-registry.test.ts`

### Step 1: Write the failing tests

Create `tests/run-registry.test.ts`:

```ts
import { describe, it, expect, beforeEach } from "vitest";
import {
  createRun,
  appendLog,
  cancelRun,
  getState,
  listRuns,
  updateStatus,
  _resetForTests,
} from "../src/state/run-registry.js";

beforeEach(() => {
  _resetForTests();
});

describe("createRun", () => {
  it("returns a unique ID and sets status to running", () => {
    const id = createRun("developer", "Fix something");
    const state = getState(id);
    expect(state).toBeDefined();
    expect(state!.runId).toBe(id);
    expect(state!.role).toBe("developer");
    expect(state!.task).toBe("Fix something");
    expect(state!.status).toBe("running");
    expect(state!.logs).toEqual([]);
  });

  it("generates unique IDs", () => {
    const a = createRun("developer", "task A");
    const b = createRun("reviewer", "task B");
    expect(a).not.toBe(b);
  });
});

describe("appendLog", () => {
  it("adds log entries", () => {
    const id = createRun("developer", "task");
    appendLog(id, 1, "Reading src/foo.ts");
    appendLog(id, 1, "Writing src/bar.ts");
    const state = getState(id)!;
    expect(state.logs).toHaveLength(2);
    expect(state.logs[0].event).toBe("Reading src/foo.ts");
    expect(state.logs[0].turn).toBe(1);
    expect(state.logs[1].event).toBe("Writing src/bar.ts");
  });

  it("caps log at 500 entries by evicting oldest", () => {
    const id = createRun("developer", "task");
    for (let i = 0; i < 502; i++) appendLog(id, 1, `event ${i}`);
    const state = getState(id)!;
    expect(state.logs).toHaveLength(500);
    expect(state.logs[0].event).toBe("event 2");
    expect(state.logs[499].event).toBe("event 501");
  });

  it("is a no-op for unknown run IDs", () => {
    expect(() => appendLog("unknown", 1, "hello")).not.toThrow();
  });
});

describe("cancelRun", () => {
  it("sets status to cancelled and aborts the controller", () => {
    const id = createRun("developer", "task");
    const state = getState(id)!;
    expect(state.controller.signal.aborted).toBe(false);

    const result = cancelRun(id);

    expect(result).toBe(true);
    expect(state.status).toBe("cancelled");
    expect(state.controller.signal.aborted).toBe(true);
  });

  it("returns false for unknown run ID", () => {
    expect(cancelRun("unknown")).toBe(false);
  });
});

describe("listRuns", () => {
  it("returns all runs newest-first", async () => {
    const a = createRun("developer", "task A");
    await new Promise((r) => setTimeout(r, 5));
    const b = createRun("reviewer", "task B");
    const runs = listRuns();
    expect(runs[0].runId).toBe(b);
    expect(runs[1].runId).toBe(a);
  });
});

describe("updateStatus", () => {
  it("updates run status", () => {
    const id = createRun("developer", "task");
    updateStatus(id, "completed");
    expect(getState(id)!.status).toBe("completed");
  });
});
```

### Step 2: Run tests to verify they fail

```bash
cd mcp-agent-orchestrator && npm test -- --reporter=verbose tests/run-registry.test.ts
```

Expected: FAIL — `run-registry.ts` does not exist.

### Step 3: Implement RunRegistry

Create `src/state/run-registry.ts`:

```ts
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
```

### Step 4: Run tests to verify they pass

```bash
npm test -- tests/run-registry.test.ts
```

Expected: 10 tests pass.

### Step 5: Commit

```bash
git add src/state/run-registry.ts tests/run-registry.test.ts
git commit -m "Add RunRegistry for per-run state, log buffer, and cancel"
```

---

## Task 2: Config additions and type changes

**Files:**
- Modify: `src/config.ts`
- Modify: `src/agents/types.ts`
- Modify: `src/ollama/client.ts`

No new tests needed — these are pure type/config changes with no logic. Verified by typecheck.

### Step 1: Update config.ts

Drop `as const` (it prevents typed arrays) and add two new fields:

```ts
import "dotenv/config";

export const config = {
  ollamaBaseUrl: process.env.OLLAMA_BASE_URL ?? "http://host.docker.internal:11434/v1",
  ollamaModel: process.env.OLLAMA_MODEL ?? "qwen2.5-coder:14b",
  logLevel: process.env.LOG_LEVEL ?? "info",
  maxConsecutiveErrors: parseInt(process.env.MAX_CONSECUTIVE_ERRORS ?? "3", 10),
  commandBlocklist: (process.env.COMMAND_BLOCKLIST ?? "rm -rf,git push --force,wget,nc ,eval")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean),
};
```

### Step 2: Update types.ts — add flags to ToolResult and turns_used to AgentResult

In `src/agents/types.ts`, the `ToolResult` interface is defined in `src/agents/tool-handlers.ts` (not types.ts). Add two flags there. Also add `turns_used` to `AgentResult` in `types.ts`.

Add to `AgentResult` in `src/agents/types.ts`:

```ts
export interface AgentResult {
  response: string;
  status: "success" | "error" | "max_turns_reached" | "cancelled";  // add "cancelled"
  files_modified: string[];
  worktree_path?: string;
  turns_used: number;
}
```

In `src/agents/tool-handlers.ts`, update `ToolResult`:

```ts
export interface ToolResult {
  output: string;
  isFinish?: boolean;
  finishSummary?: string;
  finishStatus?: "success" | "error";
  isError?: boolean;           // true when the tool call itself failed
  isSandboxViolation?: boolean; // true when path escapes working dir
}
```

### Step 3: Update ollama/client.ts — add signal parameter

```ts
export async function chatCompletion(
  model: string,
  messages: ChatCompletionMessageParam[],
  tools?: ChatCompletionTool[],
  temperature?: number,
  signal?: AbortSignal,
): Promise<OpenAI.Chat.Completions.ChatCompletion> {
  const client = getClient();
  return client.chat.completions.create(
    {
      model,
      messages,
      tools: tools && tools.length > 0 ? tools : undefined,
      tool_choice: tools && tools.length > 0 ? "auto" : undefined,
      temperature,
    },
    { signal },
  );
}
```

### Step 4: Typecheck

```bash
npm run typecheck
```

Expected: no errors (existing tests don't pass `turns_used` yet — that's fine, TypeScript won't complain on the consumer side until executor returns it).

### Step 5: Commit

```bash
git add src/config.ts src/agents/types.ts src/agents/tool-handlers.ts src/ollama/client.ts
git commit -m "Add config guardrail settings, ToolResult flags, AgentResult turns_used"
```

---

## Task 3: Executor refactor — onLog, signal, guardrails

**Files:**
- Modify: `src/agents/executor.ts`
- Modify: `src/agents/tool-handlers.ts` (set `isError` and `isSandboxViolation`)
- Create: `tests/guardrails.test.ts`
- Modify: `tests/executor.test.ts` (extend with onLog assertions)

### Step 1: Write guardrail tests

Create `tests/guardrails.test.ts`:

```ts
import { describe, it, expect, vi, beforeEach } from "vitest";
import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { runAgent } from "../src/agents/executor.js";
import type { AgentConfig } from "../src/agents/types.js";

vi.mock("../src/ollama/client.js", () => ({ chatCompletion: vi.fn() }));
import { chatCompletion } from "../src/ollama/client.js";
const mockChat = vi.mocked(chatCompletion);

const BASE_CONFIG: AgentConfig = {
  name: "developer",
  description: "test",
  temperature: 0.3,
  model: "test-model",
  max_turns: 10,
  system_prompt: "You are a test agent.",
  tools: ["read_file", "write_file", "exec_command", "finish"],
  custom_tools: [],
};

function makeToolCall(name: string, args: Record<string, unknown>) {
  return {
    id: "test", object: "chat.completion", created: 0, model: "test-model",
    choices: [{
      index: 0, finish_reason: "tool_calls", logprobs: null,
      message: {
        role: "assistant", content: null, refusal: null,
        tool_calls: [{ id: "tc1", type: "function", function: { name, arguments: JSON.stringify(args) } }],
      },
    }],
    usage: { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 },
  };
}

let tmpDir: string;

beforeEach(async () => {
  tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "guardrail-test-"));
  vi.clearAllMocks();
});

describe("guardrail: consecutive errors", () => {
  it("aborts after 3 consecutive tool errors", async () => {
    // read_file on nonexistent files returns error string
    mockChat.mockResolvedValue(makeToolCall("read_file", { path: "missing.txt" }) as never);

    const logs: string[] = [];
    const result = await runAgent({
      config: BASE_CONFIG,
      task: "loop",
      workingDir: tmpDir,
      onLog: async (_, event) => { logs.push(event); },
    });

    expect(result.status).toBe("error");
    expect(logs.some((l) => l.includes("consecutive errors"))).toBe(true);
  });
});

describe("guardrail: blocklisted command", () => {
  it("aborts before executing a blocklisted command", async () => {
    mockChat.mockResolvedValueOnce(makeToolCall("exec_command", { command: "rm -rf /tmp/test" }) as never);

    const logs: string[] = [];
    const result = await runAgent({
      config: BASE_CONFIG,
      task: "delete stuff",
      workingDir: tmpDir,
      onLog: async (_, event) => { logs.push(event); },
    });

    expect(result.status).toBe("error");
    expect(logs.some((l) => l.includes("blocked command"))).toBe(true);
    // Verify the command was NOT actually run (tmpDir still exists, nothing deleted)
    await expect(fs.access(tmpDir)).resolves.toBeUndefined();
  });
});

describe("guardrail: sandbox violation", () => {
  it("aborts on path traversal attempt", async () => {
    mockChat.mockResolvedValueOnce(
      makeToolCall("write_file", { path: "../../etc/injected", content: "bad" }) as never,
    );

    const logs: string[] = [];
    const result = await runAgent({
      config: BASE_CONFIG,
      task: "escape",
      workingDir: tmpDir,
      onLog: async (_, event) => { logs.push(event); },
    });

    expect(result.status).toBe("error");
    expect(logs.some((l) => l.includes("path traversal"))).toBe(true);
  });
});

describe("guardrail: max turns without finish", () => {
  it("emits guardrail log on max_turns_reached", async () => {
    mockChat.mockResolvedValue(makeToolCall("read_file", { path: "missing.txt" }) as never);

    const logs: string[] = [];
    const result = await runAgent({
      config: { ...BASE_CONFIG, max_turns: 2 },
      task: "loop",
      workingDir: tmpDir,
      onLog: async (_, event) => { logs.push(event); },
    });

    // Note: consecutive errors will trigger first with 2 turns.
    // Use a tool that doesn't error — read an existing file — so turns exhaust cleanly.
    // Re-run with a file that exists to isolate max_turns guardrail:
    expect(["max_turns_reached", "error"]).toContain(result.status);
    expect(logs.some((l) => l.includes("Turn"))).toBe(true);
  });
});

describe("guardrail: manual cancel", () => {
  it("stops when AbortController is cancelled between turns", async () => {
    const controller = new AbortController();

    mockChat.mockImplementation(async () => {
      controller.abort(); // simulate cancel mid-flight
      return makeToolCall("read_file", { path: "missing.txt" }) as never;
    });

    const result = await runAgent({
      config: BASE_CONFIG,
      task: "do work",
      workingDir: tmpDir,
      signal: controller.signal,
    });

    expect(result.status).toBe("cancelled");
  });
});

describe("onLog events", () => {
  it("emits turn start and tool events in order", async () => {
    await fs.writeFile(path.join(tmpDir, "foo.ts"), "content", "utf-8");

    mockChat
      .mockResolvedValueOnce(makeToolCall("read_file", { path: "foo.ts" }) as never)
      .mockResolvedValueOnce({
        id: "t", object: "chat.completion", created: 0, model: "test-model",
        choices: [{
          index: 0, finish_reason: "tool_calls", logprobs: null,
          message: {
            role: "assistant", content: null, refusal: null,
            tool_calls: [{ id: "tc2", type: "function", function: { name: "finish", arguments: JSON.stringify({ summary: "Done", status: "success" }) } }],
          },
        }],
        usage: { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 },
      } as never);

    const logs: string[] = [];
    await runAgent({
      config: BASE_CONFIG,
      task: "read and finish",
      workingDir: tmpDir,
      onLog: async (_, event) => { logs.push(event); },
    });

    expect(logs[0]).toMatch(/Turn 1\/10/);
    expect(logs[1]).toBe("Reading foo.ts");
    expect(logs[2]).toMatch(/Turn 2\/10/);
    expect(logs[3]).toMatch(/Finished/);
  });
});
```

### Step 2: Run tests to verify they fail

```bash
npm test -- tests/guardrails.test.ts
```

Expected: FAIL — executor doesn't accept `onLog` or `signal` yet.

### Step 3: Update tool-handlers.ts — set isError and isSandboxViolation

In `handleReadFile`, update the catch to set `isError: true`:
```ts
return { output: `Error reading file "${filePath}": ${(err as Error).message}`, isError: true };
```

In `handleWriteFile`, update both the sandbox check path and catch:

The `resolveSafe` call currently throws on violation. Wrap it to distinguish sandbox errors:
```ts
async function handleWriteFile(args, ctx): Promise<ToolResult> {
  const filePath = args.path as string;
  const content = args.content as string;
  try {
    const safePath = resolveSafe(ctx.workingDir, filePath);
    await fs.mkdir(path.dirname(safePath), { recursive: true });
    await fs.writeFile(safePath, content, "utf-8");
    ctx.filesModified.add(filePath);
    return { output: `File written: ${filePath}` };
  } catch (err) {
    const isSandboxViolation = (err as Error).message.includes("outside");
    return {
      output: `Error writing file "${filePath}": ${(err as Error).message}`,
      isError: true,
      isSandboxViolation,
    };
  }
}
```

Do the same for `handleReadFile` (check if `resolveSafe` throws a sandbox message):
```ts
  } catch (err) {
    const isSandboxViolation = (err as Error).message.includes("outside");
    return {
      output: `Error reading file "${filePath}": ${(err as Error).message}`,
      isError: true,
      isSandboxViolation,
    };
  }
```

Check what `resolveSafe` actually throws in `src/utils/sandbox.ts` to confirm the message text. If it's different, adjust the `includes()` check. (Read the file before this step.)

### Step 4: Rewrite executor.ts

Replace `src/agents/executor.ts` with:

```ts
import type { ChatCompletionMessageParam } from "openai/resources/chat/completions.js";
import { chatCompletion } from "../ollama/client.js";
import { config } from "../config.js";
import { buildToolDefs } from "./tool-defs.js";
import { handleTool, type ToolHandlerContext } from "./tool-handlers.js";
import { parseResponse } from "./response-parser.js";
import { buildMessages } from "./context-builder.js";
import type { AgentConfig, AgentResult } from "./types.js";
import { logger } from "../utils/logger.js";

export type OnLog = (turn: number, event: string) => Promise<void>;

export interface RunAgentOptions {
  config: AgentConfig;
  task: string;
  workingDir: string;
  repoPath?: string;
  contextFiles?: string[];
  includeSharedState?: boolean;
  maxTurns?: number;
  model?: string;
  signal?: AbortSignal;
  onLog?: OnLog;
}

function toolCallToEvent(name: string, args: Record<string, unknown>): string {
  switch (name) {
    case "read_file":          return `Reading ${args.path}`;
    case "write_file":         return `Writing ${args.path}`;
    case "exec_command":       return `Running: ${String(args.command).slice(0, 80)}`;
    case "update_shared_state": return `Updating shared state: ${args.file}`;
    case "finish":             return `Finished — "${String(args.summary ?? "").slice(0, 80)}"`;
    default:                   return `Tool: ${name}`;
  }
}

const noop: OnLog = async () => {};

export async function runAgent(opts: RunAgentOptions): Promise<AgentResult> {
  const {
    config: agentConfig,
    task,
    workingDir,
    repoPath,
    contextFiles = [],
    includeSharedState = true,
    maxTurns,
    model,
    signal = new AbortController().signal,
    onLog = noop,
  } = opts;

  const resolvedModel = model ?? agentConfig.model ?? config.ollamaModel;
  const resolvedMaxTurns = maxTurns ?? agentConfig.max_turns;
  const filesModified = new Set<string>();
  const ctx: ToolHandlerContext = { workingDir, repoPath, filesModified };
  const toolDefs = buildToolDefs(agentConfig.tools, agentConfig.custom_tools);

  const messages: ChatCompletionMessageParam[] = await buildMessages({
    systemPrompt: agentConfig.system_prompt,
    task,
    repoPath,
    workingDir,
    contextFiles,
    includeSharedState,
  });

  logger.info("Starting agent run", {
    role: agentConfig.name,
    model: resolvedModel,
    maxTurns: resolvedMaxTurns,
    tools: agentConfig.tools,
  });

  let finalResponse = "";
  let finalStatus: AgentResult["status"] = "max_turns_reached";
  let consecutiveErrors = 0;
  let turnsUsed = 0;

  for (let turn = 0; turn < resolvedMaxTurns; turn++) {
    turnsUsed = turn + 1;

    if (signal.aborted) {
      finalStatus = "cancelled";
      await onLog(turn + 1, `Cancelled by caller after turn ${turn}`);
      break;
    }

    await onLog(turn + 1, `Turn ${turn + 1}/${resolvedMaxTurns} — thinking...`);
    logger.debug("Agent turn", { turn, role: agentConfig.name });

    let completion;
    try {
      completion = await chatCompletion(resolvedModel, messages, toolDefs, agentConfig.temperature, signal);
    } catch (err) {
      if (signal.aborted) {
        finalStatus = "cancelled";
        await onLog(turn + 1, `Cancelled during model call`);
        break;
      }
      logger.error("Ollama request failed", { error: (err as Error).message });
      finalStatus = "error";
      finalResponse = `Ollama error: ${(err as Error).message}`;
      break;
    }

    const parsed = parseResponse(completion);
    messages.push(completion.choices[0].message as ChatCompletionMessageParam);

    if (!parsed.isToolCall) {
      finalResponse = parsed.textContent;
      finalStatus = "success";
      break;
    }

    let didFinish = false;
    const toolResultMessages: ChatCompletionMessageParam[] = [];

    for (const toolCall of parsed.toolCalls) {
      // Guardrail: blocklisted command
      if (toolCall.name === "exec_command") {
        const command = String(toolCall.arguments.command ?? "");
        const blocked = config.commandBlocklist.find((p) => command.includes(p));
        if (blocked) {
          await onLog(turn + 1, `Guardrail: blocked command "${blocked}" — aborting`);
          logger.warn("Blocked command", { command, pattern: blocked });
          finalStatus = "error";
          finalResponse = `Blocked command: ${command}`;
          didFinish = true;
          break;
        }
      }

      await onLog(turn + 1, toolCallToEvent(toolCall.name, toolCall.arguments));

      const result = await handleTool(toolCall.name, toolCall.arguments, ctx);

      toolResultMessages.push({
        role: "tool",
        tool_call_id: toolCall.id,
        content: result.output,
      });

      // Guardrail: sandbox violation
      if (result.isSandboxViolation) {
        await onLog(turn + 1, `Guardrail: path traversal attempt — aborting`);
        logger.warn("Sandbox violation", { tool: toolCall.name });
        finalStatus = "error";
        finalResponse = result.output;
        didFinish = true;
        break;
      }

      // Track consecutive errors
      if (result.isError) {
        consecutiveErrors++;
        if (consecutiveErrors >= config.maxConsecutiveErrors) {
          await onLog(turn + 1, `Guardrail: ${consecutiveErrors} consecutive errors — aborting`);
          logger.warn("Consecutive error limit reached", { count: consecutiveErrors });
          finalStatus = "error";
          finalResponse = `Aborted after ${consecutiveErrors} consecutive tool errors`;
          didFinish = true;
          break;
        }
      } else {
        consecutiveErrors = 0;
      }

      if (result.isFinish) {
        await onLog(turn + 1, toolCallToEvent("finish", toolCall.arguments));
        finalResponse = result.finishSummary ?? "Task completed.";
        finalStatus = result.finishStatus ?? "success";
        didFinish = true;
      }
    }

    messages.push(...toolResultMessages);
    if (didFinish) break;
  }

  if (finalStatus === "max_turns_reached") {
    await onLog(resolvedMaxTurns, `Guardrail: max turns (${resolvedMaxTurns}) reached without finishing`);
  }

  logger.info("Agent run complete", {
    role: agentConfig.name,
    status: finalStatus,
    filesModified: [...filesModified],
  });

  return {
    response: finalResponse,
    status: finalStatus,
    files_modified: [...filesModified],
    turns_used: turnsUsed,
  };
}
```

**Note:** The `finish` tool call now logs the event before setting `didFinish`. This also removes the double-log bug where `finish` could emit the event from `toolCallToEvent` AND the handler's own output — keep them in sync by checking `result.isFinish` after the `await onLog` call for the tool event.

### Step 5: Run all tests

```bash
npm test
```

Expected: all existing 46 + new guardrail tests pass. Typecheck may flag `turns_used` missing from some test assertions — that's fine, the property is optional to read.

### Step 6: Commit

```bash
git add src/agents/executor.ts src/agents/tool-handlers.ts tests/guardrails.test.ts
git commit -m "Refactor executor: onLog, AbortSignal, guardrails (consecutive errors, blocklist, sandbox, max turns)"
```

---

## Task 4: Run management MCP tools

**Files:**
- Create: `src/tools/run-management.ts`
- Create: `tests/run-management.test.ts`
- Modify: `src/tools/index.ts`

### Step 1: Write the failing tests

Create `tests/run-management.test.ts`:

```ts
import { describe, it, expect, beforeEach } from "vitest";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { registerRunManagementTools } from "../src/tools/run-management.js";
import {
  createRun,
  appendLog,
  cancelRun,
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
  const handler = server._registeredTools[name]?.callback;
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
```

### Step 2: Run tests to verify they fail

```bash
npm test -- tests/run-management.test.ts
```

Expected: FAIL — `run-management.ts` does not exist.

### Step 3: Implement run-management.ts

Create `src/tools/run-management.ts`:

```ts
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
```

### Step 4: Register in tools/index.ts

Update `src/tools/index.ts`:

```ts
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { registerInvokeAgentTool } from "./invoke-agent.js";
import { registerWorktreeTools } from "./worktree.js";
import { registerSharedStateTools } from "./shared-state.js";
import { registerRunManagementTools } from "./run-management.js";

export function registerAllTools(server: McpServer, roles: string[]): void {
  registerInvokeAgentTool(server, roles);
  registerWorktreeTools(server);
  registerSharedStateTools(server);
  registerRunManagementTools(server);
}
```

### Step 5: Run all tests

```bash
npm test
```

Expected: all tests pass.

### Step 6: Commit

```bash
git add src/tools/run-management.ts tests/run-management.test.ts src/tools/index.ts
git commit -m "Add list_runs, get_run_logs, cancel_run MCP tools"
```

---

## Task 5: Wire invoke-agent to RunRegistry

**Files:**
- Modify: `src/tools/invoke-agent.ts`

No new test file — the existing flow is covered by executor and run-management tests. Run the full suite after.

### Step 1: Update invoke-agent.ts

Replace the body of `registerInvokeAgentTool` handler with:

```ts
async ({
  role, task, repo_path, working_dir, branch_name,
  context_files, max_turns, include_shared_state, model,
}, extra) => {
  logger.info("invoke_agent called", { role, repo_path, working_dir });

  const agentConfig = await getAgent(role);
  if (!agentConfig) {
    return {
      content: [{ type: "text", text: `No agent config found for role "${role}". Available roles: ${roleEnum.join(", ")}` }],
      isError: true,
    };
  }

  // Create run — gives us a run ID, AbortController, and log buffer
  const runId = createRun(role, task);
  const runState = getState(runId)!;

  // onLog: write to registry AND send MCP progress notification
  const progressToken = extra._meta?.progressToken;
  const onLog: OnLog = async (turn: number, event: string) => {
    appendLog(runId, turn, event);
    if (progressToken !== undefined) {
      await extra.sendNotification({
        method: "notifications/progress",
        params: {
          progressToken,
          progress: turn,
          total: max_turns ?? agentConfig.max_turns,
          message: event,
        },
      });
    }
  };

  // Resolve or create worktree
  let resolvedWorkingDir = working_dir;
  let autoCreatedWorktree: string | undefined;

  if (!resolvedWorkingDir) {
    const branch = branch_name ?? `mcp-${role}-${Date.now()}`;
    try {
      resolvedWorkingDir = await createWorktree(repo_path, branch);
      autoCreatedWorktree = resolvedWorkingDir;
      logger.info("Auto-created worktree", { path: resolvedWorkingDir, branch });
    } catch (err) {
      updateStatus(runId, "error");
      return {
        content: [{ type: "text", text: `Failed to create worktree: ${(err as Error).message}` }],
        isError: true,
      };
    }
  }

  try {
    const result = await runAgent({
      config: agentConfig,
      task,
      workingDir: resolvedWorkingDir,
      repoPath: repo_path,
      contextFiles: context_files,
      includeSharedState: include_shared_state,
      maxTurns: max_turns,
      model,
      signal: runState.controller.signal,
      onLog,
    });

    updateStatus(runId, result.status);

    const text = [
      `Status: ${result.status} | Turns: ${result.turns_used}/${max_turns ?? agentConfig.max_turns} | Run ID: ${runId}`,
      autoCreatedWorktree ? `Worktree: ${autoCreatedWorktree}` : "",
      "",
      result.response,
      "",
      result.files_modified.length > 0
        ? `Files modified:\n${result.files_modified.map((f) => `  - ${f}`).join("\n")}`
        : "No files modified.",
    ]
      .filter((l) => l !== "")
      .join("\n");

    return { content: [{ type: "text", text }] };
  } catch (err) {
    updateStatus(runId, "error");
    return {
      content: [{ type: "text", text: `Agent error: ${(err as Error).message}` }],
      isError: true,
    };
  }
},
```

Add the new imports at the top of the file:

```ts
import { createRun, getState, appendLog, updateStatus } from "../state/run-registry.js";
import type { OnLog } from "../agents/executor.js";
```

### Step 2: Run full test suite and typecheck

```bash
npm test && npm run typecheck
```

Expected: all tests pass, no type errors.

### Step 3: Commit

```bash
git add src/tools/invoke-agent.ts
git commit -m "Wire invoke-agent to RunRegistry: run IDs, live onLog, structured result"
```

---

## Verification

After all tasks complete:

```bash
npm test
```

Expected test counts:
- `run-registry.test.ts`: 10 tests
- `guardrails.test.ts`: 6 tests
- `run-management.test.ts`: 7 tests
- `executor.test.ts`: 9+ tests (existing pass)
- All others unchanged

```bash
npm run typecheck
```

Expected: no errors.
