defmodule ForgeNexusWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Sets security headers on all responses.
  CSP and connect-src are configurable for production domains.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    frontend = frontend_origin()
    backend = backend_origin()

    csp = [
      "default-src 'self' #{frontend}",
      "script-src 'self' 'unsafe-inline'",
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
      "font-src 'self' https://fonts.gstatic.com",
      "img-src 'self' data: blob: #{backend}",
      "connect-src 'self' #{backend} #{ws_origin(backend)}",
      "frame-src https://www.youtube.com",
      "media-src 'self'",
      "object-src 'none'",
      "base-uri 'self'",
      "form-action 'self'",
      "frame-ancestors 'none'",
      "upgrade-insecure-requests"
    ] |> Enum.join("; ")

    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-xss-protection", "0")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy",
      "camera=(), microphone=(), geolocation=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=()"
    )
    |> put_resp_header("cross-origin-opener-policy", "same-origin")
    |> put_resp_header("cross-origin-resource-policy", "same-origin")
    |> put_resp_header("content-security-policy", csp)
  end

  defp frontend_origin do
    Application.get_env(:forge_nexus, :frontend_origin, "http://localhost:5173")
  end

  defp backend_origin do
    host = Application.get_env(:forge_nexus, ForgeNexusWeb.Endpoint)[:url][:host] || "localhost"
    port = Application.get_env(:forge_nexus, ForgeNexusWeb.Endpoint)[:http][:port] || 4000

    if host == "localhost" do
      "http://localhost:#{port}"
    else
      "https://#{host}"
    end
  end

  defp ws_origin(origin) do
    origin
    |> String.replace("https://", "wss://")
    |> String.replace("http://", "ws://")
  end
end
