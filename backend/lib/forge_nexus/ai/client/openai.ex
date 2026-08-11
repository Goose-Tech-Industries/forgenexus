defmodule ForgeNexus.AI.Client.OpenAI do
  @moduledoc "OpenAI API client."

  def complete(provider, messages, opts) do
    model = Keyword.get(opts, :model, provider.default_model || "gpt-4o")
    max_tokens = Keyword.get(opts, :max_tokens, provider.max_tokens_per_request || 4096)

    body = %{
      model: model,
      messages: messages,
      max_tokens: max_tokens,
      temperature: Keyword.get(opts, :temperature, 0.7)
    }

    case Req.post("https://api.openai.com/v1/chat/completions",
           json: body,
           headers: [{"Authorization", "Bearer #{provider.api_key_encrypted}"}],
           receive_timeout: 60_000
         ) do
      {:ok, %{status: 200, body: body}} ->
        choice = List.first(body["choices"])

        {:ok,
         %{
           content: choice["message"]["content"],
           input_tokens: body["usage"]["prompt_tokens"],
           output_tokens: body["usage"]["completion_tokens"]
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, "OpenAI API error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "OpenAI request failed: #{inspect(reason)}"}
    end
  end

  def embed(provider, text, opts) do
    model = Keyword.get(opts, :model, "text-embedding-3-small")

    case Req.post("https://api.openai.com/v1/embeddings",
           json: %{model: model, input: text},
           headers: [{"Authorization", "Bearer #{provider.api_key_encrypted}"}],
           receive_timeout: 30_000
         ) do
      {:ok, %{status: 200, body: body}} ->
        embedding = body["data"] |> List.first() |> Map.get("embedding")
        {:ok, embedding}

      {:ok, %{status: status, body: body}} ->
        {:error, "OpenAI embed error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "OpenAI embed failed: #{inspect(reason)}"}
    end
  end
end
