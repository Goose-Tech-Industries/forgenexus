defmodule ForgeNexusWeb.ThreadController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Forums
  alias ForgeNexus.Accounts

  # GET /api/thread-summary/:id — return latest AI summary for a thread, or null
  def ai_summary(conn, %{"id" => thread_id}) do
    case ForgeNexus.AI.get_thread_summary(thread_id) do
      nil ->
        conn |> json(%{summary: nil})

      summary ->
        conn |> json(%{summary: %{
          thread_id: summary.thread_id,
          summary: summary.summary,
          key_points: summary.key_points,
          participant_count: summary.participant_count,
          post_count_at_generation: summary.post_count_at_generation,
          last_generated_at: summary.last_generated_at,
          inserted_at: summary.inserted_at,
          updated_at: summary.updated_at
        }})
    end
  end

  def trending(conn, params) do
    limit = parse_int(params["limit"], 20)
    threads = Forums.trending_threads("week", limit: limit)

    conn |> json(%{threads: Enum.map(threads, fn t ->
      %{id: t.id, title: t.title, slug: t.slug, reply_count: t.reply_count,
        view_count: t.view_count, user_id: t.user_id, inserted_at: t.inserted_at}
    end)})
  end

  defp parse_int(nil, default), do: default
  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      _ -> default
    end
  end
  defp parse_int(val, _) when is_integer(val), do: val
  defp parse_int(_, default), do: default

  def show(conn, %{"slug" => slug} = params) do
    thread = Forums.get_thread_by_slug!(slug)
    user = Guardian.Plug.current_resource(conn)
    is_staff = ForgeNexus.Moderation.is_staff?(user)

    Forums.increment_view_count(thread)

    page = Map.get(params, "page", "1") |> String.to_integer()
    limit = 25
    offset = (page - 1) * limit

    posts = Forums.list_posts(thread.id, limit: limit, offset: offset, include_hidden: is_staff)

    conn
    |> json(%{
      thread: thread_json(thread),
      posts: Enum.map(posts, &post_json/1),
      page: page
    })
  end

  def create(conn, %{"thread" => thread_params}) do
    user = Guardian.Plug.current_resource(conn)

    unless Accounts.user_has_permission?(user, "can_create_threads") do
      conn |> put_status(:forbidden) |> json(%{error: "You don't have permission to do this"})
    else
      # Resolve forum_slug to forum_id if needed
      thread_params =
        case Map.get(thread_params, "forum_slug") do
          nil -> thread_params
          slug ->
            case Forums.get_forum_by_slug(slug) do
              nil -> thread_params
              forum -> Map.put(thread_params, "forum_id", forum.id)
            end
        end

      attrs =
        thread_params
        |> Map.put("user_id", user.id)
        |> Map.put("ip_address", to_string(:inet.ntoa(conn.remote_ip)))

    case Forums.create_thread(attrs) do
        {:ok, thread} ->
          thread = ForgeNexus.Repo.preload(thread, [:user, :forum])
          conn
          |> put_status(:created)
          |> json(%{thread: thread_json(thread)})

        {:error, :spam_detected, message} ->
          conn
          |> put_status(:too_many_requests)
          |> json(%{error: message})

        {:error, _changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Failed to create thread"})
      end
    end
  end

  def reply(conn, %{"slug" => slug, "post" => post_params}) do
    user = Guardian.Plug.current_resource(conn)

    unless Accounts.user_has_permission?(user, "can_post") do
      conn |> put_status(:forbidden) |> json(%{error: "You don't have permission to do this"})
    else
      thread = Forums.get_thread_by_slug!(slug)

      attrs =
      post_params
      |> Map.put("thread_id", thread.id)
      |> Map.put("user_id", user.id)
      |> Map.put("ip_address", to_string(:inet.ntoa(conn.remote_ip)))

    case Forums.create_post(attrs) do
      {:ok, post} ->
          post = Forums.get_post!(post.id)

          # Realtime push to all clients viewing this thread. Endpoint.broadcast
          # uses Phoenix's fastlane path — automatically delivered to every
          # joined channel as a "new_post" event without per-channel handlers.
          # Wrapped in Task so a slow PubSub node never blocks the HTTP response.
          require Logger
          payload = post_json(post)
          Task.start(fn ->
            Logger.info("[thread_realtime] broadcasting new_post on thread:#{thread.id} (post #{post.id})")
            ForgeNexusWeb.Endpoint.broadcast("thread:#{thread.id}", "new_post", payload)
          end)

          conn
          |> put_status(:created)
          |> json(%{post: payload})

      {:error, _} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Failed to create post"})
      end
    end
  end


  # PUT /posts/:id - edit own post (or any, if staff).
  # Edit window enforced by config :forge_nexus, :post_edit_window_minutes
  # (default 60). Staff bypass the window. Author is always required to be
  # the same user OR staff. PostEdit audit row is written by Forums.update_post.
  def edit_post(conn, %{"id" => post_id, "post" => post_params}) do
    user = Guardian.Plug.current_resource(conn)
    is_staff = ForgeNexus.Moderation.is_staff?(user)

    cond do
      is_nil(user) ->
        conn |> put_status(:unauthorized) |> json(%{error: "Authentication required"})

      not (is_staff or Accounts.user_has_permission?(user, "can_edit_own_posts")) ->
        conn |> put_status(:forbidden) |> json(%{error: "You don't have permission to do this"})

      true ->
        post = Forums.get_post!(post_id)

        window_minutes =
          Application.get_env(:forge_nexus, :post_edit_window_minutes, 60)

        # By the time we reach this check, we know either is_staff OR
        # post.user_id == user.id (the cond branch below this guards otherwise).
        edit_window_open? =
          is_staff or window_minutes <= 0 or
            DateTime.diff(DateTime.utc_now(), post.inserted_at, :minute) <= window_minutes

        cond do
          post.user_id != user.id and not is_staff ->
            conn |> put_status(:forbidden) |> json(%{error: "You can only edit your own posts"})

          not edit_window_open? ->
            conn
            |> put_status(:forbidden)
            |> json(%{error: "Edit window expired (#{window_minutes} minutes)"})

          true ->
            params = Map.put(post_params, "editor_id", user.id)

            case Forums.update_post(post, params) do
              {:ok, updated_post} ->
                updated_post = Forums.get_post!(updated_post.id)
                payload = post_json(updated_post)

                Task.start(fn ->
                  ForgeNexusWeb.Endpoint.broadcast(
                    "thread:#{updated_post.thread_id}",
                    "post_updated",
                    payload
                  )
                end)

                conn |> json(%{post: payload})

              {:error, _} ->
                conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to update post"})
            end
        end
    end
  end

  # GET /posts/:id/history — return chronological edit history for a post.
  # Visible to the post author and staff.
  def post_history(conn, %{"id" => post_id}) do
    user = Guardian.Plug.current_resource(conn)
    post = Forums.get_post!(post_id)
    is_staff = ForgeNexus.Moderation.is_staff?(user)

    cond do
      is_nil(user) ->
        conn |> put_status(:unauthorized) |> json(%{error: "Authentication required"})

      post.user_id != user.id and not is_staff ->
        conn |> put_status(:forbidden) |> json(%{error: "You can only view edit history of your own posts"})

      true ->
        edits =
          post_id
          |> Forums.list_post_edits()
          |> Enum.map(fn e ->
            %{
              id: e.id,
              body_before: e.body_before,
              body_after: e.body_after,
              edit_reason: e.edit_reason,
              inserted_at: e.inserted_at,
              editor: e.editor && %{
                id: e.editor.id,
                username: e.editor.username,
                slug: e.editor.slug,
                avatar_url: e.editor.avatar_url
              }
            }
          end)

        conn |> json(%{edits: edits})
    end
  end
  # GET /threads/scheduled - list user's scheduled threads
  def scheduled(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    if is_nil(user) do
      conn |> put_status(:unauthorized) |> json(%{error: "Authentication required"})
    else
      threads = Forums.list_scheduled_threads(user.id)
      conn |> json(%{threads: Enum.map(threads, &thread_json/1)})
    end
  end

  defp thread_json(thread) do
    %{
      id: thread.id,
      title: thread.title,
      slug: thread.slug,
      is_pinned: thread.is_pinned,
      is_locked: thread.is_locked,
      is_hidden: thread.is_hidden,
      is_private: Map.get(thread, :is_private, false),
      view_count: thread.view_count,
      reply_count: thread.reply_count,
      last_post_at: thread.last_post_at,
      prefix: thread.prefix,
      tags: thread.tags,
      inserted_at: thread.inserted_at,
      scheduled_at: thread.scheduled_at,
      status: thread.status,
      user: %{
        id: thread.user.id,
        username: thread.user.username,
        slug: thread.user.slug,
        avatar_url: thread.user.avatar_url
      },
      forum: %{
        id: thread.forum.id,
        name: thread.forum.name,
        slug: thread.forum.slug
      }
    }
  end

  defp post_json(post) do
    %{
      id: post.id,
      body: post.body,
      body_html: post.body_html,
      is_first_post: post.is_first_post,
      is_edited: post.is_edited,
      edit_count: post.edit_count,
      like_count: post.like_count,
      position: post.position,
      inserted_at: post.inserted_at,
      user: %{
        id: post.user.id,
        username: post.user.username,
        slug: post.user.slug,
        avatar_url: post.user.avatar_url,
        post_count: post.user.post_count,
        reputation: post.user.reputation
      }
    }
  end
end
