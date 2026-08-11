defmodule ForgeNexusWeb.ActivityHeatmapController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.{Accounts, Forums}

  def show(conn, %{"slug" => slug}) do
    case Accounts.get_user_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "User not found"})

      user ->
        heatmap_data = Forums.user_activity_heatmap(user.id)

        entries =
          Enum.map(heatmap_data, fn %{date: date, count: count} ->
            %{date: Date.to_iso8601(date), count: count}
          end)

        conn |> json(%{heatmap: entries})
    end
  end
end
