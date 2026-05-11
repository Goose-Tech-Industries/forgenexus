defmodule ForgeNexus.Accounts.UserPreference do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_pagination_modes ~w(paginated infinite_scroll)
  @valid_display_modes ~w(linear threaded hybrid)
  @valid_density ~w(compact comfortable spacious)
  @valid_colorblind ~w(none protanopia deuteranopia tritanopia)
  @valid_digest ~w(none daily weekly)
  @valid_visibility ~w(public members friends private)
  @valid_notification_levels ~w(watching tracking muted)
  @valid_posts_per_page [10, 15, 20, 25, 50]

  schema "user_preferences" do
    # Display
    field :pagination_mode, :string, default: "paginated"
    field :thread_display_mode, :string, default: "linear"
    field :content_density, :string, default: "comfortable"
    field :show_signatures, :boolean, default: true
    field :posts_per_page, :integer, default: 20

    # Accessibility
    field :reduced_motion, :boolean, default: false
    field :high_contrast, :boolean, default: false
    field :colorblind_mode, :string, default: "none"
    field :dyslexia_font, :boolean, default: false
    field :text_only_mode, :boolean, default: false

    # Notifications
    field :dnd_enabled, :boolean, default: false
    field :dnd_start, :string, default: "22:00"
    field :dnd_end, :string, default: "08:00"
    field :email_mentions, :boolean, default: false
    field :email_replies, :boolean, default: false
    field :email_dms, :boolean, default: false
    field :email_digest, :string, default: "none"
    field :notification_sound, :boolean, default: true

    # Privacy
    field :show_online_status, :boolean, default: true
    field :profile_visibility, :string, default: "public"
    field :show_activity, :boolean, default: true

    # In-App Notifications
    field :notify_replies, :boolean, default: true
    field :notify_mentions, :boolean, default: true
    field :notify_reactions, :boolean, default: true
    field :notify_followers, :boolean, default: true
    field :notify_badges, :boolean, default: true

    # Content
    field :auto_subscribe_threads, :boolean, default: true
    field :default_thread_notification, :string, default: "watching"
    field :show_spoilers, :boolean, default: false

    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  @cast_fields [
    :pagination_mode, :thread_display_mode, :content_density, :show_signatures, :posts_per_page,
    :reduced_motion, :high_contrast, :colorblind_mode, :dyslexia_font, :text_only_mode,
    :dnd_enabled, :dnd_start, :dnd_end, :email_mentions, :email_replies, :email_dms,
    :email_digest, :notification_sound,
    :show_online_status, :profile_visibility, :show_activity,
    :notify_replies, :notify_mentions, :notify_reactions, :notify_followers, :notify_badges,
    :auto_subscribe_threads, :default_thread_notification, :show_spoilers
  ]

  def changeset(preference, attrs) do
    preference
    |> cast(attrs, @cast_fields)
    |> validate_inclusion(:pagination_mode, @valid_pagination_modes)
    |> validate_inclusion(:thread_display_mode, @valid_display_modes)
    |> validate_inclusion(:content_density, @valid_density)
    |> validate_inclusion(:colorblind_mode, @valid_colorblind)
    |> validate_inclusion(:email_digest, @valid_digest)
    |> validate_inclusion(:profile_visibility, @valid_visibility)
    |> validate_inclusion(:default_thread_notification, @valid_notification_levels)
    |> validate_inclusion(:posts_per_page, @valid_posts_per_page)
    |> validate_time_format(:dnd_start)
    |> validate_time_format(:dnd_end)
  end

  def create_changeset(preference, attrs) do
    preference
    |> cast(attrs, [:user_id | @cast_fields])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
    |> validate_inclusion(:pagination_mode, @valid_pagination_modes)
    |> validate_inclusion(:thread_display_mode, @valid_display_modes)
    |> validate_inclusion(:content_density, @valid_density)
    |> validate_inclusion(:colorblind_mode, @valid_colorblind)
    |> validate_inclusion(:email_digest, @valid_digest)
    |> validate_inclusion(:profile_visibility, @valid_visibility)
    |> validate_inclusion(:default_thread_notification, @valid_notification_levels)
    |> validate_inclusion(:posts_per_page, @valid_posts_per_page)
    |> validate_time_format(:dnd_start)
    |> validate_time_format(:dnd_end)
  end

  defp validate_time_format(changeset, field) do
    case get_change(changeset, field) do
      nil -> changeset
      value ->
        if Regex.match?(~r/^([01]\d|2[0-3]):[0-5]\d$/, value) do
          changeset
        else
          add_error(changeset, field, "must be in HH:MM format (e.g. 22:00)")
        end
    end
  end
end
