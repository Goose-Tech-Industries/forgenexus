defmodule ForgeNexusWeb.AppealController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Moderation

  def create(conn, %{"appeal" => appeal_params}) do
    user = Guardian.Plug.current_resource(conn)

    type = Map.fetch!(appeal_params, "type")
    target_id = Map.fetch!(appeal_params, "target_id")
    reason = Map.fetch!(appeal_params, "reason")

    case Moderation.create_appeal(user.id, type, target_id, reason) do
      {:ok, appeal} ->
        appeal = ForgeNexus.Repo.preload(appeal, [:reviewer])

        conn
        |> put_status(:created)
        |> json(%{appeal: appeal_json(appeal)})

      {:error, :appeal_already_exists} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "You already have a pending appeal for this"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: changeset_errors(changeset)})
    end
  end

  def my_appeals(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    limit = parse_int(params, "limit", 25)
    offset = parse_int(params, "offset", 0)

    appeals = Moderation.my_appeals(user.id, limit: limit, offset: offset)
    conn |> json(%{appeals: Enum.map(appeals, &appeal_json/1)})
  end

  # GET /api/my/infractions — current user's own bans + warnings + appeals
  def my_infractions(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    data = Moderation.user_infractions(user.id)
    appeals = Moderation.my_appeals(user.id, limit: 100)

    conn
    |> json(%{
      bans:
        Enum.map(data.bans, fn b ->
          %{
            id: b.id,
            type: b.type,
            reason: b.reason,
            expires_at: b.expires_at,
            is_active: b.is_active,
            inserted_at: b.inserted_at
          }
        end),
      warnings:
        Enum.map(data.warnings, fn w ->
          %{
            id: w.id,
            type: w.type,
            reason: w.reason,
            points: w.points,
            is_active: w.is_active,
            expires_at: w.expires_at,
            inserted_at: w.inserted_at
          }
        end),
      active_points: data.active_points,
      appeals: Enum.map(appeals, &appeal_json/1)
    })
  end

  defp appeal_json(appeal) do
    %{
      id: appeal.id,
      type: appeal.type,
      target_id: appeal.target_id,
      reason: appeal.reason,
      status: appeal.status,
      decision_note: appeal.decision_note,
      decided_at: appeal.decided_at,
      inserted_at: appeal.inserted_at,
      reviewer:
        if(appeal.reviewer && Ecto.assoc_loaded?(appeal.reviewer),
          do: %{
            id: appeal.reviewer.id,
            username: appeal.reviewer.username,
            slug: appeal.reviewer.slug,
            avatar_url: appeal.reviewer.avatar_url
          }
        )
    }
  end

  defp parse_int(params, key, default) do
    case Map.get(params, key) do
      nil -> default
      val when is_binary(val) -> safe_to_integer(val, default)
      val when is_integer(val) -> val
    end
  end

  defp changeset_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end

  defp changeset_errors(error), do: inspect(error)

  defp safe_to_integer(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> default
    end
  end

  defp safe_to_integer(val, _default) when is_integer(val), do: val
  defp safe_to_integer(_, default), do: default
end
