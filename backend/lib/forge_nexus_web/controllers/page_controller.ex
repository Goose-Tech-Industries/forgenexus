defmodule ForgeNexusWeb.PageController do
  use ForgeNexusWeb, :controller
  import Ecto.Query

  alias ForgeNexus.Repo
  alias ForgeNexus.Plugins.PluginPage

  def show(conn, %{"slug" => slug}) do
    case Repo.one(from p in PluginPage, where: p.slug == ^slug and p.is_published == true) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Page not found"})
      page -> conn |> json(%{page: page_json(page)})
    end
  end

  def list(conn, _params) do
    pages = Repo.all(from p in PluginPage, order_by: [asc: :nav_position, asc: :title])
    conn |> json(%{pages: Enum.map(pages, &page_json/1)})
  end

  def create(conn, %{"page" => attrs}) when is_map(attrs) do
    case %PluginPage{}
         |> PluginPage.changeset(atomize_keys(attrs))
         |> Repo.insert() do
      {:ok, page} -> conn |> put_status(:created) |> json(%{page: page_json(page)})
      {:error, cs} -> conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(cs.errors)})
    end
  end

  def create(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "page object required"})
  end

  def update(conn, %{"id" => id, "page" => attrs}) when is_map(attrs) do
    case Repo.get(PluginPage, id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Page not found"})

      page ->
        case page |> PluginPage.changeset(atomize_keys(attrs)) |> Repo.update() do
          {:ok, page} -> conn |> json(%{page: page_json(page)})
          {:error, cs} -> conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(cs.errors)})
        end
    end
  end

  def update(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "page object required"})
  end

  def delete(conn, %{"id" => id}) do
    case Repo.get(PluginPage, id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Page not found"})
      page ->
        Repo.delete!(page)
        conn |> json(%{ok: true})
    end
  end

  defp page_json(page) do
    %{
      id: page.id,
      slug: page.slug,
      title: page.title,
      description: page.description,
      template: page.template,
      is_published: page.is_published,
      nav_position: page.nav_position,
      nav_label: page.nav_label,
      inserted_at: page.inserted_at,
      updated_at: page.updated_at
    }
  end

  defp atomize_keys(attrs) when is_map(attrs) do
    Map.new(attrs, fn {k, v} -> {String.to_existing_atom(k), v} end)
  rescue
    _ -> attrs
  end

  defp atomize_keys(attrs), do: attrs
end
