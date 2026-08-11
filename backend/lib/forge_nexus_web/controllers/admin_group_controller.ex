defmodule ForgeNexusWeb.AdminGroupController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Accounts
  alias ForgeNexus.Admin

  # Groups

  def list_groups(conn, _params) do
    groups = Accounts.list_groups()
    conn |> json(%{groups: Enum.map(groups, &group_json/1)})
  end

  def create_group(conn, %{"group" => group_params}) do
    case Accounts.create_group(group_params |> atomize_keys()) do
      {:ok, group} ->
        admin = Guardian.Plug.current_resource(conn)

        Admin.log_admin_action(admin.id, %{
          action: "group_created",
          category: "permissions",
          target_type: "group",
          target_id: group.id,
          description: "Created group #{group.name}"
        })

        conn |> put_status(:created) |> json(%{group: group_json(group)})

      {:error, cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(cs)})
    end
  end

  def update_group(conn, %{"id" => id, "group" => group_params}) do
    group = Accounts.get_group!(id)
    previous = %{"name" => group.name, "permissions" => group.permissions}

    attrs = group_params |> atomize_keys()

    case ForgeNexus.Repo.update(ForgeNexus.Accounts.UserGroup.admin_changeset(group, attrs)) do
      {:ok, updated} ->
        admin = Guardian.Plug.current_resource(conn)

        Admin.log_admin_action(admin.id, %{
          action: "group_updated",
          category: "permissions",
          target_type: "group",
          target_id: id,
          description: "Updated group #{group.name}",
          previous_state: previous,
          new_state: group_params
        })

        conn |> json(%{group: group_json(updated)})

      {:error, cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(cs)})
    end
  end

  def delete_group(conn, %{"id" => id}) do
    group = Accounts.get_group!(id)

    if group.is_default do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{error: "Cannot delete the default group"})
    else
      case ForgeNexus.Repo.delete(group) do
        {:ok, _} ->
          admin = Guardian.Plug.current_resource(conn)

          Admin.log_admin_action(admin.id, %{
            action: "group_deleted",
            category: "permissions",
            target_type: "group",
            target_id: id,
            description: "Deleted group #{group.name}"
          })

          conn |> json(%{ok: true})

        {:error, _} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete group"})
      end
    end
  end

  def default_permissions(conn, _params) do
    conn |> json(%{permissions: Accounts.default_permissions()})
  end

  def list_members(conn, %{"id" => id} = params) do
    import Ecto.Query
    limit = parse_int(params, "limit", 50)
    offset = parse_int(params, "offset", 0)

    case Ecto.UUID.cast(id) do
      :error ->
        conn |> put_status(:bad_request) |> json(%{error: "Invalid group id"})

      {:ok, uuid} ->
        members =
          ForgeNexus.Repo.all(
            from gm in "user_group_memberships",
              join: u in ForgeNexus.Accounts.User,
              on: u.id == gm.user_id,
              where: gm.group_id == type(^uuid, :binary_id),
              limit: ^limit,
              offset: ^offset,
              order_by: [asc: u.username],
              select: %{
                id: u.id,
                username: u.username,
                slug: u.slug,
                avatar_url: u.avatar_url,
                inserted_at: u.inserted_at
              }
          )

        total =
          ForgeNexus.Repo.one(
            from gm in "user_group_memberships",
              where: gm.group_id == type(^uuid, :binary_id),
              select: count(gm.user_id)
          ) || 0

        conn |> json(%{members: members, total: total, limit: limit, offset: offset})
    end
  end

  def add_member(conn, %{"id" => group_id, "user_id" => user_id}) do
    Accounts.add_user_to_group(user_id, group_id)
    conn |> json(%{ok: true})
  end

  def remove_member(conn, %{"id" => group_id, "user_id" => user_id}) do
    import Ecto.Query

    with {:ok, gid} <- Ecto.UUID.cast(group_id),
         {:ok, uid} <- Ecto.UUID.cast(user_id) do
      ForgeNexus.Repo.delete_all(
        from gm in "user_group_memberships",
          where: gm.group_id == type(^gid, :binary_id) and gm.user_id == type(^uid, :binary_id)
      )

      conn |> json(%{ok: true})
    else
      :error ->
        conn |> put_status(:bad_request) |> json(%{error: "Invalid id"})
    end
  end

  # Ranks

  def list_ranks(conn, _params) do
    ranks = Accounts.list_ranks()
    conn |> json(%{ranks: Enum.map(ranks, &rank_json/1)})
  end

  def create_rank(conn, %{"rank" => rank_params}) do
    case ForgeNexus.Repo.insert(
           ForgeNexus.Accounts.Rank.changeset(
             %ForgeNexus.Accounts.Rank{},
             atomize_keys(rank_params)
           )
         ) do
      {:ok, rank} ->
        conn |> put_status(:created) |> json(%{rank: rank_json(rank)})

      {:error, cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(cs)})
    end
  end

  def update_rank(conn, %{"id" => id, "rank" => rank_params}) do
    rank = ForgeNexus.Repo.get!(ForgeNexus.Accounts.Rank, id)

    case ForgeNexus.Repo.update(
           ForgeNexus.Accounts.Rank.changeset(rank, atomize_keys(rank_params))
         ) do
      {:ok, updated} ->
        conn |> json(%{rank: rank_json(updated)})

      {:error, cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(cs)})
    end
  end

  def delete_rank(conn, %{"id" => id}) do
    rank = ForgeNexus.Repo.get!(ForgeNexus.Accounts.Rank, id)

    case ForgeNexus.Repo.delete(rank) do
      {:ok, _} ->
        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete rank"})
    end
  end

  # Helpers

  defp group_json(g) do
    %{
      id: g.id,
      name: g.name,
      slug: g.slug,
      description: g.description,
      color: g.color,
      icon: g.icon,
      is_default: g.is_default,
      is_staff: g.is_staff,
      position: g.position,
      permissions: g.permissions,
      username_color: g.username_color,
      username_effect: g.username_effect,
      inserted_at: g.inserted_at
    }
  end

  defp rank_json(r) do
    %{
      id: r.id,
      name: r.name,
      min_posts: r.min_posts,
      icon: r.icon,
      color: r.color,
      position: r.position
    }
  end

  defp atomize_keys(map) do
    Map.new(map, fn {k, v} ->
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      {key, v}
    end)
  rescue
    _ -> map
  end

  defp parse_int(params, key, default) do
    case Map.get(params, key) do
      nil -> default
      val when is_binary(val) -> safe_to_integer(val, default)
      val when is_integer(val) -> val
    end
  end

  defp changeset_errors(%Ecto.Changeset{} = cs),
    do: Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)

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
