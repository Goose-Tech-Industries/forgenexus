defmodule ForgeNexus.Workers.AITranslationWorker do
  use Oban.Worker, queue: :ai, max_attempts: 2

  alias ForgeNexus.{AI, Forums}
  alias ForgeNexus.AI.Client

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"post_id" => post_id, "target_language" => target_lang}}) do
    unless AI.feature_enabled?(:translation), do: throw(:disabled)

    # Check cache first
    if AI.get_translation(post_id, target_lang), do: throw(:cached)

    post = Forums.get_post!(post_id)

    messages = [
      %{role: "system", content: "Translate the following forum post to #{target_lang}. Preserve formatting, BBCode tags, and @mentions. Return only the translated text, no explanation."},
      %{role: "user", content: post.body}
    ]

    case Client.complete(:translation, messages, metadata: %{post_id: post_id, target: target_lang}) do
      {:ok, translated} ->
        AI.create_translation(%{
          post_id: post_id,
          source_language: "en",
          target_language: target_lang,
          translated_body: translated
        })
      {:error, _} -> :ok
    end

    :ok
  catch
    :disabled -> :ok
    :cached -> :ok
  end
end
