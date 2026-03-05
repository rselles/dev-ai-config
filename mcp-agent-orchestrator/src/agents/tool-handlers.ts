import fs from "node:fs/promises";
import path from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { resolveSafe } from "../utils/sandbox.js";
import { updateSharedState } from "../state/shared-state.js";
import type { UpdateOperation, SharedStateFile } from "../state/shared-state.js";
import { logger } from "../utils/logger.js";

const execFileAsync = promisify(execFile);

const MAX_OUTPUT_CHARS = 20_000;
const DEFAULT_TIMEOUT_MS = 30_000;
const MAX_TIMEOUT_MS = 120_000;

export interface ToolHandlerContext {
  workingDir: string;
  repoPath?: string;
  filesModified: Set<string>;
}

export interface ToolResult {
  output: string;
  isFinish?: boolean;
  finishSummary?: string;
  finishStatus?: "success" | "error";
  isError?: boolean;            // true when the tool call itself failed
  isSandboxViolation?: boolean; // true when path escapes working dir
}

export async function handleTool(
  toolName: string,
  toolArgs: Record<string, unknown>,
  ctx: ToolHandlerContext,
): Promise<ToolResult> {
  switch (toolName) {
    case "read_file":
      return handleReadFile(toolArgs, ctx);
    case "write_file":
      return handleWriteFile(toolArgs, ctx);
    case "exec_command":
      return handleExecCommand(toolArgs, ctx);
    case "update_shared_state":
      return handleUpdateSharedState(toolArgs, ctx);
    case "finish":
      return {
        output: "Task marked as finished.",
        isFinish: true,
        finishSummary: (toolArgs.summary as string) ?? "Task completed.",
        finishStatus: (toolArgs.status as "success" | "error") ?? "success",
      };
    default:
      logger.warn("Unknown tool called", { toolName });
      return { output: `Unknown tool: ${toolName}` };
  }
}

async function handleReadFile(
  args: Record<string, unknown>,
  ctx: ToolHandlerContext,
): Promise<ToolResult> {
  const filePath = args.path as string;
  try {
    const safePath = resolveSafe(ctx.workingDir, filePath);
    const content = await fs.readFile(safePath, "utf-8");
    const truncated = content.length > MAX_OUTPUT_CHARS
      ? content.slice(0, MAX_OUTPUT_CHARS) + "\n[... file truncated ...]"
      : content;
    return { output: truncated };
  } catch (err) {
    const isSandboxViolation = (err as Error).message.includes("escapes");
    return {
      output: `Error reading file "${filePath}": ${(err as Error).message}`,
      isError: true,
      isSandboxViolation,
    };
  }
}

async function handleWriteFile(
  args: Record<string, unknown>,
  ctx: ToolHandlerContext,
): Promise<ToolResult> {
  const filePath = args.path as string;
  const content = args.content as string;
  try {
    const safePath = resolveSafe(ctx.workingDir, filePath);
    await fs.mkdir(path.dirname(safePath), { recursive: true });
    await fs.writeFile(safePath, content, "utf-8");
    ctx.filesModified.add(filePath);
    return { output: `File written: ${filePath}` };
  } catch (err) {
    const isSandboxViolation = (err as Error).message.includes("escapes");
    return {
      output: `Error writing file "${filePath}": ${(err as Error).message}`,
      isError: true,
      isSandboxViolation,
    };
  }
}

async function handleExecCommand(
  args: Record<string, unknown>,
  ctx: ToolHandlerContext,
): Promise<ToolResult> {
  const command = args.command as string;
  const timeoutMs = Math.min(
    (args.timeout_ms as number | undefined) ?? DEFAULT_TIMEOUT_MS,
    MAX_TIMEOUT_MS,
  );

  logger.info("Executing command", { command, timeoutMs, cwd: ctx.workingDir });

  try {
    const { stdout, stderr } = await execFileAsync("sh", ["-c", command], {
      cwd: ctx.workingDir,
      timeout: timeoutMs,
      maxBuffer: MAX_OUTPUT_CHARS,
    });

    const output = [
      stdout ? `STDOUT:\n${stdout}` : "",
      stderr ? `STDERR:\n${stderr}` : "",
    ]
      .filter(Boolean)
      .join("\n")
      .trim();

    return { output: output || "(no output)" };
  } catch (err) {
    const error = err as NodeJS.ErrnoException & { stdout?: string; stderr?: string; killed?: boolean };
    const parts = [
      error.killed ? "Command timed out." : `Command failed (exit ${(err as { code?: number }).code ?? "?"}).`,
      error.stdout ? `STDOUT:\n${error.stdout}` : "",
      error.stderr ? `STDERR:\n${error.stderr}` : "",
    ].filter(Boolean);
    return { output: parts.join("\n") };
  }
}

async function handleUpdateSharedState(
  args: Record<string, unknown>,
  ctx: ToolHandlerContext,
): Promise<ToolResult> {
  const repoPath = ctx.repoPath ?? ctx.workingDir;
  const file = args.file as SharedStateFile;
  const operation = args.operation as UpdateOperation;
  const content = args.content as string;
  const sectionHeading = args.section_heading as string | undefined;

  try {
    await updateSharedState(repoPath, file, operation, content, sectionHeading);
    return { output: `Updated ${file} (operation: ${operation})` };
  } catch (err) {
    return { output: `Error updating ${file}: ${(err as Error).message}` };
  }
}
