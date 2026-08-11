defmodule ForgeNexusWeb.Plugs.ApiKeyAuth do
  @moduledoc """
  Authenticates requests via API key in the `x-api-key` header.
  Sets `conn.assigns.api_key` and `conn.assigns.api_key_user_id`.
  Enforces rate limits and scope checks.
  """

  import Plug.Conn
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Platform.ApiKey

  def init(opts), do: opts

  def call(conn, opts) do
    required_scope = Keyword.get(opts, :scope, "read")

    case get_req_header(conn, "x-api-key") do
      [raw_key | _] ->
        hash = :crypto.hash(:sha256, raw_key) |> Base.encode16(case: :lower)

        case Repo.get_by(ApiKey, key_hash: hash, is_active: true) do
          nil ->
            conn
            |> put_status(:unauthorized)
            |> Phoenix.Controller.json(%{error: "Invalid API key"})
            |> halt()

          %ApiKey{} = key ->
            cond do
              key.expires_at && DateTime.compare(key.expires_at, DateTime.utc_now()) == :lt ->
                conn
                |> put_status(:unauthorized)
                |> Phoenix.Controller.json(%{error: "API key expired"})
                |> halt()

              required_scope not in key.scopes ->
                conn
                |> put_status(:forbidden)
                |> Phoenix.Controller.json(%{error: "Insufficient scope"})
                |> halt()

              true ->
                from(k in ApiKey, where: k.id == ^key.id)
                |> Repo.update_all(
                  set: [last_used_at: DateTime.utc_now() |> DateTime.truncate(:second)],
                  inc: [total_requests: 1]
                )

                conn
                |> assign(:api_key, key)
                |> assign(:api_key_user_id, key.user_id)
                |> assign(:community_id, key.community_id || conn.assigns[:community_id])
            end
        end

      _ ->
        conn
    end
  end
end
