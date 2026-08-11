defmodule ForgeNexusWeb.AdminQuarantineController do
  @moduledoc "Admin view and manage user quarantines."
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Moderation

  def index(conn, params) do
    active_only = Map.get(params, "active", "false") == "true"
    records = Moderation.list_quarantine_records(active: active_only, limit: 200)
    conn |> json(%{records: Enum.map(records, &record_json/1)})
  end

  def create(conn, %{"user_id" => user_id} = params) do
    reason = Map.get(params, "reason", "")
    actor = Guardian.Plug.current_resource(conn)

    case Moderation.quarantine_user(user_id, reason, actor && actor.id) do
      {:ok, _user} ->
        record = Moderation.active_quarantine_for(user_id)
        conn |> put_status(:created) |> json(%{record: record && record_json(record)})

      {:error, :already_quarantined} ->
        conn |> put_status(:conflict) |> json(%{error: "User is already quarantined"})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "User not found"})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
    end
  end

  def release(conn, %{"user_id" => user_id}) do
    actor = Guardian.Plug.current_resource(conn)

    case Moderation.release_quarantine(user_id, actor && actor.id) do
      {:ok, _user} ->
        conn |> json(%{ok: true})

      {:error, :not_quarantined} ->
        conn |> put_status(:not_found) |> json(%{error: "User is not quarantined"})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "User not found"})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
    end
  end

  defp record_json(r) do
    %{
      id: r.id,
      user_id: r.user_id,
      user: user_summary(r.user),
      quarantined_by_id: r.quarantined_by_id,
      quarantined_by: user_summary(r.quarantined_by),
      original_group_ids: r.original_group_ids,
      reason: r.reason,
      quarantined_at: r.quarantined_at,
      released_at: r.released_at,
      is_active: is_nil(r.released_at)
    }
  end

  defp user_summary(nil), do: nil
  defp user_summary(%{id: id, username: username}), do: %{id: id, username: username}
  defp user_summary(%Ecto.Association.NotLoaded{}), do: nil
  defp user_summary(_), do: nil
end
