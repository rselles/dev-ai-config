import OpenAI from "openai";
import { config } from "../config.js";
import type { ChatCompletionMessageParam, ChatCompletionTool } from "openai/resources/chat/completions.js";

let _client: OpenAI | null = null;

function getClient(): OpenAI {
  if (!_client) {
    _client = new OpenAI({
      baseURL: config.ollamaBaseUrl,
      apiKey: "ollama", // Ollama doesn't require a real key
    });
  }
  return _client;
}

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
