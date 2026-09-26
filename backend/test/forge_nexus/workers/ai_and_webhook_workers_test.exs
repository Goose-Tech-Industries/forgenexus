defmodule ForgeNexus.Workers.AIAndWebhookWorkersTest do
  use ForgeNexus.DataCase, async: false
  use Oban.Testing, repo: ForgeNexus.Repo

  alias ForgeNexus.{Accounts, Forums, Moderation, Repo, Settings}
  alias ForgeNexus.AI
  alias ForgeNexus.AI.{CommunitySentiment, PostSentiment}
  alias ForgeNexus.Forums.{ForumWebhook, WebhookDelivery}
  alias ForgeNexus.TestMockHttpServer

  alias ForgeNexus.Workers.{
    AIModerationWorker,
    AISentimentDailyWorker,
    AISentimentWorker,
    AISummarizerWorker,
    AITaggingWorker,
    AITranslationWorker,
    ForumWebhookWorker
  }

  setup do
    {server_pid, port} = TestMockHttpServer.start()

    on_exit(fn ->
      if Process.alive?(server_pid), do: Process.exit(server_pid, :shutdown)
    end)

    {:ok, provider} =
      AI.create_provider(%{
        name: "ollama",
        base_url: "http://127.0.0.1:#{port}",
        is_active: true,
        priority: 1,
        default_model: "llama3"
      })

    %{server_pid: server_pid, port: port, provider: provider}
  end

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

    test "analyzes reported content and creates moderation analysis when enabled", %{
      provider: provider
    } do
      user = create_user()
      reporter = create_user()
      {_forum, _thread, post} = create_forum_and_thread(user)

      {:ok, report} =
        Moderation.create_report(
          %{
            reason: "spam",
            description: "Contains unsolicited advertising links",
            reportable_type: "post",
            reportable_id: post.id
          },
          reporter
        )

      Settings.set("ai_global_enabled", "true")
      AI.upsert_feature_setting(:moderation, %{enabled: true, provider_id: provider.id})

      assert :ok = perform_job(AIModerationWorker, %{"report_id" => report.id})

      analysis = Repo.get_by(AI.ModerationAnalysis, report_id: report.id)
      assert analysis != nil
      assert analysis.suggested_action == "warn"
      assert analysis.confidence == 0.95
      assert analysis.reasoning == "Content violates spam policy."

      Settings.set("ai_global_enabled", "false")
    end
  end

  describe "AISentimentWorker" do
    test "completes gracefully when feature is disabled" do
      assert :ok = perform_job(AISentimentWorker, %{"post_id" => Ecto.UUID.generate()})
    end

    test "analyzes and persists post sentiment when enabled", %{provider: provider} do
      user = create_user()
      {_forum, _thread, post} = create_forum_and_thread(user)

      Settings.set("ai_global_enabled", "true")
      AI.upsert_feature_setting(:sentiment, %{enabled: true, provider_id: provider.id})

      assert :ok = perform_job(AISentimentWorker, %{"post_id" => post.id})

      sentiment = Repo.get_by(AI.PostSentiment, post_id: post.id)
      assert sentiment != nil
      assert sentiment.sentiment == 0.85
      assert sentiment.emotion_tags == ["happy", "grateful"]

      Settings.set("ai_global_enabled", "false")
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

    test "handles thread too short (< 10 posts) when feature is enabled", %{provider: provider} do
      user = create_user()
      {_forum, thread, _post} = create_forum_and_thread(user)

      Settings.set("ai_global_enabled", "true")
      AI.upsert_feature_setting(:summarizer, %{enabled: true, provider_id: provider.id})

      assert :ok = perform_job(AISummarizerWorker, %{"thread_id" => thread.id})

      Settings.set("ai_global_enabled", "false")
    end

    test "summarizes thread with 10+ posts and caches summary", %{provider: provider} do
      user = create_user()
      {_forum, thread, _post} = create_forum_and_thread(user)

      # Create 9 more posts to make length 10
      for i <- 1..9 do
        {:ok, _} =
          Forums.create_post(%{
            body: "Additional reply content number #{i}",
            thread_id: thread.id,
            user_id: user.id
          })
      end

      Settings.set("ai_global_enabled", "true")
      AI.upsert_feature_setting(:summarizer, %{enabled: true, provider_id: provider.id})

      assert :ok = perform_job(AISummarizerWorker, %{"thread_id" => thread.id})

      summary = AI.get_thread_summary(thread.id)
      assert summary != nil
      assert summary.summary == "This is a detailed summary of the conversation."
      assert summary.key_points == ["Important point 1", "Important point 2"]
      assert summary.participant_count == 3
      assert summary.post_count_at_generation == 10

      # Re-running immediately hits up_to_date branch
      assert :ok = perform_job(AISummarizerWorker, %{"thread_id" => thread.id})

      Settings.set("ai_global_enabled", "false")
    end
  end

  describe "AITaggingWorker" do
    test "completes gracefully when disabled" do
      assert :ok = perform_job(AITaggingWorker, %{"thread_id" => Ecto.UUID.generate()})
    end

    test "suggests tags and content type when enabled", %{provider: provider} do
      user = create_user()
      {_forum, thread, _post} = create_forum_and_thread(user)

      Settings.set("ai_global_enabled", "true")
      AI.upsert_feature_setting(:tagging, %{enabled: true, provider_id: provider.id})

      assert :ok = perform_job(AITaggingWorker, %{"thread_id" => thread.id})

      suggestion = Repo.get_by(AI.TagSuggestion, thread_id: thread.id)
      assert suggestion != nil
      assert suggestion.suggested_tags == ["gaming", "strategy"]
      assert suggestion.content_type == "discussion"
      assert suggestion.suggested_prefix == "Guide"
      assert suggestion.confidence == 0.9

      Settings.set("ai_global_enabled", "false")
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

    test "translates post body and handles cached translations", %{provider: provider} do
      user = create_user()
      {_forum, _thread, post} = create_forum_and_thread(user)

      Settings.set("ai_global_enabled", "true")
      AI.upsert_feature_setting(:translation, %{enabled: true, provider_id: provider.id})

      assert :ok =
               perform_job(AITranslationWorker, %{
                 "post_id" => post.id,
                 "target_language" => "fr"
               })

      translation = Repo.get_by(AI.PostTranslation, post_id: post.id, target_language: "fr")
      assert translation != nil
      assert translation.translated_body == "Ceci est une traduction automatique."

      # Re-running hits :cached branch
      assert :ok =
               perform_job(AITranslationWorker, %{
                 "post_id" => post.id,
                 "target_language" => "fr"
               })

      Settings.set("ai_global_enabled", "false")
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

    test "delivers to webhook url successfully when endpoint returns 200", %{port: port} do
      user = create_user()

      {:ok, webhook} =
        %ForumWebhook{}
        |> ForumWebhook.changeset(%{
          name: "Success Webhook",
          url: "http://127.0.0.1:#{port}/webhook/success",
          secret: "supersecretkey12345",
          events: ["forum.thread.created"],
          is_active: true,
          failure_count: 3,
          created_by_id: user.id
        })
        |> Repo.insert()

      assert :ok =
               perform_job(ForumWebhookWorker, %{
                 "webhook_id" => webhook.id,
                 "event" => "forum.thread.created",
                 "payload" => %{"thread_id" => "123"}
               })

      deliveries = Repo.all(from(d in WebhookDelivery, where: d.webhook_id == ^webhook.id))
      assert length(deliveries) == 1
      delivery = hd(deliveries)
      assert delivery.response_status == 200
      assert String.contains?(delivery.response_body, "delivered")

      updated_webhook = Repo.get!(ForumWebhook, webhook.id)
      assert updated_webhook.failure_count == 0
      assert updated_webhook.last_triggered_at != nil
    end

    test "records delivery error and increments failure count when endpoint returns 500", %{
      port: port
    } do
      user = create_user()

      {:ok, webhook} =
        %ForumWebhook{}
        |> ForumWebhook.changeset(%{
          name: "500 Error Webhook",
          url: "http://127.0.0.1:#{port}/webhook/error",
          secret: "supersecretkey12345",
          events: ["forum.thread.created"],
          is_active: true,
          failure_count: 2,
          created_by_id: user.id
        })
        |> Repo.insert()

      assert {:error, "HTTP 500"} =
               perform_job(ForumWebhookWorker, %{
                 "webhook_id" => webhook.id,
                 "event" => "forum.thread.created",
                 "payload" => %{"thread_id" => "123"}
               })

      deliveries = Repo.all(from(d in WebhookDelivery, where: d.webhook_id == ^webhook.id))
      assert length(deliveries) == 1
      delivery = hd(deliveries)
      assert delivery.response_status == 500
      assert delivery.error == "HTTP 500"

      updated_webhook = Repo.get!(ForumWebhook, webhook.id)
      assert updated_webhook.failure_count == 3
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
