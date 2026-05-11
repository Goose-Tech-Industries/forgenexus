defmodule ForgeNexus.Voice.TurnCredentials do
  @moduledoc """
  Mints short-lived TURN credentials using the coturn `use-auth-secret` (REST API)
  scheme defined in draft-uberti-rtcweb-turn-rest-00.

  username = `<unix-expiry>:<user-id>`
  password = base64(HMAC-SHA1(static-auth-secret, username))

  Returns a list of `RTCIceServer` dicts ready for the browser. Includes the
  shared static secret server-side only — never returned to the client.
  """

  alias ForgeNexus.Settings

  @spec ice_config(String.t()) :: %{ice_servers: list(map()), ttl: pos_integer()}
  def ice_config(user_id) when is_binary(user_id) do
    ttl = ttl_seconds()
    expiry = System.system_time(:second) + ttl
    secret = secret()

    base_servers = [
      %{urls: ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]}
    ]

    turn_servers =
      case {turn_url(), turn_url_tls(), secret} do
        {nil, nil, _} ->
          []

        {_, _, nil} ->
          []

        {url, tls_url, secret} ->
          username = "#{expiry}:#{user_id}"
          credential = mint_credential(secret, username)

          urls = Enum.reject([url, tls_url], &is_nil/1)
          [%{urls: urls, username: username, credential: credential}]
      end

    %{ice_servers: base_servers ++ turn_servers, ttl: ttl}
  end

  defp mint_credential(secret, username) do
    :crypto.mac(:hmac, :sha, secret, username)
    |> Base.encode64()
  end

  defp ttl_seconds do
    case Integer.parse(Settings.get("turn_credential_ttl_seconds") || "3600") do
      {n, _} when n > 0 -> n
      _ -> 3600
    end
  end

  defp turn_url do
    case Settings.get("turn_url") do
      nil -> nil
      "" -> nil
      url -> url
    end
  end

  defp turn_url_tls do
    case Settings.get("turn_url_tls") do
      nil -> nil
      "" -> nil
      url -> url
    end
  end

  defp secret do
    System.get_env("TURN_SECRET") |> nil_if_empty()
  end

  defp nil_if_empty(nil), do: nil
  defp nil_if_empty(""), do: nil
  defp nil_if_empty(s), do: s
end
