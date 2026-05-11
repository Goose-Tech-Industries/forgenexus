defmodule ForgeNexusWeb.Plugs.SetupRequired do
  @moduledoc """
  Plug that blocks all API routes (except /api/setup/*) when the site
  has not been set up yet. Returns 503 with a setup_url hint so the
  frontend can redirect to the installer.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if bypass_path?(conn.request_path) do
      conn
    else
      if ForgeNexus.Setup.installed?() do
        conn
      else
        conn
        |> put_status(:service_unavailable)
        |> Phoenix.Controller.json(%{
          error: "Setup required",
          setup_url: "/setup"
        })
        |> halt()
      end
    end
  end

  defp bypass_path?(path) do
    String.starts_with?(path, "/api/setup") or path == "/api/health"
  end
end
