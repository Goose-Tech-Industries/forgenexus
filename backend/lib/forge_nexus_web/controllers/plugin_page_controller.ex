defmodule ForgeNexusWeb.PluginPageController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Plugins

  def show(conn, %{"slug" => slug}) do
    page = Plugins.get_page_by_slug!(slug)

    if page.is_published do
      conn
      |> json(%{
        page: %{
          id: page.id,
          slug: page.slug,
          title: page.title,
          description: page.description,
          template: page.template,
          nav_label: page.nav_label
        }
      })
    else
      conn |> put_status(:not_found) |> json(%{error: "Page not found"})
    end
  end

  def widgets(conn, %{"placement" => placement}) do
    widgets = Plugins.get_widgets_for_placement(placement)

    conn
    |> json(%{
      widgets:
        Enum.map(widgets, fn w ->
          %{
            id: w.id,
            placement: w.placement,
            template: w.template,
            priority: w.priority,
            conditions: w.conditions
          }
        end)
    })
  end
end
