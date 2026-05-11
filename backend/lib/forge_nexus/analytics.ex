defmodule ForgeNexus.Analytics do
  @moduledoc """
  The Analytics context. Tracks community statistics and health metrics.
  """

  import Ecto.Query, warn: false
  alias ForgeNexus.Repo

  alias ForgeNexus.Analytics.CommunityStats

  # ── Daily Stats ──

  def get_daily_stats(days_back \\ 30) do
    cutoff = Date.utc_today() |> Date.add(-days_back)

    CommunityStats
    |> where([s], s.date >= ^cutoff)
    |> order_by([s], desc: s.date)
    |> Repo.all()
  end

  def get_today_stats do
    today = Date.utc_today()
    Repo.get_by(CommunityStats, date: today)
  end

  def compute_daily_stats(date) do
    start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

    new_members =
      from(u in "users",
        where: u.inserted_at >= ^start_of_day and u.inserted_at <= ^end_of_day,
        select: count(u.id)
      )
      |> Repo.one() || 0

    posts_created =
      from(p in "posts",
        where: p.inserted_at >= ^start_of_day and p.inserted_at <= ^end_of_day,
        select: count(p.id)
      )
      |> Repo.one() || 0

    threads_created =
      from(t in "threads",
        where: t.inserted_at >= ^start_of_day and t.inserted_at <= ^end_of_day,
        select: count(t.id)
      )
      |> Repo.one() || 0

    # Active members: users who posted on this date
    active_members =
      from(p in "posts",
        where: p.inserted_at >= ^start_of_day and p.inserted_at <= ^end_of_day,
        select: count(p.user_id, :distinct)
      )
      |> Repo.one() || 0

    attrs = %{
      date: date,
      new_members: new_members,
      active_members: active_members,
      posts_created: posts_created,
      threads_created: threads_created
    }

    case Repo.get_by(CommunityStats, date: date) do
      nil ->
        %CommunityStats{}
        |> CommunityStats.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> CommunityStats.changeset(attrs)
        |> Repo.update()
    end
  end

  # ── Community Health ──

  def get_community_health do
    recent_stats = get_daily_stats(7)

    if Enum.empty?(recent_stats) do
      %{score: 0, factors: %{}}
    else
      avg_active = Enum.map(recent_stats, & &1.active_members) |> average()
      avg_posts = Enum.map(recent_stats, & &1.posts_created) |> average()
      avg_threads = Enum.map(recent_stats, & &1.threads_created) |> average()
      avg_new_members = Enum.map(recent_stats, & &1.new_members) |> average()

      avg_response_rate =
        recent_stats
        |> Enum.map(& &1.response_rate)
        |> Enum.reject(&is_nil/1)
        |> average()

      # Score components (each 0-20, total 0-100)
      activity_score = min(avg_posts / 5, 1.0) * 20
      engagement_score = min(avg_active / 10, 1.0) * 20
      growth_score = min(avg_new_members / 3, 1.0) * 20
      content_score = min(avg_threads / 3, 1.0) * 20
      response_score = (avg_response_rate || 0) * 20

      total = round(activity_score + engagement_score + growth_score + content_score + response_score)

      %{
        score: min(total, 100),
        factors: %{
          activity: round(activity_score),
          engagement: round(engagement_score),
          growth: round(growth_score),
          content: round(content_score),
          responsiveness: round(response_score)
        }
      }
    end
  end

  defp average([]), do: 0.0
  defp average(list) do
    Enum.sum(list) / length(list)
  end

  # ── Top Contributors ──

  def get_top_contributors(opts \\ %{}) do
    days = opts[:days] || 30
    limit_count = opts[:limit] || 10
    cutoff = Date.utc_today() |> Date.add(-days)
    cutoff_dt = DateTime.new!(cutoff, ~T[00:00:00], "Etc/UTC")

    from(p in "posts",
      where: p.inserted_at >= ^cutoff_dt,
      group_by: p.user_id,
      select: %{user_id: type(p.user_id, :binary_id), post_count: count(p.id)},
      order_by: [desc: count(p.id)],
      limit: ^limit_count
    )
    |> Repo.all()
  end

  # ── Popular Topics ──

  def get_popular_topics(opts \\ %{}) do
    days = opts[:days] || 7
    limit_count = opts[:limit] || 10
    cutoff = Date.utc_today() |> Date.add(-days)
    cutoff_dt = DateTime.new!(cutoff, ~T[00:00:00], "Etc/UTC")

    from(t in "threads",
      left_join: p in "posts", on: p.thread_id == t.id,
      where: p.inserted_at >= ^cutoff_dt,
      group_by: [t.id, t.title],
      select: %{thread_id: type(t.id, :binary_id), title: t.title, reply_count: count(p.id)},
      order_by: [desc: count(p.id)],
      limit: ^limit_count
    )
    |> Repo.all()
  end
end
