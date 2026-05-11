defmodule ForgeNexus.Social do
  @moduledoc """
  Social context — status posts, social feed, likes, comments.
  """

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Social.{StatusPost, Feed, Poke, UserPremium}

  # --- Feed ---

  def get_feed(community_id, opts \\ []) do
    Feed.get_feed(community_id, opts)
  end

  def create_status_post(attrs) do
    %StatusPost{} |> StatusPost.changeset(attrs) |> Repo.insert()
  end

  def get_status_post!(id), do: Repo.get!(StatusPost, id) |> Repo.preload(:user)

  def delete_status_post(%StatusPost{} = post), do: Repo.delete(post)

  def toggle_like(post_id, user_id) do
    cond do
      not is_binary(post_id) or Ecto.UUID.cast(post_id) == :error ->
        {:error, :not_found}

      is_nil(Repo.get(StatusPost, post_id)) ->
        {:error, :not_found}

      true ->
        case Repo.get_by(ForgeNexus.Social.StatusPostLike, status_post_id: post_id, user_id: user_id) do
          nil ->
            %ForgeNexus.Social.StatusPostLike{}
            |> Ecto.Changeset.change(%{status_post_id: post_id, user_id: user_id})
            |> Repo.insert()

            from(p in StatusPost, where: p.id == ^post_id)
            |> Repo.update_all(inc: [like_count: 1])

            {:ok, :liked}

          existing ->
            Repo.delete(existing)

            from(p in StatusPost, where: p.id == ^post_id and p.like_count > 0)
            |> Repo.update_all(inc: [like_count: -1])

            {:ok, :unliked}
        end
    end
  end

  def add_comment(post_id, user_id, body) do
    cond do
      not is_binary(post_id) or Ecto.UUID.cast(post_id) == :error ->
        {:error, :not_found}

      is_nil(Repo.get(StatusPost, post_id)) ->
        {:error, :not_found}

      true ->
        %ForgeNexus.Social.StatusPostComment{}
        |> Ecto.Changeset.change(%{status_post_id: post_id, user_id: user_id, body: body})
        |> Repo.insert()
        |> case do
          {:ok, comment} ->
            from(p in StatusPost, where: p.id == ^post_id)
            |> Repo.update_all(inc: [comment_count: 1])

            {:ok, comment}

          error ->
            error
        end
    end
  end

  def list_comments(post_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    # Raw "table" syntax skips schema-driven casting — pass post_id through type/2
    # so Postgrex receives a 16-byte binary_id rather than the textual UUID.
    from(c in "status_post_comments",
      where: c.status_post_id == type(^post_id, Ecto.UUID),
      order_by: [asc: c.inserted_at],
      limit: ^limit,
      select: %{id: c.id, user_id: c.user_id, body: c.body, inserted_at: c.inserted_at}
    )
    |> Repo.all()
  end

  # --- Pokes / Winks ---

  def send_poke(attrs) do
    sender_id = Map.get(attrs, :sender_id) || Map.get(attrs, "sender_id")
    recipient_id = Map.get(attrs, :recipient_id) || Map.get(attrs, "recipient_id")

    if sender_id == recipient_id do
      {:error, :cannot_poke_self}
    else
      case %Poke{} |> Poke.changeset(attrs) |> Repo.insert() do
        {:ok, poke} ->
          ForgeNexusWeb.Endpoint.broadcast("user:#{recipient_id}", "poked", %{
            from_id: sender_id,
            type: poke.type,
            message: poke.message
          })

          {:ok, poke}

        error ->
          error
      end
    end
  end

  def list_pokes(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 30)
    unread_only = Keyword.get(opts, :unread_only, false)

    query = from(p in Poke,
      where: p.recipient_id == ^user_id,
      order_by: [desc: :inserted_at],
      limit: ^limit,
      preload: [:sender]
    )

    query = if unread_only, do: where(query, [p], p.is_read == false), else: query
    Repo.all(query)
  end

  def mark_pokes_read(user_id) do
    from(p in Poke, where: p.recipient_id == ^user_id and p.is_read == false)
    |> Repo.update_all(set: [is_read: true])
  end

  def unread_poke_count(user_id) do
    from(p in Poke, where: p.recipient_id == ^user_id and p.is_read == false)
    |> Repo.aggregate(:count)
  end

  # --- Rich Presence ---

  def update_presence(user_id, status, activity \\ nil, detail \\ nil) do
    ForgeNexus.Accounts.update_user_fields(user_id, %{
      rich_presence_status: status,
      rich_presence_activity: activity,
      rich_presence_detail: detail
    })
  end

  # --- User Premium ---

  def get_premium(user_id) do
    Repo.get_by(UserPremium, user_id: user_id)
  end

  def is_premium?(user_id) do
    case get_premium(user_id) do
      %UserPremium{status: "active", expires_at: exp} ->
        is_nil(exp) or DateTime.compare(exp, DateTime.utc_now()) == :gt

      _ ->
        false
    end
  end

  def activate_premium(user_id, plan, opts \\ []) do
    features = UserPremium.features_for_plan(plan)
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    expires = Keyword.get(opts, :expires_at)
    stripe_id = Keyword.get(opts, :stripe_subscription_id)

    attrs = %{
      user_id: user_id,
      plan: plan,
      status: "active",
      started_at: now,
      expires_at: expires,
      stripe_subscription_id: stripe_id,
      features: features
    }

    case get_premium(user_id) do
      nil ->
        %UserPremium{} |> UserPremium.changeset(attrs) |> Repo.insert()

      existing ->
        existing |> UserPremium.changeset(attrs) |> Repo.update()
    end
    |> case do
      {:ok, premium} ->
        ForgeNexus.Accounts.update_user_fields(user_id, %{is_premium: true, premium_until: expires})
        {:ok, premium}

      error ->
        error
    end
  end

  def cancel_premium(user_id) do
    case get_premium(user_id) do
      nil -> {:error, :not_premium}
      premium ->
        premium |> UserPremium.changeset(%{status: "cancelled"}) |> Repo.update()
        ForgeNexus.Accounts.update_user_fields(user_id, %{is_premium: false})
        :ok
    end
  end

  # --- Community Discovery ---

  def discover_communities(opts \\ []) do
    limit = Keyword.get(opts, :limit, 30)
    category = Keyword.get(opts, :category)
    tag = Keyword.get(opts, :tag)

    query = from(c in ForgeNexus.Communities.Community,
      where: c.is_active == true and c.is_discoverable == true,
      order_by: [desc: :activity_score, desc: :member_count],
      limit: ^limit
    )

    query = if category, do: where(query, [c], c.category == ^category), else: query
    query = if tag, do: where(query, [c], ^tag in c.tags), else: query

    Repo.all(query)
  end

  # --- Member Matchmaking ---

  def suggested_members(community_id, user_id, limit \\ 10) do
    user_categories =
      from(t in "threads",
        join: f in "forums", on: f.id == t.forum_id,
        where: t.user_id == type(^user_id, :binary_id) and t.community_id == type(^community_id, :binary_id),
        select: f.category_id,
        distinct: true
      )
      |> Repo.all()

    if user_categories == [] do
      from(u in "users",
        where: u.community_id == type(^community_id, :binary_id) and u.id != type(^user_id, :binary_id),
        order_by: fragment("RANDOM()"),
        limit: ^limit,
        select: %{id: type(u.id, :binary_id), username: u.username, avatar_url: u.avatar_url, bio: u.bio}
      )
      |> Repo.all()
    else
      from(u in "users",
        join: t in "threads", on: t.user_id == u.id,
        join: f in "forums", on: f.id == t.forum_id,
        where: u.community_id == type(^community_id, :binary_id) and u.id != type(^user_id, :binary_id) and f.category_id in ^user_categories,
        group_by: [u.id, u.username, u.avatar_url, u.bio],
        order_by: [desc: count(t.id)],
        limit: ^limit,
        select: %{id: type(u.id, :binary_id), username: u.username, avatar_url: u.avatar_url, bio: u.bio}
      )
      |> Repo.all()
    end
  end
end
