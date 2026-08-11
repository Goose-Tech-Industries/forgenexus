defmodule ForgeNexus.Voice do
  @moduledoc """
  The Voice context — manages voice/video rooms and call history.
  """
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Voice.{Room, CallLog, RoomServer, DmCall}

  # --- Room CRUD ---

  def list_rooms do
    Room
    |> where([r], r.is_active == true)
    |> order_by(asc: :position)
    |> preload(:category)
    |> Repo.all()
    |> Enum.map(fn room ->
      participants = RoomServer.get_participants(room.id)
      Map.put(room, :live_participants, participants)
    end)
  end

  def get_room!(id), do: Room |> preload(:category) |> Repo.get!(id)

  def get_room_by_slug(slug),
    do: Room |> where([r], r.slug == ^slug) |> preload(:category) |> Repo.one()

  def create_room(attrs) do
    %Room{} |> Room.changeset(attrs) |> Repo.insert()
  end

  def list_upcoming_rooms(limit \\ 20) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Room
    |> where([r], r.is_active == true and not is_nil(r.scheduled_at) and r.scheduled_at > ^now)
    |> order_by(asc: :scheduled_at)
    |> limit(^limit)
    |> preload(:category)
    |> Repo.all()
  end

  def update_room(id, attrs) do
    get_room!(id) |> Room.changeset(attrs) |> Repo.update()
  end

  def delete_room(id) do
    get_room!(id) |> Repo.delete()
  end

  # --- Live room operations (delegated to GenServer) ---

  def join_room(room_id, user) do
    RoomServer.join(room_id, user)
  end

  def leave_room(room_id, user_id) do
    RoomServer.leave(room_id, user_id)
  end

  def update_media_state(room_id, user_id, state) do
    RoomServer.update_media(room_id, user_id, state)
  end

  def promote_to_speaker(room_id, target_user_id, actor_id) do
    RoomServer.promote_to_speaker(room_id, target_user_id, actor_id)
  end

  def demote_to_audience(room_id, target_user_id, actor_id) do
    RoomServer.demote_to_audience(room_id, target_user_id, actor_id)
  end

  def set_co_host(room_id, target_user_id, actor_id) do
    RoomServer.set_co_host(room_id, target_user_id, actor_id)
  end

  def get_hand_queue(room_id) do
    RoomServer.get_hand_queue(room_id)
  end

  def set_hand_raised(room_id, user_id, raised) do
    RoomServer.set_hand_raised(room_id, user_id, raised)
  end

  # --- In-room polls ---

  def create_poll(room_id, question, options, actor_id) do
    RoomServer.create_poll(room_id, question, options, actor_id)
  end

  def vote_poll(room_id, user_id, option_index) do
    RoomServer.vote_poll(room_id, user_id, option_index)
  end

  def close_poll(room_id, actor_id) do
    RoomServer.close_poll(room_id, actor_id)
  end

  def get_poll(room_id) do
    RoomServer.get_poll(room_id)
  end

  # --- Watch party ---

  def start_watch_party(room_id, url, actor_id) do
    RoomServer.start_watch_party(room_id, url, actor_id)
  end

  def control_watch_party(room_id, actor_id, command, args \\ %{}) do
    RoomServer.control_watch_party(room_id, actor_id, command, args)
  end

  def stop_watch_party(room_id, actor_id) do
    RoomServer.stop_watch_party(room_id, actor_id)
  end

  def get_watch_party(room_id) do
    RoomServer.get_watch_party(room_id)
  end

  # --- Recordings ---

  alias ForgeNexus.Voice.Recording

  def list_recordings(room_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Recording
    |> where([r], r.room_id == ^room_id and r.is_public == true)
    |> order_by(desc: :started_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_recording!(id), do: Repo.get!(Recording, id)

  def get_recording(id), do: Repo.get(Recording, id)

  def create_recording(attrs) do
    %Recording{}
    |> Recording.changeset(attrs)
    |> Repo.insert()
  end

  def delete_recording(%Recording{} = recording), do: Repo.delete(recording)

  def delete_recording(id) when is_binary(id) do
    case get_recording(id) do
      nil -> {:error, :not_found}
      recording -> delete_recording(recording)
    end
  end

  def attach_transcript(%Recording{} = recording, text, language) do
    recording
    |> Recording.changeset(%{
      transcript: text,
      transcript_language: language,
      transcript_status: "ready"
    })
    |> Repo.update()
  end

  def mark_transcript_processing(%Recording{} = recording) do
    recording |> Recording.changeset(%{transcript_status: "processing"}) |> Repo.update()
  end

  def mark_transcript_status(%Recording{} = recording, status) do
    recording |> Recording.changeset(%{transcript_status: status}) |> Repo.update()
  end

  def get_room_participants(room_id) do
    RoomServer.get_participants(room_id)
  end

  # --- Call logs ---

  def log_call(attrs) do
    %CallLog{} |> CallLog.changeset(attrs) |> Repo.insert()
  end

  def recent_calls(room_id, limit \\ 20) do
    CallLog
    |> where([c], c.room_id == ^room_id)
    |> order_by(desc: :started_at)
    |> limit(^limit)
    |> Repo.all()
  end

  # --- Money Tips (Stripe-ready) ---

  alias ForgeNexus.Voice.{MoneyTip, TipCalculator}

  def create_money_tip(attrs) do
    amount = Map.get(attrs, :amount_cents) || Map.get(attrs, "amount_cents")
    recipient_id = Map.get(attrs, :recipient_id) || Map.get(attrs, "recipient_id")
    room_id = Map.get(attrs, :room_id) || Map.get(attrs, "room_id")

    creator_tier = TipCalculator.tier_for_user(recipient_id)
    community_plan = TipCalculator.community_plan_for_room(room_id)
    calc = TipCalculator.calculate(amount, creator_tier, community_plan)

    full_attrs =
      attrs
      |> Map.merge(%{
        platform_fee_cents: calc.platform_gross_cents,
        creator_amount_cents: calc.creator_amount_cents,
        creator_tier: calc.creator_tier,
        stripe_fee_cents: calc.stripe_fee_cents,
        community_kickback_cents: calc.community_kickback_cents,
        community_plan: calc.community_plan,
        platform_net_cents: calc.platform_net_cents,
        status: "pending"
      })

    %MoneyTip{} |> MoneyTip.changeset(full_attrs) |> Repo.insert()
  end

  def complete_money_tip(tip_id, stripe_payment_intent_id \\ nil) do
    case Repo.get(MoneyTip, tip_id) do
      nil ->
        {:error, :not_found}

      tip ->
        tip
        |> MoneyTip.changeset(%{
          status: "completed",
          stripe_payment_intent_id: stripe_payment_intent_id
        })
        |> Repo.update()
    end
  end

  def list_money_tips_for_creator(creator_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    MoneyTip
    |> where([t], t.recipient_id == ^creator_id and t.status == "completed")
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def creator_tip_earnings(creator_id) do
    MoneyTip
    |> where([t], t.recipient_id == ^creator_id and t.status == "completed")
    |> Repo.aggregate(:sum, :creator_amount_cents) || 0
  end

  # --- Redeemables (Channel Point Rewards) ---

  alias ForgeNexus.Voice.{Redeemable, Redemption, RedemptionEngine}

  def list_redeemables(room_id) do
    Redeemable
    |> where([r], r.room_id == ^room_id and r.is_enabled == true)
    |> order_by(asc: :position, asc: :name)
    |> Repo.all()
  end

  def list_all_redeemables(room_id) do
    Redeemable
    |> where([r], r.room_id == ^room_id)
    |> order_by(asc: :position)
    |> Repo.all()
  end

  def get_redeemable!(id), do: Repo.get!(Redeemable, id)

  def create_redeemable(attrs) do
    %Redeemable{} |> Redeemable.changeset(attrs) |> Repo.insert()
  end

  def update_redeemable(id, attrs) do
    get_redeemable!(id) |> Redeemable.changeset(attrs) |> Repo.update()
  end

  def delete_redeemable(id) do
    get_redeemable!(id) |> Repo.delete()
  end

  def redeem(redeemable_id, room_id, user_id, user_text \\ nil) do
    RedemptionEngine.redeem(redeemable_id, room_id, user_id, user_text)
  end

  def list_redemptions(room_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Redemption
    |> where([r], r.room_id == ^room_id)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> preload([:redeemable, :user])
    |> Repo.all()
  end

  # --- Creator Moderators ---

  alias ForgeNexus.Voice.CreatorModerator

  def add_creator_mod(creator_id, moderator_id, community_id, permissions \\ %{}) do
    perms = Map.merge(CreatorModerator.default_permissions(), permissions)

    %CreatorModerator{}
    |> CreatorModerator.changeset(%{
      creator_id: creator_id,
      moderator_id: moderator_id,
      community_id: community_id,
      permissions: perms
    })
    |> Repo.insert()
  end

  def remove_creator_mod(creator_id, moderator_id) do
    from(m in CreatorModerator,
      where: m.creator_id == ^creator_id and m.moderator_id == ^moderator_id
    )
    |> Repo.delete_all()
  end

  def list_creator_mods(creator_id) do
    CreatorModerator
    |> where([m], m.creator_id == ^creator_id)
    |> preload(:moderator)
    |> Repo.all()
  end

  def is_creator_mod?(creator_id, user_id) do
    from(m in CreatorModerator,
      where: m.creator_id == ^creator_id and m.moderator_id == ^user_id
    )
    |> Repo.exists?()
  end

  def creator_mod_can?(creator_id, user_id, permission) do
    case Repo.get_by(CreatorModerator, creator_id: creator_id, moderator_id: user_id) do
      nil -> false
      mod -> CreatorModerator.has_permission?(mod, permission)
    end
  end

  # --- Soundboard ---

  alias ForgeNexus.Voice.SoundboardClip

  def list_soundboard_clips(room_id) do
    SoundboardClip
    |> where([c], c.room_id == ^room_id or c.is_global == true)
    |> order_by(asc: :name)
    |> Repo.all()
  end

  def get_soundboard_clip!(id), do: Repo.get!(SoundboardClip, id)

  def create_soundboard_clip(attrs) do
    %SoundboardClip{} |> SoundboardClip.changeset(attrs) |> Repo.insert()
  end

  def delete_soundboard_clip(%SoundboardClip{} = clip), do: Repo.delete(clip)

  def increment_play_count(clip_id) do
    from(c in SoundboardClip, where: c.id == ^clip_id)
    |> Repo.update_all(inc: [play_count: 1])
  end

  # --- Clips ---

  alias ForgeNexus.Voice.Clip

  def create_clip(attrs) do
    %Clip{} |> Clip.changeset(attrs) |> Repo.insert()
  end

  def get_clip!(id), do: Repo.get!(Clip, id) |> Repo.preload([:recording, :created_by])

  def get_clip(id), do: Repo.get(Clip, id) |> maybe_preload_clip()

  defp maybe_preload_clip(nil), do: nil
  defp maybe_preload_clip(clip), do: Repo.preload(clip, [:recording, :created_by])

  def list_clips(recording_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Clip
    |> where([c], c.recording_id == ^recording_id and c.is_public == true)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> preload(:created_by)
    |> Repo.all()
  end

  def list_recent_clips(limit \\ 20) do
    Clip
    |> where([c], c.is_public == true)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> preload([:recording, :created_by])
    |> Repo.all()
  end

  def increment_clip_views(clip_id) do
    from(c in Clip, where: c.id == ^clip_id)
    |> Repo.update_all(inc: [view_count: 1])
  end

  def delete_clip(%Clip{} = clip), do: Repo.delete(clip)

  # --- Voice participation rewards ---

  alias ForgeNexus.Settings

  def award_participation_points(participant_ids, started_at, ended_at)
      when is_list(participant_ids) do
    if Settings.get_bool("voice_reward_enabled") do
      per_minute = Settings.get_int("voice_reward_points_per_minute") |> max(0)
      min_duration = Settings.get_int("voice_reward_min_duration_seconds") |> max(0)
      max_points = Settings.get_int("voice_reward_max_points_per_session") |> max(0)

      duration_seconds = DateTime.diff(ended_at, started_at, :second)

      if duration_seconds >= min_duration and per_minute > 0 do
        minutes = div(duration_seconds, 60)
        points = minutes |> Kernel.*(per_minute) |> min(max_points)

        if points > 0 do
          Enum.each(participant_ids, fn user_id ->
            ForgeNexus.Economy.award_points(user_id, "voice_participation",
              amount: points,
              description: "Voice room participation (#{minutes} min)"
            )
          end)
        end
      end
    end
  end

  # --- DM Calls ---

  def initiate_call(conversation_id, caller_id, type \\ "audio") do
    # Check for existing active/ringing call on this conversation
    existing =
      DmCall
      |> where([c], c.conversation_id == ^conversation_id and c.status in ["ringing", "active"])
      |> Repo.one()

    if existing do
      {:error, :call_in_progress}
    else
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      %DmCall{}
      |> DmCall.changeset(%{
        conversation_id: conversation_id,
        caller_id: caller_id,
        type: type,
        status: "ringing",
        started_at: now,
        participant_ids: [caller_id]
      })
      |> Repo.insert()
    end
  end

  def answer_call(call_id, user_id) do
    call = Repo.get!(DmCall, call_id)

    if call.status == "ringing" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      new_participants = Enum.uniq(call.participant_ids ++ [user_id])

      call
      |> DmCall.changeset(%{
        status: "active",
        answered_at: now,
        participant_ids: new_participants
      })
      |> Repo.update()
    else
      {:error, :invalid_state}
    end
  end

  def decline_call(call_id) do
    call = Repo.get!(DmCall, call_id)

    if call.status == "ringing" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      call
      |> DmCall.changeset(%{status: "declined", ended_at: now})
      |> Repo.update()
    else
      {:error, :invalid_state}
    end
  end

  def end_call(call_id) do
    call = Repo.get!(DmCall, call_id)

    if call.status in ["ringing", "active"] do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      new_status = if call.status == "ringing", do: "missed", else: "ended"

      call
      |> DmCall.changeset(%{status: new_status, ended_at: now})
      |> Repo.update()
    else
      {:error, :already_ended}
    end
  end

  def get_active_call(conversation_id) do
    DmCall
    |> where([c], c.conversation_id == ^conversation_id and c.status in ["ringing", "active"])
    |> preload(:caller)
    |> Repo.one()
  end

  def call_history(conversation_id, limit \\ 20) do
    DmCall
    |> where([c], c.conversation_id == ^conversation_id)
    |> order_by(desc: :started_at)
    |> limit(^limit)
    |> preload(:caller)
    |> Repo.all()
  end

  # Auto-expire ringing calls after 30 seconds (called by Oban or periodic check)
  def expire_ringing_calls do
    threshold = DateTime.utc_now() |> DateTime.add(-30, :second) |> DateTime.truncate(:second)

    from(c in DmCall,
      where: c.status == "ringing" and c.started_at < ^threshold
    )
    |> Repo.update_all(
      set: [status: "missed", ended_at: DateTime.utc_now() |> DateTime.truncate(:second)]
    )
  end

  # --- Seed defaults ---

  def seed_defaults do
    categories = ForgeNexus.Channels.list_categories()
    general_cat = Enum.find(categories, fn c -> c.name == "General" end)

    if general_cat do
      create_room(%{name: "Lounge", type: "lounge", category_id: general_cat.id, position: 0})
      create_room(%{name: "Music", type: "lounge", category_id: general_cat.id, position: 1})
      create_room(%{name: "Gaming", type: "lounge", category_id: general_cat.id, position: 2})
    end
  end
end
