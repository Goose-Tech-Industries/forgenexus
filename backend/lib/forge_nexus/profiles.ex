defmodule ForgeNexus.Profiles do
  @moduledoc """
  The Profiles context — profile pages, top friends, guestbook, visits.
  """
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Profiles.{TopFriend, GuestbookEntry, ProfileVisit, ProfileEndorsement}

  # --- Profile Lookup ---

  def get_profile_by_slug(slug) do
    User
    |> where([u], u.slug == ^slug)
    |> preload([:primary_group, :selected_theme])
    |> Repo.one()
  end

  # --- Top Friends ---

  def list_top_friends(user_id) do
    TopFriend
    |> where([tf], tf.user_id == ^user_id)
    |> order_by(:position)
    |> preload(:friend)
    |> Repo.all()
  end

  def set_top_friends(user_id, friend_ids) when is_list(friend_ids) do
    # Limit to 10
    friend_ids = Enum.take(friend_ids, 10)

    Repo.transaction(fn ->
      # Delete existing
      TopFriend
      |> where([tf], tf.user_id == ^user_id)
      |> Repo.delete_all()

      # Insert new ones
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      entries =
        friend_ids
        |> Enum.with_index()
        |> Enum.map(fn {friend_id, idx} ->
          %{
            id: Ecto.UUID.generate(),
            user_id: user_id,
            friend_id: friend_id,
            position: idx,
            inserted_at: now,
            updated_at: now
          }
        end)

      if entries != [] do
        Repo.insert_all(TopFriend, entries)
      end

      list_top_friends(user_id)
    end)
  end

  # --- Guestbook ---

  def list_guestbook_entries(profile_user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    GuestbookEntry
    |> where([g], g.profile_user_id == ^profile_user_id and g.is_hidden == false)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> preload(:author)
    |> Repo.all()
  end

  def create_guestbook_entry(attrs) do
    %GuestbookEntry{}
    |> GuestbookEntry.changeset(attrs)
    |> Repo.insert()
  end

  def delete_guestbook_entry(entry_id, user_id) do
    entry = Repo.get!(GuestbookEntry, entry_id)

    if entry.author_id == user_id or entry.profile_user_id == user_id do
      Repo.delete(entry)
    else
      {:error, :unauthorized}
    end
  end

  # --- Profile Visits ---

  def record_visit(profile_user_id, visitor_id) do
    # Don't count self-visits
    if profile_user_id == visitor_id do
      :ok
    else
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Repo.insert(
        %ProfileVisit{
          profile_user_id: profile_user_id,
          visitor_id: visitor_id,
          visited_at: now
        },
        on_conflict: [set: [visited_at: now, updated_at: now]],
        conflict_target: [:profile_user_id, :visitor_id]
      )

      # Increment view counter
      User
      |> where([u], u.id == ^profile_user_id)
      |> Repo.update_all(inc: [profile_views: 1])

      :ok
    end
  end

  def recent_visitors(profile_user_id, limit \\ 10) do
    ProfileVisit
    |> where([pv], pv.profile_user_id == ^profile_user_id)
    |> order_by(desc: :visited_at)
    |> limit(^limit)
    |> preload(:visitor)
    |> Repo.all()
  end

  # --- Owner analytics: daily view counts for the last N days ---

  def daily_visit_counts(profile_user_id, days \\ 30) when is_integer(days) do
    since = DateTime.utc_now() |> DateTime.add(-days * 86400, :second)

    rows =
      from(pv in ProfileVisit,
        where: pv.profile_user_id == ^profile_user_id and pv.visited_at >= ^since,
        group_by: fragment("date_trunc('day', ?)", pv.visited_at),
        select: {fragment("date_trunc('day', ?)::date", pv.visited_at), count(pv.id)}
      )
      |> Repo.all()

    by_date = Map.new(rows, fn {d, c} -> {d |> to_string(), c} end)
    today = Date.utc_today()

    for i <- (days - 1)..0//-1 do
      date = Date.add(today, -i)
      key = Date.to_iso8601(date)
      %{date: key, count: Map.get(by_date, key, 0)}
    end
  end

  # --- Endorsements (emoji reactions on a profile) ---

  def endorsement_counts(profile_user_id) do
    ProfileEndorsement
    |> where([e], e.profile_user_id == ^profile_user_id)
    |> group_by([e], e.emoji)
    |> select([e], {e.emoji, count(e.id)})
    |> Repo.all()
    |> Enum.into(%{})
  end

  def endorse(profile_user_id, sender_id, emoji) when profile_user_id == sender_id do
    {:error, :cannot_endorse_self}
  end

  def endorse(profile_user_id, sender_id, emoji) do
    %ProfileEndorsement{}
    |> ProfileEndorsement.changeset(%{
      profile_user_id: profile_user_id,
      sender_id: sender_id,
      emoji: emoji
    })
    |> Repo.insert()
    |> case do
      {:ok, e} -> {:ok, e}
      {:error, cs} ->
        if Enum.any?(cs.errors, fn {_, {msg, _}} -> String.contains?(msg, "already been taken") end) do
          {:error, :already_endorsed}
        else
          {:error, cs}
        end
    end
  end

  def revoke_endorsement(profile_user_id, sender_id, emoji) do
    from(e in ProfileEndorsement,
      where: e.profile_user_id == ^profile_user_id and e.sender_id == ^sender_id and e.emoji == ^emoji
    )
    |> Repo.delete_all()
    |> case do
      {0, _} -> {:error, :not_found}
      {_, _} -> :ok
    end
  end

  def my_endorsements(profile_user_id, sender_id) do
    ProfileEndorsement
    |> where([e], e.profile_user_id == ^profile_user_id and e.sender_id == ^sender_id)
    |> select([e], e.emoji)
    |> Repo.all()
  end
end
