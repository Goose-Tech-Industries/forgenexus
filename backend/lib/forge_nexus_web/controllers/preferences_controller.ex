defmodule ForgeNexusWeb.PreferencesController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Accounts

  def index(conn, _params) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})

      user ->
        prefs = Accounts.get_preferences(user.id)
        conn |> json(%{preferences: preferences_json(prefs)})
    end
  end

  def update(conn, %{"preferences" => attrs}) when is_map(attrs) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})

      user ->
        case Accounts.update_preferences(user.id, attrs) do
          {:ok, updated} ->
            conn |> json(%{preferences: preferences_json(updated)})

          {:error, cs} ->
            conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_json(cs)})
        end
    end
  end

  def update(conn, _),
    do: conn |> put_status(:bad_request) |> json(%{error: "Missing preferences"})

  defp preferences_json(p) do
    Map.take(p, [
      # Display
      :pagination_mode,
      :thread_display_mode,
      :content_density,
      :show_signatures,
      :posts_per_page,
      # Accessibility
      :reduced_motion,
      :high_contrast,
      :colorblind_mode,
      :dyslexia_font,
      :text_only_mode,
      # Do-not-disturb + email
      :dnd_enabled,
      :dnd_start,
      :dnd_end,
      :email_mentions,
      :email_replies,
      :email_dms,
      :email_digest,
      :notification_sound,
      # Privacy
      :show_online_status,
      :profile_visibility,
      :show_activity,
      # In-app notifications
      :notify_replies,
      :notify_mentions,
      :notify_reactions,
      :notify_followers,
      :notify_badges,
      # Content
      :auto_subscribe_threads,
      :default_thread_notification,
      :show_spoilers
    ])
  end

  defp errors_json(cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", to_string(v)) end)
    end)
  end
end
