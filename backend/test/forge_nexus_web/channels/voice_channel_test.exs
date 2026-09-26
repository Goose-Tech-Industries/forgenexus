defmodule ForgeNexusWeb.VoiceChannelTest do
  use ForgeNexusWeb.ChannelCase

  alias ForgeNexus.Accounts
  alias ForgeNexus.Voice
  alias ForgeNexus.Voice.SoundboardClip
  alias ForgeNexusWeb.{UserSocket, VoiceChannel}

  defp create_user(attrs \\ %{}) do
    unique_suffix = System.unique_integer([:positive])

    defaults = %{
      username: "voice_user_#{unique_suffix}",
      email: "voice_user_#{unique_suffix}@example.com",
      password: "SecurePass!987654#Alpha",
      password_confirmation: "SecurePass!987654#Alpha"
    }

    {:ok, user} =
      defaults
      |> Accounts.register_user()

    user
    |> Ecto.Changeset.change(attrs)
    |> Repo.update!()
  end

  defp create_room(user, attrs \\ %{}) do
    unique_suffix = System.unique_integer([:positive])

    defaults = %{
      name: "Voice Lounge #{unique_suffix}",
      type: "lounge",
      max_participants: 20,
      created_by_id: user.id
    }

    {:ok, room} =
      defaults
      |> Map.merge(Enum.into(attrs, %{}))
      |> Voice.create_room()

    room
  end

  setup do
    user = create_user()
    room = create_room(user)
    socket = socket(UserSocket, "user_socket:#{user.id}", %{current_user: user})

    {:ok, info, channel_socket} =
      subscribe_and_join(socket, VoiceChannel, "voice:#{room.id}")

    %{
      user: user,
      room: room,
      socket: channel_socket,
      raw_socket: socket,
      join_info: info
    }
  end

  describe "join/3" do
    test "rejects non-uuid room id", %{raw_socket: socket} do
      assert {:error, %{reason: "invalid room id"}} =
               subscribe_and_join(socket, VoiceChannel, "voice:not-a-uuid")
    end

    test "rejects non-existent room uuid", %{raw_socket: socket} do
      random_uuid = Ecto.UUID.generate()

      assert {:error, %{reason: "room not found"}} =
               subscribe_and_join(socket, VoiceChannel, "voice:#{random_uuid}")
    end

    test "successfully joins room and receives participant info and livekit config", %{
      join_info: info,
      socket: socket,
      room: room
    } do
      assert socket.assigns.room_id == room.id
      assert is_map(info)
      assert Map.has_key?(info, :livekit)
    end
  end

  describe "WebRTC signaling & media updates" do
    test "broadcasts signal:offer to target peer", %{socket: socket, user: user} do
      target_id = Ecto.UUID.generate()
      offer_data = %{"sdp" => "v=0...", "type" => "offer"}

      push(socket, "signal:offer", %{"to" => target_id, "offer" => offer_data})

      assert_broadcast "signal:offer", %{
        from: uid,
        to: ^target_id,
        offer: ^offer_data
      }

      assert uid == user.id
    end

    test "broadcasts signal:answer to target peer", %{socket: socket, user: user} do
      target_id = Ecto.UUID.generate()
      answer_data = %{"sdp" => "v=0...", "type" => "answer"}

      push(socket, "signal:answer", %{"to" => target_id, "answer" => answer_data})

      assert_broadcast "signal:answer", %{
        from: uid,
        to: ^target_id,
        answer: ^answer_data
      }

      assert uid == user.id
    end

    test "broadcasts signal:ice_candidate to target peer", %{socket: socket, user: user} do
      target_id = Ecto.UUID.generate()
      candidate_data = %{"candidate" => "candidate:1 1 UDP ..."}

      push(socket, "signal:ice_candidate", %{
        "to" => target_id,
        "candidate" => candidate_data
      })

      assert_broadcast "signal:ice_candidate", %{
        from: uid,
        to: ^target_id,
        candidate: ^candidate_data
      }

      assert uid == user.id
    end

    test "updates media state and speaking indicator", %{socket: socket, user: user} do
      ref =
        push(socket, "media:update", %{
          "muted" => true,
          "deafened" => false,
          "video" => true,
          "screen_share" => false
        })

      assert_reply ref, :ok, %{}

      push(socket, "speaking", %{"speaking" => true})

      assert_broadcast "speaking", %{
        user_id: uid,
        speaking: true
      }

      assert uid == user.id
    end
  end

  describe "Stage mode and town hall controls" do
    test "handles hand raise and hand queue in town_hall room", %{user: host} do
      th_room = create_room(host, %{type: "town_hall"})
      audience_user = create_user()

      aud_socket =
        socket(UserSocket, "user_socket:#{audience_user.id}", %{current_user: audience_user})

      {:ok, _, aud_chan} =
        subscribe_and_join(aud_socket, VoiceChannel, "voice:#{th_room.id}")

      ref = push(aud_chan, "stage:raise_hand", %{"raised" => true})
      assert_reply ref, :ok, %{hand_raised: true}

      ref2 = push(aud_chan, "stage:hand_queue", %{})
      assert_reply ref2, :ok, %{queue: queue}
      assert is_list(queue)

      ref3 = push(aud_chan, "stage:raise_hand", %{"raised" => false})
      assert_reply ref3, :ok, %{hand_raised: false}
    end

    test "handles promotion, demotion, and co-host assignments", %{
      socket: socket,
      room: room
    } do
      other_user = create_user()

      other_socket =
        socket(UserSocket, "user_socket:#{other_user.id}", %{current_user: other_user})

      {:ok, _, _other_chan} =
        subscribe_and_join(other_socket, VoiceChannel, "voice:#{room.id}")

      ref = push(socket, "stage:promote", %{"user_id" => other_user.id})
      assert_reply ref, :ok, %{}

      ref2 = push(socket, "stage:demote", %{"user_id" => other_user.id})
      assert_reply ref2, :ok, %{}

      ref3 = push(socket, "stage:co_host", %{"user_id" => other_user.id})
      assert_reply ref3, :ok, %{}
    end
  end

  describe "In-room polls" do
    test "creates, fetches, votes on, and closes poll", %{socket: socket} do
      # Create poll
      ref =
        push(socket, "poll:create", %{
          "question" => "Favorite color?",
          "options" => ["Red", "Blue", "Green"]
        })

      assert_reply ref, :ok, %{poll: poll}
      assert poll.question == "Favorite color?"

      # Fetch poll
      ref2 = push(socket, "poll:get", %{})
      assert_reply ref2, :ok, %{poll: fetched_poll}
      assert fetched_poll.question == "Favorite color?"

      # Vote on poll
      ref3 = push(socket, "poll:vote", %{"option" => 1})
      assert_reply ref3, :ok, %{}

      # Close poll
      ref4 = push(socket, "poll:close", %{})
      assert_reply ref4, :ok, %{results: _results}
    end
  end

  describe "Soundboard, reactions, and redeemables" do
    test "lists soundboard clips and handles playing missing or existing clip", %{socket: socket} do
      ref = push(socket, "soundboard:list", %{})
      assert_reply ref, :ok, %{clips: clips}
      assert is_list(clips)

      # Missing clip
      ref2 = push(socket, "soundboard:play", %{"clip_id" => Ecto.UUID.generate()})
      assert_reply ref2, :error, %{reason: "clip_not_found"}

      # Existing clip
      {:ok, clip} =
        %SoundboardClip{}
        |> SoundboardClip.changeset(%{
          name: "Airhorn",
          emoji: "📢",
          audio_url: "https://example.com/airhorn.mp3",
          duration_ms: 1500,
          is_global: true
        })
        |> Repo.insert()

      ref3 = push(socket, "soundboard:play", %{"clip_id" => clip.id})
      assert_reply ref3, :ok, %{}

      assert_broadcast "soundboard:played", %{
        clip_id: cid,
        name: "Airhorn"
      }

      assert cid == clip.id
    end

    test "handles live reactions and enforces rate limiting", %{socket: socket} do
      # 3 reactions should succeed
      ref1 = push(socket, "reaction:send", %{"emoji" => "🔥"})
      assert_reply ref1, :ok, %{}
      assert_broadcast "reaction", %{emoji: "🔥"}

      ref2 = push(socket, "reaction:send", %{"emoji" => "🎉"})
      assert_reply ref2, :ok, %{}

      ref3 = push(socket, "reaction:send", %{"emoji" => "👏"})
      assert_reply ref3, :ok, %{}

      # 4th immediate reaction hits the 3/second rate limit
      ref4 = push(socket, "reaction:send", %{"emoji" => "🚀"})
      assert_reply ref4, :error, %{reason: "rate_limited"}
    end

    test "lists redeemables for the room", %{socket: socket} do
      ref = push(socket, "redeemables:list", %{})
      assert_reply ref, :ok, %{redeemables: items}
      assert is_list(items)
    end
  end

  describe "Watch party controls" do
    test "starts, controls, and stops a watch party", %{socket: socket} do
      ref = push(socket, "watch:start", %{"url" => "https://www.youtube.com/watch?v=dQw4w9WgXcQ"})
      assert_reply ref, :ok, %{party: party}
      assert party.media.url == "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

      ref_play = push(socket, "watch:play", %{})
      assert_reply ref_play, :ok, %{}

      ref_pause = push(socket, "watch:pause", %{})
      assert_reply ref_pause, :ok, %{}

      ref_seek = push(socket, "watch:seek", %{"time" => 45.5})
      assert_reply ref_seek, :ok, %{}

      ref_sync = push(socket, "watch:sync", %{"time" => 50.0, "playing" => true})
      assert_reply ref_sync, :ok, %{}

      ref_qadd = push(socket, "watch:queue_add", %{"url" => "https://example.com/v2.mp4"})
      assert_reply ref_qadd, :ok, %{}

      ref_qrem = push(socket, "watch:queue_remove", %{"index" => 0})
      assert_reply ref_qrem, :ok, %{}

      ref_qclr = push(socket, "watch:queue_clear", %{})
      assert_reply ref_qclr, :ok, %{}

      ref_stop = push(socket, "watch:stop", %{})
      assert_reply ref_stop, :ok, %{}
    end
  end

  describe "fallback error handler & terminate" do
    test "handles unknown or malformed event gracefully", %{socket: socket} do
      ref = push(socket, "unknown_voice_event", %{"key" => "val"})

      assert_reply ref, :error, %{
        reason: "unknown or malformed event",
        event: "unknown_voice_event"
      }
    end

    test "terminates cleanly and leaves room", %{socket: socket} do
      assert :ok = VoiceChannel.terminate(:normal, socket)
    end
  end
end
