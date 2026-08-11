defmodule ForgeNexusWeb.StatsController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.{Accounts, Forums, Settings, StatsCache}

  # GET /api/stats/cached — instant precomputed stats from ETS (for widgets, homepage)
  def cached(conn, _params) do
    json(conn, %{
      stats: %{
        totals: %{
          members: StatsCache.get(:total_members, 0),
          threads: StatsCache.get(:total_threads, 0),
          posts: StatsCache.get(:total_posts, 0),
          forums: StatsCache.get(:total_forums, 0)
        },
        today: %{
          new_members: StatsCache.get(:new_members_today, 0),
          posts: StatsCache.get(:posts_today, 0),
          threads: StatsCache.get(:threads_today, 0)
        },
        online: %{
          current: StatsCache.get(:current_online, 0),
          peak: StatsCache.get(:peak_online, 0),
          peak_at: StatsCache.get(:peak_online_at)
        },
        most_active_24h: StatsCache.get(:most_active_24h, []),
        trending_threads: StatsCache.get(:trending_threads, []),
        last_computed_at: StatsCache.get(:last_computed_at)
      }
    })
  end

  # GET /api/stats — public, forum statistics page data (full, live queries)
  def index(conn, _params) do
    member_growth = Accounts.monthly_member_growth(12)
    thread_growth = Forums.monthly_thread_growth(12)
    post_growth = Forums.monthly_post_growth(12)

    # Merge monthly growth data
    months =
      (Enum.map(member_growth, & &1.month) ++
         Enum.map(thread_growth, & &1.month) ++ Enum.map(post_growth, & &1.month))
      |> Enum.uniq()
      |> Enum.sort()

    member_map = Map.new(member_growth, fn g -> {g.month, g.count} end)
    thread_map = Map.new(thread_growth, fn g -> {g.month, g.count} end)
    post_map = Map.new(post_growth, fn g -> {g.month, g.count} end)

    monthly_data =
      Enum.map(months, fn month ->
        %{
          month: month,
          members: Map.get(member_map, month, 0),
          threads: Map.get(thread_map, month, 0),
          posts: Map.get(post_map, month, 0)
        }
      end)

    most_active =
      Accounts.most_active_users(10)
      |> Enum.map(fn user ->
        %{
          id: user.id,
          username: user.username,
          slug: user.slug,
          avatar_url: user.avatar_url,
          post_count: user.post_count,
          username_color: resolve_color(user),
          username_effect: resolve_effect(user)
        }
      end)

    most_popular =
      Forums.most_popular_threads(10)
      |> Enum.map(fn thread ->
        %{
          id: thread.id,
          title: thread.title,
          slug: thread.slug,
          view_count: thread.view_count,
          reply_count: thread.reply_count,
          forum_name: thread.forum.name,
          forum_slug: thread.forum.slug,
          user: %{
            username: thread.user.username,
            slug: thread.user.slug
          }
        }
      end)

    conn
    |> json(%{
      stats: %{
        total_members: Accounts.count_users(),
        total_threads: Forums.count_threads(),
        total_posts: Forums.count_posts(),
        new_members_this_month: Accounts.new_members_this_month(),
        new_threads_this_month: Forums.new_threads_this_month(),
        new_posts_this_month: Forums.new_posts_this_month(),
        online_count: Accounts.online_count(),
        most_active_users: most_active,
        most_popular_threads: most_popular,
        monthly_growth: monthly_data
      }
    })
  end

  defp resolve_color(user) do
    cond do
      user.username_color && user.username_color != "" -> user.username_color
      user.primary_group && user.primary_group.username_color -> user.primary_group.username_color
      user.primary_group && user.primary_group.color -> user.primary_group.color
      true -> nil
    end
  rescue
    _ -> nil
  end

  defp resolve_effect(user) do
    cond do
      user.username_effect && user.username_effect != "none" ->
        user.username_effect

      user.primary_group && user.primary_group.username_effect &&
          user.primary_group.username_effect != "none" ->
        user.primary_group.username_effect

      true ->
        "none"
    end
  rescue
    _ -> "none"
  end

  # GET /api/featured-threads — public, recent active threads for portal
  def featured_threads(conn, params) do
    limit =
      case Map.get(params, "limit") do
        nil ->
          5

        val ->
          case Integer.parse(to_string(val)) do
            {n, _} -> min(n, 20)
            :error -> 5
          end
      end

    threads = Forums.recent_threads(limit)

    conn
    |> json(%{
      threads:
        Enum.map(threads, fn t ->
          %{
            id: t.id,
            title: t.title,
            slug: t.slug,
            reply_count: t.reply_count,
            view_count: t.view_count,
            inserted_at: t.inserted_at,
            last_post_at: t.last_post_at,
            author:
              if(Ecto.assoc_loaded?(t.user),
                do: %{
                  username: t.user.username,
                  slug: t.user.slug,
                  avatar_url: t.user.avatar_url
                }
              )
          }
        end)
    })
  end

  # GET /api/users/online — public, online users with group colors
  def online(conn, _params) do
    users = Accounts.online_users_detailed()
    stats = Accounts.online_stats()

    conn
    |> json(%{
      users: Enum.map(users, &online_user_json/1),
      stats: stats
    })
  end

  # GET /api/stats/welcome — public, welcome center data
  def welcome(conn, _params) do
    settings = welcome_settings()

    data = %{
      settings: settings,
      stats: forum_stats(),
      newest_member: newest_member_json(),
      recent_threads: recent_threads_json(),
      new_members_this_week: new_members_this_week_json(),
      online_count: Accounts.online_count()
    }

    conn |> json(%{welcome: data})
  end

  defp welcome_settings do
    %{
      enabled: Settings.get_bool("welcome_center_enabled"),
      title: Settings.get("welcome_center_title"),
      guest_message: Settings.get("welcome_center_guest_message"),
      member_message: Settings.get("welcome_center_member_message"),
      show_stats: Settings.get_bool("welcome_center_show_stats"),
      show_recent_threads: Settings.get_bool("welcome_center_show_recent_threads"),
      show_birthdays: Settings.get_bool("welcome_center_show_birthdays"),
      show_new_members: Settings.get_bool("welcome_center_show_new_members")
    }
  end

  defp forum_stats do
    %{
      total_members: Accounts.count_users(),
      total_threads: Forums.count_threads(),
      total_posts: Forums.count_posts()
    }
  end

  defp newest_member_json do
    case Accounts.newest_member() do
      nil ->
        nil

      user ->
        %{
          id: user.id,
          username: user.username,
          slug: user.slug,
          avatar_url: user.avatar_url,
          inserted_at: user.inserted_at
        }
    end
  end

  defp recent_threads_json do
    Forums.recent_threads(5)
    |> Enum.map(fn thread ->
      %{
        id: thread.id,
        title: thread.title,
        slug: thread.slug,
        last_post_at: thread.last_post_at,
        inserted_at: thread.inserted_at,
        user: %{
          id: thread.user.id,
          username: thread.user.username,
          slug: thread.user.slug,
          avatar_url: thread.user.avatar_url
        }
      }
    end)
  end

  defp new_members_this_week_json do
    Accounts.new_members_this_week()
    |> Enum.map(fn user ->
      %{
        id: user.id,
        username: user.username,
        slug: user.slug,
        avatar_url: user.avatar_url,
        inserted_at: user.inserted_at
      }
    end)
  end

  defp online_user_json(user) do
    # Pick best group: primary_group if set, else highest-position group from memberships
    best_group =
      cond do
        user.primary_group ->
          user.primary_group

        is_list(user.groups) and user.groups != [] ->
          Enum.max_by(user.groups, fn g -> g.position || 0 end, fn -> nil end)

        true ->
          nil
      end

    resolved_color =
      cond do
        user.username_color && user.username_color != "" ->
          user.username_color

        best_group && best_group.username_color && best_group.username_color != "" ->
          best_group.username_color

        best_group && best_group.color && best_group.color != "" ->
          best_group.color

        true ->
          nil
      end

    resolved_effect =
      cond do
        user.username_effect && user.username_effect != "none" ->
          user.username_effect

        best_group && best_group.username_effect && best_group.username_effect != "none" ->
          best_group.username_effect

        true ->
          "none"
      end

    %{
      id: user.id,
      username: user.username,
      slug: user.slug,
      avatar_url: user.avatar_url,
      username_color: resolved_color,
      username_effect: resolved_effect,
      is_online: user.is_online,
      last_seen_at: user.last_seen_at,
      group:
        if(user.primary_group,
          do: %{
            name: user.primary_group.name,
            color: user.primary_group.color,
            icon: user.primary_group.icon
          },
          else: nil
        )
    }
  end
end
