defmodule ForgeNexus.Settings do
  @moduledoc """
  The Settings context — site-wide configuration.
  Uses a key-value store (site_settings table) with compile-time defaults.
  """
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Settings.SiteSetting

  @defaults %{
    # General
    "site_name" => "ForgeNexus",
    "site_description" => "A modern forum community",
    "site_logo_url" => "",
    "site_favicon_url" => "",
    "meta_description" => "ForgeNexus — modern community forum",
    "default_timezone" => "UTC",
    "default_locale" => "en",
    # Registration
    "registration_mode" => "open",
    "require_email_verification" => "false",
    "min_password_length" => "8",
    # Content
    "max_post_length" => "50000",
    "allow_signatures" => "true",
    "allow_bbcode" => "true",
    "allow_images_in_posts" => "true",
    "posts_per_page" => "20",
    "threads_per_page" => "25",
    # Chat
    "chat_bar_enabled" => "true",
    "shoutbox_enabled" => "true",
    "max_chat_message_length" => "500",
    # Moderation
    "new_user_post_delay_seconds" => "0",
    "auto_escalation_enabled" => "true",
    "post_edit_time_limit" => "60",
    # Plugins
    "claude_api_enabled" => "false",
    "claude_api_key" => "",
    # Welcome Center
    "welcome_center_enabled" => "true",
    "welcome_center_title" => "Welcome to ForgeNexus",
    "welcome_center_guest_message" =>
      "Welcome! Join our community to participate in discussions.",
    "welcome_center_member_message" => "Welcome back! Check out the latest threads and activity.",
    "welcome_center_show_stats" => "true",
    "welcome_center_show_recent_threads" => "true",
    "welcome_center_show_birthdays" => "true",
    "welcome_center_show_new_members" => "true",
    # Online Tracking
    "most_online_count" => "0",
    "most_online_at" => "",
    # Maintenance
    "maintenance_mode" => "false",
    "maintenance_message" => "We'll be back soon.",
    # Features
    "reply_via_email_enabled" => "false",
    "custom_reactions_enabled" => "false",
    "thread_ratings_enabled" => "true",
    # White Label
    "white_label_enabled" => "false",
    "white_label_name" => "",
    "white_label_logo_url" => "",
    # Portal / Front Page
    "homepage_mode" => "classic",
    "portal_page_slug" => "",
    "portal_show_shoutbox" => "true",
    "portal_show_welcome" => "true",
    "portal_show_stats" => "true",
    "portal_show_online" => "true",
    "portal_featured_threads_count" => "5",
    # Email / SMTP
    "smtp_host" => "",
    "smtp_port" => "587",
    "smtp_username" => "",
    "smtp_password" => "",
    "smtp_from_address" => "",
    "smtp_from_name" => "",
    "smtp_encryption" => "tls",
    # Engagement scoring (per-activity weights, caps, and tier thresholds)
    "engagement_window_days" => "30",
    "engagement_weight_post" => "3",
    "engagement_cap_post" => "30",
    "engagement_weight_thread" => "5",
    "engagement_cap_thread" => "20",
    "engagement_weight_reputation" => "1",
    "engagement_cap_reputation" => "20",
    "engagement_recency_max" => "30",
    "engagement_tier_power" => "80",
    "engagement_tier_active" => "50",
    "engagement_tier_casual" => "20",
    # Voice recording & transcription
    "voice_recording_enabled" => "true",
    "voice_recording_max_duration_minutes" => "180",
    "voice_recording_max_size_mb" => "200",
    "voice_transcription_enabled" => "false",
    "voice_transcription_provider" => "disabled",
    "voice_transcription_max_size_mb" => "25",
    "voice_transcription_whisper_cpp_bin" => "/opt/whisper.cpp/main",
    "voice_transcription_whisper_cpp_model" => "/opt/whisper.cpp/models/ggml-small.en.bin",
    # LiveKit SFU (media plane for voice rooms). Falls back to mesh WebRTC until set.
    "livekit_url" => "",
    "livekit_api_key" => "",
    "livekit_api_secret" => "",
    "livekit_max_participants_default" => "50",
    # coturn TURN server (mesh fallback NAT traversal). Required for users behind
    # symmetric NAT when LiveKit is not configured. Read by /api/voice/ice-config.
    "turn_url" => "turn:forum.tcgaming.quest:3478",
    "turn_url_tls" => "turns:forum.tcgaming.quest:5349",
    "turn_credential_ttl_seconds" => "3600",
    # Voice participation rewards
    "voice_reward_enabled" => "true",
    "voice_reward_points_per_minute" => "1",
    "voice_reward_min_duration_seconds" => "300",
    "voice_reward_max_points_per_session" => "60",
    # Voice auto-thread (post-session forum discussion)
    "voice_auto_thread_enabled" => "false",
    "voice_auto_thread_forum_id" => "",
    # AI flow generator (natural language -> no-code flow)
    "ai_flow_generator_enabled" => "false",
    "ai_flow_generator_provider" => "anthropic",
    "ai_flow_generator_model" => "claude-sonnet-4-6"
  }

  @categories %{
    "general" =>
      ~w(site_name site_description site_logo_url site_favicon_url meta_description default_timezone default_locale),
    "registration" => ~w(registration_mode require_email_verification min_password_length),
    "content" =>
      ~w(max_post_length allow_signatures allow_bbcode allow_images_in_posts posts_per_page threads_per_page),
    "chat" => ~w(chat_bar_enabled shoutbox_enabled max_chat_message_length),
    "moderation" => ~w(new_user_post_delay_seconds auto_escalation_enabled post_edit_time_limit),
    "plugins" => ~w(claude_api_enabled claude_api_key),
    "welcome_center" =>
      ~w(welcome_center_enabled welcome_center_title welcome_center_guest_message welcome_center_member_message welcome_center_show_stats welcome_center_show_recent_threads welcome_center_show_birthdays welcome_center_show_new_members),
    "online_tracking" => ~w(most_online_count most_online_at),
    "maintenance" => ~w(maintenance_mode maintenance_message),
    "features" => ~w(reply_via_email_enabled custom_reactions_enabled thread_ratings_enabled),
    "white_label" => ~w(white_label_enabled white_label_name white_label_logo_url),
    "portal" =>
      ~w(homepage_mode portal_page_slug portal_show_shoutbox portal_show_welcome portal_show_stats portal_show_online portal_featured_threads_count),
    "email" =>
      ~w(smtp_host smtp_port smtp_username smtp_password smtp_from_address smtp_from_name smtp_encryption),
    "engagement" =>
      ~w(engagement_window_days engagement_weight_post engagement_cap_post engagement_weight_thread engagement_cap_thread engagement_weight_reputation engagement_cap_reputation engagement_recency_max engagement_tier_power engagement_tier_active engagement_tier_casual),
    "voice" =>
      ~w(voice_recording_enabled voice_recording_max_duration_minutes voice_recording_max_size_mb voice_transcription_enabled voice_transcription_provider voice_transcription_max_size_mb voice_transcription_whisper_cpp_bin voice_transcription_whisper_cpp_model),
    "ai" => ~w(ai_flow_generator_enabled ai_flow_generator_provider ai_flow_generator_model),
    "livekit" =>
      ~w(livekit_url livekit_api_key livekit_api_secret livekit_max_participants_default),
    "turn" => ~w(turn_url turn_url_tls turn_credential_ttl_seconds),
    "voice_rewards" =>
      ~w(voice_reward_enabled voice_reward_points_per_minute voice_reward_min_duration_seconds voice_reward_max_points_per_session),
    "voice_auto_thread" => ~w(voice_auto_thread_enabled voice_auto_thread_forum_id)
  }

  def get(key) do
    ForgeNexus.SettingsCache.get("setting:#{key}", fn ->
      case Repo.get_by(SiteSetting, key: key) do
        nil -> Map.get(@defaults, key)
        setting -> setting.value
      end
    end)
  rescue
    # Cache not started yet (during setup/migrations) — fall back to DB
    ArgumentError ->
      case Repo.get_by(SiteSetting, key: key) do
        nil -> Map.get(@defaults, key)
        setting -> setting.value
      end
  end

  def get_bool(key), do: get(key) == "true"

  def get_int(key) do
    case Integer.parse(get(key) || "0") do
      {n, _} -> n
      :error -> 0
    end
  end

  def set(key, value) do
    result =
      case Repo.get_by(SiteSetting, key: key) do
        nil ->
          %SiteSetting{}
          |> SiteSetting.changeset(%{
            key: key,
            value: to_string(value),
            value_type: value_type(value)
          })
          |> Repo.insert()

        setting ->
          setting
          |> SiteSetting.changeset(%{value: to_string(value)})
          |> Repo.update()
      end

    # Invalidate cache on write
    try do
      ForgeNexus.SettingsCache.invalidate("setting:#{key}")
      ForgeNexus.SettingsCache.invalidate("public_settings")
    rescue
      ArgumentError -> :ok
    end

    result
  end

  def get_all_with_defaults do
    db_settings = Repo.all(from s in SiteSetting, select: {s.key, s.value}) |> Map.new()
    Map.merge(@defaults, db_settings)
  end

  def get_all_grouped do
    all = get_all_with_defaults()

    Enum.map(@categories, fn {category, keys} ->
      settings =
        Enum.map(keys, fn key ->
          %{key: key, value: Map.get(all, key, ""), default: Map.get(@defaults, key, "")}
        end)

      {category, settings}
    end)
    |> Map.new()
  end

  def set_many(settings_map) when is_map(settings_map) do
    Enum.each(settings_map, fn {key, value} ->
      if Map.has_key?(@defaults, key) do
        set(key, value)
      end
    end)

    :ok
  end

  def public_settings do
    ForgeNexus.SettingsCache.get("public_settings", fn -> do_public_settings() end)
  rescue
    ArgumentError -> do_public_settings()
  end

  defp do_public_settings do
    %{
      site_name: get("site_name"),
      site_description: get("site_description"),
      site_logo_url: get("site_logo_url"),
      chat_bar_enabled: get_bool("chat_bar_enabled"),
      shoutbox_enabled: get_bool("shoutbox_enabled"),
      welcome_center_enabled: get_bool("welcome_center_enabled"),
      maintenance_mode: get_bool("maintenance_mode"),
      maintenance_message: get("maintenance_message"),
      thread_ratings_enabled: get_bool("thread_ratings_enabled"),
      custom_reactions_enabled: get_bool("custom_reactions_enabled"),
      post_edit_time_limit: get_int("post_edit_time_limit"),
      white_label_enabled: get_bool("white_label_enabled"),
      white_label_name: get("white_label_name"),
      white_label_logo_url: get("white_label_logo_url"),
      homepage_mode: get("homepage_mode"),
      portal_page_slug: get("portal_page_slug"),
      portal_show_shoutbox: get_bool("portal_show_shoutbox"),
      portal_show_welcome: get_bool("portal_show_welcome"),
      portal_show_stats: get_bool("portal_show_stats"),
      portal_show_online: get_bool("portal_show_online")
    }
  end

  def categories, do: @categories
  def defaults, do: @defaults

  defp value_type(value) when is_boolean(value), do: "boolean"
  defp value_type(value) when is_integer(value), do: "integer"
  defp value_type(_), do: "string"
end
