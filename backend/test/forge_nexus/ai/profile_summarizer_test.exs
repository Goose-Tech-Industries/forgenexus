defmodule ForgeNexus.AI.ProfileSummarizerTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.AI
  alias ForgeNexus.AI.ProfileSummarizer
  alias ForgeNexus.Forums.Post
  alias ForgeNexus.{Accounts, Forums, Settings}

  defp create_user(attrs \\ %{}) do
    uid = System.unique_integer([:positive])

    default_attrs = %{
      username: "sum_u_#{uid}",
      email: "sum_u_#{uid}@example.com",
      password: "ValidPassword123!@#"
    }

    {:ok, user} = Accounts.register_user(Map.merge(default_attrs, attrs))
    user
  end

  defp create_thread_and_posts(user) do
    uid = System.unique_integer([:positive])

    {:ok, cat} =
      Forums.create_category(%{
        name: "Sum Cat #{uid}",
        slug: "sum-cat-#{uid}",
        position: 1
      })

    {:ok, forum} =
      Forums.create_forum(%{
        name: "Sum Forum #{uid}",
        slug: "sum-forum-#{uid}",
        category_id: cat.id
      })

    {:ok, thread} =
      Forums.create_thread(%{
        title: "Sum Thread #{uid}",
        body: "First post by author",
        forum_id: forum.id,
        user_id: user.id
      })

    # Add a normal post
    {:ok, post1} =
      Forums.create_post(%{
        body: "Elixir and Phoenix are amazing!",
        thread_id: thread.id,
        user_id: user.id
      })

    # Add a hidden post (should be excluded)
    {:ok, post2} =
      Forums.create_post(%{body: "Hidden post", thread_id: thread.id, user_id: user.id})

    {:ok, _} = post2 |> Post.mod_changeset(%{is_hidden: true}) |> Repo.update()

    {thread, post1}
  end

  defp provider_attrs(name, overrides) do
    Map.merge(
      %{
        name: name,
        adapter: name,
        api_key: "test_key",
        default_model: "claude-haiku-4-5-20251001",
        is_active: true,
        priority: 1
      },
      overrides
    )
  end

  describe "generate/1" do
    test "returns {:error, :feature_disabled} when global or feature is disabled" do
      Settings.set("ai_global_enabled", "false")
      user = create_user()

      assert {:error, :feature_disabled} = ProfileSummarizer.generate(user)

      Settings.set("ai_global_enabled", "true")
      {:ok, _} = AI.upsert_feature_setting(:profile_summary, %{enabled: false})

      assert {:error, :feature_disabled} = ProfileSummarizer.generate(user)
    end

    test "generates summary for user with full blurbs and posts" do
      Settings.set("ai_global_enabled", "true")
      {:ok, _} = AI.upsert_feature_setting(:profile_summary, %{enabled: true})

      {:ok, _prov} =
        AI.create_provider(provider_attrs("anthropic", %{is_active: true, priority: 1}))

      user =
        create_user(%{
          display_name: "Super Coder"
        })

      {:ok, user} = user |> Ecto.Changeset.change(pronouns: "they/them") |> Repo.update()

      # Update user blurbs
      {:ok, user} =
        Accounts.update_profile(user, %{
          about_me_bbcode: "I build distributed systems in Elixir.",
          interests: "Erlang, Elixir, Distributed Systems",
          favorite_music: "Synthwave",
          favorite_movies: "The Matrix",
          favorite_games: "Chrono Trigger",
          favorite_tv: "Mr. Robot",
          favorite_books: "Designing Data-Intensive Applications",
          heroes: "Joe Armstrong",
          who_id_like_to_meet: "Jose Valim"
        })

      create_thread_and_posts(user)

      Req.default_options(plug: {Req.Test, ForgeNexus.AI.Client}, retry: false)

      on_exit(fn ->
        Req.default_options([])
      end)

      Req.Test.stub(ForgeNexus.AI.Client, fn conn ->
        if String.starts_with?(conn.request_path, "/range/") do
          Plug.Conn.send_resp(conn, 200, "0000000000000000000000000000000000000000:0\n")
        else
          assert conn.request_path == "/v1/messages"
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          parsed = Jason.decode!(body)

          user_content = Enum.find(parsed["messages"], &(&1["role"] == "user"))["content"]
          assert user_content =~ "Username: #{user.username}"
          assert user_content =~ "Display name: Super Coder"
          assert user_content =~ "Pronouns: they/them"
          assert user_content =~ "Interests: Erlang, Elixir"
          assert user_content =~ "Favorite music: Synthwave"
          assert user_content =~ "Elixir and Phoenix are amazing!"
          refute user_content =~ "Hidden post"

          resp = %{
            "content" => [
              %{"text" => "Passionate distributed systems engineer who loves Elixir."}
            ],
            "usage" => %{"input_tokens" => 80, "output_tokens" => 25}
          }

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(resp))
        end
      end)

      assert {:ok, summary} = ProfileSummarizer.generate(user)
      assert summary == "Passionate distributed systems engineer who loves Elixir."
    end

    test "generates summary for user without display_name, pronouns, blurbs, or posts" do
      Settings.set("ai_global_enabled", "true")
      {:ok, _} = AI.upsert_feature_setting(:profile_summary, %{enabled: true})

      {:ok, _prov} =
        AI.create_provider(provider_attrs("anthropic", %{is_active: true, priority: 1}))

      user = create_user()

      Req.default_options(plug: {Req.Test, ForgeNexus.AI.Client}, retry: false)

      on_exit(fn ->
        Req.default_options([])
      end)

      Req.Test.stub(ForgeNexus.AI.Client, fn conn ->
        if String.starts_with?(conn.request_path, "/range/") do
          Plug.Conn.send_resp(conn, 200, "0000000000000000000000000000000000000000:0\n")
        else
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          parsed = Jason.decode!(body)

          user_content = Enum.find(parsed["messages"], &(&1["role"] == "user"))["content"]
          assert user_content =~ "Display name: #{user.username}"
          assert user_content =~ "Pronouns: not listed"

          resp = %{
            "content" => [%{"text" => "A quiet new member with no posts yet."}],
            "usage" => %{"input_tokens" => 30, "output_tokens" => 15}
          }

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(resp))
        end
      end)

      assert {:ok, summary} = ProfileSummarizer.generate(user)
      assert summary == "A quiet new member with no posts yet."
    end
  end
end
