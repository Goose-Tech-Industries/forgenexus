defmodule ForgeNexusWeb.Plugs.VerifyCookie do
  @moduledoc """
  Reads JWT from httpOnly cookie and verifies it via Guardian.
  Only activates if no token was found via the Bearer header.
  """

  @cookie_name "fn_token"

  def init(opts), do: opts

  def call(conn, _opts) do
    # Skip if Guardian already found a resource from the Bearer header
    case Guardian.Plug.current_resource(conn) do
      nil ->
        case conn.cookies[@cookie_name] do
          nil -> conn
          token -> verify_token(conn, token)
        end

      _user ->
        conn
    end
  end

  defp verify_token(conn, token) do
    case ForgeNexus.Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        case ForgeNexus.Guardian.resource_from_claims(claims) do
          {:ok, resource} ->
            conn
            |> Guardian.Plug.put_current_resource(resource)
            |> Guardian.Plug.put_current_claims(claims)
            |> Guardian.Plug.put_current_token(token)

          _ ->
            conn
        end

      _ ->
        conn
    end
  end
end
