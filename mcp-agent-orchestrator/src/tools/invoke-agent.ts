import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { runAgent } from "../agents/executor.js";
import type { OnLog } from "../agents/executor.js";
import { getAgent } from "../agents/registry.js";
import { createWorktree } from "../worktree/manager.js";
import { logger } from "../utils/logger.js";
import { createRun, getState, appendLog, updateStatus } from "../state/run-registry.js";

// Role enum is built dynamically from registry at registration time
const FALLBACK_ROLES = [
  "developer",
  "investigator",
  "docs-writer",
  "refactor",
  "test-writer",
  "architect",
  "reviewer",
] as const;

export function registerInvokeAgentTool(server: McpServer, roles: string[]): void {
  const roleEnum = roles.length > 0 ? roles : [...FALLBACK_ROLES];

  server.tool(
    "invoke_agent",
    "Dispatch a task to an Ollama-powered worker agent. The agent runs in an isolated git worktree (or provided directory) and can read/write files and run commands.",
    {
      role: z
        .enum(roleEnum as [string, ...string[]])
        .describe("Agent role to invoke"),
      task: z.string().describe("What the agent should accomplish"),
      repo_path: z.string().describe("Path to the git repository"),
      working_dir: z
        .string()
        .optional()
        .describe("Directory to run in. If omitted, a new worktree is created automatically."),
      branch_name: z
        .string()
        .optional()
        .describe("Branch name for auto-created worktree (default: auto-generated)"),
      context_files: z
        .array(z.string())
        .default([])
        .describe("File paths (relative to working_dir) to inject into context"),
      max_turns: z
        .number()
        .int()
        .min(1)
        .max(50)
        .optional()
        .describe("Max tool-use turns (overrides agent config default)"),
      include_shared_state: z
        .boolean()
        .default(true)
        .describe("Inject PLAN.md/DOCS.md into agent context"),
      model: z
        .string()
        .optional()
        .describe("Override Ollama model for this invocation"),
    },
    async ({
      role,
      task,
      repo_path,
      working_dir,
      branch_name,
      context_files,
      max_turns,
      include_shared_state,
      model,
    }, extra) => {
      logger.info("invoke_agent called", { role, repo_path, working_dir });

      // Load agent config
      const agentConfig = await getAgent(role);
      if (!agentConfig) {
        return {
          content: [
            {
              type: "text",
              text: `No agent config found for role "${role}". Available roles: ${roleEnum.join(", ")}`,
            },
          ],
          isError: true,
        };
      }

      // Create a run in the registry
      const runId = createRun(role, task);
      const runState = getState(runId)!;

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
            content: [
              {
                type: "text",
                text: `Failed to create worktree: ${(err as Error).message}`,
              },
            ],
            isError: true,
          };
        }
      }

      // Build log callback
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

        if (result.status === "success") {
          updateStatus(runId, "completed");
        } else {
          updateStatus(runId, result.status);
        }

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
  );
}
