defmodule ForgeNexus.AI.CommunityHealth do
  @moduledoc """
  Calculates a community health score (0-100) from engagement, moderation,
  growth, and sentiment data. Stored daily for trend tracking.
  """

  import Ecto.Query
  alias ForgeNexus.Repo

  def calculate(community_id) do
    engagement = engagement_score(community_id)
    moderation = moderation_score(community_id)
    growth = growth_score(community_id)
    retention = retention_score(community_id)

    overall = (engagement * 0.35 + moderation * 0.25 + growth * 0.20 + retention * 0.20)
              |> Float.round(1)
              |> min(100.0)
              |> max(0.0)

    previous = get_previous_score(community_id)
    trend = cond do
      is_nil(previous) -> "new"
      overall > previous + 3 -> "up"
      overall < previous - 3 -> "down"
      true -> "stable"
    end

    components = %{
      engagement: Float.round(engagement, 1),
      moderation: Float.round(moderation, 1),
      growth: Float.round(growth, 1),
      retention: Float.round(retention, 1)
    }

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Raw insert_all with a string table — both UUIDs need to be raw 16-byte binaries
    {:ok, id_bin} = Ecto.UUID.dump(Ecto.UUID.generate())
    {:ok, community_id_bin} = Ecto.UUID.dump(community_id)

    Repo.insert_all("community_health_scores", [
      %{
        id: id_bin,
        community_id: community_id_bin,
        score: overall,
        trend: trend,
        components: components,
        calculated_at: now,
        inserted_at: now,
        updated_at: now
      }
    ])

    %{score: overall, trend: trend, components: components}
  end

  defp engagement_score(community_id) do
    seven_days = DateTime.utc_now() |> DateTime.add(-7 * 86400, :second)

    posts = from(p in "posts", where: p.community_id == type(^community_id, :binary_id) and p.inserted_at > ^seven_days, select: count()) |> Repo.one()
    threads = from(t in "threads", where: t.community_id == type(^community_id, :binary_id) and t.inserted_at > ^seven_days, select: count()) |> Repo.one()
    voice_sessions = from(c in "voice_call_logs", where: c.community_id == type(^community_id, :binary_id) and c.inserted_at > ^seven_days, select: count()) |> Repo.one()

    raw = posts * 1 + threads * 3 + voice_sessions * 5
    min(raw / 2.0, 100.0)
  end

  defp moderation_score(community_id) do
    seven_days = DateTime.utc_now() |> DateTime.add(-7 * 86400, :second)

    reports = from(r in "reports", where: r.community_id == type(^community_id, :binary_id) and r.inserted_at > ^seven_days, select: count()) |> Repo.one()
    bans = from(b in "bans", where: b.community_id == type(^community_id, :binary_id) and b.inserted_at > ^seven_days, select: count()) |> Repo.one()

    penalty = reports * 2 + bans * 10
    max(100.0 - penalty, 0.0)
  end

  defp growth_score(community_id) do
    seven_days = DateTime.utc_now() |> DateTime.add(-7 * 86400, :second)
    fourteen_days = DateTime.utc_now() |> DateTime.add(-14 * 86400, :second)

    this_week = from(u in "users", where: u.community_id == type(^community_id, :binary_id) and u.inserted_at > ^seven_days, select: count()) |> Repo.one()
    last_week = from(u in "users", where: u.community_id == type(^community_id, :binary_id) and u.inserted_at > ^fourteen_days and u.inserted_at <= ^seven_days, select: count()) |> Repo.one()

    if last_week == 0 do
      min(this_week * 10.0, 100.0)
    else
      growth_rate = (this_week - last_week) / last_week * 100
      min(50.0 + growth_rate, 100.0) |> max(0.0)
    end
  end

  defp retention_score(community_id) do
    seven_days = DateTime.utc_now() |> DateTime.add(-7 * 86400, :second)

    total_members = from(u in "users", where: u.community_id == type(^community_id, :binary_id), select: count()) |> Repo.one()
    active_members = from(u in "users", where: u.community_id == type(^community_id, :binary_id) and u.last_seen_at > ^seven_days, select: count()) |> Repo.one()

    if total_members == 0 do
      50.0
    else
      active_members / total_members * 100
    end
  end

  defp get_previous_score(community_id) do
    from(h in "community_health_scores",
      where: h.community_id == type(^community_id, :binary_id),
      order_by: [desc: :calculated_at],
      limit: 1,
      select: h.score
    )
    |> Repo.one()
  end

  def get_history(community_id, days \\ 30) do
    since = DateTime.utc_now() |> DateTime.add(-days * 86400, :second)

    from(h in "community_health_scores",
      where: h.community_id == type(^community_id, :binary_id) and h.calculated_at > ^since,
      order_by: [asc: :calculated_at],
      select: %{score: h.score, trend: h.trend, components: h.components, calculated_at: h.calculated_at}
    )
    |> Repo.all()
  end
end
