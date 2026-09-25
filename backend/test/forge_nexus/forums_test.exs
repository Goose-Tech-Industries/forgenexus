defmodule ForgeNexus.ForumsTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Forums
  alias ForgeNexus.Forums.{Category, Forum, Thread, Post}
  alias ForgeNexus.Accounts.User

  defp insert_user! do
    n = System.unique_integer([:positive])

    %User{
      username: "forum_user_#{n}",
      slug: "forum-user-#{n}",
      email: "forum_#{n}@example.com",
      password_hash: "$2b$12$dummyhash"
    }
    |> Repo.insert!()
  end

  describe "Categories and Forums" do
    test "creates and lists categories with forum preloads" do
      cat_attrs = %{
        name: "Gaming Hub",
        slug: "gaming-hub",
        description: "All about games",
        position: 1
      }

      assert {:ok, %Category{} = cat} = Forums.create_category(cat_attrs)
      assert cat.name == "Gaming Hub"

      forum_attrs = %{name: "PC Gaming", slug: "pc-gaming", category_id: cat.id, position: 1}
      assert {:ok, %Forum{} = forum} = Forums.create_forum(forum_attrs)
      assert forum.category_id == cat.id

      categories = Forums.list_categories()
      found = Enum.find(categories, &(&1.id == cat.id))
      assert found != nil
      assert Enum.any?(found.forums, &(&1.id == forum.id))
    end
  end

  describe "Threads and Posts" do
    setup do
      user = insert_user!()

      {:ok, cat} =
        Forums.create_category(%{
          name: "Tech",
          slug: "tech-#{System.unique_integer([:positive])}"
        })

      {:ok, forum} =
        Forums.create_forum(%{
          name: "Hardware",
          slug: "hw-#{System.unique_integer([:positive])}",
          category_id: cat.id
        })

      %{user: user, forum: forum}
    end

    test "creates a thread and automatically creates the first post with BBCode HTML", %{
      user: user,
      forum: forum
    } do
      thread_attrs = %{
        title: "Best GPU for 2026",
        body: "[b]What is the best GPU?[/b] Discuss here.",
        forum_id: forum.id,
        user_id: user.id
      }

      assert {:ok, %Thread{} = thread} = Forums.create_thread(thread_attrs)
      assert thread.title == "Best GPU for 2026"
      assert is_binary(thread.slug)

      # Verify first post was generated with BBCode HTML
      posts = Forums.list_posts(thread.id)
      assert length(posts) == 1
      [first_post] = posts
      assert first_post.is_first_post == true
      assert first_post.body =~ "[b]What is the best GPU?[/b]"
      assert first_post.body_html =~ "<strong>What is the best GPU?</strong>"

      # Verify forum counters incremented
      reloaded_forum = Forums.get_forum!(forum.id)
      assert reloaded_forum.thread_count >= 1
      assert reloaded_forum.post_count >= 1
    end

    test "creates reply posts in a thread with sequential positions", %{user: user, forum: forum} do
      {:ok, thread} =
        Forums.create_thread(%{
          title: "Sequential test",
          body: "Initial post",
          forum_id: forum.id,
          user_id: user.id
        })

      other_user = insert_user!()

      assert {:ok, %Post{} = reply1} =
               Forums.create_post(%{
                 thread_id: thread.id,
                 user_id: other_user.id,
                 body: "First reply here"
               })

      assert {:ok, %Post{} = reply2} =
               Forums.create_post(%{
                 thread_id: thread.id,
                 user_id: user.id,
                 body: "Second reply here"
               })

      assert reply1.position == 2
      assert reply2.position == 3

      all_posts = Forums.list_posts(thread.id)
      assert length(all_posts) == 3
    end

    test "sorts pinned threads before unpinned threads in thread listings", %{
      user: user,
      forum: forum
    } do
      {:ok, _normal_thread} =
        Forums.create_thread(%{
          title: "Normal Thread",
          body: "Normal body",
          forum_id: forum.id,
          user_id: user.id
        })

      {:ok, pinned_thread} =
        Forums.create_thread(%{
          title: "Sticky Announcement",
          body: "Sticky body",
          forum_id: forum.id,
          user_id: user.id
        })

      # Mark sticky thread as pinned
      from(t in Thread, where: t.id == ^pinned_thread.id)
      |> Repo.update_all(set: [is_pinned: true])

      threads = Forums.list_threads(forum.id)
      [first | _rest] = threads
      assert first.id == pinned_thread.id
      assert first.is_pinned == true
    end
  end
end
