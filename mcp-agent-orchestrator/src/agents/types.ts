export type InternalToolName =
  | "read_file"
  | "write_file"
  | "exec_command"
  | "update_shared_state"
  | "finish";

export interface CustomToolParameter {
  type: string;
  required?: boolean;
  description?: string;
}

export interface CustomToolDef {
  name: string;
  description: string;
  parameters: Record<string, CustomToolParameter>;
}

export interface AgentConfig {
  name: string;
  description: string;
  temperature: number;
  model: string | null;
  max_turns: number;
  system_prompt: string;
  tools: InternalToolName[];
  custom_tools: CustomToolDef[];
}

export interface AgentResult {
  response: string;
  status: "success" | "error" | "max_turns_reached" | "cancelled";
  files_modified: string[];
  worktree_path?: string;
  turns_used: number;
}
