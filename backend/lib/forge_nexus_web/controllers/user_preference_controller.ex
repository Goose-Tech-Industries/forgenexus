defmodule ForgeNexusWeb.UserPreferenceController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Accounts

  # GET /api/preferences
  def show(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    pref = Accounts.get_preferences(user.id)
    conn |> json(%{preferences: preference_json(pref)})
  end

  # PUT /api/preferences
  def update(conn, %{"preferences" => pref_params}) do
    user = Guardian.Plug.current_resource(conn)

    case Accounts.update_preferences(user.id, pref_params) do
      {:ok, pref} ->
        conn |> json(%{preferences: preference_json(pref)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  defp preference_json(pref) do
    %{
      # Display
      pagination_mode: pref.pagination_mode,
      thread_display_mode: pref.thread_display_mode,
      content_density: pref.content_density,
      show_signatures: pref.show_signatures,
      posts_per_page: pref.posts_per_page,
      # Accessibility
      reduced_motion: pref.reduced_motion,
      high_contrast: pref.high_contrast,
      colorblind_mode: pref.colorblind_mode,
      dyslexia_font: pref.dyslexia_font,
      text_only_mode: pref.text_only_mode,
      # Notifications
      dnd_enabled: pref.dnd_enabled,
      dnd_start: pref.dnd_start,
      dnd_end: pref.dnd_end,
      email_mentions: pref.email_mentions,
      email_replies: pref.email_replies,
      email_dms: pref.email_dms,
      email_digest: pref.email_digest,
      notification_sound: pref.notification_sound,
      # In-App Notifications
      notify_replies: pref.notify_replies,
      notify_mentions: pref.notify_mentions,
      notify_reactions: pref.notify_reactions,
      notify_followers: pref.notify_followers,
      notify_badges: pref.notify_badges,
      # Privacy
      show_online_status: pref.show_online_status,
      profile_visibility: pref.profile_visibility,
      show_activity: pref.show_activity,
      # Content
      auto_subscribe_threads: pref.auto_subscribe_threads,
      default_thread_notification: pref.default_thread_notification,
      show_spoilers: pref.show_spoilers
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
