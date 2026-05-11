defmodule ForgeNexus.Workers.AnalyticsDailyWorker do
  use Oban.Worker, queue: :default, max_attempts: 1

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Analytics.CommunityStats
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Forums.{Thread, Post}

  @impl Oban.Worker
  def perform(_job) do
    yesterday = Date.utc_today() |> Date.add(-1)
    start_dt = DateTime.new!(yesterday, ~T[00:00:00], "Etc/UTC")
    end_dt = DateTime.new!(yesterday, ~T[23:59:59], "Etc/UTC")

    new_members = from(u in User, where: u.inserted_at >= ^start_dt and u.inserted_at <= ^end_dt) |> Repo.aggregate(:count)

    # Active = posted or created thread
    active_posters = from(p in Post, where: p.inserted_at >= ^start_dt and p.inserted_at <= ^end_dt, select: p.user_id, distinct: true) |> Repo.all()
    active_creators = from(t in Thread, where: t.inserted_at >= ^start_dt and t.inserted_at <= ^end_dt, select: t.user_id, distinct: true) |> Repo.all()
    active_members = (active_posters ++ active_creators) |> Enum.uniq() |> length()

    posts_created = from(p in Post, where: p.inserted_at >= ^start_dt and p.inserted_at <= ^end_dt) |> Repo.aggregate(:count)
    threads_created = from(t in Thread, where: t.inserted_at >= ^start_dt and t.inserted_at <= ^end_dt) |> Repo.aggregate(:count)

    # Response rate: % of threads created yesterday that have at least 1 reply
    threads_with_replies = if threads_created > 0 do
      from(t in Thread,
        where: t.inserted_at >= ^start_dt and t.inserted_at <= ^end_dt and t.reply_count > 0
      ) |> Repo.aggregate(:count)
    else
      0
    end
    response_rate = if threads_created > 0, do: threads_with_replies / threads_created * 100, else: 0.0

    %CommunityStats{}
    |> CommunityStats.changeset(%{
      date: yesterday,
      new_members: new_members,
      active_members: active_members,
      posts_created: posts_created,
      threads_created: threads_created,
      response_rate: response_rate,
      top_topics: []
    })
    |> Repo.insert(on_conflict: :replace_all, conflict_target: :date)

    :ok
  end
end
