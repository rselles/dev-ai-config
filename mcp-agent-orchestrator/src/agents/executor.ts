import type { ChatCompletionMessageParam } from "openai/resources/chat/completions.js";
import { chatCompletion } from "../ollama/client.js";
import { config } from "../config.js";
import { buildToolDefs } from "./tool-defs.js";
import { handleTool, type ToolHandlerContext } from "./tool-handlers.js";
import { parseResponse } from "./response-parser.js";
import { buildMessages } from "./context-builder.js";
import type { AgentConfig, AgentResult } from "./types.js";
import { logger } from "../utils/logger.js";

export type ProgressCallback = (turn: number, maxTurns: number, message: string) => Promise<void>;

export interface RunAgentOptions {
  config: AgentConfig;
  task: string;
  workingDir: string;
  repoPath?: string;
  contextFiles?: string[];
  includeSharedState?: boolean;
  maxTurns?: number;
  model?: string;
  onProgress?: ProgressCallback;
}

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
    onProgress,
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
  let turnsUsed = 0;

  for (let turn = 0; turn < resolvedMaxTurns; turn++) {
    turnsUsed = turn + 1;
    logger.debug("Agent turn", { turn, role: agentConfig.name });

    if (onProgress) {
      await onProgress(turn, resolvedMaxTurns, `Turn ${turn + 1}/${resolvedMaxTurns}`);
    }

    let completion;
    try {
      completion = await chatCompletion(resolvedModel, messages, toolDefs, agentConfig.temperature);
    } catch (err) {
      logger.error("Ollama request failed", { error: (err as Error).message });
      finalStatus = "error";
      finalResponse = `Ollama error: ${(err as Error).message}`;
      break;
    }

    const parsed = parseResponse(completion);

    // Append assistant message
    messages.push(completion.choices[0].message as ChatCompletionMessageParam);

    if (!parsed.isToolCall) {
      // Plain text response — done
      finalResponse = parsed.textContent;
      finalStatus = "success";
      break;
    }

    // Process tool calls
    let didFinish = false;
    const toolResultMessages: ChatCompletionMessageParam[] = [];

    for (const toolCall of parsed.toolCalls) {
      const result = await handleTool(toolCall.name, toolCall.arguments, ctx);

      toolResultMessages.push({
        role: "tool",
        tool_call_id: toolCall.id,
        content: result.output,
      });

      if (result.isFinish) {
        finalResponse = result.finishSummary ?? "Task completed.";
        finalStatus = result.finishStatus ?? "success";
        didFinish = true;
      }
    }

    messages.push(...toolResultMessages);

    if (didFinish) break;
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
