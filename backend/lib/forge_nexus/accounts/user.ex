defmodule ForgeNexus.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :username, :string
    field :email, :string
    field :password_hash, :string
    field :password, :string, virtual: true
    field :display_name, :string
    field :slug, :string
    field :avatar_url, :string
    field :signature, :string
    field :bio, :string
    field :location, :string
    field :website, :string
    field :date_of_birth, :date
    field :post_count, :integer, default: 0
    field :thread_count, :integer, default: 0
    field :reputation, :integer, default: 0
    field :trust_level, :integer, default: 0
    field :status, :string, default: "active"
    field :is_online, :boolean, default: false
    field :last_seen_at, :utc_datetime
    field :last_post_at, :utc_datetime
    field :registered_ip, :string
    field :session_generation, :integer, default: 0
    field :timezone, :string, default: "UTC"
    field :locale, :string, default: "en"
    field :theme, :string, default: "dark"
    field :content_density, :string, default: "comfortable"
    field :username_color, :string
    field :username_effect, :string, default: "none"
    field :custom_title, :string
    field :nameplate_color, :string
    field :nameplate_image_url, :string
    field :avatar_frame, :string
    field :avatar_frame_color, :string
    field :postbit_background_url, :string
    field :postbit_background_opacity, :float
    field :post_background_url, :string
    field :post_background_opacity, :float
    field :signature_background_url, :string
    field :signature_html, :string
    field :profile_background_url, :string
    field :profile_background_color, :string
    field :profile_gradient_start, :string
    field :profile_gradient_end, :string
    field :profile_gradient_direction, :string
    field :profile_banner_url, :string
    field :profile_accent_color, :string
    field :profile_font, :string
    field :color_override_accent, :string
    field :color_override_bg_primary, :string
    field :color_override_bg_secondary, :string
    field :color_override_text_primary, :string
    field :profile_views, :integer, default: 0
    field :presence_status, :string, default: "online"
    field :custom_status_text, :string
    field :custom_status_emoji, :string
    field :points, :integer, default: 0
    field :email_verified_at, :utc_datetime
    field :deactivated_at, :utc_datetime
    field :deactivation_reason, :string
    field :totp_secret, :string
    field :totp_enabled, :boolean, default: false
    field :totp_backup_codes, {:array, :string}, default: []
    field :birthday, :date
    field :infraction_points, :integer, default: 0
    field :about_me_bbcode, :string
    field :about_me_html, :string
    field :email_unverified, :boolean, default: false

    # Profile song + rich presence (social features)
    field :profile_song_url, :string
    field :profile_song_title, :string
    field :profile_css, :string
    field :rich_presence_status, :string
    field :rich_presence_activity, :string
    field :rich_presence_detail, :string
    field :is_premium, :boolean, default: false
    field :premium_until, :utc_datetime
    field :walk_on_sound_url, :string
    field :walk_on_sound_name, :string

    # MySpace-style profile
    field :profile_mood, :string
    field :profile_mood_emoji, :string
    field :interests, :string
    field :favorite_music, :string
    field :favorite_movies, :string
    field :favorite_tv, :string
    field :favorite_games, :string
    field :favorite_books, :string
    field :heroes, :string
    field :who_id_like_to_meet, :string
    field :profile_layout, :string, default: "classic"

    field :profile_widget_order, {:array, :string},
      default: ["about", "top_friends", "guestbook", "activity", "achievements", "clips"]

    field :profile_song_autoplay, :boolean, default: false
    field :show_profile_views, :boolean, default: true

    # SOTA profile additions
    field :pronouns, :string
    field :social_links, :map, default: %{}
    field :profile_vibe, :string
    field :avatar_3d_url, :string
    field :verified_creator_at, :utc_datetime
    field :subscriptions_enabled_at, :utc_datetime
    # Payout tier for Voice Money Tips (ForgeNexus.Voice.TipCalculator) — how much
    # of a tip this creator keeps. Admin-granted only; see AdminUserController.update/2.
    field :creator_tier, :string, default: "basic"
    field :pinned_thread_id, :binary_id
    field :seasonal_decorations_enabled, :boolean, default: true
    field :birthday_visibility, :string, default: "members"
    field :location_visibility, :string, default: "public"
    field :email_visibility, :string, default: "private"
    field :activity_visibility, :string, default: "public"
    field :active_forge_code, :string
    field :force_readable_mode_for_screen_readers, :boolean, default: true

    belongs_to :primary_group, ForgeNexus.Accounts.UserGroup
    belongs_to :selected_theme, ForgeNexus.Accounts.Theme, foreign_key: :theme_id
    has_many :group_memberships, ForgeNexus.Accounts.UserGroupMembership
    has_many :groups, through: [:group_memberships, :group]
    has_many :threads, ForgeNexus.Forums.Thread
    has_many :posts, ForgeNexus.Forums.Post
    has_many :friendships, ForgeNexus.Chat.Friendship
    has_many :notifications, ForgeNexus.Chat.Notification

    timestamps()
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :password, :display_name, :registered_ip])
    |> validate_required([:username, :email, :password])
    |> validate_length(:username, min: 3, max: 25)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_-]+$/,
      message: "only letters, numbers, underscores, and hyphens"
    )
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email")
    |> validate_length(:password, min: 8, max: 128)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
    |> generate_slug()
    |> hash_password()
  end

  @doc """
  Changeset for users created via OAuth. Skips password requirement and
  allows a nil email (with email_unverified: true).
  """
  def oauth_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :username,
      :email,
      :display_name,
      :avatar_url,
      :registered_ip,
      :email_unverified
    ])
    |> validate_required([:username])
    |> validate_length(:username, min: 3, max: 25)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_-]+$/,
      message: "only letters, numbers, underscores, and hyphens"
    )
    |> maybe_validate_email()
    |> unique_constraint(:username)
    |> unique_constraint(:email)
    |> generate_slug()
  end

  defp maybe_validate_email(changeset) do
    case get_field(changeset, :email) do
      nil ->
        changeset

      _email ->
        validate_format(changeset, :email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/,
          message: "must be a valid email"
        )
    end
  end

  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 128)
    |> hash_password()
  end

  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email")
    |> unique_constraint(:email)
  end

  @vibe_tags ~w(default neon vaporwave goth cyber pastel gamer creator dark light minimal retro forge)
  @visibility_levels ~w(public members friends private)

  @creator_tiers ~w(basic mid top)

  def admin_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :username,
      :email,
      :display_name,
      :status,
      :trust_level,
      :primary_group_id,
      :custom_title,
      :is_premium,
      :verified_creator_at,
      :email_verified_at,
      :infraction_points,
      :avatar_url,
      :creator_tier
    ])
    |> validate_length(:username, min: 3, max: 25)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_-]+$/,
      message: "only letters, numbers, underscores, and hyphens"
    )
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email")
    |> validate_inclusion(:status, ["active", "suspended", "banned", "deleted"])
    |> validate_number(:trust_level, greater_than_or_equal_to: 0, less_than_or_equal_to: 4)
    |> validate_inclusion(:creator_tier, @creator_tiers)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
  end

  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :display_name,
      :avatar_url,
      :signature,
      :bio,
      :location,
      :website,
      :date_of_birth,
      :timezone,
      :locale,
      :theme,
      :content_density,
      # MySpace-style blurbs
      :interests,
      :favorite_music,
      :favorite_movies,
      :favorite_tv,
      :favorite_games,
      :favorite_books,
      :heroes,
      :who_id_like_to_meet,
      :about_me_bbcode,
      :about_me_html,
      :signature_html,
      # Customization
      :profile_background_url,
      :profile_background_color,
      :profile_gradient_start,
      :profile_gradient_end,
      :profile_gradient_direction,
      :profile_banner_url,
      :profile_accent_color,
      :profile_font,
      :profile_song_url,
      :profile_song_title,
      :profile_song_autoplay,
      :profile_mood,
      :profile_mood_emoji,
      :profile_layout,
      :profile_widget_order,
      :walk_on_sound_url,
      :walk_on_sound_name,
      :custom_title,
      :username_color,
      :username_effect,
      :nameplate_color,
      :nameplate_image_url,
      :avatar_frame,
      :avatar_frame_color,
      :postbit_background_url,
      :postbit_background_opacity,
      :post_background_url,
      :post_background_opacity,
      :signature_background_url,
      :color_override_accent,
      :color_override_bg_primary,
      :color_override_bg_secondary,
      :color_override_text_primary,
      # SOTA
      :pronouns,
      :social_links,
      :profile_vibe,
      :avatar_3d_url,
      :pinned_thread_id,
      :seasonal_decorations_enabled,
      :birthday_visibility,
      :location_visibility,
      :email_visibility,
      :activity_visibility,
      :show_profile_views,
      :active_forge_code
    ])
    |> validate_length(:signature, max: 500)
    |> validate_length(:bio, max: 5000)
    |> validate_length(:pronouns, max: 40)
    |> validate_length(:interests, max: 2000)
    |> validate_length(:favorite_music, max: 2000)
    |> validate_length(:favorite_movies, max: 2000)
    |> validate_length(:favorite_tv, max: 2000)
    |> validate_length(:favorite_games, max: 2000)
    |> validate_length(:favorite_books, max: 2000)
    |> validate_length(:heroes, max: 2000)
    |> validate_length(:who_id_like_to_meet, max: 2000)
    |> validate_length(:about_me_bbcode, max: 10_000)
    |> validate_inclusion(:theme, ["dark", "light", "auto"])
    |> validate_inclusion(:content_density, ["comfortable", "compact"])
    |> validate_inclusion(:profile_vibe, @vibe_tags ++ [nil])
    |> validate_inclusion(:birthday_visibility, @visibility_levels)
    |> validate_inclusion(:location_visibility, @visibility_levels)
    |> validate_inclusion(:email_visibility, @visibility_levels)
    |> validate_inclusion(:activity_visibility, @visibility_levels)
    |> validate_hex_color(:profile_accent_color)
    |> validate_hex_color(:profile_background_color)
    |> validate_hex_color(:profile_gradient_start)
    |> validate_hex_color(:profile_gradient_end)
    |> validate_hex_color(:nameplate_color)
    |> validate_hex_color(:username_color)
    |> validate_hex_color(:color_override_accent)
    |> validate_hex_color(:color_override_bg_primary)
    |> validate_hex_color(:color_override_bg_secondary)
    |> validate_hex_color(:color_override_text_primary)
    |> validate_social_links()
  end

  defp validate_hex_color(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      "" ->
        changeset

      value ->
        if Regex.match?(~r/^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/, value) do
          changeset
        else
          add_error(changeset, field, "must be a valid hex color like #ff8800")
        end
    end
  end

  @allowed_social_platforms ~w(twitter x github steam twitch youtube discord bluesky mastodon tiktok instagram reddit kofi patreon spotify soundcloud linkedin website)

  defp validate_social_links(changeset) do
    case get_change(changeset, :social_links) do
      nil ->
        changeset

      links when is_map(links) ->
        bad =
          Enum.reject(links, fn
            {k, v} when is_binary(k) and is_binary(v) ->
              k in @allowed_social_platforms and byte_size(v) <= 400 and
                String.starts_with?(v, ["https://", "http://"])

            _ ->
              false
          end)

        if bad == [] do
          changeset
        else
          add_error(
            changeset,
            :social_links,
            "only supports https:// links for: #{Enum.join(@allowed_social_platforms, ", ")}"
          )
        end

      _ ->
        add_error(changeset, :social_links, "must be an object of platform→url")
    end
  end

  @doc "Platforms we render an icon for on profiles."
  def allowed_social_platforms, do: @allowed_social_platforms

  @doc "Vibe tags offered in the gallery + editor."
  def vibe_tags, do: @vibe_tags

  @doc "Visibility levels for per-field privacy."
  def visibility_levels, do: @visibility_levels

  defp generate_slug(changeset) do
    case get_change(changeset, :username) do
      nil -> changeset
      username -> put_change(changeset, :slug, Slug.slugify(username))
    end
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      password -> put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
    end
  end
end
