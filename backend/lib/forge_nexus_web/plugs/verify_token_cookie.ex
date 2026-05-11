defmodule ForgeNexusWeb.Plugs.VerifyTokenCookie do
  @moduledoc """
  Falls back to reading JWT from the `fn_token` cookie if no Bearer header was provided.
  """

  def init(opts), do: opts

  def call(conn, _opts) do
    # If Guardian already found a resource from the Bearer header, skip
    case Guardian.Plug.current_resource(conn) do
      nil ->
        # Try reading from cookie
        case conn.cookies["fn_token"] || conn.req_cookies["fn_token"] do
          nil -> conn
          "" -> conn
          token ->
            case ForgeNexus.Guardian.resource_from_token(token) do
              {:ok, user, _claims} ->
                Guardian.Plug.put_current_resource(conn, user)
              _ ->
                conn
            end
        end

      _user ->
        conn
    end
  end
end
