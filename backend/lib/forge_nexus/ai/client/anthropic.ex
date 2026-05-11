defmodule ForgeNexus.AI.Client.Anthropic do
  @moduledoc "Anthropic Claude API client."

  def complete(provider, messages, opts) do
    model = Keyword.get(opts, :model, provider.default_model || "claude-sonnet-4-6-20251001")
    max_tokens = Keyword.get(opts, :max_tokens, provider.max_tokens_per_request || 4096)

    # Anthropic uses system as separate param
    {system_msg, user_messages} = extract_system(messages)

    body = %{
      model: model,
      max_tokens: max_tokens,
      messages: user_messages
    }
    body = if system_msg, do: Map.put(body, :system, system_msg), else: body

    case Req.post("https://api.anthropic.com/v1/messages",
      json: body,
      headers: [
        {"x-api-key", provider.api_key_encrypted},
        {"anthropic-version", "2023-06-01"},
        {"content-type", "application/json"}
      ],
      receive_timeout: 60_000
    ) do
      {:ok, %{status: 200, body: body}} ->
        content = body["content"] |> List.first() |> Map.get("text", "")
        {:ok, %{
          content: content,
          input_tokens: body["usage"]["input_tokens"],
          output_tokens: body["usage"]["output_tokens"]
        }}

      {:ok, %{status: status, body: body}} ->
        {:error, "Anthropic API error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Anthropic request failed: #{inspect(reason)}"}
    end
  end

  defp extract_system(messages) do
    case Enum.split_with(messages, &(&1["role"] == "system" || &1[:role] == "system")) do
      {[], rest} -> {nil, rest}
      {[sys | _], rest} -> {sys["content"] || sys[:content], rest}
    end
  end
end
