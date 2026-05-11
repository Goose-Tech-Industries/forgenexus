defmodule ForgeNexus.Repo.Migrations.CreateCommunityAnalyticsAndSpaces do
  use Ecto.Migration

  def change do
    # Community Stats Daily
    create table(:community_stats_daily, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :date, :date, null: false
      add :new_members, :integer, default: 0
      add :active_members, :integer, default: 0
      add :posts_created, :integer, default: 0
      add :threads_created, :integer, default: 0
      add :avg_reply_time_minutes, :float
      add :response_rate, :float
      add :top_topics, :map, default: "[]"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:community_stats_daily, [:date])

    # Community Maps
    create table(:community_maps, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :is_default, :boolean, default: false
      add :background_image_url, :string
      add :width, :integer, default: 1920
      add :height, :integer, default: 1080
      add :is_active, :boolean, default: true
      add :config, :map, default: "{}"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:community_maps, [:slug])
    create index(:community_maps, [:is_active])

    # Map Rooms
    create table(:map_rooms, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :map_id, references(:community_maps, type: :binary_id, on_delete: :delete_all)
      add :name, :string, null: false
      add :type, :string, null: false
      add :linked_resource_type, :string
      add :linked_resource_id, :binary_id
      add :x, :integer, null: false
      add :y, :integer, null: false
      add :width, :integer, default: 200
      add :height, :integer, default: 150
      add :shape, :string, default: "rect"
      add :style, :map, default: "{}"
      add :max_occupancy, :integer
      add :config, :map, default: "{}"

      timestamps(type: :utc_datetime)
    end

    create index(:map_rooms, [:map_id])
    create index(:map_rooms, [:type])
    create index(:map_rooms, [:linked_resource_type, :linked_resource_id])

    # User Map Positions
    create table(:user_map_positions, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :map_id, references(:community_maps, type: :binary_id, on_delete: :delete_all)
      add :room_id, references(:map_rooms, type: :binary_id, on_delete: :nilify_all)
      add :x, :float, null: false, default: 0.0
      add :y, :float, null: false, default: 0.0
      add :last_moved_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_map_positions, [:user_id, :map_id])
    create index(:user_map_positions, [:map_id])
    create index(:user_map_positions, [:room_id])
  end
end
