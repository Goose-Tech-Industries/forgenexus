defmodule ForgeNexus.Social.SyndicationTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Social.Syndication
  alias ForgeNexus.{Accounts, Communities, Forums, Repo}

  defp create_user do
    uid = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "syn_u_#{uid}",
        email: "syn_u_#{uid}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp create_community(user) do
    uid = System.unique_integer([:positive])

    {:ok, comm} =
      Communities.create_community(%{
        name: "Syn Comm #{uid}",
        slug: "syn-comm-#{uid}",
        owner_id: user.id
      })

    comm
  end

  defp create_forum_for_community(community) do
    uid = System.unique_integer([:positive])

    {:ok, cat} =
      Forums.create_category(%{
        name: "Syn Cat #{uid}",
        slug: "syn-cat-#{uid}",
        position: 1
      })

    {:ok, forum} =
      Forums.create_forum(%{
        name: "Syn Forum #{uid}",
        slug: "syn-forum-#{uid}",
        category_id: cat.id,
        position: 1
      })

    {:ok, comm_bin} = Ecto.UUID.dump(community.id)

    from(f in "forums", where: f.id == type(^forum.id, :binary_id))
    |> Repo.update_all(set: [community_id: comm_bin])

    forum
  end

  describe "syndicate_thread/3" do
    test "successfully syndicates thread with post excerpt into target community" do
      user = create_user()
      source_comm = create_community(user)
      target_comm = create_community(user)

      _source_forum = create_forum_for_community(source_comm)
      target_forum = create_forum_for_community(target_comm)

      {:ok, source_thread} =
        Forums.create_thread(%{
          title: "Groundbreaking Research",
          body: "This is the source post with great insights.",
          forum_id: target_forum.id,
          user_id: user.id
        })

      {:ok, comm_bin} = Ecto.UUID.dump(source_comm.id)

      # Update source thread to point to source community
      from(t in "threads", where: t.id == type(^source_thread.id, :binary_id))
      |> Repo.update_all(set: [community_id: comm_bin])

      # Syndicate thread
      assert {:ok, target_thread} =
               Syndication.syndicate_thread(source_thread.id, target_comm.id, user.id)

      assert target_thread.title =~ "[Shared] Groundbreaking Research"
      assert target_thread.forum_id == target_forum.id

      # Verify syndicated_posts record was created
      syndicated =
        from(s in "syndicated_posts",
          where: s.source_thread_id == type(^source_thread.id, :binary_id),
          select: %{status: s.status, target_community_id: s.target_community_id}
        )
        |> Repo.one()

      assert syndicated != nil
      assert syndicated.status == "active"
    end

    test "syndicates thread with empty excerpt when source thread has no posts" do
      user = create_user()
      _source_comm = create_community(user)
      target_comm = create_community(user)
      target_forum = create_forum_for_community(target_comm)

      {:ok, source_thread} =
        Forums.create_thread(%{
          title: "Empty Thread",
          body: "Body",
          forum_id: target_forum.id,
          user_id: user.id
        })

      # Clear community_id on source thread to test to_binary_id(nil)
      from(t in "threads", where: t.id == type(^source_thread.id, :binary_id))
      |> Repo.update_all(set: [community_id: nil])

      # Delete posts to test the [] -> "" branch
      from(p in "posts", where: p.thread_id == type(^source_thread.id, :binary_id))
      |> Repo.delete_all()

      assert {:ok, target_thread} =
               Syndication.syndicate_thread(source_thread.id, target_comm.id, user.id)

      assert target_thread.title =~ "[Shared] Empty Thread"
    end

    test "returns error when target thread creation fails due to no default forum" do
      user = create_user()
      target_comm = create_community(user)
      forum = create_forum_for_community(target_comm)

      {:ok, source_thread} =
        Forums.create_thread(%{
          title: "Some Thread",
          body: "Initial text",
          forum_id: forum.id,
          user_id: user.id
        })

      # Create target community with NO forums
      empty_target_comm = create_community(user)

      assert {:error, %Ecto.Changeset{}} =
               Syndication.syndicate_thread(source_thread.id, empty_target_comm.id, user.id)
    end
  end
end
