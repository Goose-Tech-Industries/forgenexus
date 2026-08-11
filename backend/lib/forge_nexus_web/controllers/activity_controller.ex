defmodule ForgeNexusWeb.ActivityController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.{Accounts, Forums}

  # GET /api/profiles/:slug/activity
  def show(conn, %{"slug" => slug} = params) do
    target_user = Accounts.get_user_by_slug(slug)

    if is_nil(target_user) do
      conn |> put_status(:not_found) |> json(%{error: "User not found"})
    else
      # Check privacy
      viewer = Guardian.Plug.current_resource(conn)
      pref = Accounts.get_preferences(target_user.id)

      if can_view_activity?(pref, target_user, viewer) do
        limit = safe_int(params["limit"], 25) |> min(50)
        offset = safe_int(params["offset"], 0)
        activity = Forums.user_activity(target_user.id, limit: limit, offset: offset)

        conn
        |> json(%{
          activity: %{
            posts: Enum.map(activity.posts, &post_json/1),
            threads: Enum.map(activity.threads, &thread_json/1)
          }
        })
      else
        conn |> put_status(:forbidden) |> json(%{error: "This user's activity is private"})
      end
    end
  end

  defp can_view_activity?(pref, target_user, viewer) do
    cond do
      !pref.show_activity -> viewer && viewer.id == target_user.id
      pref.profile_visibility == "private" -> viewer && viewer.id == target_user.id
      pref.profile_visibility == "members" -> !is_nil(viewer)
      true -> true
    end
  end

  defp post_json(post) do
    %{
      id: post.id,
      body: String.slice(post.body || "", 0, 200),
      inserted_at: post.inserted_at,
      thread: %{
        id: post.thread.id,
        title: post.thread.title,
        slug: post.thread.slug,
        forum: %{
          id: post.thread.forum.id,
          name: post.thread.forum.name,
          slug: post.thread.forum.slug
        }
      }
    }
  end

  defp safe_int(nil, default), do: default

  defp safe_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end

  defp safe_int(val, _default) when is_integer(val), do: val
  defp safe_int(_, default), do: default

  defp thread_json(thread) do
    %{
      id: thread.id,
      title: thread.title,
      slug: thread.slug,
      reply_count: thread.reply_count,
      view_count: thread.view_count,
      inserted_at: thread.inserted_at,
      forum: %{id: thread.forum.id, name: thread.forum.name, slug: thread.forum.slug}
    }
  end
end
