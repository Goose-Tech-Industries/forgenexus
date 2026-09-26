defmodule ForgeNexus.AITest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.AI

  alias ForgeNexus.AI.{
    Provider,
    FeatureSetting,
    UsageLog,
    ModerationAnalysis,
    ThreadSummary,
    TagSuggestion,
    PostSentiment,
    CommunitySentiment,
    PostTranslation,
    Client,
    ThreadSummarizer
  }

  alias ForgeNexus.Accounts
  alias ForgeNexus.Forums
  alias ForgeNexus.Repo
  alias ForgeNexus.Settings

  defp create_user do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "ai_u_#{unique}",
        email: "ai_u_#{unique}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp create_forum_and_thread(user) do
    unique = System.unique_integer([:positive])

    {:ok, cat} =
      Forums.create_category(%{
        name: "AI Category #{unique}",
        slug: "ai-cat-#{unique}",
        position: 1
      })

    {:ok, forum} =
      Forums.create_forum(%{
        name: "AI Forum #{unique}",
        slug: "ai-forum-#{unique}",
        category_id: cat.id
      })

    {:ok, thread} =
      Forums.create_thread(%{
        title: "AI Test Thread #{unique}",
        body: "First post in thread",
        forum_id: forum.id,
        user_id: user.id
      })

    post = Repo.get_by!(ForgeNexus.Forums.Post, thread_id: thread.id)
    {forum, thread, post}
  end

  defp provider_attrs(provider_name, overrides \\ %{}) do
    Map.merge(
      %{
        name: provider_name,
        display_name: "Test #{provider_name} #{System.unique_integer([:positive])}",
        api_key_encrypted: "sk-test-fake-key",
        default_model: "gpt-4o",
        is_active: true,
        priority: 1
      },
      overrides
    )
  end

  describe "providers management" do
    test "create, list, get, update, and delete provider" do
      attrs = provider_attrs("custom")
      assert {:ok, %Provider{} = prov} = AI.create_provider(attrs)
      assert prov.name == "custom"
      assert prov.is_active == true

      # list_providers
      all = AI.list_providers()
      assert Enum.any?(all, &(&1.id == prov.id))

      # get_provider!
      assert AI.get_provider!(prov.id).id == prov.id

      # update_provider
      assert {:ok, updated} = AI.update_provider(prov, %{priority: 5})
      assert updated.priority == 5

      # delete_provider
      assert {:ok, _deleted} = AI.delete_provider(prov)
      assert_raise Ecto.NoResultsError, fn -> AI.get_provider!(prov.id) end
    end

    test "get_provider_for_feature/1 with fallback and explicit configuration" do
      # Clean state: no providers active initially
      assert AI.get_provider_for_feature(:thread_summary) == {:error, :no_active_provider}

      {:ok, prov_openai} =
        AI.create_provider(provider_attrs("openai", %{priority: 10, is_active: true}))

      {:ok, prov_anthropic} =
        AI.create_provider(provider_attrs("anthropic", %{priority: 1, is_active: true}))

      # Highest priority is returned first (priority: 1 is higher than 10)
      assert {:ok, best} = AI.get_provider_for_feature(:thread_summary)
      assert best.id == prov_anthropic.id

      # Explicit feature provider
      {:ok, _} =
        AI.upsert_feature_setting(:moderation, %{
          enabled: true,
          provider_id: prov_openai.id
        })

      assert {:ok, explicit_prov} = AI.get_provider_for_feature(:moderation)
      assert explicit_prov.id == prov_openai.id
    end
  end

  describe "feature settings and feature_enabled?/1" do
    test "feature_enabled?/1 checks global setting and feature flag" do
      refute AI.feature_enabled?(:thread_summary)

      Settings.set("ai_global_enabled", "true")
      refute AI.feature_enabled?(:thread_summary)

      {:ok, %FeatureSetting{}} = AI.upsert_feature_setting(:thread_summary, %{enabled: true})
      assert AI.feature_enabled?(:thread_summary)

      # Upsert update
      {:ok, updated} = AI.upsert_feature_setting(:thread_summary, %{enabled: false})
      refute updated.enabled
      refute AI.feature_enabled?(:thread_summary)

      settings = AI.list_feature_settings()
      assert is_list(settings)
      assert AI.get_feature_setting(:thread_summary).id == updated.id
    end
  end

  describe "usage tracking and costs" do
    test "usage_stats/1 and monthly_cost/0" do
      user = create_user()
      {:ok, provider} = AI.create_provider(provider_attrs("custom"))

      %UsageLog{}
      |> UsageLog.changeset(%{
        provider_id: provider.id,
        user_id: user.id,
        feature: "thread_summary",
        input_tokens: 500,
        output_tokens: 100,
        cost_cents: 2,
        latency_ms: 320
      })
      |> Repo.insert!()

      stats = AI.usage_stats()
      assert length(stats) >= 1
      summary_stat = Enum.find(stats, &(&1.feature == "thread_summary"))
      assert summary_stat.total_calls == 1
      assert summary_stat.total_input_tokens == 500

      assert AI.monthly_cost() >= 2
    end
  end

  describe "moderation copilot" do
    test "create_moderation_analysis, get, record_mod_decision, and moderation_accuracy" do
      user = create_user()
      mod = create_user()
      {_forum, thread, post} = create_forum_and_thread(user)

      attrs = %{
        post_id: post.id,
        thread_id: thread.id,
        suggested_action: "delete",
        confidence: 0.95,
        reasoning: "Contains hate speech slur"
      }

      assert {:ok, %ModerationAnalysis{} = analysis} = AI.create_moderation_analysis(attrs)
      assert analysis.suggested_action == "delete"

      # Record mod decision accepting suggestion
      assert {:ok, updated} = AI.record_mod_decision(analysis.id, mod.id, "delete")
      assert updated.was_accepted == true
      assert updated.mod_id == mod.id

      # Accuracy stats
      acc = AI.moderation_accuracy()
      assert acc.total >= 1
      assert acc.accepted >= 1

      # Non-existent analysis
      assert {:error, :not_found} = AI.record_mod_decision(Ecto.UUID.generate(), mod.id, "delete")
    end
  end

  describe "thread summaries, tag suggestions, sentiment, and translations" do
    test "upsert_thread_summary and get_thread_summary" do
      user = create_user()
      {_forum, thread, _post} = create_forum_and_thread(user)

      assert is_nil(AI.get_thread_summary(thread.id))

      assert {:ok, %ThreadSummary{} = sum1} =
               AI.upsert_thread_summary(thread.id, %{
                 summary: "Initial summary",
                 key_points: ["point 1", "point 2"],
                 post_count_at_generation: 12
               })

      assert sum1.summary == "Initial summary"
      assert sum1.key_points == ["point 1", "point 2"]

      assert {:ok, %ThreadSummary{} = sum2} =
               AI.upsert_thread_summary(thread.id, %{
                 summary: "Updated summary",
                 key_points: ["point 1", "point 2", "point 3"],
                 post_count_at_generation: 15
               })

      assert sum2.summary == "Updated summary"

      assert %ThreadSummary{} = AI.get_thread_summary(thread.id)
    end

    test "create_tag_suggestion and get_tag_suggestions" do
      user = create_user()
      {_forum, thread, _post} = create_forum_and_thread(user)

      assert {:ok, %TagSuggestion{}} =
               AI.create_tag_suggestion(%{
                 thread_id: thread.id,
                 suggested_tags: ["elixir", "phoenix"]
               })

      assert %TagSuggestion{} = AI.get_tag_suggestions(thread.id)
    end

    test "upsert_post_sentiment, heated_threads, and daily_sentiment" do
      user = create_user()
      {_forum, thread, post1} = create_forum_and_thread(user)

      {:ok, post2} =
        Forums.create_post(%{body: "Reply 2", thread_id: thread.id, user_id: user.id})

      {:ok, post3} =
        Forums.create_post(%{body: "Reply 3", thread_id: thread.id, user_id: user.id})

      assert {:ok, %PostSentiment{} = sent} =
               AI.upsert_post_sentiment(post1.id, %{sentiment: -0.8, thread_id: thread.id})

      assert sent.sentiment == -0.8

      assert %PostSentiment{} = AI.get_post_sentiment(post1.id)

      # 2 more negative posts on same thread to meet heated_threads criteria (count >= 3)
      AI.upsert_post_sentiment(post2.id, %{sentiment: -0.9, thread_id: thread.id})
      AI.upsert_post_sentiment(post3.id, %{sentiment: -0.7, thread_id: thread.id})

      heated = AI.heated_threads(threshold: -0.5)
      assert Enum.any?(heated, &(&1.thread_id == thread.id))

      # Daily sentiment
      %CommunitySentiment{}
      |> CommunitySentiment.changeset(%{
        date: Date.utc_today(),
        avg_sentiment: 0.2,
        total_posts_analyzed: 45
      })
      |> Repo.insert!()

      daily = AI.daily_sentiment(7)
      assert length(daily) >= 1
    end

    test "create_translation and get_translation" do
      user = create_user()
      {_forum, _thread, post} = create_forum_and_thread(user)

      assert {:ok, %PostTranslation{}} =
               AI.create_translation(%{
                 post_id: post.id,
                 source_language: "en",
                 target_language: "es",
                 translated_body: "Hola mundo"
               })

      assert %PostTranslation{translated_body: "Hola mundo"} =
               AI.get_translation(post.id, "es")

      assert is_nil(AI.get_translation(post.id, "fr"))
    end
  end

  describe "ForgeNexus.AI.Client and providers with Req.Test stub" do
    setup do
      Req.default_options(plug: {Req.Test, ForgeNexus.AI.Client}, retry: false)

      on_exit(fn ->
        Req.default_options([])
      end)

      :ok
    end

    test "Client.complete with OpenAI provider" do
      {:ok, _prov} = AI.create_provider(provider_attrs("openai", %{is_active: true, priority: 1}))

      Req.Test.stub(ForgeNexus.AI.Client, fn conn ->
        assert conn.request_path == "/v1/chat/completions"

        body = %{
          "choices" => [%{"message" => %{"content" => "Summary from OpenAI"}}],
          "usage" => %{"prompt_tokens" => 50, "completion_tokens" => 20}
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(body))
      end)

      assert {:ok, "Summary from OpenAI"} =
               Client.complete(:general_ai, [%{"role" => "user", "content" => "Hi"}])
    end

    test "Client.embed with OpenAI provider" do
      {:ok, _prov} = AI.create_provider(provider_attrs("openai", %{is_active: true, priority: 1}))

      Req.Test.stub(ForgeNexus.AI.Client, fn conn ->
        assert conn.request_path == "/v1/embeddings"
        body = %{"data" => [%{"embedding" => [0.1, 0.2, 0.3]}]}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(body))
      end)

      assert {:ok, [0.1, 0.2, 0.3]} = Client.embed(:embeddings, "Sample text")
    end

    test "Client.complete with Anthropic provider" do
      {:ok, _prov} =
        AI.create_provider(provider_attrs("anthropic", %{is_active: true, priority: 1}))

      Req.Test.stub(ForgeNexus.AI.Client, fn conn ->
        assert conn.request_path == "/v1/messages"

        body = %{
          "content" => [%{"text" => "Summary from Claude"}],
          "usage" => %{"input_tokens" => 40, "output_tokens" => 15}
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(body))
      end)

      messages = [
        %{"role" => "system", "content" => "Be helpful"},
        %{"role" => "user", "content" => "Summarize"}
      ]

      assert {:ok, "Summary from Claude"} = Client.complete(:general_ai, messages)
    end

    test "Client.complete with Ollama provider" do
      {:ok, _prov} =
        AI.create_provider(
          provider_attrs("ollama", %{
            is_active: true,
            priority: 1,
            base_url: "http://localhost:11434"
          })
        )

      Req.Test.stub(ForgeNexus.AI.Client, fn conn ->
        case conn.request_path do
          "/api/chat" ->
            body = %{
              "message" => %{"content" => "Summary from Ollama"},
              "prompt_eval_count" => 30,
              "eval_count" => 10
            }

            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, Jason.encode!(body))

          "/api/embeddings" ->
            body = %{"embedding" => [0.05, 0.15]}

            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, Jason.encode!(body))
        end
      end)

      assert {:ok, "Summary from Ollama"} =
               Client.complete(:general_ai, [%{"role" => "user", "content" => "Hi Ollama"}])

      assert {:ok, [0.05, 0.15]} = Client.embed(:general_ai, "Embed me")
    end
  end

  describe "ThreadSummarizer unit checks" do
    test "get_or_generate/1 returns :thread_too_short when reply_count < 10" do
      user = create_user()
      {_forum, thread, _post} = create_forum_and_thread(user)

      assert {:error, :thread_too_short} = ThreadSummarizer.get_or_generate(thread.id)
    end
  end
end
