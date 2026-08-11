defmodule ForgeNexus.Workers.AISentimentWorker do
  use Oban.Worker, queue: :ai, max_attempts: 2

  alias ForgeNexus.AI
  alias ForgeNexus.AI.Client
  alias ForgeNexus.Forums

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"post_id" => post_id}}) do
    unless AI.feature_enabled?(:sentiment), do: throw(:disabled)

    post = Forums.get_post!(post_id)

    messages = [
      %{
        role: "system",
        content: """
        Analyze the sentiment of this forum post. Return JSON:
        {"sentiment": -1.0 to 1.0, "emotions": ["emotion1", "emotion2"]}
        Scale: -1.0 = very negative, 0.0 = neutral, 1.0 = very positive.
        Emotions: happy, excited, grateful, neutral, confused, frustrated, angry, sad, sarcastic, humorous
        """
      },
      %{role: "user", content: post.body}
    ]

    case Client.complete(:sentiment, messages, metadata: %{post_id: post_id}) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, parsed} ->
            AI.upsert_post_sentiment(post_id, %{
              thread_id: post.thread_id,
              sentiment: parsed["sentiment"] || 0.0,
              emotion_tags: parsed["emotions"] || []
            })

          _ ->
            :ok
        end

      {:error, _} ->
        :ok
    end

    :ok
  catch
    :disabled -> :ok
  end
end
