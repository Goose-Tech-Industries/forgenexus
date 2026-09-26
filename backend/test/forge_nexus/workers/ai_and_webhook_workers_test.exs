defmodule ForgeNexus.Workers.AIAndWebhookWorkersTest do
  use ForgeNexus.DataCase, async: false
  use Oban.Testing, repo: ForgeNexus.Repo

  alias ForgeNexus.{Accounts, Forums, Repo, Settings}
  alias ForgeNexus.AI.{CommunitySentiment, PostSentiment}
  alias ForgeNexus.Forums.{ForumWebhook, WebhookDelivery}

  alias ForgeNexus.Workers.{
    AIModerationWorker,
    AISentimentDailyWorker,
    AISentimentWorker,
    AISummarizerWorker,
    AITaggingWorker,
    AITranslationWorker,
    ForumWebhookWorker
  }

  defp create_user(attrs \\ %{}) do
    unique_suffix = System.unique_integer([:positive])

    defaults = %{
      username: "ai_user_#{unique_suffix}",
      email: "ai_user_#{unique_suffix}@example.com",
      password: "SecurePass!987654#Alpha",
      password_confirmation: "SecurePass!987654#Alpha"
    }

    {:ok, user} =
      defaults
      |> Map.merge(Enum.into(attrs, %{}))
      |> Accounts.register_user()

    user
  end

  defp create_forum_and_thread(user) do
    unique_suffix = System.unique_integer([:positive])

    {:ok, category} =
      Forums.create_category(%{
        name: "AI Category #{unique_suffix}"
      })

    {:ok, forum} =
      Forums.create_forum(%{
        name: "AI Forum #{unique_suffix}",
        description: "Forum for AI worker tests",
        category_id: category.id,
        position: 0
      })

    {:ok, thread} =
      Forums.create_thread(%{
        title: "AI Thread #{unique_suffix}",
        body: "Thread body content for testing AI features",
        user_id: user.id,
        forum_id: forum.id
      })

    [post | _] = Forums.list_posts(thread.id)
    {forum, thread, post}
  end

  describe "AIModerationWorker" do
    test "completes gracefully when feature is disabled" do
      # ai_global_enabled is false by default in tests
      assert :ok = perform_job(AIModerationWorker, %{"report_id" => Ecto.UUID.generate()})
    end
  end

  describe "AISentimentWorker" do
    test "completes gracefully when feature is disabled" do
      assert :ok = perform_job(AISentimentWorker, %{"post_id" => Ecto.UUID.generate()})
    end
  end

  describe "AISentimentDailyWorker" do
    test "aggregates yesterday's post sentiment and records CommunitySentiment" do
      user = create_user()
      {_forum, thread, post} = create_forum_and_thread(user)
      yesterday = Date.utc_today() |> Date.add(-1)
      yesterday_dt = NaiveDateTime.new!(yesterday, ~T[12:00:00])

      # Seed sentiment entries for yesterday
      %PostSentiment{}
      |> PostSentiment.changeset(%{
        post_id: post.id,
        thread_id: thread.id,
        sentiment: 0.8,
        emotion_tags: ["happy", "grateful"]
      })
      |> Repo.insert!()
      |> Ecto.Changeset.change(%{inserted_at: yesterday_dt})
      |> Repo.update!()

      assert :ok = perform_job(AISentimentDailyWorker, %{})

      community_sentiment = Repo.get_by(CommunitySentiment, date: yesterday)
      assert community_sentiment != nil
      assert community_sentiment.total_posts_analyzed == 1
      assert is_map(community_sentiment.top_emotions)
    end
  end

  describe "AISummarizerWorker" do
    test "completes gracefully when disabled" do
      assert :ok = perform_job(AISummarizerWorker, %{"thread_id" => Ecto.UUID.generate()})
    end

    test "handles thread too short (< 10 posts) when feature is enabled" do
      user = create_user()
      {_forum, thread, _post} = create_forum_and_thread(user)

      Settings.set("ai_global_enabled", "true")
      # Enable summarizer feature setting
      Repo.insert!(%ForgeNexus.AI.FeatureSetting{
        feature: "summarizer",
        enabled: true,
        config: %{"model" => "gpt-4o"}
      })

      assert :ok = perform_job(AISummarizerWorker, %{"thread_id" => thread.id})

      # Reset
      Settings.set("ai_global_enabled", "false")
    end
  end

  describe "AITaggingWorker" do
    test "completes gracefully when disabled" do
      assert :ok = perform_job(AITaggingWorker, %{"thread_id" => Ecto.UUID.generate()})
    end
  end

  describe "AITranslationWorker" do
    test "completes gracefully when disabled" do
      assert :ok =
               perform_job(AITranslationWorker, %{
                 "post_id" => Ecto.UUID.generate(),
                 "target_language" => "es"
               })
    end
  end

  describe "ForumWebhookWorker" do
    test "handles non-existent webhook id gracefully" do
      assert :ok =
               perform_job(ForumWebhookWorker, %{
                 "webhook_id" => Ecto.UUID.generate(),
                 "event" => "forum.thread.created",
                 "payload" => %{"thread_id" => "123"}
               })
    end

    test "skips inactive webhook gracefully" do
      user = create_user()

      {:ok, webhook} =
        %ForumWebhook{}
        |> ForumWebhook.changeset(%{
          name: "Inactive Webhook",
          url: "https://example.com/inactive",
          events: ["forum.thread.created"],
          is_active: false,
          created_by_id: user.id
        })
        |> Repo.insert()

      assert :ok =
               perform_job(ForumWebhookWorker, %{
                 "webhook_id" => webhook.id,
                 "event" => "forum.thread.created",
                 "payload" => %{"thread_id" => "123"}
               })
    end

    test "delivers to webhook url, records failure and increments failure count on connection error" do
      user = create_user()

      {:ok, webhook} =
        %ForumWebhook{}
        |> ForumWebhook.changeset(%{
          name: "Test Failure Webhook",
          url: "http://127.0.0.1:59999/webhook/nonexistent",
          events: ["forum.thread.created"],
          is_active: true,
          failure_count: 9,
          created_by_id: user.id
        })
        |> Repo.insert()

      # Delivery to closed port will fail, recording failure and disabling webhook on 10th failure
      assert {:error, _reason} =
               perform_job(ForumWebhookWorker, %{
                 "webhook_id" => webhook.id,
                 "event" => "forum.thread.created",
                 "payload" => %{"thread_id" => "123"}
               })

      # Verify delivery failure was logged
      deliveries =
        Repo.all(from(d in WebhookDelivery, where: d.webhook_id == ^webhook.id))

      assert length(deliveries) == 1
      delivery = hd(deliveries)
      assert delivery.event_type == "forum.thread.created"
      assert delivery.error != nil

      # Verify webhook was disabled after reaching 10 consecutive failures
      updated_webhook = Repo.get!(ForumWebhook, webhook.id)
      assert updated_webhook.failure_count == 10
      assert updated_webhook.is_active == false
    end
  end
end
