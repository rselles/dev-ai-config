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
    case "read_file":           return `Reading ${args.path}`;
    case "write_file":          return `Writing ${args.path}`;
    case "exec_command":        return `Running: ${String(args.command ?? "").slice(0, 80)}`;
    case "update_shared_state": return `Updating shared state: ${args.file}`;
    case "finish":              return `Finished — "${String(args.summary ?? "").slice(0, 80)}"`;
    default:                    return `Tool: ${name}`;
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
      // Guardrail: blocklisted command — check BEFORE executing
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

      if (toolCall.name !== "finish") {
        await onLog(turn + 1, toolCallToEvent(toolCall.name, toolCall.arguments));
      }

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
