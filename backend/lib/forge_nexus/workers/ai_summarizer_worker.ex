defmodule ForgeNexus.Workers.AISummarizerWorker do
  use Oban.Worker, queue: :ai, max_attempts: 3, unique: [period: 300]

  alias ForgeNexus.{AI, Forums}
  alias ForgeNexus.AI.Client

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"thread_id" => thread_id}}) do
    unless AI.feature_enabled?(:summarizer), do: throw(:disabled)

    thread = Forums.get_thread_by_id!(thread_id)
    posts = Forums.list_all_posts(thread_id)

    # Check if summary is already up-to-date
    existing = AI.get_thread_summary(thread_id)
    if existing && existing.post_count_at_generation == length(posts) do
      throw(:up_to_date)
    end

    # Only summarize threads with 10+ posts
    if length(posts) < 10, do: throw(:too_short)

    post_text = posts
    |> Enum.take(100)  # Cap at 100 posts to manage token usage
    |> Enum.map(fn p -> "#{p.user.username}: #{p.body}" end)
    |> Enum.join("\n---\n")

    messages = [
      %{role: "system", content: """
      Summarize this forum thread discussion. Return JSON:
      {
        "summary": "2-3 paragraph overview",
        "key_points": ["point 1", "point 2", ...],
        "participant_count": number
      }
      Focus on: main topic, key arguments/viewpoints, any consensus, unresolved questions.
      """},
      %{role: "user", content: "Thread: #{thread.title}\n\n#{post_text}"}
    ]

    case Client.complete(:summarizer, messages, metadata: %{thread_id: thread_id}) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, parsed} ->
            AI.upsert_thread_summary(thread_id, %{
              summary: parsed["summary"],
              key_points: parsed["key_points"] || [],
              participant_count: parsed["participant_count"] || 0,
              post_count_at_generation: length(posts),
              last_generated_at: DateTime.utc_now()
            })
          _ -> :ok
        end
      {:error, _} -> :ok
    end

    :ok
  catch
    :disabled -> :ok
    :up_to_date -> :ok
    :too_short -> :ok
  end
end
