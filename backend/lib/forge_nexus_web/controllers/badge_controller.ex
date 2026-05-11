defmodule ForgeNexusWeb.BadgeController do
  use ForgeNexusWeb, :controller
  alias ForgeNexus.Forums

  # Public
  def index(conn, _params) do
    badges = Forums.list_badges()
    conn |> json(%{badges: Enum.map(badges, &badge_json/1)})
  end

  def user_badges(conn, %{"user_id" => user_id}) do
    badges = Forums.user_badges(user_id)
    conn |> json(%{badges: Enum.map(badges, fn ub ->
      %{id: ub.id, badge: badge_json(ub.badge), reason: ub.reason, is_featured: ub.is_featured, awarded_at: ub.inserted_at}
    end)})
  end

  # Admin
  def admin_index(conn, _params) do
    badges = Forums.list_all_badges()
    conn |> json(%{badges: Enum.map(badges, &badge_json/1)})
  end

  def create(conn, params) do
    case Forums.create_badge(params) do
      {:ok, badge} -> conn |> put_status(:created) |> json(%{badge: badge_json(badge)})
      {:error, cs} -> conn |> put_status(:unprocessable_entity) |> json(%{error: format_errors(cs)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Forums.update_badge(id, params) do
      {:ok, badge} -> conn |> json(%{badge: badge_json(badge)})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to update"})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Forums.delete_badge(id) do
      {:ok, _} -> conn |> json(%{ok: true})
      _ -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete"})
    end
  end

  def award(conn, %{"user_id" => user_id, "badge_id" => badge_id} = params) do
    admin = Guardian.Plug.current_resource(conn)
    Forums.award_badge(user_id, badge_id, admin.id, params["reason"])
    conn |> json(%{ok: true})
  end

  def revoke(conn, %{"user_id" => user_id, "badge_id" => badge_id}) do
    Forums.revoke_badge(user_id, badge_id)
    conn |> json(%{ok: true})
  end

  defp badge_json(b) do
    %{id: b.id, name: b.name, description: b.description, icon_url: b.icon_url,
      icon_emoji: b.icon_emoji, color: b.color, category: b.category,
      is_auto: b.is_auto, auto_criteria: b.auto_criteria, is_active: b.is_active}
  end

  defp format_errors(cs), do: Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)
end
