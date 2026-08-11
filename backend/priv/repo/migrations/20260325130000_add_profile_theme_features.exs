defmodule ForgeNexus.Repo.Migrations.AddProfileThemeFeatures do
  use Ecto.Migration

  def change do
    # --- Themes table ---
    create table(:themes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :is_default, :boolean, default: false
      add :is_active, :boolean, default: true
      add :position, :integer, default: 0
      add :variables, :map, default: %{}
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:themes, [:slug])

    # --- Avatar Frames catalog ---
    create table(:avatar_frames, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :css_class, :string, null: false
      add :description, :text
      add :min_posts, :integer
      add :is_active, :boolean, default: true
      add :position, :integer, default: 0

      timestamps()
    end

    create unique_index(:avatar_frames, [:slug])

    # --- Profile fields on users ---
    alter table(:users) do
      add :profile_background_url, :string
      add :profile_background_color, :string
      add :profile_gradient_start, :string
      add :profile_gradient_end, :string
      add :profile_gradient_direction, :string, default: "to bottom"
      add :profile_banner_url, :string
      add :profile_accent_color, :string
      add :profile_font, :string, default: "Inter"
      add :about_me_bbcode, :text
      add :about_me_html, :text
      add :custom_title, :string
      add :nameplate_color, :string
      add :nameplate_image_url, :string
      add :avatar_frame, :string, default: "none"
      add :avatar_frame_color, :string
      add :profile_views, :integer, default: 0
      add :theme_id, references(:themes, type: :binary_id, on_delete: :nilify_all)
      add :color_override_accent, :string
      add :color_override_bg_primary, :string
      add :color_override_bg_secondary, :string
      add :color_override_text_primary, :string
    end

    # --- Top Friends ---
    create table(:profile_top_friends, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :friend_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :position, :integer, null: false

      timestamps()
    end

    create unique_index(:profile_top_friends, [:user_id, :friend_id])
    create index(:profile_top_friends, [:user_id])

    # --- Guestbook Entries ---
    create table(:guestbook_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :profile_user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false

      add :author_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :body_bbcode, :text, null: false
      add :body_html, :text, null: false
      add :is_hidden, :boolean, default: false

      timestamps()
    end

    create index(:guestbook_entries, [:profile_user_id])

    # --- Profile Visits ---
    create table(:profile_visits, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :profile_user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false

      add :visitor_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :visited_at, :utc_datetime, null: false

      timestamps()
    end

    create unique_index(:profile_visits, [:profile_user_id, :visitor_id])
    create index(:profile_visits, [:profile_user_id])
  end
end
