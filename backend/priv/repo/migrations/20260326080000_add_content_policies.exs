defmodule ForgeNexus.Repo.Migrations.AddContentPolicies do
  use Ecto.Migration

  def change do
    create table(:content_policies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :is_active, :boolean, default: false, null: false
      add :ai_moderation_enabled, :boolean, default: false, null: false
      add :rules, :map, default: %{}, null: false
      add :escalation_overrides, :map, default: %{}, null: false
      add :forum_id, references(:forums, type: :binary_id, on_delete: :delete_all)
      add :category_id, references(:categories, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create index(:content_policies, [:forum_id])
    create index(:content_policies, [:category_id])
    create index(:content_policies, [:is_active])
  end
end
