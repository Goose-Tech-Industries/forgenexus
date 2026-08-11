defmodule ForgeNexusWeb.ForumPermissionController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.{Forums, Admin}

  def index(conn, %{"id" => forum_id}) do
    permissions = Forums.list_forum_permissions(forum_id)
    conn |> json(%{permissions: permissions})
  end

  def update(conn, %{"id" => forum_id, "permissions" => permissions_list}) do
    admin = Guardian.Plug.current_resource(conn)

    results =
      Enum.map(permissions_list, fn perm ->
        group_id = perm["group_id"]

        perms = %{
          can_view: Map.get(perm, "can_view", true),
          can_post: Map.get(perm, "can_post", true),
          can_create_threads: Map.get(perm, "can_create_threads", true)
        }

        Forums.set_forum_permissions(forum_id, group_id, perms)
      end)

    if Enum.all?(results, fn {status, _} -> status == :ok end) do
      Admin.log_admin_action(admin.id, %{
        action: "forum_permissions_updated",
        category: "forums",
        target_type: "forum",
        target_id: forum_id,
        description: "Updated forum permissions"
      })

      permissions = Forums.list_forum_permissions(forum_id)
      conn |> json(%{ok: true, permissions: permissions})
    else
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{error: "Failed to update some permissions"})
    end
  end
end
