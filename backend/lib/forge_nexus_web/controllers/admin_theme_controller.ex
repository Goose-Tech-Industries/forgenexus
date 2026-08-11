defmodule ForgeNexusWeb.AdminThemeController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.{Themes, Admin}

  def index(conn, _params) do
    themes = Themes.list_active_themes()
    conn |> json(%{themes: Enum.map(themes, &theme_json/1)})
  end

  def create(conn, %{"theme" => params}) do
    case Themes.create_theme(atomize_keys(params)) do
      {:ok, theme} ->
        admin = Guardian.Plug.current_resource(conn)

        Admin.log_admin_action(admin.id, %{
          action: "theme_created",
          category: "themes",
          target_type: "theme",
          target_id: theme.id,
          description: "Created theme #{theme.name}",
          new_state: params
        })

        conn |> put_status(:created) |> json(%{theme: theme_json(theme)})

      {:error, cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: cs_errors(cs)})
    end
  end

  def update(conn, %{"id" => id, "theme" => params}) do
    theme = Themes.get_theme!(id)

    case Themes.update_theme(theme, atomize_keys(params)) do
      {:ok, updated} ->
        admin = Guardian.Plug.current_resource(conn)

        Admin.log_admin_action(admin.id, %{
          action: "theme_changed",
          category: "themes",
          target_type: "theme",
          target_id: id,
          description: "Updated theme #{theme.name}"
        })

        conn |> json(%{theme: theme_json(updated)})

      {:error, cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: cs_errors(cs)})
    end
  end

  def delete(conn, %{"id" => id}) do
    theme = Themes.get_theme!(id)

    if theme.is_default do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{error: "Cannot delete the default theme"})
    else
      case Themes.delete_theme(theme) do
        {:ok, _} ->
          admin = Guardian.Plug.current_resource(conn)

          Admin.log_admin_action(admin.id, %{
            action: "theme_deleted",
            category: "themes",
            target_type: "theme",
            target_id: id,
            description: "Deleted theme #{theme.name}"
          })

          conn |> json(%{ok: true})

        {:error, _} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete theme"})
      end
    end
  end

  def set_default(conn, %{"id" => id}) do
    import Ecto.Query

    ForgeNexus.Repo.update_all(from(t in "themes", where: t.is_default == true),
      set: [is_default: false]
    )

    theme = Themes.get_theme!(id)

    case ForgeNexus.Repo.update(Ecto.Changeset.change(theme, is_default: true)) do
      {:ok, updated} ->
        admin = Guardian.Plug.current_resource(conn)

        Admin.log_admin_action(admin.id, %{
          action: "theme_changed",
          category: "themes",
          target_type: "theme",
          target_id: id,
          description: "Set #{theme.name} as default theme"
        })

        conn |> json(%{theme: theme_json(updated)})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to set default"})
    end
  end

  defp theme_json(t) do
    %{
      id: t.id,
      name: t.name,
      slug: t.slug,
      is_active: t.is_active,
      is_default: t.is_default,
      position: t.position,
      colors:
        Map.drop(Map.from_struct(t), [
          :__meta__,
          :id,
          :name,
          :slug,
          :is_active,
          :is_default,
          :position,
          :inserted_at,
          :updated_at
        ]),
      inserted_at: t.inserted_at
    }
  end

  defp atomize_keys(map),
    do:
      Map.new(map, fn
        {k, v} when is_binary(k) ->
          try do
            {String.to_existing_atom(k), v}
          rescue
            _ -> {k, v}
          end

        {k, v} ->
          {k, v}
      end)

  defp cs_errors(%Ecto.Changeset{} = cs),
    do: Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)

  defp cs_errors(err), do: inspect(err)
end
