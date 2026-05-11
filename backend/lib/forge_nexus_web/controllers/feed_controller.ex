defmodule ForgeNexusWeb.FeedController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Social

  def index(conn, params) do
    community_id = conn.assigns.community_id
    user = Guardian.Plug.current_resource(conn)

    opts = [
      limit: parse_int(params["limit"], 30),
      filter: params["filter"] || "all",
      user_id: user && user.id
    ]

    opts = if params["before"], do: Keyword.put(opts, :before, parse_datetime(params["before"])), else: opts

    items = Social.get_feed(community_id, opts)

    conn |> json(%{
      items: Enum.map(items, fn item ->
        %{type: item.type, id: item.id, data: item.data, inserted_at: item.inserted_at}
      end)
    })
  end

  def create_status(conn, %{"body" => body} = params) do
    user = Guardian.Plug.current_resource(conn)
    community_id = conn.assigns.community_id

    attrs = %{
      community_id: community_id,
      user_id: user.id,
      body: body,
      media_urls: params["media_urls"] || [],
      media_type: params["media_type"] || "text",
      reference_type: params["reference_type"],
      reference_id: params["reference_id"],
      visibility: params["visibility"] || "public"
    }

    case Social.create_status_post(attrs) do
      {:ok, post} ->
        ForgeNexusWeb.Endpoint.broadcast("feed:#{community_id}", "new_status", %{
          id: post.id,
          user_id: post.user_id,
          username: user.username,
          avatar_url: user.avatar_url,
          body: post.body,
          media_urls: post.media_urls,
          media_type: post.media_type,
          inserted_at: post.inserted_at
        })

        conn |> put_status(:created) |> json(%{post: %{id: post.id, body: post.body}})

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
        conn |> put_status(:unprocessable_entity) |> json(%{error: errors})
    end
  end

  def like(conn, %{"id" => post_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Social.toggle_like(post_id, user.id) do
      {:ok, action} -> conn |> json(%{action: action})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "Post not found"})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
    end
  end

  def comment(conn, %{"id" => post_id, "body" => body}) do
    user = Guardian.Plug.current_resource(conn)

    case Social.add_comment(post_id, user.id, body) do
      {:ok, comment} ->
        conn |> put_status(:created) |> json(%{comment: %{id: comment.id, body: body}})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
    end
  end

  def comments(conn, %{"id" => post_id}) do
    comments = Social.list_comments(post_id)
    conn |> json(%{comments: comments})
  end

  # --- Pokes ---

  def send_poke(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    community_id = conn.assigns.community_id

    attrs = %{
      community_id: community_id,
      sender_id: user.id,
      recipient_id: params["to_user_id"],
      type: params["type"] || "poke",
      message: params["message"]
    }

    case Social.send_poke(attrs) do
      {:ok, poke} ->
        conn |> json(%{ok: true, type: poke.type})

      {:error, %Ecto.Changeset{} = cs} ->
        errors = Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)
        conn |> put_status(:unprocessable_entity) |> json(%{error: errors})

      {:error, reason} ->
        conn |> put_status(:bad_request) |> json(%{error: inspect(reason)})
    end
  end

  def list_pokes(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    unread = params["unread"] == "true"
    pokes = Social.list_pokes(user.id, unread_only: unread)

    conn |> json(%{
      pokes: Enum.map(pokes, fn p ->
        %{id: p.id, type: p.type, message: p.message, is_read: p.is_read,
          from: %{id: p.sender.id, username: p.sender.username, avatar_url: p.sender.avatar_url},
          inserted_at: p.inserted_at}
      end),
      unread_count: Social.unread_poke_count(user.id)
    })
  end

  def mark_pokes_read(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    Social.mark_pokes_read(user.id)
    conn |> json(%{ok: true})
  end

  # --- Presence ---

  def update_presence(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    Social.update_presence(
      user.id,
      params["status"],
      params["activity"],
      params["detail"]
    )

    conn |> json(%{ok: true})
  end

  # --- Premium ---

  def premium_status(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    premium = Social.get_premium(user.id)

    if premium do
      conn |> json(%{
        is_premium: premium.status == "active",
        plan: premium.plan,
        features: premium.features,
        expires_at: premium.expires_at
      })
    else
      conn |> json(%{is_premium: false, plan: nil, features: %{}})
    end
  end

  # --- Discovery ---

  def discover(conn, params) do
    communities = Social.discover_communities(
      category: params["category"],
      tag: params["tag"],
      limit: parse_int(params["limit"], 30)
    )

    conn |> json(%{communities: Enum.map(communities, fn c ->
      %{id: c.id, name: c.name, slug: c.slug, description: c.description,
        logo_url: c.logo_url, category: c.category, tags: c.tags,
        member_count: c.member_count, activity_score: c.activity_score,
        plan: c.plan}
    end)})
  end

  def suggested_members(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    community_id = conn.assigns.community_id

    members = if user do
      Social.suggested_members(community_id, user.id)
    else
      []
    end

    conn |> json(%{members: members})
  end

  def syndicate_thread(conn, %{"thread_id" => thread_id, "target_community_id" => target_id}) do
    user = Guardian.Plug.current_resource(conn)

    case ForgeNexus.Social.Syndication.syndicate_thread(thread_id, target_id, user.id) do
      {:ok, thread} ->
        conn |> json(%{ok: true, thread_id: thread.id})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  def community_health(conn, _params) do
    community_id = conn.assigns.community_id
    health = ForgeNexus.AI.CommunityHealth.calculate(community_id)
    conn |> json(%{health: health})
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

  defp parse_datetime(nil), do: nil
  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end
  defp parse_datetime(_), do: nil
end
