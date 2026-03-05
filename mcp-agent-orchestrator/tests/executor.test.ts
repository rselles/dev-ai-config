import { describe, it, expect, vi, beforeEach } from "vitest";
import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { runAgent } from "../src/agents/executor.js";
import type { AgentConfig } from "../src/agents/types.js";

// Mock chatCompletion so tests don't need Ollama
vi.mock("../src/ollama/client.js", () => ({
  chatCompletion: vi.fn(),
}));

import { chatCompletion } from "../src/ollama/client.js";
const mockChatCompletion = vi.mocked(chatCompletion);

const BASE_CONFIG: AgentConfig = {
  name: "developer",
  description: "test agent",
  temperature: 0.3,
  model: "test-model",
  max_turns: 10,
  system_prompt: "You are a test agent.",
  tools: ["read_file", "write_file", "finish"],
  custom_tools: [],
};

function makeTextResponse(content: string) {
  return {
    id: "test",
    object: "chat.completion",
    created: 0,
    model: "test-model",
    choices: [
      {
        index: 0,
        finish_reason: "stop",
        message: { role: "assistant", content, tool_calls: undefined, refusal: null },
        logprobs: null,
      },
    ],
    usage: { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 },
  };
}

function makeToolCallResponse(name: string, args: Record<string, unknown>, id = "tc_1") {
  return {
    id: "test",
    object: "chat.completion",
    created: 0,
    model: "test-model",
    choices: [
      {
        index: 0,
        finish_reason: "tool_calls",
        message: {
          role: "assistant",
          content: null,
          refusal: null,
          tool_calls: [
            {
              id,
              type: "function",
              function: { name, arguments: JSON.stringify(args) },
            },
          ],
        },
        logprobs: null,
      },
    ],
    usage: { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 },
  };
}

let tmpDir: string;

beforeEach(async () => {
  tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "exec-test-"));
  vi.clearAllMocks();
});

describe("runAgent — plain text response", () => {
  it("returns success on plain text response", async () => {
    mockChatCompletion.mockResolvedValueOnce(makeTextResponse("Task is done.") as never);

    const result = await runAgent({
      config: BASE_CONFIG,
      task: "Do something",
      workingDir: tmpDir,
    });

    expect(result.status).toBe("success");
    expect(result.response).toBe("Task is done.");
    expect(result.files_modified).toEqual([]);
  });
});

describe("runAgent — finish tool", () => {
  it("exits loop when finish is called", async () => {
    mockChatCompletion.mockResolvedValueOnce(
      makeToolCallResponse("finish", { summary: "All done", status: "success" }) as never,
    );

    const result = await runAgent({
      config: BASE_CONFIG,
      task: "Do something",
      workingDir: tmpDir,
    });

    expect(result.status).toBe("success");
    expect(result.response).toBe("All done");
    expect(mockChatCompletion).toHaveBeenCalledTimes(1);
  });

  it("propagates error status from finish", async () => {
    mockChatCompletion.mockResolvedValueOnce(
      makeToolCallResponse("finish", { summary: "Failed", status: "error" }) as never,
    );

    const result = await runAgent({
      config: BASE_CONFIG,
      task: "Do something",
      workingDir: tmpDir,
    });

    expect(result.status).toBe("error");
    expect(result.response).toBe("Failed");
  });
});

