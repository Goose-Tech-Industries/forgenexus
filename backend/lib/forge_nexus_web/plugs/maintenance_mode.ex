defmodule ForgeNexusWeb.Plugs.MaintenanceMode do
  @moduledoc """
  Plug that returns 503 for non-admin users when maintenance mode is enabled.
  Admin users and the auth/settings endpoints are always allowed through.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if ForgeNexus.Settings.get_bool("maintenance_mode") do
      # Always allow auth and public settings endpoints
      if bypass_path?(conn.request_path) do
        conn
      else
        # Check if user is admin
        user = Guardian.Plug.current_resource(conn)

        if user && ForgeNexus.Moderation.is_staff?(user) do
          conn
        else
          message = ForgeNexus.Settings.get("maintenance_message") || "We'll be back soon."

          conn
          |> put_status(:service_unavailable)
          |> Phoenix.Controller.json(%{
            error: "maintenance",
            message: message
          })
          |> halt()
        end
      end
    else
      conn
    end
  end

  defp bypass_path?(path) do
    path in ["/api/auth/login", "/api/auth/me", "/api/settings/public"]
  end
end
