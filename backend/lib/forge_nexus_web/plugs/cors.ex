defmodule ForgeNexusWeb.Plugs.CORS do
  import Plug.Conn

  @dev_origins ["http://localhost:5173", "http://127.0.0.1:5173"]

  def init(opts), do: opts

  def call(conn, _opts) do
    origin = get_req_header(conn, "origin") |> List.first()
    allowed = allowed_origins()

    if conn.method == "OPTIONS" and origin_allowed?(origin, allowed) do
      conn
      |> put_cors_headers(origin)
      |> send_resp(200, "")
      |> halt()
    else
      conn
      |> put_cors_headers_if_allowed(origin, allowed)
      |> register_before_send(fn resp_conn ->
        put_cors_headers_if_allowed(resp_conn, origin, allowed)
      end)
    end
  end

  defp allowed_origins do
    case Application.get_env(:forge_nexus, :cors_origins) do
      origins when is_list(origins) and origins != [] -> origins
      _ -> @dev_origins
    end
  end

  defp origin_allowed?(_origin, ["*"]), do: true
  defp origin_allowed?(origin, origins), do: origin in origins

  defp put_cors_headers_if_allowed(conn, origin, allowed) do
    if origin_allowed?(origin, allowed) do
      put_cors_headers(conn, origin)
    else
      conn
    end
  end

  defp put_cors_headers(conn, origin) do
    conn
    |> put_resp_header("access-control-allow-origin", origin || "*")
    |> put_resp_header("access-control-allow-credentials", "true")
    |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "content-type, authorization, accept")
    |> put_resp_header("access-control-max-age", "86400")
  end
end
