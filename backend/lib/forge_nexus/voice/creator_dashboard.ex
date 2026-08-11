defmodule ForgeNexus.Voice.CreatorDashboard do
  @moduledoc """
  Aggregated revenue and activity dashboard for creators.
  Pulls from money_tips, redemptions, point_pack_purchases, and subscriptions.
  """

  import Ecto.Query
  alias ForgeNexus.Repo

  def get_dashboard(creator_id, opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    since = DateTime.utc_now() |> DateTime.add(-days * 86400, :second)

    %{
      earnings: earnings(creator_id, since),
      activity: activity(creator_id, since),
      top_supporters: top_supporters(creator_id, since),
      recent_tips: recent_tips(creator_id, 10),
      recent_redemptions: recent_redemptions(creator_id, 10)
    }
  end

  defp earnings(creator_id, since) do
    tip_earnings =
      from(t in "money_tips",
        where:
          t.recipient_id == type(^creator_id, :binary_id) and t.status == "completed" and
            t.inserted_at >= ^since,
        select: %{
          total_cents: coalesce(sum(t.creator_amount_cents), 0),
          count: count(t.id),
          avg_cents: coalesce(fragment("AVG(?)::integer", t.amount_cents), 0)
        }
      )
      |> Repo.one()

    all_time_earnings =
      from(t in "money_tips",
        where: t.recipient_id == type(^creator_id, :binary_id) and t.status == "completed",
        select: coalesce(sum(t.creator_amount_cents), 0)
      )
      |> Repo.one()

    %{
      period_days: DateTime.diff(DateTime.utc_now(), since, :second) |> div(86400),
      tips: tip_earnings,
      all_time_cents: all_time_earnings
    }
  end

  defp activity(creator_id, since) do
    redemptions =
      from(r in "redemptions",
        join: rd in "room_redeemables",
        on: rd.id == r.redeemable_id,
        join: vr in "voice_rooms",
        on: vr.id == r.room_id,
        where: vr.created_by_id == type(^creator_id, :binary_id) and r.inserted_at >= ^since,
        select: count(r.id)
      )
      |> Repo.one()

    room_sessions =
      from(cl in "voice_call_logs",
        where: cl.host_user_id == type(^creator_id, :binary_id) and cl.inserted_at >= ^since,
        select: %{
          count: count(cl.id),
          total_minutes:
            coalesce(
              sum(
                fragment("EXTRACT(EPOCH FROM (? - ?))::integer / 60", cl.ended_at, cl.started_at)
              ),
              0
            ),
          peak_viewers: coalesce(max(cl.peak_participants), 0)
        }
      )
      |> Repo.one()

    %{
      redemptions: redemptions,
      room_sessions: room_sessions
    }
  end

  defp top_supporters(creator_id, since) do
    from(t in "money_tips",
      where:
        t.recipient_id == type(^creator_id, :binary_id) and t.status == "completed" and
          t.inserted_at >= ^since and t.is_anonymous == false,
      group_by: t.sender_id,
      order_by: [desc: sum(t.amount_cents)],
      limit: 10,
      select: %{
        user_id: type(t.sender_id, :binary_id),
        total_cents: sum(t.amount_cents),
        tip_count: count(t.id)
      }
    )
    |> Repo.all()
  end

  defp recent_tips(creator_id, limit) do
    from(t in "money_tips",
      where: t.recipient_id == type(^creator_id, :binary_id) and t.status == "completed",
      order_by: [desc: t.inserted_at],
      limit: ^limit,
      select: %{
        id: type(t.id, :binary_id),
        sender_id: type(t.sender_id, :binary_id),
        amount_cents: t.amount_cents,
        creator_amount_cents: t.creator_amount_cents,
        message: t.message,
        is_anonymous: t.is_anonymous,
        inserted_at: t.inserted_at
      }
    )
    |> Repo.all()
  end

  defp recent_redemptions(creator_id, limit) do
    from(r in "redemptions",
      join: rd in "room_redeemables",
      on: rd.id == r.redeemable_id,
      join: vr in "voice_rooms",
      on: vr.id == r.room_id,
      where: vr.created_by_id == type(^creator_id, :binary_id),
      order_by: [desc: r.inserted_at],
      limit: ^limit,
      select: %{
        id: type(r.id, :binary_id),
        user_id: type(r.user_id, :binary_id),
        redeemable_name: rd.name,
        redeemable_type: rd.type,
        cost: r.cost,
        user_text: r.user_text,
        inserted_at: r.inserted_at
      }
    )
    |> Repo.all()
  end
end
