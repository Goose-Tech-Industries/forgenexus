defmodule ForgeNexusWeb.AdminUserController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.{Accounts, Admin, Moderation}
  import Ecto.Query, only: [from: 2]

  def index(conn, params) do
    opts = [
      search: Map.get(params, "search"),
      status: Map.get(params, "status"),
      group_id: Map.get(params, "group_id"),
      sort: Map.get(params, "sort", "newest"),
      limit: parse_int(params, "limit", 25),
      offset: parse_int(params, "offset", 0)
    ]

    query = build_user_query(opts)
    users = ForgeNexus.Repo.all(query)
    total = ForgeNexus.Repo.one(count_user_query(opts)) || 0

    conn
    |> json(%{
      users: Enum.map(users, &admin_user_json/1),
      total: total,
      limit: Keyword.get(opts, :limit),
      offset: Keyword.get(opts, :offset)
    })
  end

  def show(conn, %{"id" => id}) do
    user =
      Accounts.get_user!(id)
      |> ForgeNexus.Repo.preload([:primary_group, :groups])

    infractions = Moderation.user_infractions(id)
    conn |> json(%{user: admin_user_detail_json(user, infractions)})
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Accounts.get_user!(id)
    previous = %{"username" => user.username, "email" => user.email, "status" => user.status}

    attrs = user_params
      |> Map.take(["username", "email", "display_name", "status", "primary_group_id", "trust_level"])
      |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)
      |> Map.new()

    case Accounts.admin_update_user(user, attrs) do
      {:ok, updated} ->
        admin = Guardian.Plug.current_resource(conn)
        Admin.log_admin_action(admin.id, %{
          action: "user_updated", category: "settings",
          target_type: "user", target_id: id,
          description: "Updated user #{user.username}",
          previous_state: previous,
          new_state: user_params
        })
        conn |> json(%{user: admin_user_json(updated)})
      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    case ForgeNexus.Repo.delete(user) do
      {:ok, _} ->
        admin = Guardian.Plug.current_resource(conn)
        Admin.log_admin_action(admin.id, %{
          action: "user_deleted", category: "settings",
          target_type: "user", target_id: id,
          description: "Deleted user #{user.username}"
        })
        conn |> json(%{ok: true})
      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete user"})
    end
  end

  def reset_password(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    temp_pass = :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
    case Accounts.update_profile(user, %{password: temp_pass}) do
      {:ok, _} -> conn |> json(%{temporary_password: temp_pass})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to reset password"})
    end
  end

  def bulk_action(conn, %{"action" => action, "user_ids" => user_ids} = params) when is_list(user_ids) do
    admin = Guardian.Plug.current_resource(conn)
    results = Enum.map(user_ids, fn uid ->
      case action do
        "ban" ->
          reason = Map.get(params, "reason", "Bulk ban by admin")
          case Moderation.ban_user(uid, %{type: "permanent", reason: reason}, admin) do
            {:ok, _} -> %{user_id: uid, status: "ok"}
            {:error, _} -> %{user_id: uid, status: "error"}
          end
        "add_to_group" ->
          group_id = Map.get(params, "group_id")
          if group_id do
            Accounts.add_user_to_group(uid, group_id)
            %{user_id: uid, status: "ok"}
          else
            %{user_id: uid, status: "error", error: "No group_id"}
          end
        _ ->
          %{user_id: uid, status: "error", error: "Unknown action"}
      end
    end)
    conn |> json(%{results: results})
  end

  def journey(conn, %{"id" => id}) do
    events = Admin.user_journey(id)
    conn |> json(%{events: events})
  end

  def search_by_ip(conn, %{"ip" => ip}) do
    users = Accounts.search_users_by_ip(ip)
    conn |> json(%{users: Enum.map(users, &admin_user_json/1)})
  end

  def search_by_ip(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "Missing ip parameter"})
  end

  # Private helpers

  defp build_user_query(opts) do
    import Ecto.Query
    alias ForgeNexus.Accounts.User

    query = from(u in User, preload: [:primary_group])

    query = case Keyword.get(opts, :search) do
      nil -> query
      "" -> query
      search ->
        term = "%#{search}%"
        where(query, [u], ilike(u.username, ^term) or ilike(u.email, ^term) or ilike(u.display_name, ^term))
    end

    query = case Keyword.get(opts, :status) do
      nil -> query
      "" -> query
      status -> where(query, [u], u.status == ^status)
    end

    query = case Keyword.get(opts, :sort) do
      "oldest" -> order_by(query, [u], asc: u.inserted_at)
      "username" -> order_by(query, [u], asc: u.username)
      "posts" -> order_by(query, [u], desc: u.post_count)
      _ -> order_by(query, [u], desc: u.inserted_at)
    end

    query
    |> limit(^Keyword.get(opts, :limit, 25))
    |> offset(^Keyword.get(opts, :offset, 0))
  end

  defp count_user_query(opts) do
    import Ecto.Query
    alias ForgeNexus.Accounts.User

    query = from(u in User, select: count(u.id))

    query =
      case Keyword.get(opts, :search) do
        nil -> query
        "" -> query
        search ->
          term = "%#{search}%"
          where(query, [u], ilike(u.username, ^term) or ilike(u.email, ^term) or ilike(u.display_name, ^term))
      end

    case Keyword.get(opts, :status) do
      nil -> query
      "" -> query
      status -> where(query, [u], u.status == ^status)
    end
  end

  defp admin_user_json(user) do
    %{
      id: user.id, username: user.username, email: user.email,
      display_name: user.display_name, slug: user.slug, avatar_url: user.avatar_url,
      status: user.status, is_online: user.is_online,
      post_count: user.post_count, thread_count: user.thread_count,
      reputation: user.reputation, trust_level: user.trust_level,
      last_seen_at: user.last_seen_at, last_post_at: user.last_post_at,
      inserted_at: user.inserted_at,
      custom_title: user.custom_title,
      is_premium: user.is_premium,
      verified_creator_at: user.verified_creator_at,
      email_verified_at: user.email_verified_at,
      primary_group_id: user.primary_group_id,
      primary_group: if(Ecto.assoc_loaded?(user.primary_group) && user.primary_group, do: %{id: user.primary_group.id, name: user.primary_group.name, color: user.primary_group.color, is_staff: user.primary_group.is_staff})
    }
  end

  defp admin_user_detail_json(user, infractions) do
    oauth_accounts =
      ForgeNexus.Repo.all(
        from oa in ForgeNexus.Accounts.OAuthAccount,
          where: oa.user_id == ^user.id,
          order_by: [asc: :provider]
      )

    Map.merge(admin_user_json(user), %{
      email: user.email,
      email_unverified: user.email_unverified,
      registered_ip: user.registered_ip,
      timezone: user.timezone,
      locale: user.locale,
      oauth_accounts:
        Enum.map(oauth_accounts, fn oa ->
          %{
            id: oa.id,
            provider: oa.provider,
            provider_uid: oa.provider_uid,
            provider_email: oa.provider_email,
            provider_name: oa.provider_name,
            provider_avatar: oa.provider_avatar,
            linked_at: oa.inserted_at
          }
        end),
      infractions: %{
        active_bans: length(Map.get(infractions, :bans, [])),
        active_warnings: length(Map.get(infractions, :warnings, [])),
        active_points: Map.get(infractions, :active_points, 0),
        restriction: Map.get(infractions, :restriction)
      },
      groups:
        (case user.groups do
          %Ecto.Association.NotLoaded{} -> []
          list -> Enum.map(list, fn g -> %{id: g.id, name: g.name, is_staff: g.is_staff} end)
        end),
      group_ids:
        (case user.groups do
          %Ecto.Association.NotLoaded{} -> []
          list -> Enum.map(list, & &1.id)
        end)
    })
  end

  defp parse_int(params, key, default) do
    case Map.get(params, key) do
      nil -> default
      val when is_binary(val) -> safe_to_integer(val, default)
      val when is_integer(val) -> val
    end
  end

  defp changeset_errors(%Ecto.Changeset{} = cs), do: Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)
  defp changeset_errors(err), do: inspect(err)

  defp safe_to_integer(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> default
    end
  end
  defp safe_to_integer(val, _default) when is_integer(val), do: val
  defp safe_to_integer(_, default), do: default

end
