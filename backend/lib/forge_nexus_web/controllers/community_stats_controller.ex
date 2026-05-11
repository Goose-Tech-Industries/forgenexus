defmodule ForgeNexusWeb.CommunityStatsController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Analytics

  def index(conn, params) do
    days = parse_int(params["days"], 30)
    daily = Analytics.get_daily_stats(days)
    today = Analytics.get_today_stats()
    health = Analytics.get_community_health()

    conn
    |> json(%{
      daily: Enum.map(daily, &daily_json/1),
      today: daily_json(today),
      health: health
    })
  end

  def contributors(conn, params) do
    top = Analytics.get_top_contributors(params)
    conn |> json(%{contributors: top})
  end

  def popular_topics(conn, params) do
    topics = Analytics.get_popular_topics(params)
    conn |> json(%{topics: topics})
  end

  defp daily_json(nil), do: nil

  defp daily_json(stat) do
    %{
      date: stat.date,
      new_members: stat.new_members,
      active_members: stat.active_members,
      posts_created: stat.posts_created,
      threads_created: stat.threads_created,
      avg_reply_time_minutes: stat.avg_reply_time_minutes,
      response_rate: stat.response_rate,
      top_topics: stat.top_topics
    }
  end

  defp parse_int(nil, default), do: default
  defp parse_int(v, _default) when is_integer(v), do: v

  defp parse_int(v, default) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_int(_, default), do: default
end
