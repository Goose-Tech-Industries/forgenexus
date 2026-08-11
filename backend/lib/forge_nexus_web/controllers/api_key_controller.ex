defmodule ForgeNexusWeb.ApiKeyController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Platform

  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    keys = Platform.list_api_keys(user.id)

    conn
    |> json(%{
      api_keys:
        Enum.map(keys, fn k ->
          %{
            id: k.id,
            name: k.name,
            key_prefix: k.key_prefix,
            plan: k.plan,
            scopes: k.scopes,
            rate_limit: k.rate_limit_per_minute,
            is_active: k.is_active,
            total_requests: k.total_requests,
            last_used_at: k.last_used_at,
            inserted_at: k.inserted_at
          }
        end)
    })
  end

  def create(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    community_id = conn.assigns.community_id
    name = params["name"] || "Unnamed Key"
    plan = params["plan"] || "free"

    case Platform.create_api_key(user.id, community_id, name, plan) do
      {:ok, key, raw_key} ->
        conn
        |> put_status(:created)
        |> json(%{
          api_key: %{id: key.id, name: key.name, key_prefix: key.key_prefix},
          secret: raw_key,
          warning: "Save this key now — it won't be shown again."
        })

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
        conn |> put_status(:unprocessable_entity) |> json(%{error: errors})
    end
  end

  def revoke(conn, %{"id" => key_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Platform.revoke_api_key(key_id, user.id) do
      {:ok, _} -> conn |> json(%{ok: true})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "Key not found"})
    end
  end

  def usage(conn, %{"id" => key_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Platform.get_api_key(key_id, user.id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Key not found"})

      _key ->
        usage = Platform.get_api_key_usage(key_id)

        totals =
          Enum.reduce(usage, %{requests: 0, errors: 0}, fn row, acc ->
            %{
              requests: acc.requests + (row.requests || 0),
              errors: acc.errors + (row.errors || 0)
            }
          end)

        conn |> json(%{usage: usage, totals: totals})
    end
  end
end
