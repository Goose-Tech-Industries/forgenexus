defmodule ForgeNexus.ContentFilterTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.ContentFilter
  alias ForgeNexus.Forums.{Category, Forum, Thread, Post}
  alias ForgeNexus.Accounts.User

  defp insert_user! do
    n = System.unique_integer([:positive])

    %User{
      username: "filter_user_#{n}",
      slug: "filter-user-#{n}",
      email: "filter_#{n}@example.com",
      password_hash: "$2b$12$dummyhash"
    }
    |> Repo.insert!()
  end

  defp insert_post!(user, body) do
    n = System.unique_integer([:positive])
    category = %Category{name: "Cat #{n}", slug: "cat-#{n}"} |> Repo.insert!()

    forum =
      %Forum{name: "Forum #{n}", slug: "forum-#{n}", category_id: category.id} |> Repo.insert!()

    thread =
      %Thread{title: "Thread #{n}", slug: "thread-#{n}", forum_id: forum.id, user_id: user.id}
      |> Repo.insert!()

    %Post{
      body: body,
      thread_id: thread.id,
      user_id: user.id
    }
    |> Repo.insert!()
  end

  describe "ContentFilter.check/3" do
    test "passes clean, valid text" do
      user = insert_user!()
      body = "This is a great discussion topic about open source game development."
      assert {:ok, :clean} = ContentFilter.check(body, user.id)
    end

    test "flags post with more than 5 URLs" do
      user = insert_user!()

      excessive_links = """
      Check out these sites:
      https://example1.com
      https://example2.com
      https://example3.com
      https://example4.com
      https://example5.com
      https://example6.com
      """

      assert {:error, msg} = ContentFilter.check(excessive_links, user.id)
      assert msg =~ "Too many links in your post"
    end

    test "allows post with up to 5 URLs" do
      user = insert_user!()

      allowed_links = """
      Reference links:
      https://example1.com
      https://example2.com
      https://example3.com
      """

      assert {:ok, :clean} = ContentFilter.check(allowed_links, user.id)
    end

    test "detects banned words regardless of case" do
      user = insert_user!()

      assert {:error, "Your post contains prohibited content"} =
               ContentFilter.check("Buy ViAgRa online right now!", user.id)

      assert {:error, "Your post contains prohibited content"} =
               ContentFilter.check("Win big at our online CASINO today", user.id)
    end

    test "prevents posting identical content twice within 24 hours" do
      user = insert_user!()
      repeated_body = "This is an important announcement copy-pasted."

      # First check passes
      assert {:ok, :clean} = ContentFilter.check(repeated_body, user.id)

      # User actually posts it
      insert_post!(user, repeated_body)

      # Subsequent check by same user fails
      assert {:error, msg} = ContentFilter.check(repeated_body, user.id)
      assert msg =~ "You have already posted this exact content recently"

      # Different user posting the same body is allowed
      other_user = insert_user!()
      assert {:ok, :clean} = ContentFilter.check(repeated_body, other_user.id)
    end
  end
end
