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
