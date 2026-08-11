defmodule ForgeNexus.AI.Client do
  @moduledoc "Provider-agnostic AI client. Dispatches to OpenAI, Anthropic, or Ollama."

  alias ForgeNexus.AI
  alias ForgeNexus.AI.UsageLog
  alias ForgeNexus.Repo

  @doc "Send a completion request to the configured provider for a given feature."
  def complete(feature, messages, opts \\ []) do
    with {:ok, provider} <- AI.get_provider_for_feature(feature),
         start_time <- System.monotonic_time(:millisecond),
         {:ok, result} <- dispatch(provider, messages, opts),
         elapsed <- System.monotonic_time(:millisecond) - start_time do
      log_usage(provider, feature, result, elapsed, opts)
      {:ok, result.content}
    end
  end

  @doc "Generate embeddings for text."
  def embed(feature, text, opts \\ []) do
    with {:ok, provider} <- AI.get_provider_for_feature(feature) do
      dispatch_embed(provider, text, opts)
    end
  end

  defp dispatch(provider, messages, opts) do
    case provider.name do
      "openai" -> ForgeNexus.AI.Client.OpenAI.complete(provider, messages, opts)
      "anthropic" -> ForgeNexus.AI.Client.Anthropic.complete(provider, messages, opts)
      "ollama" -> ForgeNexus.AI.Client.Ollama.complete(provider, messages, opts)
      _ -> {:error, :unknown_provider}
    end
  end

  defp dispatch_embed(provider, text, opts) do
    case provider.name do
      "openai" -> ForgeNexus.AI.Client.OpenAI.embed(provider, text, opts)
      "ollama" -> ForgeNexus.AI.Client.Ollama.embed(provider, text, opts)
      _ -> {:error, :embeddings_not_supported}
    end
  end

  defp log_usage(provider, feature, result, elapsed_ms, opts) do
    %UsageLog{}
    |> UsageLog.changeset(%{
      provider_id: provider.id,
      feature: to_string(feature),
      input_tokens: result[:input_tokens] || 0,
      output_tokens: result[:output_tokens] || 0,
      cost_cents: estimate_cost(provider, result),
      latency_ms: elapsed_ms,
      user_id: Keyword.get(opts, :user_id),
      metadata: Keyword.get(opts, :metadata, %{})
    })
    |> Repo.insert()
  end

  defp estimate_cost(provider, result) do
    # Rough cost estimates per 1K tokens (in hundredths of a cent)
    {input_rate, output_rate} =
      case provider.default_model do
        "gpt-4o" -> {0.25, 1.0}
        "gpt-4o-mini" -> {0.015, 0.06}
        m when m in ["claude-sonnet-4-6-20251001", "claude-sonnet-4-6-20251001"] -> {0.3, 1.5}
        "claude-haiku-4-5-20251001" -> {0.025, 0.125}
        # Local/Ollama = free
        _ -> {0.0, 0.0}
      end

    input_cost = (result[:input_tokens] || 0) / 1000 * input_rate
    output_cost = (result[:output_tokens] || 0) / 1000 * output_rate
    # Store as cents
    round((input_cost + output_cost) * 100)
  end
end
