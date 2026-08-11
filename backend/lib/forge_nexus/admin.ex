defmodule ForgeNexus.Admin do
  @moduledoc """
  Context for the ForgeNexus admin panel.
  Contains analytics, audit trail, and admin operations.
  """

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Forums.{Forum, Category, Thread, Post}
  alias ForgeNexus.Moderation.{Report, Ban, ModerationLog}
  alias ForgeNexus.Plugins.{Flow, FlowExecution, JsPlugin, JsPluginExecution}
  alias ForgeNexus.Admin.AuditLog

  # =====================
  # 1. War Room Stats
  # =====================

  def war_room_stats do
    now = DateTime.utc_now()
    five_min_ago = DateTime.add(now, -300, :second)
    one_hour_ago = DateTime.add(now, -3600, :second)

    posts_5m =
      Repo.one(from p in Post, where: p.inserted_at >= ^five_min_ago, select: count(p.id)) || 0

    %{
      active_users:
        Repo.one(from u in User, where: u.is_online == true, select: count(u.id)) || 0,
      posts_per_minute: Float.round(posts_5m / 5, 1),
      posts_last_hour:
        Repo.one(from p in Post, where: p.inserted_at >= ^one_hour_ago, select: count(p.id)) || 0,
      open_reports:
        Repo.one(from r in Report, where: r.status in ["open", "assigned"], select: count(r.id)) ||
          0,
      active_bans: Repo.one(from b in Ban, where: b.is_active == true, select: count(b.id)) || 0,
      online_staff: count_online_staff(),
      total_users: Repo.one(from u in User, select: count(u.id)) || 0,
      total_threads: Repo.one(from t in Thread, select: count(t.id)) || 0,
      server_uptime_seconds: elem(:erlang.statistics(:wall_clock), 0) |> div(1000)
    }
  end

  defp count_online_staff do
    Repo.one(
      from u in User,
        join: gm in "user_group_memberships",
        on: gm.user_id == u.id,
        join: g in "user_groups",
        on: g.id == gm.group_id,
        where: u.is_online == true and g.is_staff == true,
        select: count(u.id, :distinct)
    ) || 0
  end

  # =====================
  # 2. Community Health Score
  # =====================

  def community_health_score do
    now = DateTime.utc_now()
    thirty_ago = DateTime.add(now, -30 * 86400, :second)
    sixty_ago = DateTime.add(now, -60 * 86400, :second)

    current = compute_health_metrics(thirty_ago, now)
    previous = compute_health_metrics(sixty_ago, thirty_ago)

    score = weighted_score(current)
    prev_score = weighted_score(previous)

    %{
      score: score,
      trend: score - prev_score,
      metrics: current,
      previous_metrics: previous
    }
  end

  defp compute_health_metrics(from, to) do
    total_new_users =
      Repo.one(
        from u in User, where: u.inserted_at >= ^from and u.inserted_at < ^to, select: count(u.id)
      ) || 0

    retained_users =
      if total_new_users > 0 do
        Repo.one(
          from u in User,
            where: u.inserted_at >= ^from and u.inserted_at < ^to and u.post_count > 0,
            select: count(u.id)
        ) || 0
      else
        0
      end

    total_threads =
      Repo.one(
        from t in Thread,
          where: t.inserted_at >= ^from and t.inserted_at < ^to,
          select: count(t.id)
      ) || 0

    threads_with_replies =
      Repo.one(
        from t in Thread,
          where: t.inserted_at >= ^from and t.inserted_at < ^to and t.reply_count >= 2,
          select: count(t.id)
      ) || 0

    total_posts =
      Repo.one(
        from p in Post, where: p.inserted_at >= ^from and p.inserted_at < ^to, select: count(p.id)
      ) || 0

    total_reports =
      Repo.one(
        from r in Report,
          where: r.inserted_at >= ^from and r.inserted_at < ^to,
          select: count(r.id)
      ) || 0

    total_users = Repo.one(from u in User, select: count(u.id)) || 1

    active_users =
      Repo.one(
        from u in User,
          where: u.last_post_at >= ^from and u.last_post_at < ^to,
          select: count(u.id)
      ) || 0

    %{
      new_user_retention:
        if(total_new_users > 0, do: retained_users / total_new_users, else: 0.5),
      post_reply_ratio:
        if(total_threads > 0, do: threads_with_replies / total_threads, else: 0.5),
      report_density:
        if(total_posts > 0, do: max(0, 1 - total_reports / max(total_posts, 1) * 100), else: 1.0),
      active_to_lurker: active_users / total_users,
      avg_reply_time_score: 0.7
    }
  end

  defp weighted_score(metrics) do
    raw =
      metrics.new_user_retention * 0.25 +
        metrics.post_reply_ratio * 0.25 +
        metrics.report_density * 0.20 +
        metrics.active_to_lurker * 0.15 +
        metrics.avg_reply_time_score * 0.15

    round(min(raw * 100, 100))
  end

  # =====================
  # 3. Content Decay Detection
  # =====================

  @suggestion_templates %{
    "creative" => [
      "Host a flash fiction contest (500 words max, themed)",
      "Start a weekly writing prompt thread",
      "Create a \"Share Your Work\" showcase sticky",
      "Organize a collaborative storytelling round-robin"
    ],
    "tech" => [
      "Launch a weekly coding challenge",
      "Create an AMA thread with a community expert",
      "Start a \"What are you working on?\" weekly thread",
      "Host a tool/library review series"
    ],
    "gaming" => [
      "Organize a community tournament",
      "Start a screenshot/clip of the week competition",
      "Create a \"What are you playing?\" weekly thread",
      "Host a community game night event"
    ],
    "art" => [
      "Host a themed art jam (48-hour challenge)",
      "Start a critique exchange thread",
      "Create a monthly art showcase spotlight",
      "Run a design battle bracket tournament"
    ],
    "music" => [
      "Start a weekly track feedback thread",
      "Host a remix/cover challenge",
      "Create a \"What are you listening to?\" thread",
      "Organize a collaborative playlist project"
    ],
    "general" => [
      "Create a thought-provoking discussion prompt",
      "Run a community poll on a trending topic",
      "Feature spotlight on active community members",
      "Start an \"Unpopular Opinions\" or debate thread",
      "Host a community Q&A or town hall"
    ]
  }

  @category_keywords %{
    "creative" => ~w(creative writing story stories fiction poetry poem author novel),
    "tech" => ~w(tech technology programming coding code developer software dev engineering),
    "gaming" => ~w(gaming game games gamer play esports mmo rpg fps),
    "art" => ~w(art design drawing illustration graphic paint sketch digital),
    "music" => ~w(music song audio beat producer dj remix track album)
  }

  def content_decay_report do
    now = DateTime.utc_now()
    thirty_ago = DateTime.add(now, -30 * 86400, :second)
    sixty_ago = DateTime.add(now, -60 * 86400, :second)

    forums =
      Repo.all(
        from f in Forum,
          join: c in Category,
          on: f.category_id == c.id,
          where: f.is_visible == true,
          preload: [],
          select: %{
            id: f.id,
            name: f.name,
            slug: f.slug,
            description: f.description,
            category_name: c.name,
            post_count: f.post_count
          }
      )

    Enum.map(forums, fn forum ->
      current =
        Repo.one(
          from t in Thread,
            where: t.forum_id == ^forum.id and t.inserted_at >= ^thirty_ago,
            select: count(t.id)
        ) || 0

      previous =
        Repo.one(
          from t in Thread,
            where:
              t.forum_id == ^forum.id and t.inserted_at >= ^sixty_ago and
                t.inserted_at < ^thirty_ago,
            select: count(t.id)
        ) || 0

      decline_pct = if previous > 0, do: round((1 - current / previous) * 100), else: 0

      %{
        forum_id: forum.id,
        forum_name: forum.name,
        forum_slug: forum.slug,
        category_name: forum.category_name,
        current_threads_30d: current,
        previous_threads_30d: previous,
        total_posts: forum.post_count,
        decline_pct: decline_pct,
        is_declining: decline_pct >= 50 and previous >= 3,
        suggestions:
          generate_suggestions(forum.name, forum.description || "", forum.category_name)
      }
    end)
    |> Enum.filter(& &1.is_declining)
    |> Enum.sort_by(& &1.decline_pct, :desc)
  end

  defp generate_suggestions(forum_name, description, category_name) do
    text = String.downcase("#{forum_name} #{description} #{category_name}")

    matched_category =
      Enum.find_value(@category_keywords, "general", fn {cat, keywords} ->
        if Enum.any?(keywords, &String.contains?(text, &1)), do: cat
      end)

    Map.get(@suggestion_templates, matched_category, @suggestion_templates["general"])
    |> Enum.take(3)
  end

  # =====================
  # 4. Admin Audit Trail
  # =====================

  def log_admin_action(admin_id, attrs) do
    %AuditLog{}
    |> AuditLog.changeset(Map.put(attrs, :admin_id, admin_id))
    |> Repo.insert()
  end

  def list_audit_logs(opts \\ []) do
    category = Keyword.get(opts, :category)
    action = Keyword.get(opts, :action)
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from l in AuditLog,
        order_by: [desc: :inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:admin, :rolled_back_by]

    query = if category, do: where(query, [l], l.category == ^category), else: query
    query = if action, do: where(query, [l], l.action == ^action), else: query

    Repo.all(query)
  end

  def rollback_action(audit_log_id, admin_id) do
    log = Repo.get!(AuditLog, audit_log_id)

    if log.is_rolled_back do
      {:error, "Already rolled back"}
    else
      case apply_rollback(log) do
        :ok ->
          log
          |> AuditLog.rollback_changeset(%{
            is_rolled_back: true,
            rolled_back_at: DateTime.utc_now(),
            rolled_back_by_id: admin_id
          })
          |> Repo.update()

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp apply_rollback(%{target_type: "forum", target_id: id, previous_state: prev})
       when map_size(prev) > 0 do
    forum = Repo.get(Forum, id)

    if forum do
      attrs =
        Map.take(prev, ["name", "description", "position", "is_visible", "is_locked"])
        |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)
        |> Map.new()

      case Repo.update(Forum.changeset(forum, attrs)) do
        {:ok, _} -> :ok
        {:error, _} -> {:error, "Failed to rollback forum change"}
      end
    else
      {:error, "Forum not found"}
    end
  end

  defp apply_rollback(%{target_type: "category", target_id: id, previous_state: prev})
       when map_size(prev) > 0 do
    category = Repo.get(Category, id)

    if category do
      attrs =
        Map.take(prev, ["name", "description", "position", "is_visible"])
        |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)
        |> Map.new()

      case Repo.update(Category.changeset(category, attrs)) do
        {:ok, _} -> :ok
        {:error, _} -> {:error, "Failed to rollback category change"}
      end
    else
      {:error, "Category not found"}
    end
  end

  defp apply_rollback(_), do: {:error, "Rollback not supported for this action type"}

  # =====================
  # 5. Registration Funnel
  # =====================

  def registration_funnel(days \\ 30) do
    window = DateTime.add(DateTime.utc_now(), -days * 86400, :second)

    total = Repo.one(from u in User, where: u.inserted_at >= ^window, select: count(u.id)) || 0

    first_post =
      Repo.one(
        from u in User, where: u.inserted_at >= ^window and u.post_count > 0, select: count(u.id)
      ) || 0

    active_7d =
      Repo.one(
        from u in User,
          where:
            u.inserted_at >= ^window and
              not is_nil(u.last_seen_at) and
              u.last_seen_at >= fragment("? + interval '7 days'", u.inserted_at),
          select: count(u.id)
      ) || 0

    active_30d =
      Repo.one(
        from u in User,
          where:
            u.inserted_at >= ^window and
              not is_nil(u.last_seen_at) and
              u.last_seen_at >= fragment("? + interval '30 days'", u.inserted_at),
          select: count(u.id)
      ) || 0

    %{
      total_registered: total,
      email_confirmed: total,
      first_post: first_post,
      active_7d: active_7d,
      active_30d: active_30d,
      days: days
    }
  end

  # =====================
  # 6. Forum Reordering
  # =====================

  def reorder_categories(ordered_ids) when is_list(ordered_ids) do
    Repo.transaction(fn ->
      Enum.with_index(ordered_ids, fn id, idx ->
        from(c in Category, where: c.id == ^id)
        |> Repo.update_all(set: [position: idx])
      end)
    end)
  end

  def reorder_forums(category_id, ordered_ids) when is_list(ordered_ids) do
    Repo.transaction(fn ->
      Enum.with_index(ordered_ids, fn id, idx ->
        from(f in Forum, where: f.id == ^id and f.category_id == ^category_id)
        |> Repo.update_all(set: [position: idx])
      end)
    end)
  end

  # =====================
  # 7. Plugin Impact Analytics
  # =====================

  def plugin_impact_stats do
    flow_stats =
      Repo.all(
        from e in FlowExecution,
          join: f in Flow,
          on: e.flow_id == f.id,
          group_by: [f.id, f.name, f.status],
          select: %{
            id: f.id,
            name: f.name,
            status: f.status,
            type: "flow",
            total: count(e.id),
            failures: fragment("count(*) filter (where ? = 'failed')", e.status),
            avg_duration: avg(e.duration_ms)
          }
      )

    js_stats =
      Repo.all(
        from e in JsPluginExecution,
          join: p in JsPlugin,
          on: e.js_plugin_id == p.id,
          group_by: [p.id, p.name, p.status],
          select: %{
            id: p.id,
            name: p.name,
            status: p.status,
            type: "js_plugin",
            total: count(e.id),
            failures: fragment("count(*) filter (where ? = 'failed')", e.status),
            avg_duration: avg(e.duration_ms)
          }
      )

    %{plugins: flow_stats ++ js_stats}
  end

  # =====================
  # 8. Admin Activity Heatmap
  # =====================

  def activity_heatmap(days \\ 90) do
    window = DateTime.add(DateTime.utc_now(), -days * 86400, :second)

    cells =
      Repo.all(
        from l in ModerationLog,
          where: l.inserted_at >= ^window,
          group_by: [
            fragment("EXTRACT(DOW FROM ?)::int", l.inserted_at),
            fragment("EXTRACT(HOUR FROM ?)::int", l.inserted_at)
          ],
          select: %{
            day: fragment("EXTRACT(DOW FROM ?)::int", l.inserted_at),
            hour: fragment("EXTRACT(HOUR FROM ?)::int", l.inserted_at),
            count: count(l.id)
          }
      )

    %{cells: cells, days: days}
  end

  # =====================
  # 9. What If Simulator (B1)
  # =====================

  def what_if_simulator(thresholds, days \\ 90) do
    alias ForgeNexus.Moderation.Warning
    window = DateTime.add(DateTime.utc_now(), -days * 86400, :second)

    # Get all users with active warning points in the window
    user_points =
      Repo.all(
        from w in Warning,
          where: w.is_active == true and w.inserted_at >= ^window,
          group_by: [w.user_id],
          select: %{user_id: w.user_id, total_points: sum(w.points)}
      )

    # For each threshold, find users who would cross it
    Enum.map(thresholds, fn %{"points" => pts, "sanction" => sanction} ->
      affected = Enum.filter(user_points, fn %{total_points: tp} -> tp >= pts end)
      user_ids = Enum.map(affected, & &1.user_id)

      users =
        if user_ids != [] do
          Repo.all(
            from u in User,
              where: u.id in ^user_ids,
              select: %{id: u.id, username: u.username, status: u.status, is_online: u.is_online}
          )
        else
          []
        end

      %{
        threshold_points: pts,
        sanction: sanction,
        affected_count: length(users),
        currently_active: Enum.count(users, &(&1.status == "active")),
        users: Enum.take(users, 20)
      }
    end)
  end

  # =====================
  # 10. User Journey (B2)
  # =====================

  def user_journey(user_id) do
    alias ForgeNexus.Moderation.{Warning, Ban}

    user = Repo.get!(User, user_id)

    events = []

    # Registration
    events = [
      %{type: "registration", at: user.inserted_at, description: "Joined the community"} | events
    ]

    # First post
    first_post =
      Repo.one(
        from p in Post,
          where: p.user_id == ^user_id,
          order_by: [asc: :inserted_at],
          limit: 1,
          select: %{at: p.inserted_at, thread_id: p.thread_id}
      )

    events =
      if first_post,
        do: [
          %{type: "first_post", at: first_post.at, description: "Made their first post"} | events
        ],
        else: events

    # Post milestones
    for milestone <- [10, 50, 100, 250, 500, 1000, 5000] do
      if user.post_count >= milestone do
        # Approximate the date of the milestone post
        nth_post =
          Repo.one(
            from p in Post,
              where: p.user_id == ^user_id,
              order_by: [asc: :inserted_at],
              offset: ^(milestone - 1),
              limit: 1,
              select: %{at: p.inserted_at}
          )

        if nth_post,
          do: %{type: "milestone", at: nth_post.at, description: "Reached #{milestone} posts"}
      end
    end
    |> Enum.filter(& &1)
    |> then(fn milestones -> events ++ milestones end)
    |> then(fn events ->
      # Warnings
      warnings =
        Repo.all(
          from w in Warning,
            where: w.user_id == ^user_id,
            order_by: [asc: :inserted_at],
            select: %{at: w.inserted_at, type: w.type, reason: w.reason, points: w.points}
        )

      warning_events =
        Enum.map(warnings, fn w ->
          %{
            type: "warning",
            at: w.at,
            description: "#{w.type} warning (#{w.points}pts): #{w.reason}"
          }
        end)

      # Bans
      bans =
        Repo.all(
          from b in Ban,
            where: b.user_id == ^user_id,
            order_by: [asc: :inserted_at],
            select: %{at: b.inserted_at, ban_type: b.type, reason: b.reason}
        )

      ban_events =
        Enum.map(bans, fn b ->
          %{type: "ban", at: b.at, description: "#{b.ban_type} ban: #{b.reason}"}
        end)

      # Group changes from mod logs
      group_changes =
        Repo.all(
          from l in ModerationLog,
            where:
              l.target_type == "user" and l.target_id == ^user_id and
                l.action in ["add_to_group", "remove_from_group", "promote", "demote"],
            order_by: [asc: :inserted_at],
            select: %{at: l.inserted_at, action: l.action, metadata: l.metadata}
        )

      group_events =
        Enum.map(group_changes, fn l ->
          %{type: "group_change", at: l.at, description: "#{l.action}: #{inspect(l.metadata)}"}
        end)

      (events ++ warning_events ++ ban_events ++ group_events)
      |> Enum.sort_by(fn ev -> to_naive(ev.at) end, NaiveDateTime)
    end)
  end

  defp to_naive(%DateTime{} = dt), do: DateTime.to_naive(dt)
  defp to_naive(%NaiveDateTime{} = ndt), do: ndt
  defp to_naive(nil), do: ~N[1970-01-01 00:00:00]

  # =====================
  # 11. Sentiment Trends (B3)
  # =====================

  @positive_words ~w(great awesome amazing good love excellent wonderful fantastic perfect helpful thanks appreciate happy glad beautiful best nice cool excited)
  @negative_words ~w(terrible awful horrible bad hate worst disgusting pathetic broken useless annoying frustrating disappointed angry stupid toxic trash garbage)

  def sentiment_trends(days \\ 30) do
    window = DateTime.add(DateTime.utc_now(), -days * 86400, :second)

    posts =
      Repo.all(
        from p in Post,
          join: t in Thread,
          on: p.thread_id == t.id,
          where: p.inserted_at >= ^window,
          select: %{
            forum_id: t.forum_id,
            body: p.body,
            week: fragment("date_trunc('week', ?)", p.inserted_at)
          }
      )

    # Score each post
    scored =
      Enum.map(posts, fn p ->
        words = p.body |> String.downcase() |> String.split(~r/\W+/, trim: true)
        pos = Enum.count(words, &(&1 in @positive_words))
        neg = Enum.count(words, &(&1 in @negative_words))

        score =
          cond do
            pos > neg -> 1
            neg > pos -> -1
            true -> 0
          end

        Map.put(p, :score, score)
      end)

    # Group by forum_id and week
    grouped =
      scored
      |> Enum.group_by(fn p -> {p.forum_id, p.week} end)
      |> Enum.map(fn {{forum_id, week}, posts} ->
        total = length(posts)
        avg_score = Enum.sum(Enum.map(posts, & &1.score)) / max(total, 1)
        %{forum_id: forum_id, week: week, avg_score: Float.round(avg_score, 2), post_count: total}
      end)
      |> Enum.sort_by(fn p -> {p.forum_id, p.week} end)

    # Get forum names
    forum_ids = grouped |> Enum.map(& &1.forum_id) |> Enum.uniq()

    forum_names =
      if forum_ids != [] do
        Repo.all(from f in Forum, where: f.id in ^forum_ids, select: {f.id, f.name}) |> Map.new()
      else
        %{}
      end

    %{trends: grouped, forum_names: forum_names}
  end

  # =====================
  # 12. Smart Merge Suggestions (B4)
  # =====================

  def smart_merge_suggestions(days \\ 7) do
    window = DateTime.add(DateTime.utc_now(), -days * 86400, :second)

    # Use pg_trgm similarity to find similar thread titles
    results =
      Repo.query!(
        """
          SELECT t1.id AS id1, t1.title AS title1, t1.forum_id AS forum_id1,
                 t2.id AS id2, t2.title AS title2, t2.forum_id AS forum_id2,
                 similarity(t1.title, t2.title) AS score
          FROM threads t1
          JOIN threads t2 ON t1.id < t2.id
          WHERE t1.inserted_at >= $1
            AND t2.inserted_at >= $1
            AND t1.forum_id = t2.forum_id
            AND similarity(t1.title, t2.title) > 0.35
            AND t1.is_hidden = false
            AND t2.is_hidden = false
          ORDER BY score DESC
          LIMIT 20
        """,
        [window]
      )

    suggestions =
      Enum.map(results.rows, fn [id1, title1, fid1, id2, title2, fid2, score] ->
        %{
          thread_1: %{id: cast_uuid(id1), title: title1, forum_id: cast_uuid(fid1)},
          thread_2: %{id: cast_uuid(id2), title: title2, forum_id: cast_uuid(fid2)},
          similarity: Float.round(score, 2)
        }
      end)

    %{suggestions: suggestions}
  end

  defp cast_uuid(nil), do: nil

  defp cast_uuid(<<_::binary-size(16)>> = bin) do
    case Ecto.UUID.cast(bin) do
      {:ok, str} -> str
      :error -> nil
    end
  end

  defp cast_uuid(other) when is_binary(other), do: other
  defp cast_uuid(_), do: nil

  # =====================
  # 13. Live Activity Feed
  # =====================

  def live_feed(limit \\ 30) do
    # Recent posts
    recent_posts =
      Repo.all(
        from p in Post,
          join: u in User,
          on: p.user_id == u.id,
          join: t in Thread,
          on: p.thread_id == t.id,
          join: f in Forum,
          on: t.forum_id == f.id,
          where: p.is_hidden == false,
          order_by: [desc: p.inserted_at],
          limit: ^limit,
          select: %{
            type: "post",
            description: fragment("? || ' posted in ' || ?", u.username, t.title),
            user: %{
              username: u.username,
              slug: u.slug,
              avatar_url: u.avatar_url,
              username_color: u.username_color
            },
            link: %{thread_slug: t.slug, forum_slug: f.slug},
            inserted_at: p.inserted_at
          }
      )

    # Recent threads
    recent_threads =
      Repo.all(
        from t in Thread,
          join: u in User,
          on: t.user_id == u.id,
          join: f in Forum,
          on: t.forum_id == f.id,
          where: t.is_hidden == false,
          order_by: [desc: t.inserted_at],
          limit: ^limit,
          select: %{
            type: "thread",
            description: fragment("? || ' created thread: ' || ?", u.username, t.title),
            user: %{
              username: u.username,
              slug: u.slug,
              avatar_url: u.avatar_url,
              username_color: u.username_color
            },
            link: %{thread_slug: t.slug, forum_slug: f.slug},
            inserted_at: t.inserted_at
          }
      )

    # Recent registrations
    recent_registrations =
      Repo.all(
        from u in User,
          order_by: [desc: u.inserted_at],
          limit: ^limit,
          select: %{
            type: "registration",
            description: fragment("? || ' joined the community'", u.username),
            user: %{
              username: u.username,
              slug: u.slug,
              avatar_url: u.avatar_url,
              username_color: u.username_color
            },
            link: %{user_slug: u.slug},
            inserted_at: u.inserted_at
          }
      )

    # Recent mod actions
    recent_mod_actions =
      Repo.all(
        from l in ModerationLog,
          join: u in User,
          on: l.moderator_id == u.id,
          order_by: [desc: l.inserted_at],
          limit: ^limit,
          select: %{
            type: "mod_action",
            description:
              fragment(
                "? || ' performed ' || ? || ' on ' || ?",
                u.username,
                l.action,
                l.target_type
              ),
            user: %{
              username: u.username,
              slug: u.slug,
              avatar_url: u.avatar_url,
              username_color: u.username_color
            },
            link: %{target_type: l.target_type, target_id: l.target_id},
            inserted_at: l.inserted_at
          }
      )

    # Recent reports
    recent_reports =
      Repo.all(
        from r in Report,
          join: u in User,
          on: r.reporter_id == u.id,
          order_by: [desc: r.inserted_at],
          limit: ^limit,
          select: %{
            type: "report",
            description:
              fragment(
                "? || ' reported a ' || ? || ': ' || ?",
                u.username,
                r.reportable_type,
                r.reason
              ),
            user: %{
              username: u.username,
              slug: u.slug,
              avatar_url: u.avatar_url,
              username_color: u.username_color
            },
            link: %{reportable_type: r.reportable_type, reportable_id: r.reportable_id},
            inserted_at: r.inserted_at
          }
      )

    # Merge all events, sort by timestamp desc, take limit.
    # Schemas mix :utc_datetime and :naive_datetime — normalize before comparing.
    (recent_posts ++
       recent_threads ++ recent_registrations ++ recent_mod_actions ++ recent_reports)
    |> Enum.sort_by(&live_feed_sort_key/1, :desc)
    |> Enum.take(limit)
  end

  defp live_feed_sort_key(%{inserted_at: %DateTime{} = dt}),
    do: DateTime.to_unix(dt, :microsecond)

  defp live_feed_sort_key(%{inserted_at: %NaiveDateTime{} = ndt}),
    do: ndt |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(:microsecond)

  defp live_feed_sort_key(_), do: 0

  # =====================
  # 14. Today vs Yesterday Comparison
  # =====================

  def today_vs_yesterday_comparison do
    today = Date.utc_today()
    yesterday = Date.add(today, -1)
    today_start = DateTime.new!(today, ~T[00:00:00], "Etc/UTC")
    yesterday_start = DateTime.new!(yesterday, ~T[00:00:00], "Etc/UTC")

    posts_today =
      Repo.one(from p in Post, where: p.inserted_at >= ^today_start, select: count(p.id)) || 0

    posts_yesterday =
      Repo.one(
        from p in Post,
          where: p.inserted_at >= ^yesterday_start and p.inserted_at < ^today_start,
          select: count(p.id)
      ) || 0

    threads_today =
      Repo.one(from t in Thread, where: t.inserted_at >= ^today_start, select: count(t.id)) || 0

    threads_yesterday =
      Repo.one(
        from t in Thread,
          where: t.inserted_at >= ^yesterday_start and t.inserted_at < ^today_start,
          select: count(t.id)
      ) || 0

    registrations_today =
      Repo.one(from u in User, where: u.inserted_at >= ^today_start, select: count(u.id)) || 0

    registrations_yesterday =
      Repo.one(
        from u in User,
          where: u.inserted_at >= ^yesterday_start and u.inserted_at < ^today_start,
          select: count(u.id)
      ) || 0

    reports_today =
      Repo.one(from r in Report, where: r.inserted_at >= ^today_start, select: count(r.id)) || 0

    reports_yesterday =
      Repo.one(
        from r in Report,
          where: r.inserted_at >= ^yesterday_start and r.inserted_at < ^today_start,
          select: count(r.id)
      ) || 0

    active_users_today =
      Repo.one(
        from p in Post, where: p.inserted_at >= ^today_start, select: count(p.user_id, :distinct)
      ) || 0

    active_users_yesterday =
      Repo.one(
        from p in Post,
          where: p.inserted_at >= ^yesterday_start and p.inserted_at < ^today_start,
          select: count(p.user_id, :distinct)
      ) || 0

    %{
      posts: change_stat(posts_today, posts_yesterday),
      threads: change_stat(threads_today, threads_yesterday),
      registrations: change_stat(registrations_today, registrations_yesterday),
      reports: change_stat(reports_today, reports_yesterday),
      active_users: change_stat(active_users_today, active_users_yesterday)
    }
  end

  defp change_stat(today_val, yesterday_val) do
    change_pct =
      if yesterday_val > 0,
        do: Float.round((today_val - yesterday_val) / yesterday_val * 100, 1),
        else: 0.0

    %{today: today_val, yesterday: yesterday_val, change_pct: change_pct}
  end

  # =====================
  # 15. Mod Queue Snapshot
  # =====================

  def mod_queue_snapshot do
    alias ForgeNexus.Moderation.Appeal

    open_reports = Repo.one(from r in Report, where: r.status == "open", select: count(r.id)) || 0

    pending_appeals =
      Repo.one(from a in Appeal, where: a.status == "pending", select: count(a.id)) || 0

    oldest_report =
      Repo.one(
        from r in Report,
          where: r.status in ["open", "assigned"],
          order_by: [asc: r.inserted_at],
          limit: 1,
          select: r.inserted_at
      )

    oldest_report_age_minutes =
      case oldest_report do
        nil -> nil
        ts -> DateTime.diff(DateTime.utc_now(), ts, :second) |> div(60)
      end

    assigned_unresolved =
      Repo.one(
        from r in Report,
          where: r.status == "assigned" and not is_nil(r.assigned_to_id),
          select: count(r.id)
      ) || 0

    %{
      open_reports: open_reports,
      pending_appeals: pending_appeals,
      oldest_report_age_minutes: oldest_report_age_minutes,
      assigned_unresolved: assigned_unresolved
    }
  end

  # =====================
  # 16. Announcements CRUD
  # =====================

  alias ForgeNexus.Admin.Announcement

  def list_announcements do
    Repo.all(
      from a in Announcement,
        order_by: [desc: :priority, desc: :inserted_at],
        preload: [:created_by]
    )
  end

  def get_active_announcements do
    now = DateTime.utc_now()

    Repo.all(
      from a in Announcement,
        where: a.is_active == true,
        where: is_nil(a.starts_at) or a.starts_at <= ^now,
        where: is_nil(a.ends_at) or a.ends_at > ^now,
        order_by: [desc: :priority],
        preload: [:created_by]
    )
  end

  # =====================
  # 19. Staff Performance
  # =====================

  def staff_performance(days \\ 30) do
    since =
      DateTime.utc_now() |> DateTime.add(-days * 86400, :second) |> DateTime.truncate(:second)

    # Get all staff users (membership in any group flagged is_staff)
    staff_ids =
      from(u in User,
        join: gm in "user_group_memberships",
        on: gm.user_id == u.id,
        join: g in "user_groups",
        on: g.id == gm.group_id,
        where: g.is_staff == true,
        distinct: u.id,
        select: u.id
      )
      |> Repo.all()

    Enum.map(staff_ids, fn staff_id ->
      user = Repo.get(User, staff_id)

      # Reports resolved
      reports_resolved =
        from(r in Report,
          where: r.resolver_id == ^staff_id and r.updated_at >= ^since,
          select: count(r.id)
        )
        |> Repo.one() || 0

      # Mod actions taken
      mod_actions =
        from(l in ModerationLog,
          where: l.moderator_id == ^staff_id and l.inserted_at >= ^since,
          select: count(l.id)
        )
        |> Repo.one() || 0

      # Bans issued
      bans_issued =
        from(b in Ban,
          where: b.banned_by_id == ^staff_id and b.inserted_at >= ^since,
          select: count(b.id)
        )
        |> Repo.one() || 0

      # Average report response time (in minutes)
      avg_response =
        from(r in Report,
          where:
            r.resolver_id == ^staff_id and r.updated_at >= ^since and not is_nil(r.resolved_at),
          select: fragment("AVG(EXTRACT(EPOCH FROM (? - ?)) / 60)", r.resolved_at, r.inserted_at)
        )
        |> Repo.one()

      # Most active hours (top 3)
      active_hours =
        from(l in ModerationLog,
          where: l.moderator_id == ^staff_id and l.inserted_at >= ^since,
          group_by: fragment("EXTRACT(HOUR FROM ?)", l.inserted_at),
          select: {fragment("EXTRACT(HOUR FROM ?)::integer", l.inserted_at), count(l.id)},
          order_by: [desc: 2],
          limit: 3
        )
        |> Repo.all()

      %{
        user_id: staff_id,
        username: user && user.username,
        avatar_url: user && user.avatar_url,
        reports_resolved: reports_resolved,
        mod_actions: mod_actions,
        bans_issued: bans_issued,
        avg_response_minutes: avg_response && Float.round(avg_response / 1.0, 1),
        active_hours: Enum.map(active_hours, fn {hour, count} -> %{hour: hour, count: count} end),
        efficiency_score: reports_resolved + mod_actions * 2
      }
    end)
    |> Enum.sort_by(fn s -> -s.efficiency_score end)
  end

  # =====================
  # 20. Engagement Scoring
  # =====================

  def engagement_scores(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    cfg = engagement_config()

    since =
      DateTime.utc_now()
      |> DateTime.add(-cfg.window_days * 86400, :second)
      |> DateTime.truncate(:second)

    users =
      from(u in User,
        where: u.inserted_at <= ^since or u.post_count > 0,
        order_by: [desc: :post_count],
        limit: ^limit,
        select: %{
          id: u.id,
          username: u.username,
          avatar_url: u.avatar_url,
          post_count: u.post_count,
          thread_count: u.thread_count,
          reputation: u.reputation,
          inserted_at: u.inserted_at,
          last_seen_at: u.last_seen_at
        }
      )
      |> Repo.all()

    Enum.map(users, fn user ->
      recent_posts =
        from(p in Post,
          where: p.user_id == ^user.id and p.inserted_at >= ^since,
          select: count(p.id)
        )
        |> Repo.one() || 0

      recent_threads =
        from(t in Thread,
          where: t.user_id == ^user.id and t.inserted_at >= ^since,
          select: count(t.id)
        )
        |> Repo.one() || 0

      days_inactive =
        if user.last_seen_at do
          (DateTime.diff(DateTime.utc_now(), user.last_seen_at, :second) / 86400) |> round()
        else
          999
        end

      post_score = min(recent_posts * cfg.weight_post, cfg.cap_post)
      thread_score = min(recent_threads * cfg.weight_thread, cfg.cap_thread)
      reputation_score = min(user.reputation * cfg.weight_reputation, cfg.cap_reputation)
      recency_score = max(0, cfg.recency_max - days_inactive)

      score = min(post_score + thread_score + reputation_score + recency_score, 100)

      tier =
        cond do
          score >= cfg.tier_power -> "power_user"
          score >= cfg.tier_active -> "active"
          score >= cfg.tier_casual -> "casual"
          score > 0 -> "lurker"
          true -> "inactive"
        end

      Map.merge(user, %{
        engagement_score: score,
        tier: tier,
        recent_posts: recent_posts,
        recent_threads: recent_threads,
        days_inactive: days_inactive
      })
    end)
    |> Enum.sort_by(fn u -> -u.engagement_score end)
  end

  @doc "Engagement scoring configuration (read from Settings with hardcoded fallbacks)."
  def engagement_config do
    %{
      window_days: engagement_int("engagement_window_days", 30),
      weight_post: engagement_int("engagement_weight_post", 3),
      cap_post: engagement_int("engagement_cap_post", 30),
      weight_thread: engagement_int("engagement_weight_thread", 5),
      cap_thread: engagement_int("engagement_cap_thread", 20),
      weight_reputation: engagement_int("engagement_weight_reputation", 1),
      cap_reputation: engagement_int("engagement_cap_reputation", 20),
      recency_max: engagement_int("engagement_recency_max", 30),
      tier_power: engagement_int("engagement_tier_power", 80),
      tier_active: engagement_int("engagement_tier_active", 50),
      tier_casual: engagement_int("engagement_tier_casual", 20)
    }
  end

  defp engagement_int(key, default) do
    case ForgeNexus.Settings.get_int(key) do
      n when is_integer(n) and n >= 0 -> n
      _ -> default
    end
  end

  # =====================
  # 21. Toxic User Early Warning
  # =====================

  def toxic_early_warning do
    since = DateTime.utc_now() |> DateTime.add(-30 * 86400, :second) |> DateTime.truncate(:second)

    # Users with recent reports against them — Report has no reported_user_id;
    # derive the offender from the reportable polymorphic target.
    # - reportable_type "user": the offender IS the reportable_id
    # - reportable_type "post": offender is posts.user_id
    # - reportable_type "thread": offender is threads.user_id
    direct_user_reports =
      from(r in Report,
        where:
          r.inserted_at >= ^since and r.status != "dismissed" and r.reportable_type == "user",
        select: {r.reportable_id, r.id}
      )
      |> Repo.all()

    post_target_reports =
      from(r in Report,
        join: p in Post,
        on: p.id == r.reportable_id,
        where:
          r.inserted_at >= ^since and r.status != "dismissed" and r.reportable_type == "post",
        select: {p.user_id, r.id}
      )
      |> Repo.all()

    thread_target_reports =
      from(r in Report,
        join: t in Thread,
        on: t.id == r.reportable_id,
        where:
          r.inserted_at >= ^since and r.status != "dismissed" and r.reportable_type == "thread",
        select: {t.user_id, r.id}
      )
      |> Repo.all()

    reported_users =
      (direct_user_reports ++ post_target_reports ++ thread_target_reports)
      |> Enum.group_by(fn {uid, _} -> uid end, fn {_, rid} -> rid end)
      |> Enum.into(%{}, fn {uid, ids} -> {uid, length(ids)} end)
      |> Enum.filter(fn {_, n} -> n >= 2 end)
      |> Map.new()

    # Users with recent warnings
    warned_users =
      from(w in ForgeNexus.Moderation.Warning,
        where: w.inserted_at >= ^since,
        group_by: w.user_id,
        select: {w.user_id, count(w.id)}
      )
      |> Repo.all()
      |> Map.new()

    # Combine and score
    all_ids =
      MapSet.union(MapSet.new(Map.keys(reported_users)), MapSet.new(Map.keys(warned_users)))

    all_ids
    |> Enum.map(fn user_id ->
      user = Repo.get(User, user_id)
      report_count = Map.get(reported_users, user_id, 0)
      warning_count = Map.get(warned_users, user_id, 0)

      # Check if user has active ban
      active_ban =
        Repo.one(from b in Ban, where: b.user_id == ^user_id and b.is_active == true, limit: 1)

      # Toxicity score: weighted sum
      toxicity = report_count * 10 + warning_count * 25

      risk =
        cond do
          toxicity >= 80 -> "critical"
          toxicity >= 50 -> "high"
          toxicity >= 25 -> "medium"
          true -> "low"
        end

      %{
        user_id: user_id,
        username: user && user.username,
        avatar_url: user && user.avatar_url,
        report_count: report_count,
        warning_count: warning_count,
        has_active_ban: active_ban != nil,
        toxicity_score: toxicity,
        risk_level: risk
      }
    end)
    |> Enum.filter(fn u -> u.toxicity_score >= 20 end)
    |> Enum.sort_by(fn u -> -u.toxicity_score end)
    |> Enum.take(25)
  end

  # =====================
  # 22. Content Quality Scoring
  # =====================

  def content_quality_report(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    mode = Keyword.get(opts, :mode, "best")
    since = DateTime.utc_now() |> DateTime.add(-30 * 86400, :second) |> DateTime.truncate(:second)

    posts =
      from(p in Post,
        where: p.inserted_at >= ^since and p.is_hidden != true,
        preload: [:user, :thread],
        limit: 200
      )
      |> Repo.all()

    scored =
      Enum.map(posts, fn post ->
        body = post.body || ""
        length_score = min(String.length(body) / 10, 25) |> round()

        has_formatting =
          if String.contains?(body, ["[b]", "[i]", "[url", "[img", "[code", "**", "```"]),
            do: 10,
            else: 0

        # Reply count for the thread
        thread_replies = if post.thread, do: post.thread.reply_count || 0, else: 0
        engagement_score = min(thread_replies * 2, 25)

        # Reports against this post
        report_count =
          Repo.one(
            from r in Report,
              where: r.reportable_type == "post" and r.reportable_id == ^post.id,
              select: count(r.id)
          ) || 0

        report_penalty = report_count * -15

        quality =
          max(0, min(length_score + has_formatting + engagement_score + report_penalty, 100))

        %{
          post_id: post.id,
          body_preview: String.slice(body, 0, 150),
          quality_score: quality,
          length: String.length(body),
          has_formatting: has_formatting > 0,
          thread_title: post.thread && post.thread.title,
          report_count: report_count,
          user: post.user && %{id: post.user.id, username: post.user.username},
          inserted_at: post.inserted_at
        }
      end)

    case mode do
      "worst" -> Enum.sort_by(scored, fn p -> p.quality_score end) |> Enum.take(limit)
      _ -> Enum.sort_by(scored, fn p -> -p.quality_score end) |> Enum.take(limit)
    end
  end

  # =====================
  # 23. Growth Forecasting
  # =====================

  def growth_forecast do
    # Get weekly data points for last 12 weeks
    now = DateTime.utc_now()

    weeks =
      for i <- 11..0//-1 do
        week_start =
          DateTime.add(now, -(i + 1) * 7 * 86400, :second) |> DateTime.truncate(:second)

        week_end = DateTime.add(now, -i * 7 * 86400, :second) |> DateTime.truncate(:second)

        registrations =
          Repo.one(
            from u in User,
              where: u.inserted_at >= ^week_start and u.inserted_at < ^week_end,
              select: count(u.id)
          ) || 0

        posts =
          Repo.one(
            from p in Post,
              where: p.inserted_at >= ^week_start and p.inserted_at < ^week_end,
              select: count(p.id)
          ) || 0

        threads =
          Repo.one(
            from t in Thread,
              where: t.inserted_at >= ^week_start and t.inserted_at < ^week_end,
              select: count(t.id)
          ) || 0

        %{
          week: 12 - i,
          registrations: registrations,
          posts: posts,
          threads: threads,
          date: DateTime.to_date(week_start)
        }
      end

    # Simple linear regression for projections
    reg_values = Enum.map(weeks, fn w -> w.registrations end)
    post_values = Enum.map(weeks, fn w -> w.posts end)

    %{
      weekly_data: weeks,
      projections: %{
        registrations_30d: project_sum(reg_values, 4),
        registrations_60d: project_sum(reg_values, 8),
        registrations_90d: project_sum(reg_values, 12),
        posts_30d: project_sum(post_values, 4),
        posts_60d: project_sum(post_values, 8),
        posts_90d: project_sum(post_values, 12)
      },
      total_users: Repo.one(from u in User, select: count(u.id)) || 0,
      total_posts: Repo.one(from p in Post, select: count(p.id)) || 0,
      trend: trend_direction(reg_values)
    }
  end

  defp project_sum(values, weeks_ahead) do
    n = length(values)

    if n < 2 do
      0
    else
      avg = Enum.sum(values) / n
      # Simple trend: compare last half to first half
      first_half = Enum.take(values, div(n, 2)) |> Enum.sum() |> Kernel./(max(div(n, 2), 1))
      second_half = Enum.drop(values, div(n, 2)) |> Enum.sum() |> Kernel./(max(n - div(n, 2), 1))
      growth_rate = if first_half > 0, do: (second_half - first_half) / first_half, else: 0

      projected_weekly = avg * (1 + growth_rate)
      round(projected_weekly * weeks_ahead)
    end
  end

  defp trend_direction(values) do
    n = length(values)

    if n < 4 do
      "stable"
    else
      recent = Enum.take(values, -4) |> Enum.sum()
      earlier = Enum.take(values, 4) |> Enum.sum()

      cond do
        recent > earlier * 1.2 -> "growing"
        recent < earlier * 0.8 -> "declining"
        true -> "stable"
      end
    end
  end

  # =====================
  # 24. Re-engagement Campaigns
  # =====================

  def lapsed_users(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    min_posts = Keyword.get(opts, :min_posts, 5)

    # Active 30-90 days ago, not seen in last 14 days
    active_start =
      DateTime.utc_now() |> DateTime.add(-90 * 86400, :second) |> DateTime.truncate(:second)

    active_end =
      DateTime.utc_now() |> DateTime.add(-14 * 86400, :second) |> DateTime.truncate(:second)

    from(u in User,
      where: u.post_count >= ^min_posts,
      where: u.last_seen_at >= ^active_start and u.last_seen_at <= ^active_end,
      where: u.status != "banned",
      order_by: [desc: :post_count],
      limit: ^limit,
      select: %{
        id: u.id,
        username: u.username,
        avatar_url: u.avatar_url,
        post_count: u.post_count,
        reputation: u.reputation,
        last_seen_at: u.last_seen_at,
        inserted_at: u.inserted_at
      }
    )
    |> Repo.all()
    |> Enum.map(fn user ->
      days_gone =
        (DateTime.diff(DateTime.utc_now(), user.last_seen_at, :second) / 86400) |> round()

      Map.put(user, :days_inactive, days_gone)
    end)
  end

  # =====================
  # 25. SEO Health Monitor
  # =====================

  def seo_health do
    # Forum activity scores
    forums_data =
      from(f in Forum,
        left_join: t in Thread,
        on: t.forum_id == f.id,
        group_by: [f.id, f.name, f.slug],
        select: %{
          id: f.id,
          name: f.name,
          slug: f.slug,
          thread_count: count(t.id),
          recent_threads:
            fragment("COUNT(CASE WHEN ? >= NOW() - INTERVAL '30 days' THEN 1 END)", t.inserted_at)
        },
        order_by: [desc: 3]
      )
      |> Repo.all()

    # Threads with most potential (long titles, good content, no replies)
    underperforming =
      from(t in Thread,
        where: t.reply_count == 0 and t.inserted_at >= ago(30, "day"),
        order_by: [desc: :view_count],
        limit: 10,
        preload: [:forum, :user],
        select_merge: %{}
      )
      |> Repo.all()

    # Top threads by view count
    top_threads =
      from(t in Thread,
        order_by: [desc: :view_count],
        limit: 10,
        preload: [:forum]
      )
      |> Repo.all()

    # Dead categories (no threads in 60 days)
    _sixty_days_ago =
      DateTime.utc_now() |> DateTime.add(-60 * 86400, :second) |> DateTime.truncate(:second)

    dead_forums = Enum.filter(forums_data, fn f -> f.recent_threads == 0 end)

    %{
      forums: forums_data,
      dead_forums: dead_forums,
      underperforming_threads:
        Enum.map(underperforming, fn t ->
          %{
            id: t.id,
            title: t.title,
            slug: t.slug,
            view_count: t.view_count,
            forum_name: t.forum && t.forum.name,
            user: t.user && t.user.username,
            suggestion: suggest_title_improvement(t.title)
          }
        end),
      top_threads:
        Enum.map(top_threads, fn t ->
          %{
            id: t.id,
            title: t.title,
            slug: t.slug,
            view_count: t.view_count,
            reply_count: t.reply_count,
            forum_name: t.forum && t.forum.name
          }
        end),
      overall_score: calculate_seo_score(forums_data, dead_forums)
    }
  end

  defp suggest_title_improvement(title) when is_binary(title) do
    cond do
      String.length(title) < 20 -> "Title is too short. Add more descriptive keywords."
      String.length(title) > 100 -> "Title is too long. Keep under 60 chars for SEO."
      String.downcase(title) == title -> "Consider capitalizing key words."
      not String.contains?(title, "?") and not String.contains?(title, "how") -> nil
      true -> nil
    end
  end

  defp suggest_title_improvement(_), do: nil

  defp calculate_seo_score(forums, dead_forums) do
    total = length(forums)

    if total == 0 do
      0
    else
      active_ratio = (total - length(dead_forums)) / total * 100
      round(active_ratio)
    end
  end

  # =====================
  # 27. Automated Cleanup Rules
  # =====================

  def run_cleanup(rule) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case rule do
      "prune_unverified" ->
        threshold = DateTime.add(now, -30 * 86400, :second)

        {count, _} =
          from(u in User, where: u.status == "unverified" and u.inserted_at < ^threshold)
          |> Repo.delete_all()

        %{rule: rule, affected: count}

      "archive_stale_threads" ->
        threshold = DateTime.add(now, -180 * 86400, :second)

        {count, _} =
          from(t in Thread,
            where: t.reply_count == 0 and t.inserted_at < ^threshold and t.is_locked != true
          )
          |> Repo.update_all(set: [is_locked: true])

        %{rule: rule, affected: count}

      "prune_old_notifications" ->
        threshold = DateTime.add(now, -90 * 86400, :second)

        {count, _} =
          from(n in ForgeNexus.Chat.Notification,
            where: n.is_read == true and n.inserted_at < ^threshold
          )
          |> Repo.delete_all()

        %{rule: rule, affected: count}

      "prune_old_sessions" ->
        threshold = DateTime.add(now, -30 * 86400, :second)

        {count, _} =
          from(u in User,
            where: u.last_seen_at < ^threshold and u.is_online == true
          )
          |> Repo.update_all(set: [is_online: false])

        %{rule: rule, affected: count}

      _ ->
        %{rule: rule, affected: 0, error: "Unknown rule"}
    end
  end

  def cleanup_rules_preview do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    [
      %{
        id: "prune_unverified",
        name: "Prune Unverified Accounts",
        description: "Delete accounts unverified for 30+ days",
        affected:
          Repo.one(
            from u in User,
              where:
                u.status == "unverified" and
                  u.inserted_at < ^DateTime.add(now, -30 * 86400, :second),
              select: count(u.id)
          ) || 0
      },
      %{
        id: "archive_stale_threads",
        name: "Archive Stale Threads",
        description: "Lock threads with 0 replies older than 6 months",
        affected:
          Repo.one(
            from t in Thread,
              where:
                t.reply_count == 0 and t.inserted_at < ^DateTime.add(now, -180 * 86400, :second) and
                  t.is_locked != true,
              select: count(t.id)
          ) || 0
      },
      %{
        id: "prune_old_notifications",
        name: "Prune Old Notifications",
        description: "Delete read notifications older than 90 days",
        affected:
          Repo.one(
            from n in ForgeNexus.Chat.Notification,
              where:
                n.is_read == true and n.inserted_at < ^DateTime.add(now, -90 * 86400, :second),
              select: count(n.id)
          ) || 0
      },
      %{
        id: "prune_old_sessions",
        name: "Clear Stale Online Status",
        description: "Mark offline users not seen in 30 days",
        affected:
          Repo.one(
            from u in User,
              where:
                u.last_seen_at < ^DateTime.add(now, -30 * 86400, :second) and u.is_online == true,
              select: count(u.id)
          ) || 0
      }
    ]
  end
end
