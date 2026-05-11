defmodule ForgeNexusWeb.ThemeController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Themes

  # GET /themes — list active themes
  def index(conn, _params) do
    themes = Themes.list_active_themes()
    conn |> json(%{themes: Enum.map(themes, &theme_json/1)})
  end

  # GET /themes/:id — single theme
  def show(conn, %{"id" => id}) do
    theme = Themes.get_theme!(id)
    conn |> json(%{theme: theme_json(theme)})
  end

  # POST /admin/themes — create theme (admin only)
  def create(conn, %{"theme" => theme_params}) do
    user = Guardian.Plug.current_resource(conn)
    theme_params = Map.put(theme_params, "created_by_id", user.id)

    case Themes.create_theme(theme_params) do
      {:ok, theme} ->
        conn |> put_status(:created) |> json(%{theme: theme_json(theme)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  # PUT /admin/themes/:id — update theme (admin only)
  def update(conn, %{"id" => id, "theme" => theme_params}) do
    theme = Themes.get_theme!(id)

    case Themes.update_theme(theme, theme_params) do
      {:ok, updated} ->
        conn |> json(%{theme: theme_json(updated)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  defp theme_json(theme) do
    %{
      id: theme.id,
      name: theme.name,
      slug: theme.slug,
      description: theme.description,
      is_default: theme.is_default,
      variables: theme.variables,
      position: theme.position
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
