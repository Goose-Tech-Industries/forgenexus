defmodule ForgeNexus.Workers.RoomAutoThreadWorker do
  @moduledoc """
  Creates or updates a forum thread when a voice room session ends.
  Generates a summary post with recording link, transcript excerpt,
  participant list, and session stats. Triggered by RoomServer on shutdown.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger
  alias ForgeNexus.{Repo, Voice, Forums, Settings}
  alias ForgeNexus.Voice.CallLog

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"call_log_id" => call_log_id, "room_id" => room_id}}) do
    if not Settings.get_bool("voice_auto_thread_enabled") do
      :ok
    else
      case {Repo.get(CallLog, call_log_id), Voice.get_room!(room_id)} do
        {nil, _} -> :ok
        {call_log, room} -> create_or_update_thread(room, call_log)
      end
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.warning("[RoomAutoThread] missing required args, got: #{inspect(args)}")
    {:error, :missing_args}
  end

  defp create_or_update_thread(room, call_log) do
    forum_id = Settings.get("voice_auto_thread_forum_id")

    if is_nil(forum_id) or forum_id == "" do
      Logger.info("[RoomAutoThread] No forum_id configured, skipping")
      :ok
    else
      body = build_session_summary(room, call_log)
      host_id = call_log.host_user_id

      system_user_id = host_id || List.first(call_log.participant_ids || [])

      if system_user_id do
        Forums.create_thread(%{
          "title" => "#{room.name} — Session #{format_date(call_log.started_at)}",
          "body" => body,
          "user_id" => system_user_id,
          "forum_id" => forum_id
        })
      end

      :ok
    end
  end

  defp build_session_summary(room, call_log) do
    duration = if call_log.started_at && call_log.ended_at do
      secs = DateTime.diff(call_log.ended_at, call_log.started_at, :second)
      minutes = div(secs, 60)
      "#{minutes} minutes"
    else
      "Unknown"
    end

    participants = call_log.participant_ids || []
    participant_count = length(participants)

    recordings = Voice.list_recordings(room.id, limit: 5)

    recording_section = if recordings != [] do
      links = Enum.map(recordings, fn r ->
        title = r.title || "Recording"
        "- [#{title}](/voice/recordings/#{r.id})" <>
          if(r.transcript_status == "ready", do: " (transcript available)", else: "")
      end)
      "\n\n**Recordings:**\n#{Enum.join(links, "\n")}"
    else
      ""
    end

    stats = [
      {"Peak participants", call_log.peak_participants},
      {"Peak speakers", call_log.peak_speakers},
      {"Peak audience", call_log.peak_audience},
      {"Hand raises", call_log.total_hand_raises},
      {"Promotions", call_log.total_promotions}
    ]
    |> Enum.filter(fn {_, v} -> v && v > 0 end)
    |> Enum.map(fn {k, v} -> "- #{k}: #{v}" end)
    |> Enum.join("\n")

    """
    **#{room.name}** — Voice Room Session

    **Duration:** #{duration}
    **Participants:** #{participant_count}
    **Room type:** #{room.type}

    #{if stats != "", do: "**Stats:**\n#{stats}", else: ""}#{recording_section}

    ---
    *This thread was automatically created when the voice session ended. Join the discussion below!*
    """
    |> String.trim()
  end

  defp format_date(nil), do: "Unknown"

  defp format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%B %d, %Y at %H:%M UTC")
  end
end
