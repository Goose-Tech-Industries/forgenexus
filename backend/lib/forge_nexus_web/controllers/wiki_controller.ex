defmodule ForgeNexusWeb.WikiController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Wiki

  def categories(conn, _params) do
    cats = Wiki.list_categories()

    conn
    |> json(%{
      categories:
        Enum.map(cats, fn c ->
          %{id: c.id, name: c.name, slug: c.slug, description: c.description, icon: c.icon, position: c.position}
        end)
    })
  end

  def index(conn, params) do
    category_id = Map.get(params, "category_id")

    pages =
      case category_id do
        nil -> []
        id -> Wiki.list_pages(id)
      end

    conn |> json(%{pages: Enum.map(pages, &page_json/1)})
  end

  def show(conn, %{"slug" => slug}) do
    case fetch_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "wiki page not found"})

      page ->
        _ = Wiki.increment_view_count(page)
        conn |> json(%{page: page_json(page, include_body: true)})
    end
  rescue
    Ecto.NoResultsError ->
      conn |> put_status(:not_found) |> json(%{error: "wiki page not found"})
  end

  def revisions(conn, %{"slug" => slug}) do
    case fetch_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "wiki page not found"})

      page ->
        revs = Wiki.get_revisions(page.id)

        conn
        |> json(%{
          page_id: page.id,
          revisions:
            Enum.map(revs, fn r ->
              %{
                id: r.id,
                revision_number: r.revision_number,
                edit_summary: r.edit_summary,
                edited_by_id: r.edited_by_id,
                inserted_at: r.inserted_at
              }
            end)
        })
    end
  rescue
    Ecto.NoResultsError ->
      conn |> put_status(:not_found) |> json(%{error: "wiki page not found"})
  end

  def search(conn, %{"q" => q}) do
    pages = Wiki.search_pages(q)
    conn |> json(%{results: Enum.map(pages, &page_json/1)})
  end

  def search(conn, _params), do: conn |> json(%{results: []})

  defp fetch_by_slug(slug) do
    Wiki.get_page_by_slug!(slug)
  rescue
    Ecto.NoResultsError -> nil
  end

  defp page_json(page, opts \\ []) do
    base = %{
      id: page.id,
      title: page.title,
      slug: page.slug,
      category_id: page.category_id,
      is_published: page.is_published,
      is_locked: page.is_locked,
      view_count: page.view_count,
      updated_at: page.updated_at
    }

    if Keyword.get(opts, :include_body, false) do
      Map.merge(base, %{body: page.body, body_html: page.body_html})
    else
      base
    end
  end
end
