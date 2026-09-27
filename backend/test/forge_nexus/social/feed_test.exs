defmodule ForgeNexus.Social.FeedTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Social.Feed
  alias ForgeNexus.{Accounts, Communities, Forums, Repo}

  defmodule DummyRoomServer do
    use GenServer

    def start_link(room_id) do
      GenServer.start_link(__MODULE__, [],
        name: {:via, Registry, {ForgeNexus.Voice.RoomRegistry, room_id}}
      )
    end

    def init(_) do
      {:ok, []}
    end

    def handle_call(:get_participants, _from, state) do
      {:reply, [%{user_id: "u1", username: "Alice"}], state}
    end
  end

  defp create_user do
    uid = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "feed_u_#{uid}",
        email: "feed_u_#{uid}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp create_community(user) do
    uid = System.unique_integer([:positive])

    {:ok, comm} =
      Communities.create_community(%{
        name: "Feed Comm #{uid}",
        slug: "feed-comm-#{uid}",
        owner_id: user.id
      })

    comm
  end

  defp create_forum(community) do
    uid = System.unique_integer([:positive])

    {:ok, cat} =
      Forums.create_category(%{
        name: "Feed Cat #{uid}",
        slug: "feed-cat-#{uid}",
        position: 1
      })

    {:ok, forum} =
      Forums.create_forum(%{
        name: "Feed Forum #{uid}",
        slug: "feed-forum-#{uid}",
        category_id: cat.id,
        position: 1
      })

    {:ok, comm_bin} = Ecto.UUID.dump(community.id)

    from(f in "forums", where: f.id == type(^forum.id, :binary_id))
    |> Repo.update_all(set: [community_id: comm_bin])

    forum
  end

  describe "get_feed/2" do
    test "retrieves and aggregates all item types with correct weighting and pagination" do
      user = create_user()
      community = create_community(user)
      forum = create_forum(community)
      {:ok, comm_bin} = Ecto.UUID.dump(community.id)
      {:ok, user_bin} = Ecto.UUID.dump(user.id)

      # 1. Status posts (pinned and unpinned, and non-public which should be excluded)
      post_id1 = Ecto.UUID.generate()
      post_id2 = Ecto.UUID.generate()
      post_id3 = Ecto.UUID.generate()
      {:ok, post_bin1} = Ecto.UUID.dump(post_id1)
      {:ok, post_bin2} = Ecto.UUID.dump(post_id2)
      {:ok, post_bin3} = Ecto.UUID.dump(post_id3)
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      earlier = NaiveDateTime.add(now, -3600, :second)

      Repo.insert_all("status_posts", [
        %{
          id: post_bin1,
          community_id: comm_bin,
          user_id: user_bin,
          body: "Pinned public post",
          visibility: "public",
          is_pinned: true,
          media_urls: [],
          media_type: "text",
          like_count: 5,
          comment_count: 2,
          inserted_at: now,
          updated_at: now
        },
        %{
          id: post_bin2,
          community_id: comm_bin,
          user_id: user_bin,
          body: "Normal public post",
          visibility: "public",
          is_pinned: false,
          media_urls: ["https://example.com/img.png"],
          media_type: "image",
          like_count: 1,
          comment_count: 0,
          inserted_at: earlier,
          updated_at: earlier
        },
        %{
          id: post_bin3,
          community_id: comm_bin,
          user_id: user_bin,
          body: "Private post",
          visibility: "private",
          is_pinned: false,
          media_urls: [],
          media_type: "text",
          like_count: 0,
          comment_count: 0,
          inserted_at: now,
          updated_at: now
        }
      ])

      # 2. Threads (normal, hot by replies, hot by views, pinned, and hidden)
      {:ok, thread1} =
        Forums.create_thread(%{
          title: "Normal Thread",
          body: "Normal thread post body",
          forum_id: forum.id,
          user_id: user.id
        })

      {:ok, thread2} =
        Forums.create_thread(%{
          title: "Hot Thread Replies",
          body: "Hot thread replies post body",
          forum_id: forum.id,
          user_id: user.id
        })

      {:ok, thread3} =
        Forums.create_thread(%{
          title: "Hot Thread Views",
          body: "Hot thread views post body",
          forum_id: forum.id,
          user_id: user.id
        })

      {:ok, thread4} =
        Forums.create_thread(%{
          title: "Pinned Thread",
          body: "Pinned thread post body",
          forum_id: forum.id,
          user_id: user.id
        })

      {:ok, thread5} =
        Forums.create_thread(%{
          title: "Hidden Thread",
          body: "Hidden thread post body",
          forum_id: forum.id,
          user_id: user.id
        })

      from(t in "threads", where: t.id == type(^thread1.id, :binary_id))
      |> Repo.update_all(
        set: [community_id: comm_bin, is_hidden: false, reply_count: 0, view_count: 0]
      )

      from(t in "threads", where: t.id == type(^thread2.id, :binary_id))
      |> Repo.update_all(
        set: [community_id: comm_bin, is_hidden: false, reply_count: 15, view_count: 5]
      )

      from(t in "threads", where: t.id == type(^thread3.id, :binary_id))
      |> Repo.update_all(
        set: [community_id: comm_bin, is_hidden: false, reply_count: 2, view_count: 150]
      )

      from(t in "threads", where: t.id == type(^thread4.id, :binary_id))
      |> Repo.update_all(
        set: [
          community_id: comm_bin,
          is_hidden: false,
          is_pinned: true,
          reply_count: 0,
          view_count: 0
        ]
      )

      from(t in "threads", where: t.id == type(^thread5.id, :binary_id))
      |> Repo.update_all(set: [community_id: comm_bin, is_hidden: true])

      # 3. Voice rooms
      room_id1 = Ecto.UUID.generate()
      room_id2 = Ecto.UUID.generate()
      room_id3 = Ecto.UUID.generate()
      {:ok, room_bin1} = Ecto.UUID.dump(room_id1)
      {:ok, room_bin2} = Ecto.UUID.dump(room_id2)
      {:ok, room_bin3} = Ecto.UUID.dump(room_id3)

      Repo.insert_all("voice_rooms", [
        %{
          id: room_bin1,
          community_id: comm_bin,
          name: "Active Room with Users",
          slug: "active-room-#{System.unique_integer([:positive])}",
          type: "lounge",
          is_active: true,
          inserted_at: now,
          updated_at: now
        },
        %{
          id: room_bin2,
          community_id: comm_bin,
          name: "Empty Room",
          slug: "empty-room-#{System.unique_integer([:positive])}",
          type: "lounge",
          is_active: true,
          inserted_at: now,
          updated_at: now
        },
        %{
          id: room_bin3,
          community_id: comm_bin,
          name: "Inactive Room",
          slug: "inactive-room-#{System.unique_integer([:positive])}",
          type: "lounge",
          is_active: false,
          inserted_at: now,
          updated_at: now
        }
      ])

      # 4. Clips (public vs non-public)
      rec_id = Ecto.UUID.generate()
      {:ok, rec_bin} = Ecto.UUID.dump(rec_id)
      clip_id1 = Ecto.UUID.generate()
      clip_id2 = Ecto.UUID.generate()
      {:ok, clip_bin1} = Ecto.UUID.dump(clip_id1)
      {:ok, clip_bin2} = Ecto.UUID.dump(clip_id2)

      Repo.insert_all("voice_recordings", [
        %{
          id: rec_bin,
          community_id: comm_bin,
          room_id: room_bin1,
          host_user_id: user_bin,
          title: "Recording 1",
          audio_url: "https://example.com/audio.webm",
          started_at: now,
          inserted_at: now,
          updated_at: now
        }
      ])

      Repo.insert_all("voice_clips", [
        %{
          id: clip_bin1,
          recording_id: rec_bin,
          created_by_id: user_bin,
          title: "Public Clip",
          start_ms: 1000,
          end_ms: 5000,
          view_count: 10,
          is_public: true,
          inserted_at: now,
          updated_at: now
        },
        %{
          id: clip_bin2,
          recording_id: rec_bin,
          created_by_id: user_bin,
          title: "Private Clip",
          start_ms: 5000,
          end_ms: 10000,
          view_count: 0,
          is_public: false,
          inserted_at: now,
          updated_at: now
        }
      ])

      # 4. Announcements
      ann_id = Ecto.UUID.generate()
      {:ok, ann_bin} = Ecto.UUID.dump(ann_id)

      Repo.insert_all("announcements", [
        %{
          id: ann_bin,
          community_id: comm_bin,
          created_by_id: user_bin,
          title: "Grand Opening",
          body: "Welcome to the new community!",
          inserted_at: now,
          updated_at: now
        }
      ])

      # 5. Achievements (User Badges)
      badge_id = Ecto.UUID.generate()
      {:ok, badge_bin} = Ecto.UUID.dump(badge_id)
      ub_id = Ecto.UUID.generate()
      {:ok, ub_bin} = Ecto.UUID.dump(ub_id)

      Repo.insert_all("badges", [
        %{
          id: badge_bin,
          name: "Trailblazer #{System.unique_integer([:positive])}",
          inserted_at: now,
          updated_at: now
        }
      ])

      Repo.insert_all("user_badges", [
        %{
          id: ub_bin,
          community_id: comm_bin,
          user_id: user_bin,
          badge_id: badge_bin,
          inserted_at: now,
          updated_at: now
        }
      ])

      # 6. Polls
      poll_id = Ecto.UUID.generate()
      {:ok, poll_bin} = Ecto.UUID.dump(poll_id)
      {:ok, thread_bin1} = Ecto.UUID.dump(thread1.id)

      Repo.insert_all("polls", [
        %{
          id: poll_bin,
          community_id: comm_bin,
          thread_id: thread_bin1,
          question: "Favorite programming language?",
          voter_count: 42,
          inserted_at: now,
          updated_at: now
        }
      ])

      # Start DummyRoomServer for room_id1 only
      start_supervised!({DummyRoomServer, room_id1})

      # Test default filter "all"
      all_feed = Feed.get_feed(community.id)
      types = Enum.map(all_feed, & &1.type)

      assert "status_post" in types
      assert "thread" in types
      assert "clip" in types
      assert "announcement" in types
      assert "achievement" in types
      assert "poll" in types
      assert "live_room" in types

      # Inactive room and empty room should NOT be in the feed
      refute Enum.any?(all_feed, fn item -> item.id in [room_id2, room_id3] end)

      # Private post and hidden thread and private clip should NOT be in the feed
      refute Enum.any?(all_feed, fn item -> item.id in [post_id3, thread5.id, clip_id2] end)

      # Test specific filters
      posts_only = Feed.get_feed(community.id, filter: "posts")
      assert Enum.all?(posts_only, &(&1.type == "status_post"))
      assert length(posts_only) == 2

      clips_only = Feed.get_feed(community.id, filter: "clips")
      assert Enum.all?(clips_only, &(&1.type == "clip"))
      assert length(clips_only) == 1
      assert hd(clips_only).id == clip_id1

      threads_only = Feed.get_feed(community.id, filter: "threads")
      assert Enum.all?(threads_only, &(&1.type == "thread"))
      assert length(threads_only) == 4

      polls_only = Feed.get_feed(community.id, filter: "polls")
      assert Enum.all?(polls_only, &(&1.type == "poll"))
      assert length(polls_only) == 1

      live_only = Feed.get_feed(community.id, filter: "live")
      assert Enum.all?(live_only, &(&1.type == "live_room"))
      assert length(live_only) == 1
      assert hd(live_only).data.participant_count == 1

      friends_feed = Feed.get_feed(community.id, filter: "friends", user_id: user.id)
      friend_types = Enum.map(friends_feed, & &1.type) |> Enum.uniq() |> Enum.sort()
      assert friend_types == ["achievement", "clip", "status_post", "thread"]

      # Test limit
      limited = Feed.get_feed(community.id, limit: 3)
      assert length(limited) == 3

      # Test before pagination
      before_ts = NaiveDateTime.add(now, -1800, :second)
      before_feed = Feed.get_feed(community.id, before: before_ts)
      # Only earlier items (post_id2) should appear
      assert Enum.any?(before_feed, &(&1.id == post_id2))
      refute Enum.any?(before_feed, &(&1.id == post_id1))
    end
  end

  describe "to_unix/1" do
    test "converts DateTime, NaiveDateTime, and fallback values to unix timestamp" do
      dt = ~U[2026-01-01 12:00:00Z]
      ndt = ~N[2026-01-01 12:00:00]

      assert Feed.to_unix(dt) == DateTime.to_unix(dt)
      assert Feed.to_unix(ndt) == NaiveDateTime.diff(ndt, ~N[1970-01-01 00:00:00])
      assert Feed.to_unix(nil) == 0
      assert Feed.to_unix("invalid") == 0
    end
  end
end
