defmodule ForgeNexus.Affiliate do
  @moduledoc """
  Affiliate gate — creator must meet three thresholds before they can
  enable subscriptions on their channel:

    * 50 followers
    * 7 distinct active days (any activity: posts, threads, voice sessions)
    * 500 minutes streamed (sum of voice_call_logs durations as host)

  Stats are DERIVED from existing tables — no new affiliate_progress
  table. Once all three are met, the creator can call
  enable_subscriptions/1 to flip `users.subscriptions_enabled_at`.
  """

  import Ecto.Query
  alias ForgeNexus.Accounts.{User, UserFollow}
  alias ForgeNexus.Repo

  @follower_target 50
  @days_active_target 7
  @stream_minutes_target 500

  def follower_target, do: @follower_target
  def days_active_target, do: @days_active_target
  def stream_minutes_target, do: @stream_minutes_target

  @doc """
  Snapshot of the gate for a creator. Returns the raw counts, the targets,
  per-axis percentages (capped at 100), and an `all_met` boolean.
  """
  def progress(%User{} = user) do
    followers = follower_count(user.id)
    days_active = days_active_count(user.id)
    stream_minutes = stream_minutes_count(user.id)
    enabled = not is_nil(user.subscriptions_enabled_at)

    %{
      followers: build_metric(followers, @follower_target),
      days_active: build_metric(days_active, @days_active_target),
      stream_minutes: build_metric(stream_minutes, @stream_minutes_target),
      all_met:
        followers >= @follower_target and days_active >= @days_active_target and
          stream_minutes >= @stream_minutes_target,
      subscriptions_enabled: enabled,
      subscriptions_enabled_at: user.subscriptions_enabled_at
    }
  end

  defp build_metric(current, target) do
    pct = min(100, round(current * 100 / target))
    %{current: current, target: target, percent: pct, met: current >= target}
  end

  @doc """
  Flip the creator's subscription gate. Idempotent — re-calling on an
  already-enabled user returns the existing row unchanged. Returns
  `{:error, :gate_not_met}` if the thresholds haven't all been reached.
  """
  def enable_subscriptions(%User{subscriptions_enabled_at: t} = user) when not is_nil(t) do
    {:ok, user}
  end

  def enable_subscriptions(%User{} = user) do
    case progress(user) do
      %{all_met: true} ->
        user
        |> Ecto.Changeset.change(
          subscriptions_enabled_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )
        |> Repo.update()

      _ ->
        {:error, :gate_not_met}
    end
  end

  # ---- count helpers ---------------------------------------------------

  defp follower_count(user_id) do
    from(f in UserFollow, where: f.followee_id == ^user_id, select: count(f.id))
    |> Repo.one()
  end

  # Activity = any day with a post, thread, or voice room hosted. Counting
  # DISTINCT calendar days (UTC) gives the creator credit for sustained
  # presence regardless of how busy a single day was.
  defp days_active_count(user_id) do
    posts_days =
      from(p in "posts",
        where: p.user_id == type(^user_id, :binary_id),
        select: fragment("DATE(?)", p.inserted_at)
      )

    threads_days =
      from(t in "threads",
        where: t.user_id == type(^user_id, :binary_id),
        select: fragment("DATE(?)", t.inserted_at)
      )

    voice_days =
      from(cl in "voice_call_logs",
        where: cl.host_user_id == type(^user_id, :binary_id),
        select: fragment("DATE(?)", cl.inserted_at)
      )

    union_sql =
      posts_days
      |> union(^threads_days)
      |> union(^voice_days)

    from(d in subquery(union_sql), select: count(d.date, :distinct))
    |> Repo.one()
    |> case do
      nil -> 0
      n -> n
    end
  end

  defp stream_minutes_count(user_id) do
    from(cl in "voice_call_logs",
      where: cl.host_user_id == type(^user_id, :binary_id) and not is_nil(cl.ended_at),
      select:
        coalesce(
          sum(fragment("EXTRACT(EPOCH FROM (? - ?))::integer / 60", cl.ended_at, cl.started_at)),
          0
        )
    )
    |> Repo.one()
    |> Kernel.||(0)
    |> trunc()
  end
end
