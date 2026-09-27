defmodule ForgeNexus.AI.ThreadSummarizerTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.AI.ThreadSummarizer
  alias ForgeNexus.Forums.Thread
  alias ForgeNexus.{Accounts, Forums, Repo, Settings}

  defp create_user do
    uid = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "tsum_u_#{uid}",
        email: "tsum_u_#{uid}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp create_thread_with_replies(user, reply_count) do
    uid = System.unique_integer([:positive])

    {:ok, cat} =
      Forums.create_category(%{
        name: "TSum Cat #{uid}",
        slug: "tsum-cat-#{uid}",
        position: 1
      })

    {:ok, forum} =
      Forums.create_forum(%{
        name: "TSum Forum #{uid}",
        slug: "tsum-forum-#{uid}",
        category_id: cat.id
      })

    {:ok, thread} =
      Forums.create_thread(%{
        title: "Discussion on Distributed Consensus #{uid}",
        body: "Initial post discussing Raft vs Paxos.",
        forum_id: forum.id,
        user_id: user.id
      })

    if reply_count > 0 do
      {:ok, _post} =
        Forums.create_post(%{
          body: "Reply 1: insightful discussion points about consensus algorithms.",
          thread_id: thread.id,
          user_id: user.id
        })

      from(t in Thread, where: t.id == ^thread.id)
      |> Repo.update_all(set: [reply_count: reply_count])
    end

    Repo.get!(Thread, thread.id)
  end

  describe "get_or_generate/1" do
    test "returns {:error, :thread_too_short} when reply_count < 10" do
      user = create_user()
      thread = create_thread_with_replies(user, 3)

      assert {:error, :thread_too_short} = ThreadSummarizer.get_or_generate(thread.id)
    end

    test "returns {:error, :disabled} when feature is disabled and no cached summary exists" do
      user = create_user()
      thread = create_thread_with_replies(user, 10)
      Settings.set("ai_thread_summary_enabled", "false")

      assert {:error, :disabled} = ThreadSummarizer.get_or_generate(thread.id)
    end

    test "returns {:error, :no_api_key} when enabled but ANTHROPIC_API_KEY is missing or empty" do
      user = create_user()
      thread = create_thread_with_replies(user, 10)
      Settings.set("ai_thread_summary_enabled", "true")

      prev_key = System.get_env("ANTHROPIC_API_KEY")
      System.delete_env("ANTHROPIC_API_KEY")

      on_exit(fn ->
        if prev_key,
          do: System.put_env("ANTHROPIC_API_KEY", prev_key),
          else: System.delete_env("ANTHROPIC_API_KEY")
      end)

      assert {:error, :no_api_key} = ThreadSummarizer.get_or_generate(thread.id)

      System.put_env("ANTHROPIC_API_KEY", "")
      assert {:error, :no_api_key} = ThreadSummarizer.get_or_generate(thread.id)
    end

    test "generates and caches summary on 200 response, hits cache on subsequent calls, and returns cached even when disabled" do
      user = create_user()
      thread = create_thread_with_replies(user, 10)

      # Ensure community_id is nil to exercise the nil branch of to_binary_id
      from(t in Thread, where: t.id == ^thread.id)
      |> Repo.update_all(set: [community_id: nil])

      Settings.set("ai_thread_summary_enabled", "true")
      Settings.set("ai_thread_summary_model", "claude-haiku-4-5-20251001")
      prev_key = System.get_env("ANTHROPIC_API_KEY")
      System.put_env("ANTHROPIC_API_KEY", "test_key")

      Req.default_options(plug: {Req.Test, ForgeNexus.AI.ThreadSummarizer}, retry: false)

      on_exit(fn ->
        Req.default_options([])

        if prev_key,
          do: System.put_env("ANTHROPIC_API_KEY", prev_key),
          else: System.delete_env("ANTHROPIC_API_KEY")
      end)

      Req.Test.stub(ForgeNexus.AI.ThreadSummarizer, fn conn ->
        assert conn.request_path == "/v1/messages"
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)
        assert parsed["model"] == "claude-haiku-4-5-20251001"

        prompt = hd(parsed["messages"])["content"]
        assert prompt =~ "Discussion on Distributed Consensus"
        assert prompt =~ "Reply 1:"

        resp = %{"content" => [%{"text" => "This thread provides an overview of Raft vs Paxos."}]}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(resp))
      end)

      # 1. First generation: cache miss, calls Claude and caches
      assert {:ok, summary} = ThreadSummarizer.get_or_generate(thread.id)
      assert summary == "This thread provides an overview of Raft vs Paxos."

      # 2. Cache hit: reply_count diff is 0 (< 5 stale threshold), does not call Claude
      Req.Test.stub(ForgeNexus.AI.ThreadSummarizer, fn _conn ->
        flunk("Should have used cache without making HTTP request")
      end)

      assert {:ok, cached_summary} = ThreadSummarizer.get_or_generate(thread.id)
      assert cached_summary == summary

      # 3. Cache hit when feature disabled: returns cached summary
      Settings.set("ai_thread_summary_enabled", "false")
      assert {:ok, disabled_cached} = ThreadSummarizer.get_or_generate(thread.id)
      assert disabled_cached == summary

      # 4. Cache stale: update reply_count to 16 (diff >= 5), feature re-enabled, updates cache
      Settings.set("ai_thread_summary_enabled", "true")

      from(t in Thread, where: t.id == ^thread.id)
      |> Repo.update_all(set: [reply_count: 16])

      Req.Test.stub(ForgeNexus.AI.ThreadSummarizer, fn conn ->
        resp = %{"content" => [%{"text" => "Updated summary incorporating recent benchmarks."}]}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(resp))
      end)

      assert {:ok, updated_summary} = ThreadSummarizer.get_or_generate(thread.id)
      assert updated_summary == "Updated summary incorporating recent benchmarks."
    end

    test "handles HTTP error, transport failure, and exception when calling Claude" do
      user = create_user()
      thread = create_thread_with_replies(user, 10)

      Settings.set("ai_thread_summary_enabled", "true")
      prev_key = System.get_env("ANTHROPIC_API_KEY")
      System.put_env("ANTHROPIC_API_KEY", "test_key")

      Req.default_options(plug: {Req.Test, ForgeNexus.AI.ThreadSummarizer}, retry: false)

      on_exit(fn ->
        Req.default_options([])

        if prev_key,
          do: System.put_env("ANTHROPIC_API_KEY", prev_key),
          else: System.delete_env("ANTHROPIC_API_KEY")
      end)

      # 1. HTTP 500 error
      Req.Test.stub(ForgeNexus.AI.ThreadSummarizer, fn conn ->
        Plug.Conn.send_resp(conn, 500, Jason.encode!(%{"error" => "overloaded"}))
      end)

      assert {:error, {:http, 500}} = ThreadSummarizer.get_or_generate(thread.id)

      # 2. Transport failure
      Req.Test.stub(ForgeNexus.AI.ThreadSummarizer, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, {:request_failed, _}} = ThreadSummarizer.get_or_generate(thread.id)

      # 3. Exception
      Req.Test.stub(ForgeNexus.AI.ThreadSummarizer, fn _conn ->
        raise RuntimeError, "Anthropic API unavailable"
      end)

      assert {:error, {:exception, "Anthropic API unavailable"}} =
               ThreadSummarizer.get_or_generate(thread.id)
    end
  end
end
