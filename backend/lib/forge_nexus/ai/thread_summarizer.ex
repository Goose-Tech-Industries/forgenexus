defmodule ForgeNexus.AI.ThreadSummarizer do
  @moduledoc """
  AI-powered thread summaries using Claude. Generates a concise summary of
  long threads for latecomers. Caches results and regenerates when post
  count changes significantly.
  """

  require Logger
  import Ecto.Query
  alias ForgeNexus.{Repo, Settings}

  @min_posts_for_summary 10
  @stale_threshold 5

  def get_or_generate(thread_id) do
    thread = ForgeNexus.Forums.get_thread!(thread_id)
    cached = get_cached(thread_id)

    cond do
      thread.reply_count < @min_posts_for_summary ->
        {:error, :thread_too_short}

      cached && (thread.reply_count - (cached.post_count_at_generation || 0)) < @stale_threshold ->
        {:ok, cached.summary}

      not Settings.get_bool("ai_thread_summary_enabled") ->
        if cached, do: {:ok, cached.summary}, else: {:error, :disabled}

      true ->
        generate_and_cache(thread)
    end
  end

  defp get_cached(thread_id) do
    from(s in "thread_summaries_ai", where: s.thread_id == ^thread_id)
    |> Repo.one()
  end

  defp generate_and_cache(thread) do
    posts = ForgeNexus.Forums.list_posts(thread.id, limit: 50)

    post_texts =
      posts
      |> Enum.map(fn p -> "#{p.user_id}: #{String.slice(p.body || "", 0, 500)}" end)
      |> Enum.join("\n\n")

    prompt = """
    Summarize this forum thread discussion in 2-3 paragraphs. Focus on the key points,
    any conclusions reached, and notable disagreements. Be neutral and factual.

    Thread title: #{thread.title}

    Posts:
    #{post_texts}
    """

    api_key = System.get_env("ANTHROPIC_API_KEY")

    if is_nil(api_key) or api_key == "" do
      {:error, :no_api_key}
    else
      model = Settings.get("ai_thread_summary_model") || "claude-haiku-4-5-20251001"

      case call_claude(api_key, model, prompt) do
        {:ok, summary} ->
          upsert_cache(thread, summary, model)
          {:ok, summary}

        error ->
          error
      end
    end
  end

  defp call_claude(api_key, model, prompt) do
    url = "https://api.anthropic.com/v1/messages"

    body = %{
      model: model,
      max_tokens: 1024,
      messages: [%{role: "user", content: prompt}]
    }

    headers = [
      {"x-api-key", api_key},
      {"anthropic-version", "2023-06-01"},
      {"content-type", "application/json"}
    ]

    try do
      case Req.post(url, headers: headers, json: body, receive_timeout: 60_000) do
        {:ok, %{status: 200, body: %{"content" => [%{"text" => text} | _]}}} ->
          {:ok, text}

        {:ok, %{status: status}} ->
          {:error, {:http, status}}

        {:error, reason} ->
          {:error, {:request_failed, reason}}
      end
    rescue
      e -> {:error, {:exception, Exception.message(e)}}
    end
  end

  defp upsert_cache(thread, summary, model) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case get_cached(thread.id) do
      nil ->
        Repo.insert_all("thread_summaries_ai", [
          %{
            id: Ecto.UUID.generate(),
            thread_id: thread.id,
            community_id: thread.community_id,
            summary: summary,
            post_count_at_generation: thread.reply_count,
            model: model,
            generated_at: now,
            inserted_at: now,
            updated_at: now
          }
        ])

      _existing ->
        from(s in "thread_summaries_ai", where: s.thread_id == ^thread.id)
        |> Repo.update_all(set: [
          summary: summary,
          post_count_at_generation: thread.reply_count,
          model: model,
          generated_at: now,
          updated_at: now
        ])
    end
  end
end
