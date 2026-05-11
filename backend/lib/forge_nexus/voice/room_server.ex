defmodule ForgeNexus.Voice.RoomServer do
  @moduledoc """
  GenServer managing live state for a single voice room.
  Tracks participants, their media states, and handles WebRTC signaling coordination.
  Started on-demand when first user joins, stops when room empties.

  Stage mode: in `town_hall` rooms, participants have a :role of :speaker or
  :audience. Audience members are force-muted and cannot unmute themselves.
  Speakers (and the host) can promote audience members to speakers. The room
  creator becomes the initial host; if they leave, the earliest-joined speaker
  takes over.
  """
  use GenServer

  alias ForgeNexus.Voice

  defstruct [
    :room_id,
    :room_type,
    :max_participants,
    :host_id,
    participants: %{},   # user_id => participant map (see join/1)
    started_at: nil,
    active_poll: nil,    # %{question, options, votes, created_by, created_at}
    peak_count: 0,
    peak_audience: 0,
    peak_speakers: 0,
    total_hand_raises: 0,
    total_promotions: 0,
    total_demotions: 0,
    seen_user_ids: MapSet.new(),
    watch_party: nil     # see ForgeNexus.Voice.WatchParty for shape
  ]

  # --- Client API ---

  def start_link(opts) do
    room_id = Keyword.fetch!(opts, :room_id)
    GenServer.start_link(__MODULE__, opts, name: via(room_id))
  end

  def join(room_id, user) do
    ensure_started(room_id)
    GenServer.call(via(room_id), {:join, user})
  end

  def leave(room_id, user_id) do
    GenServer.cast(via(room_id), {:leave, user_id})
  end

  def update_media(room_id, user_id, media_state) do
    GenServer.call(via(room_id), {:update_media, user_id, media_state})
  end

  def promote_to_speaker(room_id, target_user_id, actor_id) do
    call_if_running(room_id, {:set_role, target_user_id, :speaker, actor_id})
  end

  def demote_to_audience(room_id, target_user_id, actor_id) do
    call_if_running(room_id, {:set_role, target_user_id, :audience, actor_id})
  end

  def set_co_host(room_id, target_user_id, actor_id) do
    call_if_running(room_id, {:set_role, target_user_id, :co_host, actor_id})
  end

  def set_hand_raised(room_id, user_id, raised) when is_boolean(raised) do
    call_if_running(room_id, {:set_hand, user_id, raised})
  end

  def start_watch_party(room_id, url, actor_id) do
    call_if_running(room_id, {:start_watch_party, url, actor_id})
  end

  def control_watch_party(room_id, actor_id, command, args \\ %{}) do
    call_if_running(room_id, {:control_watch_party, command, args, actor_id})
  end

  def stop_watch_party(room_id, actor_id) do
    call_if_running(room_id, {:stop_watch_party, actor_id})
  end

  def get_watch_party(room_id) do
    case GenServer.whereis(via(room_id)) do
      nil -> nil
      _pid -> GenServer.call(via(room_id), :get_watch_party)
    end
  end

  def get_participants(room_id) do
    case GenServer.whereis(via(room_id)) do
      nil -> []
      _pid -> GenServer.call(via(room_id), :get_participants)
    end
  end

  def get_hand_queue(room_id) do
    call_if_running(room_id, :get_hand_queue)
  end

  def create_poll(room_id, question, options, actor_id) do
    call_if_running(room_id, {:create_poll, question, options, actor_id})
  end

  def vote_poll(room_id, user_id, option_index) do
    call_if_running(room_id, {:vote_poll, user_id, option_index})
  end

  def close_poll(room_id, actor_id) do
    call_if_running(room_id, {:close_poll, actor_id})
  end

  def get_poll(room_id) do
    call_if_running(room_id, :get_poll)
  end

  def get_state(room_id) do
    case GenServer.whereis(via(room_id)) do
      nil -> nil
      _pid -> GenServer.call(via(room_id), :get_state)
    end
  end

  defp call_if_running(room_id, msg) do
    case GenServer.whereis(via(room_id)) do
      nil -> {:error, :room_not_running}
      _pid -> GenServer.call(via(room_id), msg)
    end
  end

  # --- Server callbacks ---

  @impl true
  def init(opts) do
    room_id = Keyword.fetch!(opts, :room_id)
    room_type = Keyword.get(opts, :room_type, "lounge")
    max = Keyword.get(opts, :max_participants, 15)
    created_by_id = Keyword.get(opts, :created_by_id)

    state = %__MODULE__{
      room_id: room_id,
      room_type: room_type,
      max_participants: max,
      host_id: created_by_id,
      started_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:join, user}, _from, state) do
    if map_size(state.participants) >= state.max_participants do
      {:reply, {:error, :room_full}, state}
    else
      # In town_hall (stage) rooms, everyone joins as audience unless they are
      # the host or the first joiner (who becomes host if no pre-declared host).
      is_stage = state.room_type == "town_hall"
      first_joiner = map_size(state.participants) == 0 and is_nil(state.host_id)
      is_host = user.id == state.host_id or first_joiner

      state =
        if first_joiner do
          %{user_id: user.id, room_id: state.room_id, room_name: state.room_id}
          |> ForgeNexus.Workers.LiveNotificationWorker.new()
          |> Oban.insert()

          %{state | host_id: user.id}
        else
          state
        end

      role = cond do
        not is_stage -> :speaker
        is_host -> :speaker
        true -> :audience
      end

      # Audience members start force-muted
      muted = role == :audience

      participant = %{
        username: user.username,
        avatar_url: user.avatar_url,
        role: role,
        hand_raised: false,
        muted: muted,
        deafened: false,
        video: false,
        screen_share: false,
        joined_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      new_participants = Map.put(state.participants, user.id, participant)
      new_peak = max(state.peak_count, map_size(new_participants))

      {speakers_count, audience_count} = count_roles(new_participants)
      new_peak_speakers = max(state.peak_speakers, speakers_count)
      new_peak_audience = max(state.peak_audience, audience_count)

      ForgeNexusWeb.Endpoint.broadcast("voice:#{state.room_id}", "user_joined", %{
        user_id: user.id,
        username: user.username,
        avatar_url: user.avatar_url,
        role: to_string(role),
        muted: muted,
        participant_count: map_size(new_participants)
      })

      state = %{
        state
        | participants: new_participants,
          peak_count: new_peak,
          peak_speakers: new_peak_speakers,
          peak_audience: new_peak_audience,
          seen_user_ids: MapSet.put(state.seen_user_ids, user.id)
      }

      existing = Enum.map(state.participants, &participant_json/1)

      {:reply,
       {:ok,
        %{
          participants: existing,
          host_id: state.host_id,
          your_role: to_string(role),
          is_host: is_host,
          room_type: state.room_type,
          watch_party:
            case state.watch_party do
              nil -> nil
              party -> party_payload(party)
            end
        }}, state}
    end
  end

  @impl true
  def handle_call(:get_participants, _from, state) do
    {:reply, Enum.map(state.participants, &participant_json/1), state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, %{
      room_id: state.room_id,
      room_type: state.room_type,
      host_id: state.host_id,
      participant_count: map_size(state.participants),
      max_participants: state.max_participants,
      started_at: state.started_at
    }, state}
  end

  @impl true
  def handle_call({:update_media, user_id, media_state}, _from, state) do
    case Map.get(state.participants, user_id) do
      nil ->
        {:reply, {:error, :not_in_room}, state}

      %{role: :audience} = _participant when state.room_type == "town_hall" ->
        # Audience in a stage room cannot change their own media state
        # (except to stay muted). Silently reject un-mute attempts.
        incoming = atomize_keys(media_state)
        if Map.get(incoming, :muted) == false do
          {:reply, {:error, :audience_cannot_unmute}, state}
        else
          new_state = do_update_media(state, user_id, incoming)
          {:reply, :ok, new_state}
        end

      _participant ->
        new_state = do_update_media(state, user_id, atomize_keys(media_state))
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:set_role, target_id, new_role, actor_id}, _from, state)
      when new_role in [:speaker, :audience, :co_host] do
    with :ok <- require_host_or_co_host(state, actor_id),
         {:ok, target} <- fetch_participant(state, target_id) do
      # Promotion un-mutes force-muted audience members; demotion re-mutes them in stage rooms.
      muted =
        cond do
          new_role == :audience and state.room_type == "town_hall" -> true
          new_role in [:speaker, :co_host] and target.role == :audience -> false
          true -> target.muted
        end

      updated = %{target | role: new_role, muted: muted, hand_raised: false}
      new_participants = Map.put(state.participants, target_id, updated)

      metric_delta =
        if target.role != new_role do
          case new_role do
            :speaker -> %{total_promotions: state.total_promotions + 1}
            :audience -> %{total_demotions: state.total_demotions + 1}
          end
        else
          %{}
        end

      {speakers_count, audience_count} = count_roles(new_participants)

      ForgeNexusWeb.Endpoint.broadcast("voice:#{state.room_id}", "role_changed", %{
        user_id: target_id,
        role: to_string(new_role),
        muted: muted,
        by: actor_id
      })

      state =
        state
        |> Map.merge(metric_delta)
        |> Map.put(:participants, new_participants)
        |> Map.put(:peak_speakers, max(state.peak_speakers, speakers_count))
        |> Map.put(:peak_audience, max(state.peak_audience, audience_count))

      {:reply, :ok, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:set_hand, user_id, raised}, _from, state) do
    case Map.get(state.participants, user_id) do
      nil ->
        {:reply, {:error, :not_in_room}, state}

      %{role: :speaker} ->
        # Speakers don't raise hands — they already have the floor.
        {:reply, {:error, :already_speaker}, state}

      participant ->
        updated = %{participant | hand_raised: raised}
        new_participants = Map.put(state.participants, user_id, updated)

        hand_delta =
          if raised and not participant.hand_raised, do: 1, else: 0

        new_state = %{
          state
          | participants: new_participants,
            total_hand_raises: state.total_hand_raises + hand_delta
        }

        queue = build_hand_queue(new_state)

        ForgeNexusWeb.Endpoint.broadcast("voice:#{state.room_id}", "hand_changed", %{
          user_id: user_id,
          hand_raised: raised,
          queue: queue
        })

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:get_hand_queue, _from, state) do
    {:reply, build_hand_queue(state), state}
  end

  # --- In-room polls ---

  @impl true
  def handle_call({:create_poll, question, options, actor_id}, _from, state)
      when is_binary(question) and is_list(options) do
    if state.active_poll do
      {:reply, {:error, :poll_already_active}, state}
    else
      if length(options) < 2 or length(options) > 10 do
        {:reply, {:error, :invalid_option_count}, state}
      else
        poll = %{
          question: question,
          options: options,
          votes: %{},
          created_by: actor_id,
          created_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }

        ForgeNexusWeb.Endpoint.broadcast("voice:#{state.room_id}", "poll_created", %{
          question: question,
          options: options,
          created_by: actor_id
        })

        {:reply, {:ok, poll_payload(poll)}, %{state | active_poll: poll}}
      end
    end
  end

  @impl true
  def handle_call({:vote_poll, user_id, option_index}, _from, state) do
    case state.active_poll do
      nil ->
        {:reply, {:error, :no_active_poll}, state}

      poll ->
        if option_index < 0 or option_index >= length(poll.options) do
          {:reply, {:error, :invalid_option}, state}
        else
          new_votes = Map.put(poll.votes, user_id, option_index)
          new_poll = %{poll | votes: new_votes}

          ForgeNexusWeb.Endpoint.broadcast("voice:#{state.room_id}", "poll_updated", %{
            results: tally_votes(new_poll),
            total_votes: map_size(new_votes)
          })

          {:reply, :ok, %{state | active_poll: new_poll}}
        end
    end
  end

  @impl true
  def handle_call({:close_poll, actor_id}, _from, state) do
    case state.active_poll do
      nil ->
        {:reply, {:error, :no_active_poll}, state}

      poll ->
        if actor_id == poll.created_by or actor_id == state.host_id do
          ForgeNexusWeb.Endpoint.broadcast("voice:#{state.room_id}", "poll_closed", %{
            question: poll.question,
            options: poll.options,
            results: tally_votes(poll),
            total_votes: map_size(poll.votes),
            closed_by: actor_id
          })

          {:reply, {:ok, poll_payload(poll)}, %{state | active_poll: nil}}
        else
          {:reply, {:error, :permission_denied}, state}
        end
    end
  end

  @impl true
  def handle_call(:get_poll, _from, state) do
    reply = if state.active_poll, do: poll_payload(state.active_poll), else: nil
    {:reply, reply, state}
  end

  @impl true
  def handle_call({:start_watch_party, url, actor_id}, _from, state) do
    with :ok <- require_speaker_or_host(state, actor_id),
         {:ok, media} <- ForgeNexus.Voice.WatchParty.parse_url(url) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      existing_queue = if state.watch_party, do: Map.get(state.watch_party, :queue, []), else: []

      party = %{
        media: media,
        host_user_id: actor_id,
        current_time: 0.0,
        is_playing: true,
        started_at: now,
        updated_at: now,
        queue: existing_queue
      }

      ForgeNexusWeb.Endpoint.broadcast("voice:#{state.room_id}", "watch_party_started", %{
        party: party_payload(party)
      })

      {:reply, {:ok, party_payload(party)}, %{state | watch_party: party}}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:control_watch_party, command, args, actor_id}, _from, state) do
    case state.watch_party do
      nil ->
        {:reply, {:error, :no_watch_party}, state}

      party ->
        if party.host_user_id == actor_id or state.host_id == actor_id do
          new_party = apply_watch_command(party, command, args)

          ForgeNexusWeb.Endpoint.broadcast("voice:#{state.room_id}", "watch_party_updated", %{
            party: party_payload(new_party),
            command: to_string(command),
            by: actor_id
          })

          {:reply, {:ok, party_payload(new_party)}, %{state | watch_party: new_party}}
        else
          {:reply, {:error, :permission_denied}, state}
        end
    end
  end

  @impl true
  def handle_call({:stop_watch_party, actor_id}, _from, state) do
    case state.watch_party do
      nil ->
        {:reply, {:error, :no_watch_party}, state}

      party ->
        if party.host_user_id == actor_id or state.host_id == actor_id do
          case advance_queue(state, party, actor_id) do
            {:advanced, new_party, new_state} ->
              {:reply, {:ok, party_payload(new_party)}, new_state}

            :empty ->
              ForgeNexusWeb.Endpoint.broadcast("voice:#{state.room_id}", "watch_party_ended", %{
                by: actor_id
              })

              {:reply, :ok, %{state | watch_party: nil}}
          end
        else
          {:reply, {:error, :permission_denied}, state}
        end
    end
  end

  @impl true
  def handle_call(:get_watch_party, _from, state) do
    reply =
      case state.watch_party do
        nil -> nil
        party -> party_payload(party)
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_cast({:leave, user_id}, state) do
    case Map.pop(state.participants, user_id) do
      {nil, _} ->
        {:noreply, state}

      {_participant, new_participants} ->
        ForgeNexusWeb.Endpoint.broadcast("voice:#{state.room_id}", "user_left", %{
          user_id: user_id,
          participant_count: map_size(new_participants)
        })

        state = %{state | participants: new_participants}

        # Host left? Hand off to earliest-joined speaker (stage rooms only)
        state =
          if state.room_type == "town_hall" and state.host_id == user_id do
            promote_next_host(state)
          else
            state
          end

        # Watch party host left? End the party.
        state =
          case state.watch_party do
            %{host_user_id: ^user_id} ->
              ForgeNexusWeb.Endpoint.broadcast("voice:#{state.room_id}", "watch_party_ended", %{
                by: user_id,
                reason: "host_left"
              })

              %{state | watch_party: nil}

            _ ->
              state
          end

        if map_size(new_participants) == 0 do
          {:ok, call_log} = Voice.log_call(%{
            room_id: state.room_id,
            room_type: state.room_type,
            started_at: state.started_at,
            ended_at: DateTime.utc_now() |> DateTime.truncate(:second),
            peak_participants: state.peak_count,
            peak_audience: state.peak_audience,
            peak_speakers: state.peak_speakers,
            total_hand_raises: state.total_hand_raises,
            total_promotions: state.total_promotions,
            total_demotions: state.total_demotions,
            host_user_id: state.host_id,
            participant_ids: MapSet.to_list(state.seen_user_ids)
          })

          Voice.award_participation_points(
            MapSet.to_list(state.seen_user_ids),
            state.started_at,
            DateTime.utc_now() |> DateTime.truncate(:second)
          )

          %{call_log_id: call_log.id, room_id: state.room_id}
          |> ForgeNexus.Workers.RoomAutoThreadWorker.new()
          |> Oban.insert()

          {:stop, :normal, state}
        else
          {:noreply, state}
        end
    end
  end

  # --- Helpers ---

  defp via(room_id), do: {:via, Registry, {ForgeNexus.Voice.RoomRegistry, room_id}}

  defp ensure_started(room_id) do
    case GenServer.whereis(via(room_id)) do
      nil ->
        room = ForgeNexus.Voice.get_room!(room_id)

        DynamicSupervisor.start_child(
          ForgeNexus.Voice.RoomSupervisor,
          {__MODULE__,
           room_id: room_id,
           room_type: room.type,
           max_participants: room.max_participants,
           created_by_id: room.created_by_id}
        )

      _pid ->
        :ok
    end
  end

  defp participant_json({uid, p}) do
    %{
      user_id: uid,
      username: p.username,
      avatar_url: p.avatar_url,
      role: to_string(Map.get(p, :role, :speaker)),
      hand_raised: Map.get(p, :hand_raised, false),
      muted: p.muted,
      deafened: p.deafened,
      video: p.video,
      screen_share: p.screen_share,
      joined_at: p.joined_at
    }
  end

  defp do_update_media(state, user_id, incoming) do
    participant = Map.fetch!(state.participants, user_id)
    updated = Map.merge(participant, incoming)
    new_participants = Map.put(state.participants, user_id, updated)

    ForgeNexusWeb.Endpoint.broadcast("voice:#{state.room_id}", "media_updated", %{
      user_id: user_id,
      muted: updated.muted,
      deafened: updated.deafened,
      video: updated.video,
      screen_share: updated.screen_share
    })

    %{state | participants: new_participants}
  end

  defp poll_payload(poll) do
    %{
      question: poll.question,
      options: poll.options,
      results: tally_votes(poll),
      total_votes: map_size(poll.votes),
      created_by: poll.created_by,
      created_at: poll.created_at
    }
  end

  defp tally_votes(poll) do
    Enum.with_index(poll.options)
    |> Enum.map(fn {option, idx} ->
      count = Enum.count(poll.votes, fn {_uid, vote_idx} -> vote_idx == idx end)
      %{option: option, index: idx, votes: count}
    end)
  end

  defp build_hand_queue(state) do
    state.participants
    |> Enum.filter(fn {_id, p} -> p.hand_raised end)
    |> Enum.sort_by(fn {_id, p} -> p.joined_at end, DateTime)
    |> Enum.map(fn {uid, p} ->
      %{user_id: uid, username: p.username, avatar_url: p.avatar_url}
    end)
  end

  defp require_host_or_co_host(state, actor_id) do
    cond do
      state.host_id == actor_id -> :ok
      match?(%{role: :co_host}, Map.get(state.participants, actor_id)) -> :ok
      true -> {:error, :permission_denied}
    end
  end

  defp fetch_participant(state, user_id) do
    case Map.get(state.participants, user_id) do
      nil -> {:error, :not_in_room}
      p -> {:ok, p}
    end
  end

  defp promote_next_host(state) do
    next =
      state.participants
      |> Enum.filter(fn {_id, p} -> p.role == :speaker end)
      |> Enum.min_by(fn {_id, p} -> p.joined_at end, fn -> nil end)

    case next do
      nil ->
        # No speakers left; promote the earliest-joined audience member if any
        case Enum.min_by(state.participants, fn {_id, p} -> p.joined_at end, fn -> nil end) do
          nil ->
            state

          {uid, p} ->
            updated = %{p | role: :speaker, muted: false, hand_raised: false}
            new_participants = Map.put(state.participants, uid, updated)

            ForgeNexusWeb.Endpoint.broadcast("voice:#{state.room_id}", "host_changed", %{
              host_id: uid
            })

            %{state | host_id: uid, participants: new_participants}
        end

      {uid, _} ->
        ForgeNexusWeb.Endpoint.broadcast("voice:#{state.room_id}", "host_changed", %{
          host_id: uid
        })

        %{state | host_id: uid}
    end
  end

  defp require_speaker_or_host(state, actor_id) do
    cond do
      state.host_id == actor_id ->
        :ok

      match?(%{role: r} when r in [:speaker, :co_host], Map.get(state.participants, actor_id)) ->
        :ok

      state.room_type != "town_hall" and Map.has_key?(state.participants, actor_id) ->
        :ok

      true ->
        {:error, :permission_denied}
    end
  end

  defp apply_watch_command(party, :play, _args) do
    %{party | is_playing: true, updated_at: DateTime.utc_now() |> DateTime.truncate(:second)}
  end

  defp apply_watch_command(party, :pause, _args) do
    %{party | is_playing: false, updated_at: DateTime.utc_now() |> DateTime.truncate(:second)}
  end

  defp apply_watch_command(party, :seek, %{time: time}) when is_number(time) do
    %{party | current_time: time * 1.0, updated_at: DateTime.utc_now() |> DateTime.truncate(:second)}
  end

  defp apply_watch_command(party, :sync, %{time: time, playing: playing})
       when is_number(time) and is_boolean(playing) do
    %{
      party
      | current_time: time * 1.0,
        is_playing: playing,
        updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  defp apply_watch_command(party, :queue_add, %{url: url}) when is_binary(url) do
    case ForgeNexus.Voice.WatchParty.parse_url(url) do
      {:ok, media} ->
        queue = Map.get(party, :queue, []) ++ [media]
        %{party | queue: queue, updated_at: DateTime.utc_now() |> DateTime.truncate(:second)}

      {:error, _} ->
        party
    end
  end

  defp apply_watch_command(party, :queue_remove, %{index: idx}) when is_integer(idx) do
    queue = Map.get(party, :queue, [])
    new_queue = List.delete_at(queue, idx)
    %{party | queue: new_queue, updated_at: DateTime.utc_now() |> DateTime.truncate(:second)}
  end

  defp apply_watch_command(party, :queue_clear, _args) do
    %{party | queue: [], updated_at: DateTime.utc_now() |> DateTime.truncate(:second)}
  end

  defp apply_watch_command(party, _, _), do: party

  defp advance_queue(state, party, actor_id) do
    queue = Map.get(party, :queue, [])

    case queue do
      [next_media | rest] ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        new_party = %{
          media: next_media,
          host_user_id: actor_id,
          current_time: 0.0,
          is_playing: true,
          started_at: now,
          updated_at: now,
          queue: rest
        }

        ForgeNexusWeb.Endpoint.broadcast("voice:#{state.room_id}", "watch_party_started", %{
          party: party_payload(new_party),
          auto_advanced: true
        })

        {:advanced, new_party, %{state | watch_party: new_party}}

      _ ->
        :empty
    end
  end

  defp party_payload(party) do
    queue = Map.get(party, :queue, [])

    %{
      media: %{
        type: to_string(party.media.type),
        id: party.media.id,
        url: party.media.url,
        label: party.media.label
      },
      host_user_id: party.host_user_id,
      current_time: party.current_time,
      is_playing: party.is_playing,
      started_at: party.started_at,
      updated_at: party.updated_at,
      queue: Enum.map(queue, fn m ->
        %{type: to_string(m.type), id: m.id, url: m.url, label: m.label}
      end),
      queue_length: length(queue)
    }
  end

  defp count_roles(participants) do
    Enum.reduce(participants, {0, 0}, fn {_id, p}, {s, a} ->
      case Map.get(p, :role, :speaker) do
        r when r in [:speaker, :co_host] -> {s + 1, a}
        :audience -> {s, a + 1}
        _ -> {s, a}
      end
    end)
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} when is_atom(k) -> {k, v}
    end)
  end
end
