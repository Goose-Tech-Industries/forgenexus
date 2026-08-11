defmodule ForgeNexusWeb.MemberController do
  use ForgeNexusWeb, :controller

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Forums.Post

  # GET /api/members?page=1&search=&sort=posts|joined|username
  def index(conn, params) do
    page = safe_int(params["page"], 1)
    limit = 25
    offset = (page - 1) * limit
    search = params["search"]
    sort = params["sort"] || "joined"

    query =
      from(u in User,
        where: u.status != "deactivated",
        limit: ^limit,
        offset: ^offset
      )

    query =
      if search && search != "" do
        term = "%#{search}%"
        where(query, [u], ilike(u.username, ^term) or ilike(u.display_name, ^term))
      else
        query
      end

    query =
      case sort do
        "posts" -> order_by(query, [u], desc: u.post_count)
        "username" -> order_by(query, [u], asc: u.username)
        _ -> order_by(query, [u], desc: u.inserted_at)
      end

    users = Repo.all(query)
    total = Repo.one(from u in User, where: u.status != "deactivated", select: count(u.id))

    conn
    |> json(%{
      members: Enum.map(users, &member_json/1),
      total: total,
      page: page,
      total_pages: ceil(total / limit)
    })
  end

  # GET /api/recent-posts?limit=25
  def recent_posts(conn, params) do
    limit = safe_int(params["limit"], 25) |> min(50)

    posts =
      from(p in Post,
        where: p.is_hidden == false,
        order_by: [desc: :inserted_at],
        limit: ^limit,
        preload: [user: [], thread: :forum]
      )
      |> Repo.all()

    conn
    |> json(%{
      posts:
        Enum.map(posts, fn p ->
          %{
            id: p.id,
            body: String.slice(p.body || "", 0, 200),
            inserted_at: p.inserted_at,
            user: %{
              id: p.user.id,
              username: p.user.username,
              slug: p.user.slug,
              avatar_url: p.user.avatar_url
            },
            thread: %{id: p.thread.id, title: p.thread.title, slug: p.thread.slug},
            forum: %{id: p.thread.forum.id, name: p.thread.forum.name, slug: p.thread.forum.slug}
          }
        end)
    })
  end

  defp member_json(user) do
    %{
      id: user.id,
      username: user.username,
      slug: user.slug,
      avatar_url: user.avatar_url,
      display_name: user.display_name,
      post_count: user.post_count,
      thread_count: user.thread_count,
      reputation: user.reputation,
      is_online: user.is_online,
      inserted_at: user.inserted_at,
      last_seen_at: user.last_seen_at
    }
  end

  # GET /api/members/search?q=username (for @mentions autocomplete)
  def search_users(conn, %{"q" => q}) when byte_size(q) >= 1 do
    users =
      from(u in User,
        where: ilike(u.username, ^"#{q}%") and u.status != "deactivated",
        limit: 8,
        select: %{id: u.id, username: u.username, slug: u.slug, avatar_url: u.avatar_url}
      )
      |> Repo.all()

    conn |> json(%{users: users})
  end

  def search_users(conn, _), do: conn |> json(%{users: []})

  defp safe_int(nil, default), do: default

  defp safe_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end

  defp safe_int(_, default), do: default
end
