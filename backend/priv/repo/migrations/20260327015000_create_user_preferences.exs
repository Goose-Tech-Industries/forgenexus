defmodule ForgeNexus.Repo.Migrations.CreateUserPreferences do
  use Ecto.Migration

  def change do
    create table(:user_preferences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # Display
      add :pagination_mode, :string, default: "paginated"
      add :thread_display_mode, :string, default: "linear"
      add :content_density, :string, default: "comfortable"
      add :show_signatures, :boolean, default: true
      add :posts_per_page, :integer, default: 20

      # Accessibility
      add :reduced_motion, :boolean, default: false
      add :high_contrast, :boolean, default: false
      add :colorblind_mode, :string, default: "none"
      add :dyslexia_font, :boolean, default: false
      add :text_only_mode, :boolean, default: false

      # Notifications
      add :dnd_enabled, :boolean, default: false
      add :dnd_start, :string, default: "22:00"
      add :dnd_end, :string, default: "08:00"
      add :email_mentions, :boolean, default: true
      add :email_replies, :boolean, default: true
      add :email_dms, :boolean, default: true
      add :email_digest, :string, default: "none"
      add :notification_sound, :boolean, default: true

      # Privacy
      add :show_online_status, :boolean, default: true
      add :profile_visibility, :string, default: "public"
      add :show_activity, :boolean, default: true

      # Content
      add :auto_subscribe_threads, :boolean, default: true
      add :default_thread_notification, :string, default: "watching"
      add :show_spoilers, :boolean, default: false

      timestamps()
    end

    create unique_index(:user_preferences, [:user_id])
  end
end
