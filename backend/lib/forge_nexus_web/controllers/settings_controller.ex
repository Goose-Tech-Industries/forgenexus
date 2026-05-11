defmodule ForgeNexusWeb.SettingsController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Settings

  def public(conn, _params) do
    settings = Settings.public_settings()
    conn |> json(%{settings: settings})
  end
end
