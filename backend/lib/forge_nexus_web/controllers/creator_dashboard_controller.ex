defmodule ForgeNexusWeb.CreatorDashboardController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Voice.CreatorDashboard

  def show(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    days = parse_int(params["days"], 30)

    dashboard = CreatorDashboard.get_dashboard(user.id, days: days)

    conn |> json(%{dashboard: dashboard})
  end

  defp parse_int(nil, default), do: default

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      _ -> default
    end
  end

  defp parse_int(val, _) when is_integer(val), do: val
  defp parse_int(_, default), do: default
end
