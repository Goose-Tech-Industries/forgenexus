defmodule ForgeNexusWeb.VoiceRoomController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.{Voice, Settings}
  alias ForgeNexus.Voice.{LiveKit, Recording, TurnCredentials}
  require Logger

  @recording_dir "priv/static/uploads/voice_recordings"
  @allowed_mime_types ~w(audio/webm audio/ogg audio/mp4 audio/mpeg audio/wav)

  def index(conn, _params) do
    rooms = Voice.list_rooms()

    conn
    |> json(%{
      rooms:
        Enum.map(rooms, fn room ->
          live = Map.get(room, :live_participants, [])
          room_json(room, live)
        end)
    })
  end

  def upcoming(conn, _params) do
    rooms = Voice.list_upcoming_rooms()

    conn
    |> json(%{
      rooms:
        Enum.map(rooms, fn room ->
          room_json(room, [])
          |> Map.put(:scheduled_at, room.scheduled_at)
          |> Map.put(:description, room.description)
        end)
    })
  end

  def show(conn, %{"slug" => slug}) do
    case Voice.get_room_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Room not found"})

      room ->
        participants = Voice.get_room_participants(room.id)
        conn |> json(%{room: room_json(room, participants)})
    end
  end

  # Admin endpoints
  def create(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    attrs = Map.put(params, "created_by_id", user.id)

    case Voice.create_room(attrs) do
      {:ok, room} ->
        conn |> put_status(:created) |> json(%{room: room_json(room, [])})

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
        conn |> put_status(:unprocessable_entity) |> json(%{error: errors})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Voice.update_room(id, params) do
      {:ok, room} ->
        conn |> json(%{room: room_json(room, [])})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to update"})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Voice.delete_room(id) do
      {:ok, _} ->
        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete"})
    end
  end

  # --- Recording endpoints ---

  def list_recordings(conn, %{"slug" => slug}) do
    case Voice.get_room_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Room not found"})

      room ->
        recordings = Voice.list_recordings(room.id)
        conn |> json(%{recordings: Enum.map(recordings, &recording_json/1)})
    end
  end

  def show_recording(conn, %{"recording_id" => id}) do
    case Voice.get_recording(id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Recording not found"})
      recording -> conn |> json(%{recording: recording_json(recording, full_transcript: true)})
    end
  end

  def upload_recording(conn, %{"id" => room_id} = params) do
    cond do
      not Settings.get_bool("voice_recording_enabled") ->
        conn |> put_status(:forbidden) |> json(%{error: "Voice recording is disabled"})

      Ecto.UUID.cast(room_id) == :error ->
        conn |> put_status(:not_found) |> json(%{error: "Room not found"})

      true ->
        do_upload_recording(conn, room_id, params)
    end
  end

  defp do_upload_recording(conn, room_id, params) do
    user = Guardian.Plug.current_resource(conn)
    audio = Map.get(params, "audio")

    with {:ok, %Plug.Upload{} = upload} <- extract_upload(audio),
         :ok <- validate_mime(upload.content_type),
         :ok <- validate_size(upload.path),
         {:ok, {url, size}} <- persist_file(upload),
         {:ok, started_at} <- parse_datetime(Map.get(params, "started_at")),
         ended_at <- parse_datetime_or_now(Map.get(params, "ended_at")),
         transcript_status <- initial_transcript_status(size),
         attrs <- %{
           room_id: room_id,
           host_user_id: user && user.id,
           title: Map.get(params, "title"),
           description: Map.get(params, "description"),
           audio_url: url,
           mime_type: upload.content_type,
           size_bytes: size,
           duration_seconds: parse_int(Map.get(params, "duration_seconds")),
           participant_count: parse_int(Map.get(params, "participant_count")),
           started_at: started_at,
           ended_at: ended_at,
           is_public: parse_bool(Map.get(params, "is_public"), true),
           transcript_status: transcript_status
         },
         {:ok, recording} <- Voice.create_recording(attrs) do
      maybe_enqueue_transcription(recording)
      conn |> put_status(:created) |> json(%{recording: recording_json(recording)})
    else
      {:error, :no_upload} ->
        conn |> put_status(:bad_request) |> json(%{error: "Missing audio file"})

      {:error, :invalid_mime} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Unsupported audio type"})

      {:error, :too_large} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Recording exceeds max size"})

      {:error, :invalid_datetime} ->
        conn |> put_status(:bad_request) |> json(%{error: "Invalid started_at timestamp"})

      {:error, %Ecto.Changeset{} = cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: format_errors(cs)})

      {:error, reason} ->
        Logger.warning("[upload_recording] failed: #{inspect(reason)}")
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to save recording"})
    end
  end

  def delete_recording(conn, %{"recording_id" => id}) do
    case Voice.delete_recording(id) do
      {:ok, _} ->
        conn |> json(%{ok: true})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Recording not found"})

      _ ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete"})
    end
  end

  # --- Redeemables (Channel Point Rewards) ---

  def list_redeemables(conn, %{"id" => room_id}) do
    items = Voice.list_all_redeemables(room_id)

    conn
    |> json(%{
      redeemables:
        Enum.map(items, fn r ->
          %{
            id: r.id,
            name: r.name,
            description: r.description,
            emoji: r.emoji,
            cost: r.cost,
            type: r.type,
            config: r.config,
            cooldown_seconds: r.cooldown_seconds,
            max_per_stream: r.max_per_stream,
            max_per_user_per_stream: r.max_per_user_per_stream,
            is_enabled: r.is_enabled,
            requires_text: r.requires_text,
            position: r.position,
            inserted_at: r.inserted_at
          }
        end)
    })
  end

  def create_redeemable(conn, %{"id" => room_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    attrs =
      params
      |> Map.put("room_id", room_id)
      |> Map.put("created_by_id", user && user.id)

    case Voice.create_redeemable(attrs) do
      {:ok, r} ->
        conn
        |> put_status(:created)
        |> json(%{redeemable: %{id: r.id, name: r.name, type: r.type, cost: r.cost}})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: format_errors(changeset)})
    end
  end

  def update_redeemable(conn, %{"redeemable_id" => id} = params) do
    case Voice.update_redeemable(id, params) do
      {:ok, r} ->
        conn
        |> json(%{redeemable: %{id: r.id, name: r.name, cost: r.cost, is_enabled: r.is_enabled}})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: format_errors(changeset)})
    end
  end

  def delete_redeemable(conn, %{"redeemable_id" => id}) do
    case Voice.delete_redeemable(id) do
      {:ok, _} ->
        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete"})
    end
  end

  def list_redemptions(conn, %{"id" => room_id}) do
    redemptions = Voice.list_redemptions(room_id)

    conn
    |> json(%{
      redemptions:
        Enum.map(redemptions, fn r ->
          %{
            id: r.id,
            user_id: r.user_id,
            username: get_in_assoc(r, :user, :username),
            redeemable_name: get_in_assoc(r, :redeemable, :name),
            redeemable_type: get_in_assoc(r, :redeemable, :type),
            cost: r.cost,
            user_text: r.user_text,
            status: r.status,
            inserted_at: r.inserted_at
          }
        end)
    })
  end

  # --- Translation ---

  def translate(conn, %{"room_id" => room_id, "text" => text, "target_language" => lang}) do
    user = Guardian.Plug.current_resource(conn)

    case ForgeNexus.AI.LiveTranslator.translate(room_id, user.id, text, lang) do
      {:ok, translated} ->
        conn |> json(%{translated: translated, language: lang})

      {:error, :disabled} ->
        conn |> put_status(:service_unavailable) |> json(%{error: "Translation disabled"})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  # --- Soundboard ---

  def list_soundboard(conn, %{"id" => room_id}) do
    clips = Voice.list_soundboard_clips(room_id)

    conn
    |> json(%{
      clips:
        Enum.map(clips, fn c ->
          %{
            id: c.id,
            name: c.name,
            emoji: c.emoji,
            audio_url: c.audio_url,
            duration_ms: c.duration_ms,
            size_bytes: c.size_bytes,
            play_count: c.play_count,
            is_global: c.is_global,
            room_id: c.room_id,
            inserted_at: c.inserted_at
          }
        end)
    })
  end

  def upload_soundboard_clip(conn, %{"id" => room_id} = params) do
    if Ecto.UUID.cast(room_id) == :error do
      conn |> put_status(:not_found) |> json(%{error: "Room not found"})
    else
      do_upload_soundboard_clip(conn, room_id, params)
    end
  end

  defp do_upload_soundboard_clip(conn, room_id, params) do
    user = Guardian.Plug.current_resource(conn)
    audio = Map.get(params, "audio")

    with {:ok, %Plug.Upload{} = upload} <- extract_upload(audio),
         :ok <- validate_mime(upload.content_type),
         {:ok, {url, size}} <- persist_soundboard_file(upload) do
      attrs = %{
        room_id: room_id,
        uploaded_by_id: user && user.id,
        name:
          Map.get(
            params,
            "name",
            Path.basename(upload.filename || "clip", Path.extname(upload.filename || ""))
          ),
        emoji: Map.get(params, "emoji"),
        audio_url: url,
        size_bytes: size,
        duration_ms: parse_int(Map.get(params, "duration_ms")),
        is_global: parse_bool(Map.get(params, "is_global"), false)
      }

      case Voice.create_soundboard_clip(attrs) do
        {:ok, clip} ->
          conn
          |> put_status(:created)
          |> json(%{clip: %{id: clip.id, name: clip.name, audio_url: clip.audio_url}})

        {:error, changeset} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: format_errors(changeset)})
      end
    else
      {:error, reason} ->
        conn |> put_status(:bad_request) |> json(%{error: to_string(reason)})
    end
  end

  def delete_soundboard_clip(conn, %{"clip_id" => clip_id}) do
    clip = Voice.get_soundboard_clip!(clip_id)

    case Voice.delete_soundboard_clip(clip) do
      {:ok, _} ->
        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete"})
    end
  end

  @soundboard_dir "priv/static/uploads/soundboard"

  defp persist_soundboard_file(%Plug.Upload{path: src, content_type: mime, filename: original}) do
    ext = extension_for(mime, original)
    File.mkdir_p!(@soundboard_dir)
    unique = "#{UUID.uuid4()}#{ext}"
    dest = Path.join(@soundboard_dir, unique)
    File.cp!(src, dest)
    %{size: size} = File.stat!(dest)
    {:ok, {"/uploads/soundboard/#{unique}", size}}
  end

  # --- Clips ---

  def create_clip(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    attrs = %{
      recording_id: params["recording_id"],
      created_by_id: user && user.id,
      title: params["title"],
      start_ms: parse_int(params["start_ms"]),
      end_ms: parse_int(params["end_ms"])
    }

    case Voice.create_clip(attrs) do
      {:ok, clip} ->
        conn |> put_status(:created) |> json(%{clip: clip_json(clip)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: format_errors(changeset)})
    end
  end

  def list_clips(conn, %{"recording_id" => recording_id}) do
    clips = Voice.list_clips(recording_id)
    conn |> json(%{clips: Enum.map(clips, &clip_json/1)})
  end

  def show_clip(conn, %{"clip_id" => id}) do
    case Voice.get_clip(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Clip not found"})

      clip ->
        Voice.increment_clip_views(clip.id)
        conn |> json(%{clip: clip_json(clip)})
    end
  end

  def recent_clips(conn, _params) do
    clips = Voice.list_recent_clips()
    conn |> json(%{clips: Enum.map(clips, &clip_json/1)})
  end

  @doc """
  Returns a fresh ICE configuration (STUN + time-limited TURN credentials) for
  the authenticated user. Frontend mesh-WebRTC fallback uses this when LiveKit
  is not configured. Credentials expire per `turn_credential_ttl_seconds`.
  """
  def ice_config(conn, _params) do
    user = conn.assigns[:current_user]

    user_id =
      if user,
        do: to_string(user.id),
        else: "anon-" <> Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)

    %{ice_servers: ice_servers, ttl: ttl} = TurnCredentials.ice_config(user_id)

    conn
    |> json(%{
      ice_servers: ice_servers,
      ttl: ttl,
      livekit_configured: LiveKit.configured?()
    })
  end

  defp clip_json(clip) do
    %{
      id: clip.id,
      recording_id: clip.recording_id,
      created_by_id: clip.created_by_id,
      created_by_username: get_in_assoc(clip, :created_by, :username),
      title: clip.title,
      start_ms: clip.start_ms,
      end_ms: clip.end_ms,
      duration_ms: clip.end_ms - clip.start_ms,
      view_count: clip.view_count,
      is_public: clip.is_public,
      audio_url: get_in_assoc(clip, :recording, :audio_url),
      inserted_at: clip.inserted_at
    }
  end

  defp get_in_assoc(struct, assoc, field) do
    case Map.get(struct, assoc) do
      %{} = loaded -> Map.get(loaded, field)
      _ -> nil
    end
  end

  # --- LiveKit access token ---

  def livekit_token(conn, %{"id" => room_id}) do
    user = Guardian.Plug.current_resource(conn)

    cond do
      is_nil(user) ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})

      not LiveKit.configured?() ->
        conn |> put_status(:service_unavailable) |> json(%{error: "LiveKit not configured"})

      true ->
        room = Voice.get_room!(room_id)
        participants = Voice.get_room_participants(room.id)
        role = participant_role(room, participants, user.id)

        case LiveKit.access_token(room.id, user.id, role, name: user.username) do
          {:ok, token} ->
            conn
            |> json(%{
              token: token,
              url: LiveKit.url(),
              room: LiveKit.room_name(room.id),
              identity: user.id,
              role: to_string(role)
            })

          {:error, :not_configured} ->
            conn |> put_status(:service_unavailable) |> json(%{error: "LiveKit not configured"})
        end
    end
  end

  # Determine LiveKit publish privilege from the RoomServer's live role.
  # Stage (town_hall) rooms: only speakers/host can publish; audience listens.
  defp participant_role(room, participants, user_id) do
    live = Enum.find(participants, fn p -> p.user_id == user_id end)

    cond do
      room.type != "town_hall" -> :speaker
      is_nil(live) and room.created_by_id == user_id -> :speaker
      is_nil(live) -> :audience
      Map.get(live, :role, "speaker") in ["speaker", :speaker] -> :speaker
      true -> :audience
    end
  end

  # --- Private helpers ---

  defp extract_upload(%Plug.Upload{} = upload), do: {:ok, upload}
  defp extract_upload(_), do: {:error, :no_upload}

  defp validate_mime(mime) when mime in @allowed_mime_types, do: :ok
  defp validate_mime(_), do: {:error, :invalid_mime}

  defp validate_size(path) do
    max_mb =
      case Settings.get_int("voice_recording_max_size_mb") do
        n when n > 0 -> n
        _ -> 200
      end

    max_bytes = max_mb * 1024 * 1024

    case File.stat(path) do
      {:ok, %{size: size}} when size <= max_bytes -> :ok
      {:ok, _} -> {:error, :too_large}
      {:error, _} -> {:error, :file_error}
    end
  end

  defp persist_file(%Plug.Upload{path: src, content_type: mime, filename: original}) do
    ext = extension_for(mime, original)
    date_path = Date.utc_today() |> Date.to_iso8601() |> String.replace("-", "/")
    dir = Path.join(@recording_dir, date_path)
    File.mkdir_p!(dir)
    unique = "#{UUID.uuid4()}#{ext}"
    dest = Path.join(dir, unique)
    File.cp!(src, dest)
    %{size: size} = File.stat!(dest)
    {:ok, {"/uploads/voice_recordings/#{date_path}/#{unique}", size}}
  end

  defp extension_for(mime, filename) do
    case Path.extname(filename || "") do
      "" <> ext when byte_size(ext) > 0 ->
        ext

      _ ->
        case mime do
          "audio/webm" -> ".webm"
          "audio/ogg" -> ".ogg"
          "audio/mp4" -> ".m4a"
          "audio/mpeg" -> ".mp3"
          "audio/wav" -> ".wav"
          _ -> ".bin"
        end
    end
  end

  defp parse_datetime(nil), do: {:ok, DateTime.utc_now() |> DateTime.truncate(:second)}
  defp parse_datetime(""), do: {:ok, DateTime.utc_now() |> DateTime.truncate(:second)}

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> {:ok, DateTime.truncate(dt, :second)}
      _ -> {:error, :invalid_datetime}
    end
  end

  defp parse_datetime_or_now(nil), do: DateTime.utc_now() |> DateTime.truncate(:second)
  defp parse_datetime_or_now(""), do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp parse_datetime_or_now(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(n) when is_integer(n), do: n

  defp parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {n, _} -> n
      _ -> nil
    end
  end

  defp parse_int(_), do: nil

  defp parse_bool(nil, default), do: default
  defp parse_bool(true, _), do: true
  defp parse_bool(false, _), do: false
  defp parse_bool("true", _), do: true
  defp parse_bool("false", _), do: false
  defp parse_bool(_, default), do: default

  defp initial_transcript_status(file_size_bytes) do
    cond do
      not Settings.get_bool("voice_transcription_enabled") ->
        "disabled"

      file_size_bytes > transcription_max_bytes() ->
        "failed"

      true ->
        "pending"
    end
  end

  defp transcription_max_bytes do
    mb =
      case Settings.get_int("voice_transcription_max_size_mb") do
        n when n > 0 -> n
        _ -> 25
      end

    mb * 1024 * 1024
  end

  defp maybe_enqueue_transcription(%Recording{transcript_status: "pending"} = recording) do
    %{recording_id: recording.id}
    |> ForgeNexus.Workers.TranscribeRecordingWorker.new()
    |> Oban.insert()
  end

  defp maybe_enqueue_transcription(_), do: :ok

  defp format_errors(changeset),
    do: Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)

  defp recording_json(recording, opts \\ []) do
    full_transcript? = Keyword.get(opts, :full_transcript, false)

    transcript =
      cond do
        full_transcript? -> recording.transcript
        is_binary(recording.transcript) -> String.slice(recording.transcript, 0, 500)
        true -> nil
      end

    %{
      id: recording.id,
      room_id: recording.room_id,
      host_user_id: recording.host_user_id,
      title: recording.title,
      description: recording.description,
      audio_url: recording.audio_url,
      mime_type: recording.mime_type,
      size_bytes: recording.size_bytes,
      duration_seconds: recording.duration_seconds,
      started_at: recording.started_at,
      ended_at: recording.ended_at,
      transcript: transcript,
      transcript_status: recording.transcript_status,
      transcript_language: recording.transcript_language,
      participant_count: recording.participant_count,
      is_public: recording.is_public,
      inserted_at: recording.inserted_at
    }
  end

  defp room_json(room, participants) do
    category_name =
      if Ecto.assoc_loaded?(room.category) and room.category, do: room.category.name, else: nil

    %{
      id: room.id,
      name: room.name,
      slug: room.slug,
      type: room.type,
      max_participants: room.max_participants,
      is_locked: room.is_locked,
      is_private: room.is_private,
      position: room.position,
      category_id: room.category_id,
      category_name: category_name,
      community_id: room.community_id,
      participant_count: length(participants),
      participants: participants
    }
  end
end
