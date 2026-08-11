defmodule ForgeNexusWeb.VoiceChannel do
  @moduledoc """
  WebSocket channel for voice/video rooms.
  Handles:
  - Room join/leave lifecycle
  - WebRTC signaling (offer, answer, ICE candidates)
  - Media state updates (mute, deafen, video, screen share)
  """
  use ForgeNexusWeb, :channel

  alias ForgeNexus.Voice
  alias ForgeNexus.Voice.LiveKit

  @impl true
  def join("voice:" <> room_id, _params, socket) do
    user = socket.assigns.current_user

    case Ecto.UUID.cast(room_id) do
      :error ->
        {:error, %{reason: "invalid room id"}}

      {:ok, _uuid} ->
        case Voice.join_room(room_id, user) do
          {:ok, info} when is_map(info) ->
            send(self(), :after_join)
            socket = assign(socket, :room_id, room_id)
            {:ok, Map.put(info, :livekit, livekit_info(room_id)), socket}

          {:ok, participants} when is_list(participants) ->
            # Legacy shape (pre stage-mode). Kept for backward compatibility.
            send(self(), :after_join)
            socket = assign(socket, :room_id, room_id)
            {:ok, %{participants: participants, livekit: livekit_info(room_id)}, socket}

          {:error, :not_found} ->
            {:error, %{reason: "room not found"}}

          {:error, :room_full} ->
            {:error, %{reason: "room is full"}}

          {:error, reason} ->
            {:error, %{reason: inspect(reason)}}
        end
    end
  end

  # Tells the client whether to use LiveKit for media or fall back to mesh WebRTC.
  # When enabled, the client fetches a token via POST /api/voice/rooms/:id/token
  # and connects to `url` directly — the Phoenix channel still handles role
  # commands, watch parties, speaking indicator, and presence events.
  defp livekit_info(room_id) do
    if LiveKit.configured?() do
      %{enabled: true, url: LiveKit.url(), room: LiveKit.room_name(room_id)}
    else
      %{enabled: false}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    # Track presence in the voice room
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    user = socket.assigns.current_user
    room_id = socket.assigns[:room_id]

    if room_id do
      Voice.leave_room(room_id, user.id)
    end

    :ok
  end

  # --- WebRTC Signaling ---

  # Peer A sends an offer to Peer B
  @impl true
  def handle_in("signal:offer", %{"to" => target_user_id, "offer" => offer}, socket) do
    user = socket.assigns.current_user

    broadcast_from!(socket, "signal:offer", %{
      from: user.id,
      to: target_user_id,
      offer: offer
    })

    {:noreply, socket}
  end

  # Peer B responds with an answer to Peer A
  @impl true
  def handle_in("signal:answer", %{"to" => target_user_id, "answer" => answer}, socket) do
    user = socket.assigns.current_user

    broadcast_from!(socket, "signal:answer", %{
      from: user.id,
      to: target_user_id,
      answer: answer
    })

    {:noreply, socket}
  end

  # ICE candidate exchange
  @impl true
  def handle_in(
        "signal:ice_candidate",
        %{"to" => target_user_id, "candidate" => candidate},
        socket
      ) do
    user = socket.assigns.current_user

    broadcast_from!(socket, "signal:ice_candidate", %{
      from: user.id,
      to: target_user_id,
      candidate: candidate
    })

    {:noreply, socket}
  end

  # --- Media State ---

  @impl true
  def handle_in("media:update", params, socket) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room_id

    media_state =
      %{
        muted: params["muted"],
        deafened: params["deafened"],
        video: params["video"],
        screen_share: params["screen_share"]
      }
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()

    case Voice.update_media_state(room_id, user.id, media_state) do
      :ok -> {:reply, {:ok, %{}}, socket}
      {:error, reason} -> {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  # Speaking indicator (VAD — voice activity detection from client)
  @impl true
  def handle_in("speaking", %{"speaking" => speaking}, socket) do
    user = socket.assigns.current_user

    broadcast_from!(socket, "speaking", %{
      user_id: user.id,
      speaking: speaking
    })

    {:noreply, socket}
  end

  # --- Stage Mode (town_hall rooms) ---

  def handle_in("stage:raise_hand", %{"raised" => raised}, socket)
      when is_boolean(raised) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room_id

    case Voice.set_hand_raised(room_id, user.id, raised) do
      :ok -> {:reply, {:ok, %{hand_raised: raised}}, socket}
      {:error, reason} -> {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  def handle_in("stage:promote", %{"user_id" => target_id}, socket) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room_id

    case Voice.promote_to_speaker(room_id, target_id, user.id) do
      :ok -> {:reply, {:ok, %{}}, socket}
      {:error, reason} -> {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  def handle_in("stage:demote", %{"user_id" => target_id}, socket) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room_id

    case Voice.demote_to_audience(room_id, target_id, user.id) do
      :ok -> {:reply, {:ok, %{}}, socket}
      {:error, reason} -> {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  # --- Channel point redemptions ---

  def handle_in("redeem", %{"redeemable_id" => rid} = params, socket) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room_id
    user_text = Map.get(params, "text")

    case Voice.redeem(rid, room_id, user.id, user_text) do
      {:ok, result} ->
        broadcast!(socket, "redeemed", %{
          user_id: user.id,
          username: user.username,
          redeemable: result.redeemable,
          user_text: result.user_text,
          effect: result.effect
        })

        {:reply, {:ok, %{result: result}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  def handle_in("redeemables:list", _params, socket) do
    room_id = socket.assigns.room_id
    items = Voice.list_redeemables(room_id)

    {:reply,
     {:ok,
      %{
        redeemables:
          Enum.map(items, fn r ->
            %{
              id: r.id,
              name: r.name,
              description: r.description,
              emoji: r.emoji,
              cost: r.cost,
              type: r.type,
              requires_text: r.requires_text,
              cooldown_seconds: r.cooldown_seconds
            }
          end)
      }}, socket}
  end

  # --- In-room polls ---

  def handle_in("poll:create", %{"question" => q, "options" => opts}, socket)
      when is_binary(q) and is_list(opts) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room_id

    case Voice.create_poll(room_id, q, opts, user.id) do
      {:ok, poll} -> {:reply, {:ok, %{poll: poll}}, socket}
      {:error, reason} -> {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  def handle_in("poll:vote", %{"option" => idx}, socket) when is_integer(idx) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room_id

    case Voice.vote_poll(room_id, user.id, idx) do
      :ok -> {:reply, {:ok, %{}}, socket}
      {:error, reason} -> {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  def handle_in("poll:close", _params, socket) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room_id

    case Voice.close_poll(room_id, user.id) do
      {:ok, results} -> {:reply, {:ok, %{results: results}}, socket}
      {:error, reason} -> {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  def handle_in("poll:get", _params, socket) do
    room_id = socket.assigns.room_id

    case Voice.get_poll(room_id) do
      {:error, reason} -> {:reply, {:error, %{reason: to_string(reason)}}, socket}
      nil -> {:reply, {:ok, %{poll: nil}}, socket}
      poll -> {:reply, {:ok, %{poll: poll}}, socket}
    end
  end

  # --- Soundboard ---

  def handle_in("soundboard:play", %{"clip_id" => clip_id}, socket) do
    user = socket.assigns.current_user

    try do
      clip = Voice.get_soundboard_clip!(clip_id)
      Voice.increment_play_count(clip_id)

      broadcast!(socket, "soundboard:played", %{
        clip_id: clip.id,
        name: clip.name,
        emoji: clip.emoji,
        audio_url: clip.audio_url,
        played_by: user.id,
        played_by_username: user.username
      })

      {:reply, {:ok, %{}}, socket}
    rescue
      Ecto.NoResultsError ->
        {:reply, {:error, %{reason: "clip_not_found"}}, socket}
    end
  end

  def handle_in("soundboard:list", _params, socket) do
    room_id = socket.assigns.room_id
    clips = Voice.list_soundboard_clips(room_id)

    {:reply,
     {:ok,
      %{
        clips:
          Enum.map(clips, fn c ->
            %{
              id: c.id,
              name: c.name,
              emoji: c.emoji,
              audio_url: c.audio_url,
              duration_ms: c.duration_ms,
              play_count: c.play_count
            }
          end)
      }}, socket}
  end

  # --- Live reactions (TikTok/Spaces-style emoji bursts) ---

  @max_reactions_per_second 3

  def handle_in("reaction:send", %{"emoji" => emoji}, socket) when is_binary(emoji) do
    user = socket.assigns.current_user
    now = System.monotonic_time(:millisecond)
    last_reactions = socket.assigns[:reaction_timestamps] || []
    recent = Enum.filter(last_reactions, fn ts -> now - ts < 1000 end)

    if length(recent) >= @max_reactions_per_second do
      {:reply, {:error, %{reason: "rate_limited"}}, socket}
    else
      broadcast_from!(socket, "reaction", %{
        user_id: user.id,
        username: user.username,
        emoji: String.slice(emoji, 0, 8)
      })

      {:reply, {:ok, %{}}, assign(socket, :reaction_timestamps, [now | recent])}
    end
  end

  def handle_in("stage:co_host", %{"user_id" => target_id}, socket) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room_id

    case Voice.set_co_host(room_id, target_id, user.id) do
      :ok -> {:reply, {:ok, %{}}, socket}
      {:error, reason} -> {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  def handle_in("stage:hand_queue", _params, socket) do
    room_id = socket.assigns.room_id

    case Voice.get_hand_queue(room_id) do
      {:error, reason} -> {:reply, {:error, %{reason: to_string(reason)}}, socket}
      queue -> {:reply, {:ok, %{queue: queue}}, socket}
    end
  end

  # --- Watch party ---

  def handle_in("watch:start", %{"url" => url}, socket) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room_id

    case Voice.start_watch_party(room_id, url, user.id) do
      {:ok, party} -> {:reply, {:ok, %{party: party}}, socket}
      {:error, reason} -> {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  def handle_in("watch:play", _params, socket) do
    apply_watch_command(socket, :play, %{})
  end

  def handle_in("watch:pause", _params, socket) do
    apply_watch_command(socket, :pause, %{})
  end

  def handle_in("watch:seek", %{"time" => time}, socket) when is_number(time) do
    apply_watch_command(socket, :seek, %{time: time})
  end

  def handle_in("watch:sync", %{"time" => time, "playing" => playing}, socket)
      when is_number(time) and is_boolean(playing) do
    apply_watch_command(socket, :sync, %{time: time, playing: playing})
  end

  def handle_in("watch:queue_add", %{"url" => url}, socket) when is_binary(url) do
    apply_watch_command(socket, :queue_add, %{url: url})
  end

  def handle_in("watch:queue_remove", %{"index" => idx}, socket) when is_integer(idx) do
    apply_watch_command(socket, :queue_remove, %{index: idx})
  end

  def handle_in("watch:queue_clear", _params, socket) do
    apply_watch_command(socket, :queue_clear, %{})
  end

  def handle_in("watch:skip", _params, socket) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room_id

    case Voice.stop_watch_party(room_id, user.id) do
      {:ok, party} -> {:reply, {:ok, %{party: party}}, socket}
      :ok -> {:reply, {:ok, %{ended: true}}, socket}
      {:error, reason} -> {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  def handle_in("watch:stop", _params, socket) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room_id

    case Voice.stop_watch_party(room_id, user.id) do
      :ok -> {:reply, {:ok, %{}}, socket}
      {:error, reason} -> {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  defp apply_watch_command(socket, command, args) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room_id

    case Voice.control_watch_party(room_id, user.id, command, args) do
      {:ok, party} -> {:reply, {:ok, %{party: party}}, socket}
      {:error, reason} -> {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  # Catch-all: any event whose payload doesn't match a strict head above used
  # to crash the channel with FunctionClauseError, dropping the user from the
  # call. Reply with a graceful error and keep the channel alive.
  @impl true
  def handle_in(event, payload, socket) do
    require Logger

    Logger.warning(
      "[VoiceChannel] unhandled or malformed event #{inspect(event)} payload=#{inspect(payload)}"
    )

    {:reply, {:error, %{reason: "unknown or malformed event", event: event}}, socket}
  end
end
