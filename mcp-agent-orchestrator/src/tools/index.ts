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