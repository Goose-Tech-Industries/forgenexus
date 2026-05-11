defmodule ForgeNexusWeb.AdminDashboardController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Admin
  alias ForgeNexus.Accounts

  # War Room (HTTP fallback for initial load)
  def war_room(conn, _params) do
    stats = Admin.war_room_stats()
    conn |> json(%{stats: stats})
  end

  # Community Health Score
  def health_score(conn, _params) do
    data = Admin.community_health_score()
    conn |> json(%{health: data})
  end

  # Content Decay
  def content_decay(conn, _params) do
    report = Admin.content_decay_report()
    conn |> json(%{forums: report})
  end

  # Registration Funnel
  def registration_funnel(conn, params) do
    days = parse_int(params, "days", 30)
    data = Admin.registration_funnel(days)
    conn |> json(%{funnel: data})
  end

  # Plugin Impact
  def plugin_impact(conn, _params) do
    data = Admin.plugin_impact_stats()
    conn |> json(%{impact: data})
  end

  # Activity Heatmap
  def activity_heatmap(conn, params) do
    days = parse_int(params, "days", 90)
    data = Admin.activity_heatmap(days)
    conn |> json(%{heatmap: data})
  end

  # Audit Trail
  def list_audit_logs(conn, params) do
    opts = [
      category: Map.get(params, "category"),
      action: Map.get(params, "action"),
      limit: parse_int(params, "limit", 50),
      offset: parse_int(params, "offset", 0)
    ]
    logs = Admin.list_audit_logs(opts)
    conn |> json(%{logs: Enum.map(logs, &audit_log_json/1)})
  end

  def rollback_audit_log(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)
    case Admin.rollback_action(id, user.id) do
      {:ok, log} ->
        conn |> json(%{log: audit_log_json(ForgeNexus.Repo.preload(log, [:admin, :rolled_back_by]))})
      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: reason})
    end
  end

  # Forum Reordering
  def reorder_categories(conn, %{"ordered_ids" => ids}) when is_list(ids) do
    user = Guardian.Plug.current_resource(conn)
    case Admin.reorder_categories(ids) do
      {:ok, _} ->
        Admin.log_admin_action(user.id, %{
          action: "category_reordered", category: "forums",
          target_type: "category", description: "Reordered #{length(ids)} categories"
        })
        conn |> json(%{ok: true})
      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to reorder"})
    end
  end

  def reorder_forums(conn, %{"category_id" => cat_id, "ordered_ids" => ids}) when is_list(ids) do
    user = Guardian.Plug.current_resource(conn)
    case Admin.reorder_forums(cat_id, ids) do
      {:ok, _} ->
        Admin.log_admin_action(user.id, %{
          action: "forum_reordered", category: "forums",
          target_type: "forum", description: "Reordered #{length(ids)} forums"
        })
        conn |> json(%{ok: true})
      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to reorder"})
    end
  end

  # What If Simulator
  def what_if(conn, %{"thresholds" => thresholds} = params) when is_list(thresholds) do
    days = parse_int(params, "days", 90)
    results = Admin.what_if_simulator(thresholds, days)
    conn |> json(%{results: results})
  end

  # Sentiment Trends
  def sentiment_trends(conn, params) do
    days = parse_int(params, "days", 30)
    data = Admin.sentiment_trends(days)
    conn |> json(%{sentiment: data})
  end

  # Smart Merge Suggestions
  def merge_suggestions(conn, params) do
    days = parse_int(params, "days", 7)
    data = Admin.smart_merge_suggestions(days)
    conn |> json(%{merge: data})
  end

  # Live Activity Feed
  def live_feed(conn, params) do
    limit = parse_int(params, "limit", 30) |> min(100)
    events = Admin.live_feed(limit)
    conn |> json(%{events: events})
  end

  # Today vs Yesterday Comparison
  def comparison(conn, _params) do
    data = Admin.today_vs_yesterday_comparison()
    conn |> json(%{comparison: data})
  end

  # Mod Queue Snapshot
  def mod_queue(conn, _params) do
    data = Admin.mod_queue_snapshot()
    conn |> json(%{mod_queue: data})
  end

  # New Member Spotlight
  def new_members(conn, _params) do
    members = Accounts.recent_registrations(5)
    conn |> json(%{members: Enum.map(members, &member_json/1)})
  end

  # JSON serializers

  defp audit_log_json(log) do
    %{
      id: log.id,
      action: log.action,
      category: log.category,
      target_type: log.target_type,
      target_id: log.target_id,
      description: log.description,
      previous_state: log.previous_state,
      new_state: log.new_state,
      is_rolled_back: log.is_rolled_back,
      rolled_back_at: log.rolled_back_at,
      admin: if(Ecto.assoc_loaded?(log.admin), do: user_mini(log.admin)),
      rolled_back_by: if(Ecto.assoc_loaded?(log.rolled_back_by), do: user_mini(log.rolled_back_by)),
      inserted_at: log.inserted_at
    }
  end

  defp user_mini(nil), do: nil
  defp user_mini(user), do: %{id: user.id, username: user.username, slug: user.slug, avatar_url: user.avatar_url}

  defp member_json(user) do
    %{
      id: user.id,
      username: user.username,
      slug: user.slug,
      avatar_url: user.avatar_url,
      username_color: user.username_color,
      username_effect: user.username_effect,
      inserted_at: user.inserted_at,
      post_count: user.post_count
    }
  end

  defp parse_int(params, key, default) do
    case Map.get(params, key) do
      nil -> default
      val when is_binary(val) -> safe_to_integer(val, default)
      val when is_integer(val) -> val
    end
  end

  # --- Innovative Features (19-28) ---

  def staff_performance(conn, params) do
    days = parse_int(params, "days", 30)
    data = Admin.staff_performance(days)
    conn |> json(%{staff: data})
  end

  def engagement_scores(conn, params) do
    limit = parse_int(params, "limit", 50)
    data = Admin.engagement_scores(limit: limit)
    conn |> json(%{users: data, config: Admin.engagement_config()})
  end

  def update_engagement_config(conn, %{"config" => cfg}) when is_map(cfg) do
    allowed = ~w(window_days weight_post cap_post weight_thread cap_thread weight_reputation cap_reputation recency_max tier_power tier_active tier_casual)

    updates =
      cfg
      |> Enum.filter(fn {k, _} -> to_string(k) in allowed end)
      |> Enum.map(fn {k, v} -> {"engagement_#{k}", to_string(v)} end)
      |> Map.new()

    ForgeNexus.Settings.set_many(updates)

    conn |> json(%{ok: true, config: Admin.engagement_config()})
  end

  def toxic_warning(conn, _params) do
    data = Admin.toxic_early_warning()
    conn |> json(%{users: data})
  end

  def content_quality(conn, params) do
    mode = Map.get(params, "mode", "best")
    limit = parse_int(params, "limit", 20)
    data = Admin.content_quality_report(mode: mode, limit: limit)
    conn |> json(%{posts: data})
  end

  def growth_forecast(conn, _params) do
    data = Admin.growth_forecast()
    conn |> json(%{forecast: data})
  end

  def lapsed_users(conn, params) do
    limit = parse_int(params, "limit", 50)
    data = Admin.lapsed_users(limit: limit)
    conn |> json(%{users: data})
  end

  def seo_health(conn, _params) do
    data = Admin.seo_health()
    conn |> json(%{seo: data})
  end

  def cleanup_preview(conn, _params) do
    data = Admin.cleanup_rules_preview()
    conn |> json(%{rules: data})
  end

  def run_cleanup(conn, %{"rule" => rule}) do
    result = Admin.run_cleanup(rule)
    conn |> json(%{result: result})
  end

  defp safe_to_integer(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> default
    end
  end
  defp safe_to_integer(val, _default) when is_integer(val), do: val
  defp safe_to_integer(_, default), do: default

end
