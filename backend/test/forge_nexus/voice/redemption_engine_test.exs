defmodule ForgeNexus.Voice.RedemptionEngineTest do
  use ForgeNexus.DataCase

  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Economy
  alias ForgeNexus.Repo
  alias ForgeNexus.Voice.{Redeemable, RedemptionEngine, Room, SoundboardClip}

  setup do
    Application.put_env(:forge_nexus, :redemption_async_runner, fn fun -> fun.() end)
    Application.put_env(:forge_nexus, :redemption_sleep_fn, fn _ms -> :ok end)

    on_exit(fn ->
      Application.delete_env(:forge_nexus, :redemption_async_runner)
      Application.delete_env(:forge_nexus, :redemption_sleep_fn)
    end)

    :ok
  end

  defp create_user(attrs \\ %{}) do
    uid = System.unique_integer([:positive])

    defaults = %{
      email: "user_#{uid}@example.com",
      username: "user_#{uid}",
      password: "Password1234!",
      password_confirmation: "Password1234!"
    }

    user =
      %User{}
      |> User.registration_changeset(Map.merge(defaults, attrs))
      |> Repo.insert!()

    points = Map.get(attrs, :points, 1000)

    from(u in User, where: u.id == ^user.id)
    |> Repo.update_all(set: [points: points])

    Repo.get!(User, user.id)
  end

  defp create_room(user, attrs \\ %{}) do
    uid = System.unique_integer([:positive])

    defaults = %{
      name: "Voice Lounge #{uid}",
      type: "lounge",
      created_by_id: user.id
    }

    %Room{}
    |> Room.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp create_redeemable(room, user, attrs \\ %{}) do
    uid = System.unique_integer([:positive])

    defaults = %{
      room_id: room.id,
      created_by_id: user.id,
      name: "Reward #{uid}",
      type: "highlighted_message",
      cost: 50,
      is_enabled: true
    }

    %Redeemable{}
    |> Redeemable.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  describe "redeem/4 validations and limits" do
    test "returns error when redeemable is not found" do
      room_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               RedemptionEngine.redeem(Ecto.UUID.generate(), room_id, user_id)
    end

    test "returns error when redeemable is disabled" do
      user = create_user()
      room = create_room(user)
      redeemable = create_redeemable(room, user, %{is_enabled: false})

      assert {:error, :disabled} = RedemptionEngine.redeem(redeemable.id, room.id, user.id)
    end

    test "returns error when redeeming in wrong room" do
      user = create_user()
      room1 = create_room(user)
      room2 = create_room(user)
      redeemable = create_redeemable(room1, user)

      assert {:error, :wrong_room} = RedemptionEngine.redeem(redeemable.id, room2.id, user.id)
    end

    test "validates required user text" do
      user = create_user()
      room = create_room(user)
      redeemable = create_redeemable(room, user, %{requires_text: true})

      assert {:error, :text_required} =
               RedemptionEngine.redeem(redeemable.id, room.id, user.id, nil)

      assert {:error, :text_required} =
               RedemptionEngine.redeem(redeemable.id, room.id, user.id, "")

      assert {:ok, _} = RedemptionEngine.redeem(redeemable.id, room.id, user.id, "Hello!")
    end

    test "validates cooldown period" do
      user = create_user()
      room = create_room(user)
      redeemable = create_redeemable(room, user, %{cooldown_seconds: 60})

      assert {:ok, _} = RedemptionEngine.redeem(redeemable.id, room.id, user.id)
      assert {:error, :cooldown} = RedemptionEngine.redeem(redeemable.id, room.id, user.id)

      # When cooldown_seconds is 0 or negative
      redeemable_no_cd = create_redeemable(room, user, %{cooldown_seconds: 0})
      assert {:ok, _} = RedemptionEngine.redeem(redeemable_no_cd.id, room.id, user.id)
      assert {:ok, _} = RedemptionEngine.redeem(redeemable_no_cd.id, room.id, user.id)
    end

    test "validates per-stream limit" do
      user1 = create_user()
      user2 = create_user()
      room = create_room(user1)
      redeemable = create_redeemable(room, user1, %{max_per_stream: 1})

      assert {:ok, _} = RedemptionEngine.redeem(redeemable.id, room.id, user1.id)

      assert {:error, :stream_limit_reached} =
               RedemptionEngine.redeem(redeemable.id, room.id, user2.id)
    end

    test "validates per-user per-stream limit" do
      user1 = create_user()
      user2 = create_user()
      room = create_room(user1)
      redeemable = create_redeemable(room, user1, %{max_per_user_per_stream: 1})

      assert {:ok, _} = RedemptionEngine.redeem(redeemable.id, room.id, user1.id)

      assert {:error, :user_limit_reached} =
               RedemptionEngine.redeem(redeemable.id, room.id, user1.id)

      assert {:ok, _} = RedemptionEngine.redeem(redeemable.id, room.id, user2.id)
    end

    test "validates sufficient points" do
      user = create_user(%{points: 20})
      room = create_room(user)
      redeemable = create_redeemable(room, user, %{cost: 50})

      assert {:error, :insufficient_points} =
               RedemptionEngine.redeem(redeemable.id, room.id, user.id)
    end
  end

  describe "dispatch_effect for all types" do
    test "sound_effect with and without soundboard_clip_id" do
      user = create_user()
      room = create_room(user)

      clip =
        %SoundboardClip{}
        |> SoundboardClip.changeset(%{
          name: "Applause",
          room_id: room.id,
          audio_url: "https://example.com/sound.mp3",
          play_count: 0
        })
        |> Repo.insert!()

      r1 =
        create_redeemable(room, user, %{
          type: "sound_effect",
          config: %{
            "soundboard_clip_id" => clip.id,
            "audio_url" => "https://example.com/sound.mp3"
          }
        })

      assert {:ok, %{effect: effect}} = RedemptionEngine.redeem(r1.id, room.id, user.id)
      assert effect.type == "sound_effect"
      assert effect.clip_id == clip.id
      assert effect.audio_url == "https://example.com/sound.mp3"
      assert Repo.get!(SoundboardClip, clip.id).play_count == 1

      # without clip_id
      r2 = create_redeemable(room, user, %{type: "sound_effect", config: %{}})
      assert {:ok, %{effect: effect2}} = RedemptionEngine.redeem(r2.id, room.id, user.id)
      assert effect2.clip_id == nil
    end

    test "visual_effect with custom and default config" do
      user = create_user()
      room = create_room(user)

      r1 =
        create_redeemable(room, user, %{
          type: "visual_effect",
          config: %{"effect" => "sparkles", "duration_ms" => 5000, "color" => "#ff0000"}
        })

      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r1.id, room.id, user.id)
      assert e1.effect == "sparkles"
      assert e1.duration_ms == 5000
      assert e1.color == "#ff0000"

      r2 = create_redeemable(room, user, %{type: "visual_effect", config: %{}})
      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id)
      assert e2.effect == "confetti"
      assert e2.duration_ms == 3000
      assert e2.color == nil
    end

    test "highlighted_message with custom and default style" do
      user = create_user()
      room = create_room(user)

      r1 =
        create_redeemable(room, user, %{
          type: "highlighted_message",
          config: %{"style" => "neon"}
        })

      assert {:ok, %{effect: e1}} =
               RedemptionEngine.redeem(r1.id, room.id, user.id, "Nice stream!")

      assert e1.text == "Nice stream!"
      assert e1.style == "neon"

      r2 = create_redeemable(room, user, %{type: "highlighted_message", config: %{}})
      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id, "Hi")
      assert e2.style == "gold"
    end

    test "game_command with webhook and PubSub event" do
      user = create_user()
      room = create_room(user)

      r1 =
        create_redeemable(room, user, %{
          type: "game_command",
          config: %{
            "command" => "spawn_boss",
            "args" => %{"level" => 5},
            "webhook_url" => "http://127.0.0.1:1/nonexistent",
            "event_name" => "boss_spawned"
          }
        })

      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r1.id, room.id, user.id, "boss text")
      assert e1.type == "game_command"
      assert e1.command == "spawn_boss"

      r2 =
        create_redeemable(room, user, %{
          type: "game_command",
          config: %{"command" => "noop"}
        })

      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id)
      assert e2.command == "noop"
    end

    test "custom_flow with and without flow_id" do
      user = create_user()
      room = create_room(user)

      flow_id = Ecto.UUID.generate()

      r1 =
        create_redeemable(room, user, %{
          type: "custom_flow",
          name: "FlowTrigger",
          config: %{"flow_id" => flow_id}
        })

      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r1.id, room.id, user.id)
      assert e1.flow_id == flow_id

      r2 = create_redeemable(room, user, %{type: "custom_flow", config: %{}})
      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id)
      assert e2.flow_id == nil
    end

    test "webhook with and without url" do
      user = create_user()
      room = create_room(user)

      r1 =
        create_redeemable(room, user, %{
          type: "webhook",
          config: %{"webhook_url" => "http://127.0.0.1:1/nonexistent"}
        })

      assert {:ok, %{effect: e1}} =
               RedemptionEngine.redeem(r1.id, room.id, user.id, "webhook data")

      assert e1.type == "webhook"

      r2 = create_redeemable(room, user, %{type: "webhook", config: %{}})
      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id)
      assert e2.type == "webhook"
    end

    test "tts_message with custom and default config" do
      user = create_user()
      room = create_room(user)

      r1 =
        create_redeemable(room, user, %{
          type: "tts_message",
          config: %{"voice" => "alice", "rate" => 1.25, "max_length" => 100}
        })

      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r1.id, room.id, user.id, "Hello TTS")
      assert e1.text == "Hello TTS"
      assert e1.voice == "alice"
      assert e1.rate == 1.25
      assert e1.max_length == 100

      r2 = create_redeemable(room, user, %{type: "tts_message", config: %{}})
      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id, nil)
      assert e2.text == ""
      assert e2.voice == "default"
      assert e2.rate == 1.0
      assert e2.max_length == 200
    end

    test "temp_custom_title with text, default, and fallback" do
      user = create_user()
      room = create_room(user)

      r1 =
        create_redeemable(room, user, %{
          type: "temp_custom_title",
          config: %{"duration_hours" => 12}
        })

      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r1.id, room.id, user.id, "Pro Gamer")
      assert e1.title == "Pro Gamer"
      assert e1.duration_hours == 12

      r2 =
        create_redeemable(room, user, %{
          type: "temp_custom_title",
          config: %{"default_title" => "Moderator"}
        })

      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id, nil)
      assert e2.title == "Moderator"
      assert e2.duration_hours == 24

      r3 = create_redeemable(room, user, %{type: "temp_custom_title", config: %{}})
      assert {:ok, %{effect: e3}} = RedemptionEngine.redeem(r3.id, room.id, user.id, nil)
      assert e3.title == "VIP"
    end

    test "temp_username_color with text, default, and fallback" do
      user = create_user()
      room = create_room(user)

      r1 =
        create_redeemable(room, user, %{
          type: "temp_username_color",
          config: %{"duration_hours" => 6}
        })

      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r1.id, room.id, user.id, "#ff5500")
      assert e1.color == "#ff5500"
      assert e1.duration_hours == 6

      r2 =
        create_redeemable(room, user, %{
          type: "temp_username_color",
          config: %{"color" => "#00ff00"}
        })

      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id, nil)
      assert e2.color == "#00ff00"
      assert e2.duration_hours == 24

      r3 = create_redeemable(room, user, %{type: "temp_username_color", config: %{}})
      assert {:ok, %{effect: e3}} = RedemptionEngine.redeem(r3.id, room.id, user.id, nil)
      assert e3.color == "#6366f1"
    end

    test "queue_priority calls RoomServer" do
      user = create_user()
      room = create_room(user)
      r = create_redeemable(room, user, %{type: "queue_priority"})

      assert {:ok, %{effect: e}} = RedemptionEngine.redeem(r.id, room.id, user.id)
      assert e.type == "queue_priority"
    end

    test "choose_next_video with valid, invalid, and nil url" do
      user = create_user()
      room = create_room(user)
      r = create_redeemable(room, user, %{type: "choose_next_video"})

      # Valid YouTube
      yt_url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r.id, room.id, user.id, yt_url)
      assert e1.type == "choose_next_video"
      assert e1.media.type == :youtube

      # Invalid URL
      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r.id, room.id, user.id, "bad-url")
      assert e2.error == "invalid_url"

      # Nil URL
      assert {:ok, %{effect: e3}} = RedemptionEngine.redeem(r.id, room.id, user.id, nil)
      assert e3.error == "no_url"
    end

    test "timeout_user with config target, user_text target, and nil target" do
      user = create_user()
      room = create_room(user)

      target_id = Ecto.UUID.generate()

      r1 =
        create_redeemable(room, user, %{
          type: "timeout_user",
          config: %{"target_user_id" => target_id, "duration_seconds" => 120}
        })

      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r1.id, room.id, user.id)
      assert e1.target == target_id
      assert e1.duration_seconds == 120

      r2 = create_redeemable(room, user, %{type: "timeout_user", config: %{}})
      text_target = Ecto.UUID.generate()
      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id, text_target)
      assert e2.target == text_target
      assert e2.duration_seconds == 60

      assert {:ok, %{effect: e3}} = RedemptionEngine.redeem(r2.id, room.id, user.id, nil)
      assert e3.target == nil
    end

    test "raid with config target, text target, and nil target" do
      user = create_user()
      room = create_room(user)

      target_room = Ecto.UUID.generate()

      r1 =
        create_redeemable(room, user, %{
          type: "raid",
          config: %{"target_room_id" => target_room}
        })

      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r1.id, room.id, user.id)
      assert e1.target_room_id == target_room

      r2 = create_redeemable(room, user, %{type: "raid", config: %{}})
      text_room = Ecto.UUID.generate()
      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id, text_room)
      assert e2.target_room_id == text_room

      assert {:ok, %{effect: e3}} = RedemptionEngine.redeem(r2.id, room.id, user.id, nil)
      assert e3.target_room_id == nil
    end

    test "screen_takeover with custom and default config" do
      user = create_user()
      room = create_room(user)

      r1 =
        create_redeemable(room, user, %{
          type: "screen_takeover",
          config: %{"effect" => "matrix", "duration_ms" => 10_000, "color" => "#00ff00"}
        })

      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r1.id, room.id, user.id, "Takeover!")
      assert e1.effect == "matrix"
      assert e1.duration_ms == 10_000
      assert e1.color == "#00ff00"
      assert e1.text == "Takeover!"
      assert e1.size == "fullscreen"

      r2 = create_redeemable(room, user, %{type: "screen_takeover", config: %{}})
      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id)
      assert e2.effect == "fireworks"
      assert e2.duration_ms == 5000
      assert e2.color == "#6366f1"
    end

    test "gift_achievement with and without achievement_id" do
      user = create_user()
      room = create_room(user)

      {:ok, badge} =
        ForgeNexus.Forums.create_badge(%{
          name: "Badge #{System.unique_integer([:positive])}",
          category: "milestone"
        })

      r1 =
        create_redeemable(room, user, %{
          type: "gift_achievement",
          config: %{"achievement_id" => badge.id}
        })

      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r1.id, room.id, user.id)
      assert e1.achievement_id == badge.id

      r2 = create_redeemable(room, user, %{type: "gift_achievement", config: %{}})
      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id)
      assert e2.achievement_id == nil
    end

    test "emote_unlock returns effect map" do
      user = create_user()
      room = create_room(user)
      emote_id = Ecto.UUID.generate()

      r =
        create_redeemable(room, user, %{type: "emote_unlock", config: %{"emote_id" => emote_id}})

      assert {:ok, %{effect: e}} = RedemptionEngine.redeem(r.id, room.id, user.id)
      assert e.type == "emote_unlock"
      assert e.emote_id == emote_id
      assert e.user_id == user.id
    end

    test "slow_mode_toggle with custom and default duration" do
      user = create_user()
      room = create_room(user)

      r1 =
        create_redeemable(room, user, %{
          type: "slow_mode_toggle",
          config: %{"duration_seconds" => 60}
        })

      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r1.id, room.id, user.id)
      assert e1.duration_seconds == 60

      r2 = create_redeemable(room, user, %{type: "slow_mode_toggle", config: %{}})
      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id)
      assert e2.duration_seconds == 300
    end

    test "dare_challenge with custom and default style" do
      user = create_user()
      room = create_room(user)

      r1 =
        create_redeemable(room, user, %{
          type: "dare_challenge",
          config: %{"alert_style" => "ice"}
        })

      assert {:ok, %{effect: e1}} =
               RedemptionEngine.redeem(r1.id, room.id, user.id, "Eat a pepper")

      assert e1.text == "Eat a pepper"
      assert e1.alert_style == "ice"

      r2 = create_redeemable(room, user, %{type: "dare_challenge", config: %{}})
      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id, nil)
      assert e2.text == ""
      assert e2.alert_style == "fire"
    end

    test "hydration_check with sound config" do
      user = create_user()
      room = create_room(user)

      r =
        create_redeemable(room, user, %{
          type: "hydration_check",
          config: %{"sound_url" => "https://example.com/water.mp3"}
        })

      assert {:ok, %{effect: e}} = RedemptionEngine.redeem(r.id, room.id, user.id)
      assert e.type == "hydration_check"
      assert e.alert == true
      assert e.sound == "https://example.com/water.mp3"
    end

    test "change_room_title with text, default, and fallback" do
      user = create_user()
      room = create_room(user)

      r1 =
        create_redeemable(room, user, %{
          type: "change_room_title",
          config: %{"duration_minutes" => 15}
        })

      assert {:ok, %{effect: e1}} =
               RedemptionEngine.redeem(r1.id, room.id, user.id, "My Cool Title")

      assert e1.title == "My Cool Title"
      assert e1.duration_minutes == 15

      r2 =
        create_redeemable(room, user, %{
          type: "change_room_title",
          config: %{"default_title" => "Community Chill"}
        })

      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id, nil)
      assert e2.title == "Community Chill"
      assert e2.duration_minutes == 5

      r3 = create_redeemable(room, user, %{type: "change_room_title", config: %{}})
      assert {:ok, %{effect: e3}} = RedemptionEngine.redeem(r3.id, room.id, user.id, nil)
      assert e3.title == "Viewer Takeover!"
    end

    test "dj_request with valid, invalid, and nil url" do
      user = create_user()
      room = create_room(user)
      r = create_redeemable(room, user, %{type: "dj_request"})

      yt_url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r.id, room.id, user.id, yt_url)
      assert e1.type == "dj_request"
      assert e1.priority == true
      assert e1.media.type == :youtube

      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r.id, room.id, user.id, "not-valid")
      assert e2.error == "invalid_url"

      assert {:ok, %{effect: e3}} = RedemptionEngine.redeem(r.id, room.id, user.id, nil)
      assert e3.error == "no_url"
    end

    test "spotlight with custom and default duration" do
      user = create_user()
      room = create_room(user)

      r1 =
        create_redeemable(room, user, %{
          type: "spotlight",
          config: %{"duration_seconds" => 45}
        })

      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r1.id, room.id, user.id)
      assert e1.duration_seconds == 45

      r2 = create_redeemable(room, user, %{type: "spotlight", config: %{}})
      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id)
      assert e2.duration_seconds == 30
    end

    test "shoutout with user_text, default, and fallback" do
      user = create_user()
      room = create_room(user)

      r1 = create_redeemable(room, user, %{type: "shoutout", config: %{}})

      assert {:ok, %{effect: e1}} =
               RedemptionEngine.redeem(r1.id, room.id, user.id, "Follow Alice!")

      assert e1.message == "Follow Alice!"

      r2 =
        create_redeemable(room, user, %{
          type: "shoutout",
          config: %{"default_message" => "Awesome streamer!"}
        })

      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id, nil)
      assert e2.message == "Awesome streamer!"

      r3 = create_redeemable(room, user, %{type: "shoutout", config: %{}})
      assert {:ok, %{effect: e3}} = RedemptionEngine.redeem(r3.id, room.id, user.id, nil)
      assert e3.message == "Check them out!"
    end

    test "emoji_rain with user_text, default, and config count" do
      user = create_user()
      room = create_room(user)

      r1 =
        create_redeemable(room, user, %{
          type: "emoji_rain",
          config: %{"emoji" => "🔥", "count" => 100, "duration_ms" => 6000}
        })

      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r1.id, room.id, user.id, "🚀")
      assert e1.emoji == "🚀"
      assert e1.count == 100

      r2 = create_redeemable(room, user, %{type: "emoji_rain", config: %{}})
      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id, nil)
      assert e2.emoji == "🎉"
      assert e2.count == 50
    end

    test "lucky_wheel award_points action (amount > 0 and amount <= 0)" do
      user = create_user(%{points: 100})
      room = create_room(user)

      # amount > 0
      r1 =
        create_redeemable(room, user, %{
          type: "lucky_wheel",
          cost: 10,
          config: %{
            "prizes" => [
              %{"label" => "100 pts", "weight" => 1, "action" => "award_points", "value" => 100}
            ]
          }
        })

      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r1.id, room.id, user.id)
      assert e1.prize == "100 pts"
      assert Economy.get_points(user.id) == 190

      # amount == 0
      r2 =
        create_redeemable(room, user, %{
          type: "lucky_wheel",
          cost: 10,
          config: %{
            "prizes" => [
              %{"label" => "0 pts", "weight" => 1, "action" => "award_points", "value" => 0}
            ]
          }
        })

      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id)
      assert e2.prize == "0 pts"
    end

    test "lucky_wheel temp_title and default fallback actions" do
      user = create_user()
      room = create_room(user)

      # temp_title
      r1 =
        create_redeemable(room, user, %{
          type: "lucky_wheel",
          cost: 10,
          config: %{
            "prizes" => [
              %{
                "label" => "VIP Title",
                "weight" => 1,
                "action" => "temp_title",
                "value" => "Superstar"
              }
            ]
          }
        })

      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r1.id, room.id, user.id)
      assert e1.prize == "VIP Title"

      # temp_title with nil value (fallback "Lucky")
      r1_nil =
        create_redeemable(room, user, %{
          type: "lucky_wheel",
          cost: 10,
          config: %{
            "prizes" => [
              %{
                "label" => "Default Title",
                "weight" => 1,
                "action" => "temp_title",
                "value" => nil
              }
            ]
          }
        })

      assert {:ok, %{effect: e1_nil}} = RedemptionEngine.redeem(r1_nil.id, room.id, user.id)
      assert e1_nil.prize == "Default Title"

      # default fallback action (none)
      r2 =
        create_redeemable(room, user, %{
          type: "lucky_wheel",
          cost: 10,
          config: %{
            "prizes" => [
              %{"label" => "Nothing", "weight" => 1, "action" => "none", "value" => nil}
            ]
          }
        })

      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id)
      assert e2.prize == "Nothing"

      # default prizes when prizes not in config
      r3 = create_redeemable(room, user, %{type: "lucky_wheel", cost: 10, config: %{}})
      assert {:ok, %{effect: e3}} = RedemptionEngine.redeem(r3.id, room.id, user.id)
      assert is_binary(e3.prize)
    end

    test "banner_message with text and defaults" do
      user = create_user()
      room = create_room(user)

      r1 =
        create_redeemable(room, user, %{
          type: "banner_message",
          config: %{"duration_minutes" => 10}
        })

      assert {:ok, %{effect: e1}} =
               RedemptionEngine.redeem(r1.id, room.id, user.id, "Attention all!")

      assert e1.text == "Attention all!"
      assert e1.duration_minutes == 10

      r2 = create_redeemable(room, user, %{type: "banner_message", config: %{}})
      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id, nil)
      assert e2.text == ""
      assert e2.duration_minutes == 3
    end

    test "collab_request broadcasts and sets hand raised" do
      user = create_user()
      room = create_room(user)
      r = create_redeemable(room, user, %{type: "collab_request"})

      assert {:ok, %{effect: e}} =
               RedemptionEngine.redeem(r.id, room.id, user.id, "Let's play together")

      assert e.type == "collab_request"
      assert e.auto_raised_hand == true
    end

    test "pet_spawn with config, text, and default" do
      user = create_user()
      room = create_room(user)

      r1 =
        create_redeemable(room, user, %{
          type: "pet_spawn",
          config: %{"pet_type" => "dragon", "pet_name" => "Smaug"}
        })

      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r1.id, room.id, user.id)
      assert e1.pet_type == "dragon"

      r2 = create_redeemable(room, user, %{type: "pet_spawn", config: %{}})
      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id, "puppy")
      assert e2.pet_type == "puppy"

      assert {:ok, %{effect: e3}} = RedemptionEngine.redeem(r2.id, room.id, user.id, nil)
      assert e3.pet_type == "cat"
    end

    test "quest_trigger with config, text, and default" do
      user = create_user()
      room = create_room(user)

      r1 =
        create_redeemable(room, user, %{
          type: "quest_trigger",
          config: %{"quest_name" => "Raid Boss Quest"}
        })

      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r1.id, room.id, user.id)
      assert e1.quest_name == "Raid Boss Quest"

      r2 = create_redeemable(room, user, %{type: "quest_trigger", config: %{}})

      assert {:ok, %{effect: e2}} =
               RedemptionEngine.redeem(r2.id, room.id, user.id, "Custom Quest")

      assert e2.quest_name == "Custom Quest"

      assert {:ok, %{effect: e3}} = RedemptionEngine.redeem(r2.id, room.id, user.id, nil)
      assert e3.quest_name == "Community Challenge"
    end

    test "force_poll with custom and default options" do
      user = create_user()
      room = create_room(user)

      r1 =
        create_redeemable(room, user, %{
          type: "force_poll",
          config: %{"options" => ["Option A", "Option B", "Option C"]}
        })

      assert {:ok, %{effect: e1}} =
               RedemptionEngine.redeem(r1.id, room.id, user.id, "Which game?")

      assert e1.question == "Which game?"

      r2 = create_redeemable(room, user, %{type: "force_poll", config: %{}})
      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id, nil)
      assert e2.question == "Vote!"
    end

    test "gift_points with target and amount > 0, and nil target" do
      user1 = create_user(%{points: 200})
      user2 = create_user(%{points: 50})
      room = create_room(user1)

      r1 =
        create_redeemable(room, user1, %{
          type: "gift_points",
          cost: 50,
          config: %{"target_user_id" => user2.id, "gift_amount" => 50}
        })

      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r1.id, room.id, user1.id)
      assert e1.target == user2.id
      assert e1.amount == 50
      assert Economy.get_points(user2.id) == 100

      # target_id in user_text
      r2 = create_redeemable(room, user1, %{type: "gift_points", cost: 30, config: %{}})
      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user1.id, user2.id)
      assert e2.target == user2.id
      assert e2.amount == 30

      # target_id is nil
      assert {:ok, %{effect: e3}} = RedemptionEngine.redeem(r2.id, room.id, user1.id, nil)
      assert e3.target == nil
    end

    test "combo_multiplier with custom and default config" do
      user = create_user()
      room = create_room(user)

      r1 =
        create_redeemable(room, user, %{
          type: "combo_multiplier",
          config: %{"multiplier" => 3, "window_seconds" => 20}
        })

      assert {:ok, %{effect: e1}} = RedemptionEngine.redeem(r1.id, room.id, user.id)
      assert e1.multiplier == 3
      assert e1.window_seconds == 20

      r2 = create_redeemable(room, user, %{type: "combo_multiplier", config: %{}})
      assert {:ok, %{effect: e2}} = RedemptionEngine.redeem(r2.id, room.id, user.id)
      assert e2.multiplier == 2
      assert e2.window_seconds == 10
    end

    test "fallback for unknown or unhandled redeemable type" do
      user = create_user()
      room = create_room(user)
      r = create_redeemable(room, user, %{type: "highlighted_message"})

      from(red in Redeemable, where: red.id == ^r.id)
      |> Repo.update_all(set: [type: "unknown_custom_type"])

      assert {:ok, %{effect: e}} = RedemptionEngine.redeem(r.id, room.id, user.id)
      assert e.type == "unknown_custom_type"
    end
  end

  describe "default async runner, sleep, and webhook error rescue" do
    test "exercises default Task.start and sleep when custom runners are deleted" do
      user = create_user()
      room = create_room(user)

      Application.delete_env(:forge_nexus, :redemption_async_runner)
      Application.delete_env(:forge_nexus, :redemption_sleep_fn)

      r =
        create_redeemable(room, user, %{
          type: "webhook",
          config: %{"webhook_url" => 123}
        })

      assert {:ok, %{effect: e}} = RedemptionEngine.redeem(r.id, room.id, user.id)
      assert e.type == "webhook"

      # Exercise default sleep (_ -> :ok) when redemption_sleep_fn is nil
      Application.put_env(:forge_nexus, :redemption_async_runner, fn fun -> fun.() end)
      Application.delete_env(:forge_nexus, :redemption_sleep_fn)
      r_title = create_redeemable(room, user, %{type: "temp_custom_title"})
      assert {:ok, _} = RedemptionEngine.redeem(r_title.id, room.id, user.id)

      # Also test custom sleep function
      Application.put_env(:forge_nexus, :redemption_sleep_fn, fn _ms -> :ok end)
      assert {:ok, _} = RedemptionEngine.redeem(r_title.id, room.id, user.id)
    end
  end
end
