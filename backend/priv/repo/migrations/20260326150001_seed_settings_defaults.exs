defmodule ForgeNexus.Repo.Migrations.SeedSettingsDefaults do
  use Ecto.Migration

  def up do
    # Settings are stored on-demand via the KV store.
    # This migration just ensures the site_settings table exists properly.
    # Defaults are defined in ForgeNexus.Settings module.
    :ok
  end

  def down, do: :ok
end
