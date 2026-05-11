defmodule ForgeNexusWeb.AdminSettingsController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Settings

  def index(conn, _params) do
    grouped = Settings.get_all_grouped()
    conn |> json(%{settings: grouped, categories: Settings.categories()})
  end

  def update(conn, %{"settings" => settings_map}) when is_map(settings_map) do
    Settings.set_many(settings_map)

    user = Guardian.Plug.current_resource(conn)
    ForgeNexus.Admin.log_admin_action(user.id, %{
      action: "setting_changed", category: "settings",
      target_type: "setting",
      description: "Updated #{map_size(settings_map)} setting(s): #{settings_map |> Map.keys() |> Enum.join(", ")}",
      new_state: settings_map
    })

    grouped = Settings.get_all_grouped()
    conn |> json(%{settings: grouped})
  end
end