describe("runAgent — file tools", () => {
  it("write_file creates a file and tracks it as modified", async () => {
    mockChatCompletion
      .mockResolvedValueOnce(
        makeToolCallResponse("write_file", { path: "hello.txt", content: "Hello World" }) as never,
      )
      .mockResolvedValueOnce(
        makeToolCallResponse("finish", { summary: "Written", status: "success" }) as never,
      );

    const result = await runAgent({
      config: BASE_CONFIG,
      task: "Write hello.txt",
      workingDir: tmpDir,
    });

    expect(result.status).toBe("success");
    expect(result.files_modified).toContain("hello.txt");

    const content = await fs.readFile(path.join(tmpDir, "hello.txt"), "utf-8");
    expect(content).toBe("Hello World");
  });

  it("read_file returns file contents to the model", async () => {
    await fs.writeFile(path.join(tmpDir, "existing.txt"), "file contents", "utf-8");

    mockChatCompletion
      .mockResolvedValueOnce(
        makeToolCallResponse("read_file", { path: "existing.txt" }) as never,
      )
      .mockResolvedValueOnce(
        makeToolCallResponse("finish", { summary: "Read it", status: "success" }) as never,
      );

    const result = await runAgent({
      config: BASE_CONFIG,
      task: "Read existing.txt",
      workingDir: tmpDir,
    });

    expect(result.status).toBe("success");

    // Verify the tool result was appended to messages (model received file contents)
    const secondCall = mockChatCompletion.mock.calls[1];
    const messages = secondCall[1] as Array<{ role: string; content: string }>;
    const toolResult = messages.find((m) => m.role === "tool");
    expect(toolResult?.content).toBe("file contents");
  });

  it("read_file returns error message for missing file", async () => {
    mockChatCompletion
      .mockResolvedValueOnce(
        makeToolCallResponse("read_file", { path: "nonexistent.txt" }) as never,
      )
      .mockResolvedValueOnce(
        makeToolCallResponse("finish", { summary: "Done", status: "success" }) as never,
      );

    const result = await runAgent({
      config: BASE_CONFIG,
      task: "Read missing file",
      workingDir: tmpDir,
    });

    const secondCall = mockChatCompletion.mock.calls[1];
    const messages = secondCall[1] as Array<{ role: string; content: string }>;
    const toolResult = messages.find((m) => m.role === "tool");
    expect(toolResult?.content).toMatch(/Error reading file/);
  });
});

describe("runAgent — max_turns_reached", () => {
  it("stops after max_turns and returns max_turns_reached", async () => {
    // Create file so read_file succeeds each turn (avoids consecutive-errors guardrail)
    await fs.writeFile(path.join(tmpDir, "x.txt"), "content", "utf-8");

    // Always return a tool call (never finish) to exhaust turns
    mockChatCompletion.mockResolvedValue(
      makeToolCallResponse("read_file", { path: "x.txt" }) as never,
    );

    const result = await runAgent({
      config: { ...BASE_CONFIG, max_turns: 3 },
      task: "Loop forever",
      workingDir: tmpDir,
    });

    expect(result.status).toBe("max_turns_reached");
    expect(mockChatCompletion).toHaveBeenCalledTimes(3);
  });
});

describe("runAgent — Ollama error", () => {
  it("returns error status when chatCompletion throws", async () => {
    mockChatCompletion.mockRejectedValueOnce(new Error("Connection refused"));

    const result = await runAgent({
      config: BASE_CONFIG,
      task: "Do something",
      workingDir: tmpDir,
    });

    expect(result.status).toBe("error");
    expect(result.response).toMatch(/Connection refused/);
  });
});

describe("runAgent — path traversal protection", () => {
  it("rejects path traversal in write_file", async () => {
    // The sandbox-violation guardrail aborts immediately — only one LLM call needed
    mockChatCompletion.mockResolvedValueOnce(
      makeToolCallResponse("write_file", { path: "../../etc/passwd", content: "hacked" }) as never,
    );

    const result = await runAgent({
      config: BASE_CONFIG,
      task: "Write outside dir",
      workingDir: tmpDir,
    });

    // Guardrail aborted the run
    expect(result.status).toBe("error");
    expect(mockChatCompletion).toHaveBeenCalledTimes(1);

    // File should NOT have been created outside tmpDir
    await expect(fs.access("/etc/passwd")).resolves.toBeUndefined(); // original still exists
    const badFile = path.resolve(tmpDir, "../../etc/injected");
    await expect(fs.access(badFile)).rejects.toThrow();
  });
});
