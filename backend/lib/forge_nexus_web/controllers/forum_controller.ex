defmodule ForgeNexusWeb.ForumController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Forums

  def index(conn, _params) do
    categories = Forums.list_categories()

    conn
    |> json(%{
      categories: Enum.map(categories, &category_json/1)
    })
  end

  def show(conn, %{"slug" => slug}) do
    forum = Forums.get_forum_by_slug!(slug)

    conn |> json(%{forum: forum_json(forum)})
  end

  def threads(conn, %{"slug" => slug} = params) do
    forum = Forums.get_forum_by_slug!(slug)
    page = Map.get(params, "page", "1") |> String.to_integer()
    limit = 25
    offset = (page - 1) * limit
    user = ForgeNexus.Guardian.Plug.current_resource(conn)
    include_hidden = ForgeNexus.Moderation.is_staff?(user)

    threads = Forums.list_threads(forum.id, limit: limit, offset: offset, include_hidden: include_hidden)

    conn
    |> json(%{
      forum: forum_json(forum),
      threads: Enum.map(threads, &thread_json/1),
      page: page
    })
  end


  defp category_json(category) do
    %{
      id: category.id,
      name: category.name,
      slug: category.slug,
      description: category.description,
      icon: category.icon,
      color: category.color,
      position: category.position,
      forums: Enum.map(category.forums, &forum_json/1)
    }
  end

  defp forum_json(forum) do
    base = %{
      id: forum.id,
      name: forum.name,
      slug: forum.slug,
      description: forum.description,
      icon: forum.icon,
      color: forum.color,
      thread_count: forum.thread_count,
      post_count: forum.post_count,
      last_post_at: forum.last_post_at,
      parent_id: forum.parent_id
    }

    base =
      if Ecto.assoc_loaded?(forum.last_post_user) and forum.last_post_user do
        Map.put(base, :last_post_user, %{
          username: forum.last_post_user.username,
          slug: forum.last_post_user.slug,
          username_color: forum.last_post_user.username_color,
          username_effect: forum.last_post_user.username_effect
        })
      else
        base
      end

    base =
      if Ecto.assoc_loaded?(forum.parent) and forum.parent do
        Map.put(base, :parent, %{id: forum.parent.id, name: forum.parent.name, slug: forum.parent.slug})
      else
        base
      end

    if Ecto.assoc_loaded?(forum.children) do
      Map.put(base, :children, Enum.map(forum.children, &forum_json/1))
    else
      base
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
      view_count: thread.view_count,
      reply_count: thread.reply_count,
      last_post_at: thread.last_post_at,
      prefix: thread.prefix,
      tags: thread.tags,
      inserted_at: thread.inserted_at,
      user: %{
        id: thread.user.id,
        username: thread.user.username,
        slug: thread.user.slug,
        avatar_url: thread.user.avatar_url
      }
    }
  end
end
