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
    // Use a file that exists so read_file succeeds and doesn't trigger consecutive-errors guardrail
    const testFile = path.join(tmpDir, "exists.txt");
    await fs.writeFile(testFile, "content");
    mockChat.mockResolvedValue(makeToolCall("read_file", { path: "exists.txt" }) as never);

    const logs: string[] = [];
    const result = await runAgent({
      config: { ...BASE_CONFIG, max_turns: 3 },
      task: "loop",
      workingDir: tmpDir,
      onLog: async (_, event) => { logs.push(event); },
    });

    expect(result.status).toBe("max_turns_reached");
    expect(logs.some((l) => l.includes("max turns"))).toBe(true);
  });
});

describe("guardrail: manual cancel", () => {
  it("stops when AbortController is cancelled mid-run", async () => {
    const controller = new AbortController();

    mockChat.mockImplementation(async () => {
      controller.abort();
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
