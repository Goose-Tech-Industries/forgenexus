defmodule ForgeNexus.Voice.VoiceSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Voice.{
    Clip,
    CreatorModerator,
    DmCall,
    Recording,
    Redeemable,
    Redemption,
    Room,
    SoundboardClip
  }

  describe "Clip" do
    @rid Ecto.UUID.generate()

    test "valid changeset and validate_clip_range" do
      cs =
        Clip.changeset(%Clip{}, %{
          recording_id: @rid,
          title: "Funny Moment",
          start_ms: 10_000,
          end_ms: 25_000
        })

      assert cs.valid?

      req_cs = Clip.changeset(%Clip{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).recording_id
      assert "can't be blank" in errors_on(req_cs).start_ms
      assert "can't be blank" in errors_on(req_cs).end_ms

      # end <= start
      reversed_cs =
        Clip.changeset(%Clip{}, %{
          recording_id: @rid,
          start_ms: 20_000,
          end_ms: 10_000
        })

      refute reversed_cs.valid?
      assert "must be after start" in errors_on(reversed_cs).end_ms

      # duration < 1s
      too_short_cs =
        Clip.changeset(%Clip{}, %{
          recording_id: @rid,
          start_ms: 10_000,
          end_ms: 10_500
        })

      refute too_short_cs.valid?
      assert "clip must be at least 1 second" in errors_on(too_short_cs).end_ms

      # duration > 2m
      too_long_cs =
        Clip.changeset(%Clip{}, %{
          recording_id: @rid,
          start_ms: 10_000,
          end_ms: 140_000
        })

      refute too_long_cs.valid?
      assert "clip cannot exceed 2 minutes" in errors_on(too_long_cs).end_ms
    end
  end

  describe "CreatorModerator" do
    @cid Ecto.UUID.generate()
    @mid Ecto.UUID.generate()

    test "valid changeset, default_permissions/0, has_permission?/2" do
      defaults = CreatorModerator.default_permissions()
      assert defaults["manage_chat"] == true
      assert defaults["ban_users"] == false

      cs =
        CreatorModerator.changeset(%CreatorModerator{}, %{
          creator_id: @cid,
          moderator_id: @mid,
          permissions: %{"manage_chat" => true, "ban_users" => true}
        })

      assert cs.valid?

      mod = %CreatorModerator{permissions: %{"ban_users" => true}}
      assert CreatorModerator.has_permission?(mod, "ban_users")
      refute CreatorModerator.has_permission?(mod, "manage_soundboard")

      # nil permissions fallback
      mod_nil = %CreatorModerator{permissions: nil}
      assert CreatorModerator.has_permission?(mod_nil, "manage_chat")
      refute CreatorModerator.has_permission?(mod_nil, "ban_users")

      req_cs = CreatorModerator.changeset(%CreatorModerator{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).creator_id
      assert "can't be blank" in errors_on(req_cs).moderator_id
    end
  end

  describe "DmCall" do
    @cid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset and inclusions" do
      for status <- ["ringing", "active", "ended", "missed", "declined"] do
        for type <- ["audio", "video"] do
          cs =
            DmCall.changeset(%DmCall{}, %{
              conversation_id: @cid,
              caller_id: @uid,
              status: status,
              type: type
            })

          assert cs.valid?
          assert get_field(cs, :status) == status
          assert get_field(cs, :type) == type
        end
      end

      req_cs = DmCall.changeset(%DmCall{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).conversation_id
      assert "can't be blank" in errors_on(req_cs).caller_id

      bad_cs =
        DmCall.changeset(%DmCall{}, %{
          conversation_id: @cid,
          caller_id: @uid,
          status: "lost",
          type: "hologram"
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).status
      assert "is invalid" in errors_on(bad_cs).type
    end
  end

  describe "Recording" do
    @rid Ecto.UUID.generate()

    test "valid changeset, transcript_statuses/0 and inclusions" do
      statuses = Recording.transcript_statuses()
      assert "pending" in statuses
      assert "ready" in statuses

      start_time = ~U[2026-03-01 12:00:00Z]

      for status <- statuses do
        cs =
          Recording.changeset(%Recording{}, %{
            room_id: @rid,
            audio_url: "https://cdn.example.com/recording.webm",
            started_at: start_time,
            transcript_status: status
          })

        assert cs.valid?
        assert get_field(cs, :transcript_status) == status
      end

      req_cs = Recording.changeset(%Recording{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).room_id
      assert "can't be blank" in errors_on(req_cs).audio_url
      assert "can't be blank" in errors_on(req_cs).started_at

      bad_status_cs =
        Recording.changeset(%Recording{}, %{
          room_id: @rid,
          audio_url: "https://example.com/audio",
          started_at: start_time,
          transcript_status: "corrupted"
        })

      refute bad_status_cs.valid?
      assert "is invalid" in errors_on(bad_status_cs).transcript_status
    end
  end

  describe "Redeemable" do
    test "valid changeset, types/0, and validations" do
      types = Redeemable.types()
      assert is_list(types)
      assert length(types) > 0

      for rtype <- types do
        cs =
          Redeemable.changeset(%Redeemable{}, %{
            name: "Highlight Message",
            cost: 100,
            type: rtype,
            emoji: "✨",
            cooldown_seconds: 30
          })

        assert cs.valid?
        assert get_field(cs, :type) == rtype
      end

      req_cs = Redeemable.changeset(%Redeemable{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).cost
      assert "can't be blank" in errors_on(req_cs).type

      bad_cs =
        Redeemable.changeset(%Redeemable{}, %{
          name: "Test",
          cost: 0,
          type: "unknown_type",
          cooldown_seconds: -1
        })

      refute bad_cs.valid?
      assert "must be greater than 0" in errors_on(bad_cs).cost
      assert "is invalid" in errors_on(bad_cs).type
      assert "must be greater than or equal to 0" in errors_on(bad_cs).cooldown_seconds
    end
  end

  describe "Redemption" do
    @rid Ecto.UUID.generate()
    @roid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset and status inclusions" do
      for status <- ~w(fulfilled pending refunded) do
        cs =
          Redemption.changeset(%Redemption{}, %{
            redeemable_id: @rid,
            room_id: @roid,
            user_id: @uid,
            cost: 50,
            status: status
          })

        assert cs.valid?
        assert get_field(cs, :status) == status
      end

      req_cs = Redemption.changeset(%Redemption{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).redeemable_id
      assert "can't be blank" in errors_on(req_cs).room_id
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).cost

      bad_status_cs =
        Redemption.changeset(%Redemption{}, %{
          redeemable_id: @rid,
          room_id: @roid,
          user_id: @uid,
          cost: 50,
          status: "destroyed"
        })

      refute bad_status_cs.valid?
      assert "is invalid" in errors_on(bad_status_cs).status
    end
  end

  describe "Room" do
    test "valid changeset, type inclusions, and max_participants bounds" do
      for type <- ["lounge", "huddle", "town_hall"] do
        cs =
          Room.changeset(%Room{}, %{
            name: "Main Stage",
            type: type,
            max_participants: 100
          })

        assert cs.valid?
        assert get_field(cs, :type) == type
      end

      req_cs = Room.changeset(%Room{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name

      bad_type_cs =
        Room.changeset(%Room{}, %{
          name: "Stage",
          type: "auditorium"
        })

      refute bad_type_cs.valid?
      assert "is invalid" in errors_on(bad_type_cs).type

      zero_part_cs = Room.changeset(%Room{}, %{name: "Stage", max_participants: 0})
      refute zero_part_cs.valid?
      assert "must be greater than 0" in errors_on(zero_part_cs).max_participants

      over_part_cs = Room.changeset(%Room{}, %{name: "Stage", max_participants: 501})
      refute over_part_cs.valid?
      assert "must be less than or equal to 500" in errors_on(over_part_cs).max_participants
    end
  end

  describe "SoundboardClip" do
    test "valid changeset and size/duration limits" do
      cs =
        SoundboardClip.changeset(%SoundboardClip{}, %{
          name: "Applause",
          audio_url: "https://cdn.example.com/applause.mp3",
          duration_ms: 5000,
          size_bytes: 500_000,
          emoji: "👏"
        })

      assert cs.valid?

      req_cs = SoundboardClip.changeset(%SoundboardClip{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).audio_url

      over_cs =
        SoundboardClip.changeset(%SoundboardClip{}, %{
          name: "Long sound",
          audio_url: "https://cdn.example.com/sound.mp3",
          duration_ms: 35_000,
          size_bytes: 3 * 1024 * 1024
        })

      refute over_cs.valid?
      assert "must be less than or equal to 30000" in errors_on(over_cs).duration_ms
      assert "must be less than or equal to 2097152" in errors_on(over_cs).size_bytes
    end
  end
end
