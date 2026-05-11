defmodule ForgeNexus.Repo.Migrations.AddCustomizationFields do
  use Ecto.Migration

  def change do
    # Site settings table
    create table(:site_settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :value, :string
      add :value_type, :string, default: "string"

      timestamps()
    end

    create unique_index(:site_settings, [:key])

    # User customization fields
    alter table(:users) do
      add :post_background_url, :string
      add :post_background_opacity, :float, default: 0.15
      add :postbit_background_url, :string
      add :postbit_background_opacity, :float, default: 0.15
      add :signature_background_url, :string
      add :signature_html, :text
      add :username_color, :string
      add :username_effect, :string, default: "none"
    end

    # UserGroup styling fields
    alter table(:user_groups) do
      add :username_color, :string
      add :username_effect, :string, default: "none"
    end

    # Copy existing group color to username_color
    execute "UPDATE user_groups SET username_color = color WHERE color IS NOT NULL", ""
  end
end
