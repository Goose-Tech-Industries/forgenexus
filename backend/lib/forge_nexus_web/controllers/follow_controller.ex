defmodule ForgeNexusWeb.FollowController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Accounts

  # POST /api/users/:id/follow — toggle follow
  def toggle(conn, %{"id" => followed_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Accounts.toggle_follow(user.id, followed_id) do
      {:ok, :followed} ->
        conn |> json(%{following: true, follower_count: Accounts.follower_count(followed_id)})

      {:ok, :unfollowed} ->
        conn |> json(%{following: false, follower_count: Accounts.follower_count(followed_id)})

      {:error, :cannot_follow_self} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Cannot follow yourself"})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to update follow status"})
    end
  end

  # GET /api/users/:id/followers
  def followers(conn, %{"id" => user_id}) do
    followers = Accounts.list_followers(user_id)
    conn |> json(%{users: Enum.map(followers, &user_json/1), count: Accounts.follower_count(user_id)})
  end

  # GET /api/users/:id/following
  def following(conn, %{"id" => user_id}) do
    following = Accounts.list_following(user_id)
    conn |> json(%{users: Enum.map(following, &user_json/1), count: Accounts.following_count(user_id)})
  end

  # GET /api/following/feed
  def feed(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    limit = safe_int(Map.get(params, "limit"), 25)
    offset = safe_int(Map.get(params, "offset"), 0)

    posts = Accounts.following_feed(user.id, limit: limit, offset: offset)

    conn |> json(%{posts: Enum.map(posts, &post_json/1)})
  end

  defp safe_int(nil, default), do: default
  defp safe_int(v, _) when is_integer(v), do: v
  defp safe_int(v, default) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> default
    end
  end
  defp safe_int(_, default), do: default

  defp user_json(user) do
    %{
      id: user.id,
      username: user.username,
      slug: user.slug,
      avatar_url: user.avatar_url,
      username_color: user.username_color,
      username_effect: user.username_effect,
      custom_title: user.custom_title
    }
  end

  defp post_json(post) do
    %{
      id: post.id,
      body: post.body,
      body_html: post.body_html,
      inserted_at: post.inserted_at,
      user: post.user && %{
        id: post.user.id,
        username: post.user.username,
        slug: post.user.slug,
        avatar_url: post.user.avatar_url,
        username_color: post.user.username_color,
        username_effect: post.user.username_effect
      },
      thread: post.thread && %{
        id: post.thread.id,
        title: post.thread.title,
        slug: post.thread.slug,
        forum: post.thread.forum && %{
          id: post.thread.forum.id,
          name: post.thread.forum.name,
          slug: post.thread.forum.slug
        }
      }
    }
  end
end
