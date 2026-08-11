defmodule ForgeNexus.Workers.AITaggingWorker do
  use Oban.Worker, queue: :ai, max_attempts: 2

  alias ForgeNexus.{AI, Forums}
  alias ForgeNexus.AI.Client

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"thread_id" => thread_id}}) do
    unless AI.feature_enabled?(:tagging), do: throw(:disabled)

    thread = Forums.get_thread_by_id!(thread_id)
    first_post = Forums.get_first_post(thread_id)
    forum = Forums.get_forum!(thread.forum_id)

    # Get existing tags and prefixes for context
    existing_prefixes = Forums.list_prefixes(forum.id) |> Enum.map(& &1.name)

    messages = [
      %{
        role: "system",
        content: """
        Analyze this forum post and suggest categorization. Return JSON:
        {
          "tags": ["tag1", "tag2", "tag3"],
          "content_type": "question|discussion|announcement|tutorial|showcase",
          "suggested_prefix": "prefix or null",
          "confidence": 0.0-1.0
        }
        Available prefixes: #{Enum.join(existing_prefixes, ", ")}
        Forum: #{forum.name} - #{forum.description}
        """
      },
      %{
        role: "user",
        content: "Title: #{thread.title}\n\nBody: #{if first_post, do: first_post.body, else: ""}"
      }
    ]

    case Client.complete(:tagging, messages, metadata: %{thread_id: thread_id}) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, parsed} ->
            AI.create_tag_suggestion(%{
              thread_id: thread_id,
              suggested_tags: parsed["tags"] || [],
              suggested_prefix: parsed["suggested_prefix"],
              content_type: parsed["content_type"],
              confidence: parsed["confidence"] || 0.5
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
