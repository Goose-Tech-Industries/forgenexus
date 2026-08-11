defmodule ForgeNexus.Workers.StatsComputer do
  @moduledoc """
  Oban cron worker that precomputes community stats every 5 minutes.
  Results are stored in StatsCache (ETS) for instant reads.

  Stats computed:
  - Total members, threads, posts
  - New members today
  - Posts today
  - Most active users (24h)
  - Trending threads (7 days)
  - Online user count
  - Peak online count
  """
  use Oban.Worker, queue: :default, max_attempts: 1

  import Ecto.Query
  require Logger

  alias ForgeNexus.Repo.Read
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Forums.{Thread, Forum, Category}
  alias ForgeNexus.Forums.Post
  alias ForgeNexus.StatsCache

  @impl Oban.Worker
  def perform(_job) do
    start = System.monotonic_time(:millisecond)

    compute_totals()
    compute_today_activity()
    compute_most_active()
    compute_trending()
    compute_online_peak()

    StatsCache.put(:last_computed_at, DateTime.utc_now())

    elapsed = System.monotonic_time(:millisecond) - start
    Logger.info("[StatsComputer] Computed all stats in #{elapsed}ms")

    :ok
  end

  defp compute_totals do
    total_members =
      Read.one(from u in User, where: u.status == "active", select: count(u.id)) || 0

    total_threads = Read.one(from t in Thread, select: count(t.id)) || 0
    total_posts = Read.one(from p in Post, select: count(p.id)) || 0

    total_forums =
      Read.one(from f in Forum, where: f.is_visible == true, select: count(f.id)) || 0

    total_categories =
      Read.one(from c in Category, where: c.is_visible == true, select: count(c.id)) || 0

    StatsCache.put(:total_members, total_members)
    StatsCache.put(:total_threads, total_threads)
    StatsCache.put(:total_posts, total_posts)
    StatsCache.put(:total_forums, total_forums)
    StatsCache.put(:total_categories, total_categories)
  end

  defp compute_today_activity do
    today_start = Date.utc_today() |> DateTime.new!(~T[00:00:00])

    new_members_today =
      Read.one(from u in User, where: u.inserted_at >= ^today_start, select: count(u.id)) || 0

    posts_today =
      Read.one(from p in Post, where: p.inserted_at >= ^today_start, select: count(p.id)) || 0

    threads_today =
      Read.one(from t in Thread, where: t.inserted_at >= ^today_start, select: count(t.id)) || 0

    StatsCache.put(:new_members_today, new_members_today)
    StatsCache.put(:posts_today, posts_today)
    StatsCache.put(:threads_today, threads_today)
  end

  defp compute_most_active do
    cutoff = DateTime.utc_now() |> DateTime.add(-24, :hour)

    most_active =
      from(p in Post,
        where: p.inserted_at >= ^cutoff,
        join: u in User,
        on: u.id == p.user_id,
        group_by: [u.id, u.username, u.slug, u.display_name],
        select: %{
          user_id: u.id,
          username: u.username,
          slug: u.slug,
          display_name: u.display_name,
          post_count: count(p.id)
        },
        order_by: [desc: count(p.id)],
        limit: 10
      )
      |> Read.all()

    StatsCache.put(:most_active_24h, most_active)
  end

  defp compute_trending do
    cutoff = DateTime.utc_now() |> DateTime.add(-7, :day)

    trending =
      from(t in Thread,
        where: t.inserted_at >= ^cutoff or t.last_post_at >= ^cutoff,
        join: u in User,
        on: u.id == t.user_id,
        join: f in Forum,
        on: f.id == t.forum_id,
        select: %{
          id: t.id,
          title: t.title,
          slug: t.slug,
          reply_count: t.reply_count,
          view_count: t.view_count,
          forum_name: f.name,
          forum_slug: f.slug,
          author: u.username,
          last_post_at: t.last_post_at
        },
        order_by: [desc: fragment("? * 3 + ? + ?", t.reply_count, t.view_count, t.reply_count)],
        limit: 10
      )
      |> Read.all()

    StatsCache.put(:trending_threads, trending)
  end

  defp compute_online_peak do
    current_online = ForgeNexus.PresenceTracker.online_count()
    previous_peak = StatsCache.get(:peak_online, 0)

    if current_online > previous_peak do
      StatsCache.put(:peak_online, current_online)
      StatsCache.put(:peak_online_at, DateTime.utc_now())
    end

    StatsCache.put(:current_online, current_online)
  rescue
    # PresenceTracker might not be started yet
    _ -> :ok
  end
end
