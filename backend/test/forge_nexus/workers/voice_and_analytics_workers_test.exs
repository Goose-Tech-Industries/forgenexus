defmodule ForgeNexus.Workers.VoiceAndAnalyticsWorkersTest do
  use ForgeNexus.DataCase, async: false
  use Oban.Testing, repo: ForgeNexus.Repo

  alias ForgeNexus.{Accounts, Forums, Repo, Settings, Voice}
  alias ForgeNexus.Analytics.CommunityStats
  alias ForgeNexus.Voice.Recording

  alias ForgeNexus.Workers.{
    AnalyticsDailyWorker,
    AutoHighlightWorker,
    RoomAutoThreadWorker,
    TranscribeRecordingWorker
  }

  defp create_user(attrs \\ %{}) do
    unique_suffix = System.unique_integer([:positive])

    defaults = %{
      username: "voice_worker_#{unique_suffix}",
      email: "voice_worker_#{unique_suffix}@example.com",
      password: "SecurePass!987654#Alpha",
      password_confirmation: "SecurePass!987654#Alpha"
    }

    {:ok, user} =
      defaults
      |> Map.merge(Enum.into(attrs, %{}))
      |> Accounts.register_user()

    user
  end

  defp create_room(user) do
    unique_suffix = System.unique_integer([:positive])

    {:ok, room} =
      Voice.create_room(%{
        name: "Analytics Room #{unique_suffix}",
        type: "lounge",
        created_by_id: user.id
      })

    room
  end

  describe "AnalyticsDailyWorker" do
    test "aggregates daily statistics and inserts CommunityStats record" do
      user = create_user()

      # Create some forum activity
      {:ok, cat} = Forums.create_category(%{name: "Analytics Cat"})
      {:ok, forum} = Forums.create_forum(%{name: "Analytics Forum", category_id: cat.id})

      {:ok, _thread} =
        Forums.create_thread(%{
          title: "Daily Thread",
          body: "Daily Body",
          user_id: user.id,
          forum_id: forum.id
        })

      # Run worker
      assert :ok = perform_job(AnalyticsDailyWorker, %{})

      yesterday = Date.utc_today() |> Date.add(-1)
      stats = Repo.get_by(CommunityStats, date: yesterday)
      assert stats != nil
      assert is_integer(stats.new_members)
      assert is_integer(stats.active_members)
    end
  end

  describe "RoomAutoThreadWorker" do
    setup do
      user = create_user()
      room = create_room(user)

      {:ok, call_log} =
        Voice.log_call(%{
          room_id: room.id,
          room_type: room.type,
          started_at:
            DateTime.utc_now() |> DateTime.add(-1800, :second) |> DateTime.truncate(:second),
          ended_at: DateTime.utc_now() |> DateTime.truncate(:second),
          peak_participants: 5,
          peak_speakers: 2,
          peak_audience: 3,
          total_hand_raises: 1,
          total_promotions: 1,
          host_user_id: user.id,
          participant_ids: [user.id]
        })

      %{user: user, room: room, call_log: call_log}
    end

    test "skips when voice_auto_thread_enabled is disabled", %{room: room, call_log: call_log} do
      Settings.set("voice_auto_thread_enabled", "false")

      assert :ok =
               perform_job(RoomAutoThreadWorker, %{
                 "call_log_id" => call_log.id,
                 "room_id" => room.id
               })
    end

    test "skips gracefully when forum_id is not configured", %{room: room, call_log: call_log} do
      Settings.set("voice_auto_thread_enabled", "true")
      Settings.set("voice_auto_thread_forum_id", "")

      assert :ok =
               perform_job(RoomAutoThreadWorker, %{
                 "call_log_id" => call_log.id,
                 "room_id" => room.id
               })
    end

    test "creates a summary thread when enabled and forum is configured", %{
      room: room,
      call_log: call_log
    } do
      {:ok, cat} = Forums.create_category(%{name: "Auto Cat"})
      {:ok, forum} = Forums.create_forum(%{name: "Auto Forum", category_id: cat.id})

      Settings.set("voice_auto_thread_enabled", "true")
      Settings.set("voice_auto_thread_forum_id", forum.id)

      assert :ok =
               perform_job(RoomAutoThreadWorker, %{
                 "call_log_id" => call_log.id,
                 "room_id" => room.id
               })

      # Reset setting after test
      Settings.set("voice_auto_thread_enabled", "false")

      # Verify thread was created
      threads = Forums.list_threads(forum.id)
      assert length(threads) == 1
      thread = hd(threads)
      assert String.contains?(thread.title, room.name)
    end

    test "handles missing args and nonexistent records", %{room: room} do
      assert {:error, :missing_args} = perform_job(RoomAutoThreadWorker, %{})

      assert :ok =
               perform_job(RoomAutoThreadWorker, %{
                 "call_log_id" => Ecto.UUID.generate(),
                 "room_id" => room.id
               })
    end
  end

  describe "AutoHighlightWorker" do
    test "processes highlights for recording and handles missing transcript gracefully" do
      user = create_user()
      room = create_room(user)

      {:ok, recording} =
        Voice.create_recording(%{
          room_id: room.id,
          created_by_id: user.id,
          audio_url: "https://example.com/recording.mp3",
          duration_seconds: 120,
          transcript_status: "ready",
          is_public: true,
          started_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      assert :ok = perform_job(AutoHighlightWorker, %{"recording_id" => recording.id})
    end

    test "generates clips when recording has high-energy keywords in transcript" do
      user = create_user()
      room = create_room(user)

      {:ok, recording} =
        Voice.create_recording(%{
          room_id: room.id,
          created_by_id: user.id,
          audio_url: "https://example.com/highlight_recording.mp3",
          duration_seconds: 120,
          transcript_status: "ready",
          transcript:
            "OMG this was an amazing insane play! Wow that was an unbelievable crazy clutch win lets go!",
          is_public: true,
          started_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      assert :ok = perform_job(AutoHighlightWorker, %{"recording_id" => recording.id})
    end

    test "handles non-existent recording gracefully" do
      assert :ok = perform_job(AutoHighlightWorker, %{"recording_id" => Ecto.UUID.generate()})
    end

    test "handles missing args with {:error, :missing_args}" do
      assert {:error, :missing_args} = perform_job(AutoHighlightWorker, %{})
    end
  end

  describe "TranscribeRecordingWorker" do
    test "handles non-existent recording gracefully" do
      assert :ok =
               perform_job(TranscribeRecordingWorker, %{"recording_id" => Ecto.UUID.generate()})
    end

    test "marks disabled when voice transcription is disabled" do
      user = create_user()
      room = create_room(user)

      {:ok, recording} =
        Voice.create_recording(%{
          room_id: room.id,
          created_by_id: user.id,
          audio_url: "https://example.com/rec.mp3",
          duration_seconds: 60,
          is_public: true,
          started_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      # By default voice_transcription_enabled is false
      assert :ok = perform_job(TranscribeRecordingWorker, %{"recording_id" => recording.id})

      updated = Repo.get!(Recording, recording.id)
      assert updated.transcript_status == "disabled"
    end

    test "marks failed when enabled but audio file does not exist" do
      user = create_user()
      room = create_room(user)

      {:ok, recording} =
        Voice.create_recording(%{
          room_id: room.id,
          created_by_id: user.id,
          audio_url: "/uploads/nonexistent_voice_clip.mp3",
          duration_seconds: 60,
          is_public: true,
          started_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      Settings.set("voice_transcription_enabled", "true")
      Settings.set("voice_transcription_provider", "local")

      assert {:error, :file_not_found} =
               perform_job(TranscribeRecordingWorker, %{"recording_id" => recording.id})

      updated = Repo.get!(Recording, recording.id)
      assert updated.transcript_status == "failed"

      Settings.set("voice_transcription_enabled", "false")
    end
  end
end
