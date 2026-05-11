defmodule ForgeNexusWeb.MarketplaceController do
  use ForgeNexusWeb, :controller

  import Ecto.Query
  alias ForgeNexus.Repo

  # --- Templates ---

  def list_templates(conn, params) do
    category = params["category"]
    limit = parse_int(params["limit"], 30)

    query =
      from(t in "community_templates",
        where: t.is_published == true,
        order_by: [desc: :install_count],
        limit: ^limit,
        select: %{
          id: type(t.id, :binary_id),
          name: t.name,
          description: t.description,
          category: t.category,
          preview_url: t.preview_url,
          price_cents: t.price_cents,
          is_free: t.is_free,
          install_count: t.install_count,
          rating: t.rating,
          creator_id: type(t.creator_id, :binary_id),
          inserted_at: t.inserted_at
        }
      )

    query = if category, do: where(query, [t], t.category == ^category), else: query
    templates = Repo.all(query)
    conn |> json(%{templates: templates})
  end

  def show_template(conn, %{"id" => id}) do
    template =
      from(t in "community_templates",
        where: t.id == type(^id, :binary_id) and t.is_published == true,
        select: %{
          id: type(t.id, :binary_id),
          name: t.name,
          description: t.description,
          category: t.category,
          preview_url: t.preview_url,
          price_cents: t.price_cents,
          is_free: t.is_free,
          install_count: t.install_count,
          rating: t.rating,
          template_data: t.template_data,
          inserted_at: t.inserted_at
        }
      )
      |> Repo.one()

    if template do
      conn |> json(%{template: template})
    else
      conn |> put_status(:not_found) |> json(%{error: "Template not found"})
    end
  end

  # --- Plugins ---

  def list_plugins(conn, params) do
    limit = parse_int(params["limit"], 30)

    plugins =
      from(p in "js_plugins",
        where: p.is_marketplace == true,
        order_by: [desc: :install_count],
        limit: ^limit,
        select: %{
          id: type(p.id, :binary_id),
          name: p.name,
          description: p.description,
          price_cents: p.price_cents,
          install_count: p.install_count,
          rating: p.rating,
          inserted_at: p.inserted_at
        }
      )
      |> Repo.all()

    conn |> json(%{plugins: plugins})
  end

  def show_plugin(conn, %{"id" => id}) do
    plugin =
      from(p in "js_plugins",
        where: p.id == type(^id, :binary_id) and p.is_marketplace == true,
        select: %{
          id: type(p.id, :binary_id),
          name: p.name,
          description: p.description,
          price_cents: p.price_cents,
          install_count: p.install_count,
          rating: p.rating,
          revenue_share_percent: p.revenue_share_percent,
          inserted_at: p.inserted_at
        }
      )
      |> Repo.one()

    if plugin do
      conn |> json(%{plugin: plugin})
    else
      conn |> put_status(:not_found) |> json(%{error: "Plugin not found"})
    end
  end

  defp parse_int(nil, default), do: default
  defp parse_int(val, _) when is_integer(val), do: val
  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      _ -> default
    end
  end
  defp parse_int(_, default), do: default
end
