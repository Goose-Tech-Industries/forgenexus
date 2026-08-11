defmodule ForgeNexus.Repo.Migrations.ForgeCodesAndSotaProfile do
  use Ecto.Migration

  def change do
    # ---- SOTA profile columns on users ----
    alter table(:users) do
      add :pronouns, :string
      add :social_links, :map, default: %{}
      add :profile_vibe, :string
      add :avatar_3d_url, :string
      add :verified_creator_at, :utc_datetime
      add :pinned_thread_id, :binary_id
      add :seasonal_decorations_enabled, :boolean, null: false, default: true

      # Per-field visibility: "public" | "members" | "friends" | "private"
      add :birthday_visibility, :string, null: false, default: "members"
      add :location_visibility, :string, null: false, default: "public"
      add :email_visibility, :string, null: false, default: "private"
      add :activity_visibility, :string, null: false, default: "public"

      # Opaque short Forge Code currently applied to this profile (if any)
      add :active_forge_code, :string

      # Per-profile reader-mode opt-out override for viewers who already set
      # reduced_motion — always honor, but this lets the OWNER ship pristine.
      add :force_readable_mode_for_screen_readers, :boolean, null: false, default: true
    end

    create index(:users, [:profile_vibe])
    create index(:users, [:verified_creator_at])
    create index(:users, [:active_forge_code])

    # ---- Forge Codes ----
    create table(:forge_codes, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # Short shareable identifier, e.g. "a7k9m2xq"
      add :code, :string, null: false

      add :name, :string, null: false
      add :description, :string
      add :vibe_tag, :string

      # Strict-schema JSON. Never rendered as HTML/CSS — compiled to CSS vars.
      add :config, :map, null: false, default: %{}

      # Author. NULL allowed for future "system templates" with no author.
      add :owner_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      add :is_official, :boolean, null: false, default: false
      add :is_public, :boolean, null: false, default: true
      add :is_remixable, :boolean, null: false, default: true

      # Gallery stats
      add :applies_count, :integer, null: false, default: 0
      add :endorsement_count, :integer, null: false, default: 0

      # Optional preview screenshot URL
      add :preview_image_url, :string

      # Versioning lets us tighten the schema later without breaking old codes
      add :schema_version, :integer, null: false, default: 1

      timestamps()
    end

    create unique_index(:forge_codes, [:code])
    create index(:forge_codes, [:owner_id])
    create index(:forge_codes, [:vibe_tag])
    create index(:forge_codes, [:is_official, :inserted_at])
    create index(:forge_codes, [:is_public, :applies_count])

    # ---- Log of applications (for trending + per-user history) ----
    create table(:forge_code_applications, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :forge_code_id, references(:forge_codes, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :inserted_at, :utc_datetime, null: false
    end

    create index(:forge_code_applications, [:forge_code_id, :inserted_at])
    create index(:forge_code_applications, [:user_id, :inserted_at])

    # ---- Profile endorsements (emoji reactions on a profile) ----
    create table(:profile_endorsements, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :profile_user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false

      add :sender_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :emoji, :string, null: false

      timestamps()
    end

    create unique_index(:profile_endorsements, [:profile_user_id, :sender_id, :emoji])
    create index(:profile_endorsements, [:profile_user_id])
  end
end
