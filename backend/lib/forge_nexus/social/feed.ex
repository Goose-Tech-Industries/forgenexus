defmodule ForgeNexus.Social.Feed do
  @moduledoc """
  Aggregated social feed pulling from all content types within a community.
  Returns a unified timeline of status posts, threads, clips, achievements,
  polls, live rooms, economy events, and announcements — weighted and merged
  into a single chronological stream.
  """

  import Ecto.Query
  alias ForgeNexus.Repo

  @type feed_item :: %{
          type: String.t(),
          id: String.t(),
          data: map(),
          inserted_at: DateTime.t(),
          weight: float()
        }

  @spec get_feed(String.t(), keyword()) :: [feed_item()]
  def get_feed(community_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 30)
    filter = Keyword.get(opts, :filter, "all")
    before = Keyword.get(opts, :before)
    user_id = Keyword.get(opts, :user_id)

    sources =
      case filter do
        "posts" -> [:status_posts]
        "clips" -> [:clips]
        "threads" -> [:threads]
        "polls" -> [:polls]
        "live" -> [:live_rooms]
        "friends" -> [:status_posts, :threads, :clips, :achievements]
        _ -> [:status_posts, :threads, :clips, :announcements, :achievements, :polls, :live_rooms]
      end

    items =
      sources
      |> Enum.flat_map(fn source -> fetch_source(source, community_id, limit, before, user_id) end)
      |> Enum.sort_by(fn item -> {-item.weight, to_unix(item.inserted_at)} end, :desc)
      |> Enum.sort_by(fn item -> to_unix(item.inserted_at) end, :desc)
      |> Enum.take(limit)

    items
  end

  defp fetch_source(:status_posts, community_id, limit, before, _user_id) do
    query =
      from(p in "status_posts",
        where: p.community_id == type(^community_id, :binary_id) and p.visibility == "public",
        order_by: [desc: p.inserted_at],
        limit: ^limit,
        select: %{
          id: type(p.id, :binary_id),
          body: p.body,
          user_id: type(p.user_id, :binary_id),
          media_urls: p.media_urls,
          media_type: p.media_type,
          reference_type: p.reference_type,
          reference_id: type(p.reference_id, :binary_id),
          like_count: p.like_count,
          comment_count: p.comment_count,
          is_pinned: p.is_pinned,
          inserted_at: p.inserted_at
        }
      )

    query = if before, do: where(query, [p], p.inserted_at < ^before), else: query

    Repo.all(query)
    |> Enum.map(fn row ->
      %{
        type: "status_post",
        id: row.id,
        data: row,
        inserted_at: row.inserted_at,
        weight: if(row.is_pinned, do: 10.0, else: 1.0)
      }
    end)
  end

  defp fetch_source(:threads, community_id, limit, before, _user_id) do
    query =
      from(t in "threads",
        where: t.community_id == type(^community_id, :binary_id) and t.is_hidden == false,
        order_by: [desc: t.inserted_at],
        limit: ^limit,
        select: %{
          id: type(t.id, :binary_id),
          title: t.title,
          slug: t.slug,
          user_id: type(t.user_id, :binary_id),
          reply_count: t.reply_count,
          view_count: t.view_count,
          is_pinned: t.is_pinned,
          is_locked: t.is_locked,
          inserted_at: t.inserted_at
        }
      )

    query = if before, do: where(query, [t], t.inserted_at < ^before), else: query

    Repo.all(query)
    |> Enum.map(fn row ->
      hot = if(row.reply_count > 10 or row.view_count > 100, do: 0.3, else: 0.0)

      %{
        type: "thread",
        id: row.id,
        data: row,
        inserted_at: row.inserted_at,
        weight: 0.6 + hot + if(row.is_pinned, do: 5.0, else: 0.0)
      }
    end)
  end

  defp fetch_source(:clips, community_id, limit, before, _user_id) do
    query =
      from(c in "voice_clips",
        join: r in "voice_recordings", on: r.id == c.recording_id,
        where: r.community_id == type(^community_id, :binary_id) and c.is_public == true,
        order_by: [desc: c.inserted_at],
        limit: ^limit,
        select: %{
          id: type(c.id, :binary_id),
          title: c.title,
          start_ms: c.start_ms,
          end_ms: c.end_ms,
          view_count: c.view_count,
          created_by_id: type(c.created_by_id, :binary_id),
          recording_id: type(c.recording_id, :binary_id),
          inserted_at: c.inserted_at
        }
      )

    query = if before, do: where(query, [c, _r], c.inserted_at < ^before), else: query

    Repo.all(query)
    |> Enum.map(fn row ->
      %{
        type: "clip",
        id: row.id,
        data: row,
        inserted_at: row.inserted_at,
        weight: 0.7
      }
    end)
  end

  defp fetch_source(:announcements, community_id, limit, _before, _user_id) do
    query =
      from(a in "announcements",
        where: a.community_id == type(^community_id, :binary_id),
        order_by: [desc: a.inserted_at],
        limit: ^limit,
        select: %{
          id: type(a.id, :binary_id),
          title: a.title,
          body: a.body,
          user_id: type(a.created_by_id, :binary_id),
          inserted_at: a.inserted_at
        }
      )

    Repo.all(query)
    |> Enum.map(fn row ->
      %{
        type: "announcement",
        id: row.id,
        data: row,
        inserted_at: row.inserted_at,
        weight: 8.0
      }
    end)
  end

  defp fetch_source(:achievements, community_id, limit, before, _user_id) do
    query =
      from(ub in "user_badges",
        where: ub.community_id == type(^community_id, :binary_id),
        order_by: [desc: ub.inserted_at],
        limit: ^limit,
        select: %{
          id: type(ub.id, :binary_id),
          user_id: type(ub.user_id, :binary_id),
          badge_id: type(ub.badge_id, :binary_id),
          inserted_at: ub.inserted_at
        }
      )

    query = if before, do: where(query, [ub], ub.inserted_at < ^before), else: query

    Repo.all(query)
    |> Enum.map(fn row ->
      %{
        type: "achievement",
        id: row.id,
        data: row,
        inserted_at: row.inserted_at,
        weight: 0.5
      }
    end)
  end

  defp fetch_source(:polls, community_id, limit, _before, _user_id) do
    query =
      from(p in "polls",
        where: p.community_id == type(^community_id, :binary_id),
        order_by: [desc: p.inserted_at],
        limit: ^limit,
        select: %{
          id: type(p.id, :binary_id),
          question: p.question,
          thread_id: type(p.thread_id, :binary_id),
          voter_count: p.voter_count,
          inserted_at: p.inserted_at
        }
      )

    Repo.all(query)
    |> Enum.map(fn row ->
      %{
        type: "poll",
        id: row.id,
        data: row,
        inserted_at: row.inserted_at,
        weight: 0.9
      }
    end)
  end

  defp fetch_source(:live_rooms, community_id, _limit, _before, _user_id) do
    rooms =
      from(r in "voice_rooms",
        where: r.community_id == type(^community_id, :binary_id) and r.is_active == true,
        select: %{
          id: type(r.id, :binary_id),
          name: r.name,
          slug: r.slug,
          type: r.type,
          inserted_at: r.inserted_at
        }
      )
      |> Repo.all()
      |> Enum.filter(fn room ->
        participants = ForgeNexus.Voice.RoomServer.get_participants(room.id)
        length(participants) > 0
      end)

    Enum.map(rooms, fn room ->
      participants = ForgeNexus.Voice.RoomServer.get_participants(room.id)

      %{
        type: "live_room",
        id: room.id,
        data: Map.put(room, :participant_count, length(participants)),
        inserted_at: room.inserted_at,
        weight: 15.0
      }
    end)
  end

  defp to_unix(%DateTime{} = dt), do: DateTime.to_unix(dt)
  defp to_unix(%NaiveDateTime{} = ndt), do: NaiveDateTime.diff(ndt, ~N[1970-01-01 00:00:00])
  defp to_unix(_), do: 0
end
