defmodule ForgeNexus.ThreadTypesTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.ThreadTypes

  alias ForgeNexus.ThreadTypes.{
    ThreadType,
    ThreadAnswer,
    AmaSession,
    MarketplaceListing,
    WikiEdit
  }

  alias ForgeNexus.{Accounts, Forums}

  defp create_user do
    uid = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "tt_u_#{uid}",
        email: "tt_u_#{uid}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp create_thread_and_post(user) do
    uid = System.unique_integer([:positive])

    {:ok, cat} =
      Forums.create_category(%{
        name: "TT Cat #{uid}",
        slug: "tt-cat-#{uid}",
        position: 1
      })

    {:ok, forum} =
      Forums.create_forum(%{
        name: "TT Forum #{uid}",
        slug: "tt-forum-#{uid}",
        category_id: cat.id
      })

    {:ok, thread} =
      Forums.create_thread(%{
        title: "TT Thread #{uid}",
        body: "First post content",
        forum_id: forum.id,
        user_id: user.id
      })

    {:ok, post} =
      Forums.create_post(%{
        body: "Answer post content",
        thread_id: thread.id,
        user_id: user.id
      })

    {thread, post}
  end

  describe "Thread Types CRUD and seeding" do
    test "create_thread_type, get_thread_type!, get_thread_type_by_slug, update, delete, list" do
      uid = System.unique_integer([:positive])

      attrs = %{
        name: "Custom Type #{uid}",
        slug: "custom-type-#{uid}",
        label: "Custom",
        icon: "star",
        description: "A custom thread type",
        position: 10,
        is_active: true
      }

      assert {:ok, %ThreadType{} = tt} = ThreadTypes.create_thread_type(attrs)
      assert tt.slug == attrs.slug

      # get_thread_type!
      assert ThreadTypes.get_thread_type!(tt.id).id == tt.id

      # get_thread_type_by_slug
      assert ThreadTypes.get_thread_type_by_slug(tt.slug).id == tt.id
      assert is_nil(ThreadTypes.get_thread_type_by_slug("non-existent-slug"))

      # update_thread_type
      assert {:ok, updated} = ThreadTypes.update_thread_type(tt, %{label: "Updated Label"})
      assert updated.label == "Updated Label"

      # list_thread_types
      all = ThreadTypes.list_thread_types()
      assert Enum.any?(all, &(&1.id == tt.id))

      # delete_thread_type
      assert {:ok, _deleted} = ThreadTypes.delete_thread_type(tt)
      assert is_nil(ThreadTypes.get_thread_type_by_slug(tt.slug))
    end

    test "seed_builtin_types seeds when absent and safely skips when existing" do
      # 1. First run inserts missing builtin types
      assert :ok = ThreadTypes.seed_builtin_types()

      discussion = ThreadTypes.get_thread_type_by_slug("discussion")
      assert discussion != nil
      assert discussion.is_builtin == true

      # 2. Second run exercises `_existing -> :ok` branch
      assert :ok = ThreadTypes.seed_builtin_types()
    end
  end

  describe "Q&A (Answers and Votes)" do
    test "create_answer, accept_answer, vote_on_answer, and get_answers" do
      user = create_user()
      user2 = create_user()
      {thread, post} = create_thread_and_post(user)

      assert {:ok, %ThreadAnswer{} = ans} =
               ThreadTypes.create_answer(%{
                 thread_id: thread.id,
                 post_id: post.id
               })

      assert ans.is_accepted == false
      assert ans.vote_count == 0

      # accept_answer
      assert {:ok, accepted} = ThreadTypes.accept_answer(ans, %{accepted_by_id: user.id})
      assert accepted.is_accepted == true
      assert accepted.accepted_by_id == user.id
      assert accepted.accepted_at != nil

      # vote_on_answer: new vote (+1)
      assert {:ok, _vote} = ThreadTypes.vote_on_answer(ans.id, user.id, 1)
      updated_ans = hd(ThreadTypes.get_answers(thread.id))
      assert updated_ans.vote_count == 1

      # vote_on_answer: update existing vote (-1)
      assert {:ok, _vote2} = ThreadTypes.vote_on_answer(ans.id, user.id, -1)
      updated_ans2 = hd(ThreadTypes.get_answers(thread.id))
      assert updated_ans2.vote_count == -1

      # vote_on_answer: error branch (invalid value)
      assert {:error, changeset} = ThreadTypes.vote_on_answer(ans.id, user2.id, 5)
      assert "is invalid" in errors_on(changeset).value
    end
  end

  describe "Debate (Positions)" do
    test "set_position (insert and update), get_positions, and get_position_counts" do
      user1 = create_user()
      user2 = create_user()
      {thread, post} = create_thread_and_post(user1)

      # 1. New position (pro)
      assert {:ok, pos1} =
               ThreadTypes.set_position(%{
                 thread_id: thread.id,
                 post_id: post.id,
                 user_id: user1.id,
                 side: "pro"
               })

      assert pos1.side == "pro"

      # 2. Update existing position (switch from pro to con)
      assert {:ok, pos1_updated} =
               ThreadTypes.set_position(%{
                 thread_id: thread.id,
                 post_id: post.id,
                 user_id: user1.id,
                 side: "con"
               })

      assert pos1_updated.side == "con"

      # 3. User2 takes pro position
      {:ok, post2} =
        Forums.create_post(%{body: "Debate post 2", thread_id: thread.id, user_id: user2.id})

      assert {:ok, _pos2} =
               ThreadTypes.set_position(%{
                 "thread_id" => thread.id,
                 "post_id" => post2.id,
                 "user_id" => user2.id,
                 "side" => "pro"
               })

      # get_positions
      grouped = ThreadTypes.get_positions(thread.id)
      assert Map.has_key?(grouped, "pro")
      assert Map.has_key?(grouped, "con")

      # get_position_counts
      counts = ThreadTypes.get_position_counts(thread.id)
      assert counts["pro"] == 1
      assert counts["con"] == 1
    end
  end

  describe "AMA Sessions" do
    test "create_ama_session, update_ama_status, and get_ama_session" do
      user = create_user()
      {thread, _post} = create_thread_and_post(user)

      assert {:ok, %AmaSession{} = session} =
               ThreadTypes.create_ama_session(%{
                 thread_id: thread.id,
                 host_id: user.id,
                 title: "Ask Me Anything with Founder",
                 status: "upcoming"
               })

      assert session.status == "upcoming"

      # get_ama_session
      assert ThreadTypes.get_ama_session(thread.id).id == session.id

      # update_ama_status
      assert {:ok, updated} = ThreadTypes.update_ama_status(session, "live")
      assert updated.status == "live"
    end
  end

  describe "Marketplace Listings" do
    test "create_listing, update_listing_status, and get_listing" do
      user = create_user()
      {thread, _post} = create_thread_and_post(user)

      assert {:ok, %MarketplaceListing{} = listing} =
               ThreadTypes.create_listing(%{
                 thread_id: thread.id,
                 user_id: user.id,
                 price: Decimal.new("99.99"),
                 condition: "like_new",
                 status: "available"
               })

      assert listing.status == "available"

      # get_listing
      assert ThreadTypes.get_listing(thread.id).id == listing.id

      # update_listing_status
      assert {:ok, updated} = ThreadTypes.update_listing_status(listing, "sold")
      assert updated.status == "sold"
    end
  end

  describe "Wiki Edits" do
    test "create_wiki_edit, get_wiki_edits, and get_latest_wiki_content" do
      user = create_user()
      {thread, _post} = create_thread_and_post(user)

      assert {:ok, %WikiEdit{} = _rev1} =
               ThreadTypes.create_wiki_edit(%{
                 thread_id: thread.id,
                 user_id: user.id,
                 body: "Wiki initial revision content",
                 revision_number: 1,
                 edit_summary: "Initial creation"
               })

      assert {:ok, %WikiEdit{} = rev2} =
               ThreadTypes.create_wiki_edit(%{
                 thread_id: thread.id,
                 user_id: user.id,
                 body: "Wiki second revision content with fixes",
                 revision_number: 2,
                 edit_summary: "Typo fix"
               })

      # get_wiki_edits (ordered desc by revision_number)
      edits = ThreadTypes.get_wiki_edits(thread.id)
      assert length(edits) == 2
      assert hd(edits).revision_number == 2

      # get_latest_wiki_content
      latest = ThreadTypes.get_latest_wiki_content(thread.id)
      assert latest.id == rev2.id
      assert latest.revision_number == 2
    end
  end

  describe "default arity function clauses" do
    test "exercises 0-arity defaults" do
      assert {:error, %Ecto.Changeset{}} = ThreadTypes.create_thread_type()
      assert {:error, %Ecto.Changeset{}} = ThreadTypes.create_answer()
      assert {:error, %Ecto.Changeset{}} = ThreadTypes.set_position()
      assert {:error, %Ecto.Changeset{}} = ThreadTypes.create_ama_session()
      assert {:error, %Ecto.Changeset{}} = ThreadTypes.create_listing()
      assert {:error, %Ecto.Changeset{}} = ThreadTypes.create_wiki_edit()
    end
  end
end
