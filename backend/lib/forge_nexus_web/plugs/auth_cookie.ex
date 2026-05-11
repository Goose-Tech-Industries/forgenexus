defmodule ForgeNexusWeb.Plugs.AuthCookie do
  @moduledoc """
  Helpers to set/clear httpOnly auth cookies.
  Uses a short-lived access token (1 day) and a long-lived refresh token (30 days).
  """
  import Plug.Conn

  @access_cookie "fn_token"
  @refresh_cookie "fn_refresh"
  @access_max_age 86_400       # 1 day
  @refresh_max_age 2_592_000   # 30 days

  def set_cookie(conn, token) do
    put_resp_cookie(conn, @access_cookie, token,
      http_only: true,
      secure: Mix.env() == :prod,
      same_site: "Lax",
      max_age: @access_max_age,
      path: "/"
    )
  end

  def set_refresh_cookie(conn, refresh_token) do
    put_resp_cookie(conn, @refresh_cookie, refresh_token,
      http_only: true,
      secure: Mix.env() == :prod,
      same_site: "Lax",
      max_age: @refresh_max_age,
      path: "/api/auth"
    )
  end

  def set_both(conn, access_token, refresh_token) do
    conn
    |> set_cookie(access_token)
    |> set_refresh_cookie(refresh_token)
  end

  def get_refresh_token(conn) do
    conn.cookies[@refresh_cookie]
  end

  def clear_cookie(conn) do
    conn
    |> delete_resp_cookie(@access_cookie, path: "/")
    |> delete_resp_cookie(@refresh_cookie, path: "/api/auth")
  end

  def refresh_cookie_name, do: @refresh_cookie
end
