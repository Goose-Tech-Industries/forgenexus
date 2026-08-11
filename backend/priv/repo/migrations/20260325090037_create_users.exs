defmodule ForgeNexus.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    # User groups (Admin, Moderator, Member, etc.)
    create table(:user_groups, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :color, :string
      add :icon, :string
      add :is_default, :boolean, default: false
      add :is_staff, :boolean, default: false
      add :position, :integer, default: 0
      add :permissions, :map, default: %{}

      timestamps()
    end

    create unique_index(:user_groups, [:slug])

    # Users
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :username, :string, null: false
      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :display_name, :string
      add :slug, :string, null: false
      add :avatar_url, :string
      add :signature, :text
      add :bio, :text
      add :location, :string
      add :website, :string
      add :date_of_birth, :date
      add :post_count, :integer, default: 0
      add :thread_count, :integer, default: 0
      add :reputation, :integer, default: 0
      add :trust_level, :integer, default: 0
      add :status, :string, default: "active"
      add :is_online, :boolean, default: false
      add :last_seen_at, :utc_datetime
      add :last_post_at, :utc_datetime
      add :registered_ip, :string
      add :timezone, :string, default: "UTC"
      add :locale, :string, default: "en"
      add :theme, :string, default: "dark"
      add :content_density, :string, default: "comfortable"
      add :primary_group_id, references(:user_groups, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:users, [:username])
    create unique_index(:users, [:email])
    create unique_index(:users, [:slug])
    create index(:users, [:primary_group_id])
    create index(:users, [:status])
    create index(:users, [:last_seen_at])

    # Secondary group memberships
    create table(:user_group_memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :group_id, references(:user_groups, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create unique_index(:user_group_memberships, [:user_id, :group_id])

    # Ranks
    create table(:ranks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :min_posts, :integer
      add :image_url, :string
      add :position, :integer, default: 0

      timestamps()
    end
  end
end
