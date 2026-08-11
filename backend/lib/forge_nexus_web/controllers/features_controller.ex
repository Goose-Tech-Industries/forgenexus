defmodule ForgeNexusWeb.FeaturesController do
  @moduledoc "Controller for core forum features: solved, prefixes, blocks, drafts, similar threads."
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Forums
  alias ForgeNexus.Accounts

  # === BBCode preview render ===

  def render_bbcode(conn, %{"body" => body}) when is_binary(body) do
    # Cap input size to keep the renderer cheap and prevent abuse.
    truncated = String.slice(body, 0, 50_000)
    conn |> json(%{html: ForgeNexus.BBCode.to_html(truncated)})
  end

  def render_bbcode(conn, _), do: conn |> json(%{html: ""})

  # === Post Ratings ===

  def rate_post(conn, %{"post_id" => post_id, "rating_type" => rating_type}) do
    user = Guardian.Plug.current_resource(conn)

    case Forums.rate_post(post_id, user.id, rating_type) do
      {:ok, _} ->
        ratings = Forums.get_post_ratings(post_id)
        my_ratings = Forums.get_user_ratings_for_post(post_id, user.id)
        conn |> json(%{ratings: ratings, my_ratings: my_ratings})

      {:error, %Ecto.Changeset{} = cs} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: format_errors(cs)})
    end
  end

  def post_ratings(conn, %{"post_id" => post_id}) do
    user = Guardian.Plug.current_resource(conn)
    ratings = Forums.get_post_ratings(post_id)
    my_ratings = if user, do: Forums.get_user_ratings_for_post(post_id, user.id), else: []
    conn |> json(%{ratings: ratings, my_ratings: my_ratings})
  end

  # === Best Answer / Solved ===

  def mark_solved(conn, %{"thread_id" => thread_id, "post_id" => post_id}) do
    user = Guardian.Plug.current_resource(conn)
    thread = Forums.get_thread!(thread_id)

    if thread.user_id == user.id or ForgeNexus.Moderation.is_staff?(user) do
      case Forums.mark_solved(thread_id, post_id) do
        {:ok, _} -> conn |> json(%{ok: true})
        {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Only the thread author or staff can mark solved"})
    end
  end

  def unmark_solved(conn, %{"thread_id" => thread_id}) do
    user = Guardian.Plug.current_resource(conn)
    thread = Forums.get_thread!(thread_id)

    if thread.user_id == user.id or ForgeNexus.Moderation.is_staff?(user) do
      case Forums.unmark_solved(thread_id) do
        {:ok, _} -> conn |> json(%{ok: true})
        {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Only the thread author or staff can unmark solved"})
    end
  end

  # === Thread Prefixes ===

  def list_prefixes(conn, %{"forum_id" => forum_id}) do
    prefixes = Forums.list_prefixes_for_forum(forum_id)
    conn |> json(%{prefixes: Enum.map(prefixes, &prefix_json/1)})
  end

  def admin_list_prefixes(conn, _params) do
    prefixes = Forums.list_all_prefixes()
    conn |> json(%{prefixes: Enum.map(prefixes, &prefix_json/1)})
  end

  def create_prefix(conn, params) do
    case Forums.create_prefix(params) do
      {:ok, p} ->
        conn |> put_status(:created) |> json(%{prefix: prefix_json(p)})

      {:error, cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: format_errors(cs)})
    end
  end

  def update_prefix(conn, %{"id" => id} = params) do
    case Forums.update_prefix(id, params) do
      {:ok, p} -> conn |> json(%{prefix: prefix_json(p)})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
    end
  end

  def delete_prefix(conn, %{"id" => id}) do
    case Forums.delete_prefix(id) do
      {:ok, _} -> conn |> json(%{ok: true})
      _ -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
    end
  end

  def set_thread_prefix(conn, %{"thread_id" => thread_id, "prefix_id" => prefix_id}) do
    case Forums.set_thread_prefix(thread_id, prefix_id) do
      {:ok, _} -> conn |> json(%{ok: true})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
    end
  end

  # === User Blocks ===

  def block_user(conn, %{"user_id" => blocked_user_id}) do
    user = Guardian.Plug.current_resource(conn)
    Accounts.block_user(user.id, blocked_user_id)
    conn |> json(%{ok: true})
  end

  def unblock_user(conn, %{"user_id" => blocked_user_id}) do
    user = Guardian.Plug.current_resource(conn)
    Accounts.unblock_user(user.id, blocked_user_id)
    conn |> json(%{ok: true})
  end

  def list_blocked(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    blocked = Accounts.list_blocked_users(user.id)
    conn |> json(%{blocked: blocked})
  end

  # === Drafts ===

  def save_draft(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    case Forums.save_draft(
           user.id,
           params["context_type"],
           params["context_id"],
           params["body"],
           params["title"]
         ) do
      {:ok, draft} ->
        conn
        |> json(%{
          draft: %{
            id: draft.id,
            body: draft.body,
            title: draft.title,
            updated_at: draft.updated_at
          }
        })

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to save draft"})
    end
  end

  def get_draft(conn, %{"context_type" => ct, "context_id" => cid}) do
    user = Guardian.Plug.current_resource(conn)

    case Forums.get_draft(user.id, ct, cid) do
      nil ->
        conn |> json(%{draft: nil})

      draft ->
        conn
        |> json(%{
          draft: %{
            id: draft.id,
            body: draft.body,
            title: draft.title,
            updated_at: draft.updated_at
          }
        })
    end
  end

  def delete_draft(conn, %{"context_type" => ct, "context_id" => cid}) do
    user = Guardian.Plug.current_resource(conn)
    Forums.delete_draft(user.id, ct, cid)
    conn |> json(%{ok: true})
  end

  # === Similar Threads ===

  def similar_threads(conn, %{"title" => title} = params) do
    forum_id = params["forum_id"]
    threads = Forums.find_similar_threads(title, forum_id)

    conn
    |> json(%{
      threads:
        Enum.map(threads, fn t ->
          %{
            id: t.id,
            title: t.title,
            slug: t.slug,
            reply_count: t.reply_count,
            forum_name: t.forum && t.forum.name,
            user: t.user && t.user.username,
            inserted_at: t.inserted_at
          }
        end)
    })
  end

  # === Post Bookmarks ===

  def toggle_post_bookmark(conn, %{"post_id" => post_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    case Forums.toggle_post_bookmark(user.id, post_id, params["note"]) do
      {:ok, bookmark} ->
        conn |> json(%{bookmarked: true, id: bookmark.id})

      _ ->
        conn |> json(%{bookmarked: false})
    end
  end

  def list_post_bookmarks(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    bookmarks = Forums.list_post_bookmarks(user.id)

    conn
    |> json(%{
      bookmarks:
        Enum.map(bookmarks, fn b ->
          post = b.post
          thread = post.thread

          %{
            id: b.id,
            note: b.note,
            bookmarked_at: b.inserted_at,
            post: %{
              id: post.id,
              body: post.body,
              body_html: post.body_html,
              inserted_at: post.inserted_at,
              user:
                post.user &&
                  %{
                    id: post.user.id,
                    username: post.user.username,
                    slug: post.user.slug,
                    avatar_url: post.user.avatar_url
                  },
              thread:
                thread &&
                  %{
                    id: thread.id,
                    title: thread.title,
                    slug: thread.slug,
                    forum:
                      thread.forum &&
                        %{
                          id: thread.forum.id,
                          name: thread.forum.name,
                          slug: thread.forum.slug
                        }
                  }
            }
          }
        end)
    })
  end

  def post_bookmark_ids(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    ids = Forums.post_bookmark_ids(user.id) |> MapSet.to_list()
    conn |> json(%{post_ids: ids})
  end

  # === Post Reactions (Emoji Picker) ===

  def react_to_post(conn, %{"post_id" => post_id, "reaction" => reaction_type}) do
    user = Guardian.Plug.current_resource(conn)

    case Forums.toggle_reaction(post_id, user.id, reaction_type) do
      {:ok, _} ->
        counts = Forums.reaction_counts(post_id)
        my_reactions = Forums.user_reactions_for_post(post_id, user.id)
        conn |> json(%{counts: counts, my_reactions: my_reactions})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: format_errors(changeset)})
    end
  end

  def get_post_reactions(conn, %{"post_id" => post_id}) do
    user = Guardian.Plug.current_resource(conn)
    counts = Forums.reaction_counts(post_id)
    my_reactions = if user, do: Forums.user_reactions_for_post(post_id, user.id), else: []
    conn |> json(%{counts: counts, my_reactions: my_reactions})
  end

  # === Helpers ===

  defp prefix_json(p) do
    %{
      id: p.id,
      name: p.name,
      color: p.color,
      bg_color: p.bg_color,
      forum_id: p.forum_id,
      is_global: p.is_global,
      position: p.position
    }
  end

  defp format_errors(cs), do: Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)
end
