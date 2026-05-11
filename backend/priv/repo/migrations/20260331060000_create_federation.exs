defmodule ForgeNexus.Repo.Migrations.CreateFederation do
  use Ecto.Migration

  def change do
    # Instance signing keypairs
    create table(:instance_keypairs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :public_key, :text, null: false
      add :private_key_encrypted, :binary, null: false
      add :is_active, :boolean, default: true

      timestamps()
    end

    # Known ForgeNexus/Fediverse instances
    create table(:federated_instances, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :domain, :string, null: false
      add :name, :string
      add :description, :text
      add :public_key, :text
      add :software, :string
      add :software_version, :string
      add :trust_level, :string, default: "untrusted"
      add :status, :string, default: "pending"
      add :last_seen_at, :utc_datetime
      add :stats, :map, default: %{}

      timestamps()
    end

    create unique_index(:federated_instances, [:domain])

    # Cross-instance user mappings
    create table(:federated_identities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :local_user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :remote_instance_id, references(:federated_instances, type: :binary_id, on_delete: :delete_all)
      add :remote_user_id, :string, null: false
      add :remote_username, :string
      add :remote_display_name, :string
      add :portable_reputation, :map, default: %{}
      add :last_synced_at, :utc_datetime

      timestamps()
    end

    create index(:federated_identities, [:local_user_id])
    create index(:federated_identities, [:remote_instance_id])
    create unique_index(:federated_identities, [:local_user_id, :remote_instance_id])
    create unique_index(:federated_identities, [:remote_instance_id, :remote_user_id])

    # ActivityPub actors (local forums/users mapped to AP)
    create table(:ap_actors, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :uri, :string, null: false
      add :type, :string, null: false
      add :local_forum_id, references(:forums, type: :binary_id, on_delete: :delete_all)
      add :local_user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :inbox_url, :string, null: false
      add :outbox_url, :string, null: false
      add :followers_url, :string
      add :public_key_pem, :text
      add :private_key_pem_encrypted, :binary
      add :followers_count, :integer, default: 0
      add :following_count, :integer, default: 0
      add :is_local, :boolean, default: true

      timestamps()
    end

    create unique_index(:ap_actors, [:uri])
    create index(:ap_actors, [:local_forum_id])
    create index(:ap_actors, [:local_user_id])
    create index(:ap_actors, [:type])

    # ActivityPub objects (posts, threads, activities)
    create table(:ap_objects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :uri, :string, null: false
      add :type, :string, null: false
      add :data, :map, null: false
      add :local_post_id, references(:posts, type: :binary_id, on_delete: :delete_all)
      add :local_thread_id, references(:threads, type: :binary_id, on_delete: :delete_all)
      add :actor_id, references(:ap_actors, type: :binary_id, on_delete: :delete_all)
      add :is_local, :boolean, default: true

      timestamps()
    end

    create unique_index(:ap_objects, [:uri])
    create index(:ap_objects, [:local_post_id])
    create index(:ap_objects, [:local_thread_id])
    create index(:ap_objects, [:actor_id])
    create index(:ap_objects, [:type])

    # AP follower relationships
    create table(:ap_followers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :actor_id, references(:ap_actors, type: :binary_id, on_delete: :delete_all)
      add :follower_uri, :string, null: false
      add :follower_inbox, :string, null: false
      add :accepted, :boolean, default: false

      timestamps()
    end

    create index(:ap_followers, [:actor_id])
    create unique_index(:ap_followers, [:actor_id, :follower_uri])

    # Outgoing activity delivery tracking
    create table(:ap_delivery_queue, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :object_id, references(:ap_objects, type: :binary_id, on_delete: :delete_all)
      add :target_inbox, :string, null: false
      add :status, :string, default: "pending"
      add :attempts, :integer, default: 0
      add :last_attempted_at, :utc_datetime
      add :error, :text

      timestamps()
    end

    create index(:ap_delivery_queue, [:object_id])
    create index(:ap_delivery_queue, [:status])
    create index(:ap_delivery_queue, [:target_inbox])

    # Federation policy configuration
    create table(:federation_policies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :mode, :string, default: "closed"
      add :allowed_domains, {:array, :string}, default: []
      add :blocked_domains, {:array, :string}, default: []
      add :auto_accept_follows, :boolean, default: false
      add :share_user_profiles, :boolean, default: false

      timestamps()
    end
  end
end
