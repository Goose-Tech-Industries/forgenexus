defmodule ForgeNexus.AI.Client.Ollama do
  @moduledoc "Ollama local LLM client."

  def complete(provider, messages, opts) do
    base_url = provider.base_url || "http://localhost:11434"
    model = Keyword.get(opts, :model, provider.default_model || "llama3")

    body = %{
      model: model,
      messages: messages,
      stream: false
    }

    case Req.post("#{base_url}/api/chat",
           json: body,
           receive_timeout: 120_000
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok,
         %{
           content: body["message"]["content"],
           input_tokens: body["prompt_eval_count"] || 0,
           output_tokens: body["eval_count"] || 0
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, "Ollama error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Ollama request failed: #{inspect(reason)}"}
    end
  end

  def embed(provider, text, opts) do
    base_url = provider.base_url || "http://localhost:11434"
    model = Keyword.get(opts, :model, "nomic-embed-text")

    case Req.post("#{base_url}/api/embeddings",
           json: %{model: model, prompt: text},
           receive_timeout: 30_000
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body["embedding"]}

      {:ok, %{status: status, body: body}} ->
        {:error, "Ollama embed error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Ollama embed failed: #{inspect(reason)}"}
    end
  end
end
