defmodule ForgeNexus.Repo.Migrations.AlignProgressionSystemTables do
  use Ecto.Migration

  def up do
    alter table(:item_templates) do
      add_if_not_exists :is_equippable, :boolean, default: false
    end

    create_if_not_exists table(:inventory_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :item_template_id,
          references(:item_templates, type: :binary_id, on_delete: :delete_all), null: false

      add :quantity, :integer, default: 1
      add :is_equipped, :boolean, default: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create_if_not_exists index(:inventory_items, [:user_id, :item_template_id])

    alter table(:crafting_recipes) do
      add_if_not_exists :description, :text
      add_if_not_exists :ingredients, {:array, :map}, default: []
      add_if_not_exists :is_active, :boolean, default: true
    end

    alter table(:quests) do
      modify :slug, :string, null: true
      add_if_not_exists :icon, :string
      add_if_not_exists :steps, {:array, :map}, default: []
      add_if_not_exists :rewards, :map, default: %{}
      add_if_not_exists :is_daily, :boolean, default: false
      add_if_not_exists :is_active, :boolean, default: true
      add_if_not_exists :sort_order, :integer, default: 0
    end

    alter table(:user_quests) do
      add_if_not_exists :progress_data, :map, default: %{}
    end

    alter table(:collection_sets) do
      modify :slug, :string, null: true
      add_if_not_exists :is_active, :boolean, default: true
    end

    alter table(:collection_items) do
      add_if_not_exists :sort_order, :integer, default: 0
    end

    create_if_not_exists table(:user_collections, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :collection_item_id,
          references(:collection_items, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create_if_not_exists unique_index(:user_collections, [:user_id, :collection_item_id])

    alter table(:pet_templates) do
      add_if_not_exists :species, :string

      add_if_not_exists :evolves_into_id,
                        references(:pet_templates, type: :binary_id, on_delete: :nilify_all)
    end

    create_if_not_exists table(:pets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :pet_template_id, references(:pet_templates, type: :binary_id, on_delete: :delete_all),
        null: false

      add :nickname, :string, null: false
      add :experience, :integer, default: 0
      add :level, :integer, default: 1
      add :hunger, :integer, default: 100
      add :happiness, :integer, default: 100
      add :energy, :integer, default: 100
      add :is_active, :boolean, default: false

      timestamps()
    end

    create_if_not_exists index(:pets, [:user_id])
  end

  def down do
    drop_if_exists table(:pets)
    drop_if_exists table(:user_collections)
    drop_if_exists table(:inventory_items)
  end
end
