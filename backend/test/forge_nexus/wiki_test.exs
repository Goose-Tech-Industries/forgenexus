defmodule ForgeNexus.WikiTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Wiki
  alias ForgeNexus.Wiki.{WikiCategory, WikiPage, WikiRevision, EditLock}
  alias ForgeNexus.Accounts

  defp create_user do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "wiki_u_#{unique}",
        email: "wiki_u_#{unique}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp category_attrs(attrs) do
    unique = System.unique_integer([:positive])

    Enum.into(attrs, %{
      name: "Guides #{unique}",
      slug: "guides-#{unique}",
      description: "Community guides and manuals",
      position: 1,
      is_visible: true
    })
  end

  defp page_attrs(category_id, attrs) do
    unique = System.unique_integer([:positive])

    Enum.into(attrs, %{
      title: "Getting Started #{unique}",
      slug: "getting-started-#{unique}",
      body: "Welcome to the wiki guide.",
      body_html: "<p>Welcome to the wiki guide.</p>",
      category_id: category_id,
      is_published: true
    })
  end

  describe "categories CRUD" do
    test "create, get, list_categories, update, delete" do
      attrs = category_attrs(%{name: "Alpha Category"})
      assert {:ok, %WikiCategory{} = cat} = Wiki.create_category(attrs)

      assert %WikiCategory{id: id} = Wiki.get_category!(cat.id)
      assert id == cat.id

      cats = Wiki.list_categories()
      assert Enum.any?(cats, &(&1.id == cat.id))
      found_cat = Enum.find(cats, &(&1.id == cat.id))
      assert found_cat.page_count == 0

      assert {:ok, updated} = Wiki.update_category(cat, %{name: "Updated Guides"})
      assert updated.name == "Updated Guides"

      assert {:ok, %WikiCategory{}} = Wiki.delete_category(cat)
      assert_raise Ecto.NoResultsError, fn -> Wiki.get_category!(cat.id) end
    end
  end

  describe "pages and revisions lifecycle" do
    test "create_page, update_page, revisions history, and revert_to_revision" do
      user = create_user()
      {:ok, cat} = Wiki.create_category(category_attrs(%{}))

      attrs = page_attrs(cat.id, %{title: "Intro Guide", body: "First version body"})
      assert {:ok, %WikiPage{} = page} = Wiki.create_page(attrs, user.id)
      assert page.title == "Intro Guide"

      # Revisions created automatically on creation (revision 1)
      revisions = Wiki.get_revisions(page.id)
      assert length(revisions) == 1
      rev1 = hd(revisions)
      assert rev1.revision_number == 1
      assert rev1.edit_summary == "Initial version"
      assert rev1.body == "First version body"

      # Fetching page preloads revisions and user
      fetched = Wiki.get_page!(page.id)
      assert length(fetched.revisions) == 1
      assert fetched.created_by.id == user.id

      # Fetch by slug
      assert %WikiPage{id: slug_id} = Wiki.get_page_by_slug!(page.slug)
      assert slug_id == page.id

      # Update page creates revision 2
      assert {:ok, %WikiPage{} = updated_page} =
               Wiki.update_page(
                 page,
                 %{body: "Second version body", edit_summary: "Updated typos"},
                 user.id
               )

      assert updated_page.body == "Second version body"

      revisions2 = Wiki.get_revisions(page.id)
      assert length(revisions2) == 2
      rev2 = hd(revisions2)
      assert rev2.revision_number == 2
      assert rev2.edit_summary == "Updated typos"

      # get_revision!/1
      assert %WikiRevision{id: r_id} = Wiki.get_revision!(rev1.id)
      assert r_id == rev1.id

      # Revert to revision 1 creates revision 3 with revision 1 content
      assert {:ok, reverted} = Wiki.revert_to_revision(updated_page, rev1.id)
      assert reverted.body == "First version body"

      revisions3 = Wiki.get_revisions(page.id)
      assert length(revisions3) == 3
      assert hd(revisions3).revision_number == 3
      assert hd(revisions3).edit_summary == "Reverted to revision #1"

      # list_pages in category
      pages = Wiki.list_pages(cat.id)
      assert length(pages) == 1
      assert hd(pages).id == page.id
    end
  end

  describe "edit locks" do
    test "acquire, check, conflict, and release edit locks" do
      user_a = create_user()
      user_b = create_user()
      {:ok, cat} = Wiki.create_category(category_attrs(%{}))
      {:ok, page} = Wiki.create_page(page_attrs(cat.id, %{}), user_a.id)

      assert is_nil(Wiki.check_edit_lock(page.id))

      # User A acquires lock
      assert {:ok, %EditLock{} = lock} = Wiki.acquire_edit_lock(page.id, user_a.id)
      assert lock.user_id == user_a.id

      # Lock is active
      active = Wiki.check_edit_lock(page.id)
      assert active.user_id == user_a.id

      # User A re-acquiring refreshes the lock
      assert {:ok, %EditLock{}} = Wiki.acquire_edit_lock(page.id, user_a.id)

      # User B attempting to acquire returns conflict
      assert {:error, {:locked_by, locked_by}} = Wiki.acquire_edit_lock(page.id, user_b.id)
      assert locked_by == user_a.id

      # Release lock
      assert :ok = Wiki.release_edit_lock(page.id)
      assert is_nil(Wiki.check_edit_lock(page.id))

      # Expired lock is cleaned up
      expired_time =
        DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      %EditLock{}
      |> EditLock.changeset(%{
        page_id: page.id,
        user_id: user_a.id,
        locked_at: expired_time,
        expires_at: expired_time
      })
      |> ForgeNexus.Repo.insert!()

      assert is_nil(Wiki.check_edit_lock(page.id))
    end
  end

  describe "view count and search" do
    test "increment_view_count/1 and search_pages/1" do
      user = create_user()
      {:ok, cat} = Wiki.create_category(category_attrs(%{}))

      {:ok, page1} =
        Wiki.create_page(
          page_attrs(cat.id, %{
            title: "Elixir OTP Guide",
            body: "A deep dive into GenServer and Supervision",
            is_published: true
          }),
          user.id
        )

      {:ok, _page2} =
        Wiki.create_page(
          page_attrs(cat.id, %{
            title: "Cooking Recipes",
            body: "How to make sourdough bread",
            is_published: true
          }),
          user.id
        )

      # Increment view count
      assert {1, _} = Wiki.increment_view_count(page1)
      reloaded = Wiki.get_page!(page1.id)
      assert reloaded.view_count == 1

      # Search matches title or body
      results = Wiki.search_pages("GenServer")
      assert length(results) == 1
      assert hd(results).id == page1.id

      results_title = Wiki.search_pages("Elixir")
      assert length(results_title) == 1
      assert hd(results_title).id == page1.id

      assert Wiki.search_pages("NonexistentTermXyz") == []
    end
  end
end
