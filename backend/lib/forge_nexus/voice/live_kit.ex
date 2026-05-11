defmodule ForgeNexus.Voice.LiveKit do
  @moduledoc """
  LiveKit integration — SFU-backed WebRTC rooms.

  Phoenix remains the source of truth for roles, stage mode, watch parties,
  and metrics. LiveKit is the **media plane only**: we mint short-lived JWT
  access tokens that clients use to connect to a LiveKit room whose name
  matches our `voice_rooms.id`.

  ## Access tokens

  LiveKit access tokens are HS256 JWTs signed with the project API secret.
  The grant shape is documented at https://docs.livekit.io/home/get-started/authentication/

  We issue the minimum privileges needed for each role:

    * `:speaker`  — can publish tracks, subscribe, send data
    * `:audience` — can subscribe and send data; cannot publish
    * `:egress`   — server-side recording bot (publish + subscribe off, hidden)

  ## Configuration

  Three site settings, all admin-editable at runtime:

    * `livekit_url`        — e.g. `wss://my-project.livekit.cloud`
    * `livekit_api_key`    — project API key
    * `livekit_api_secret` — project API secret (used only server-side)

  Until `livekit_url` is set, `configured?/0` returns false and the voice
  channel falls back to the legacy mesh WebRTC signalling path.
  """

  alias ForgeNexus.Settings

  @default_ttl_seconds 6 * 60 * 60

  @type role :: :speaker | :audience | :egress

  @doc "Is LiveKit configured? True iff URL + key + secret are all set."
  @spec configured?() :: boolean()
  def configured? do
    with url when is_binary(url) and url != "" <- Settings.get("livekit_url"),
         key when is_binary(key) and key != "" <- Settings.get("livekit_api_key"),
         secret when is_binary(secret) and secret != "" <- Settings.get("livekit_api_secret") do
      true
    else
      _ -> false
    end
  end

  @doc "LiveKit WS URL for the client, or nil if not configured."
  @spec url() :: String.t() | nil
  def url do
    case Settings.get("livekit_url") do
      s when is_binary(s) and s != "" -> s
      _ -> nil
    end
  end

  @doc """
  Mint an access token for a participant joining a room.

  Options:
    * `:ttl_seconds` — token lifetime (default 6 hours)
    * `:name`        — display name embedded in the token
    * `:metadata`    — opaque participant metadata (JSON string)
  """
  @spec access_token(String.t(), String.t(), role(), keyword()) ::
          {:ok, String.t()} | {:error, :not_configured}
  def access_token(room_id, identity, role, opts \\ [])
      when is_binary(room_id) and is_binary(identity) and role in [:speaker, :audience, :egress] do
    with true <- configured?() || {:error, :not_configured},
         key when is_binary(key) <- Settings.get("livekit_api_key"),
         secret when is_binary(secret) <- Settings.get("livekit_api_secret") do
      now = System.system_time(:second)
      ttl = Keyword.get(opts, :ttl_seconds, @default_ttl_seconds)

      claims =
        %{
          "iss" => key,
          "sub" => identity,
          "nbf" => now,
          "iat" => now,
          "exp" => now + ttl,
          "name" => Keyword.get(opts, :name, identity),
          "video" => grants_for(role, room_id)
        }
        |> maybe_put_metadata(Keyword.get(opts, :metadata))

      {:ok, sign(claims, secret)}
    else
      {:error, _} = err -> err
      _ -> {:error, :not_configured}
    end
  end

  @doc "Room name used by LiveKit for a given voice_rooms.id."
  @spec room_name(String.t()) :: String.t()
  def room_name(room_id), do: "vr_" <> room_id

  # --- Grants ---

  defp grants_for(:speaker, room_id) do
    %{
      "room" => room_name(room_id),
      "roomJoin" => true,
      "canPublish" => true,
      "canSubscribe" => true,
      "canPublishData" => true
    }
  end

  defp grants_for(:audience, room_id) do
    %{
      "room" => room_name(room_id),
      "roomJoin" => true,
      "canPublish" => false,
      "canSubscribe" => true,
      "canPublishData" => true
    }
  end

  defp grants_for(:egress, room_id) do
    %{
      "room" => room_name(room_id),
      "roomJoin" => true,
      "canPublish" => false,
      "canSubscribe" => true,
      "canPublishData" => false,
      "hidden" => true,
      "recorder" => true
    }
  end

  defp maybe_put_metadata(claims, nil), do: claims
  defp maybe_put_metadata(claims, ""), do: claims
  defp maybe_put_metadata(claims, meta) when is_binary(meta), do: Map.put(claims, "metadata", meta)

  # --- JWT signing (HS256 via JOSE) ---

  defp sign(claims, secret) do
    jwk = %{"kty" => "oct", "k" => :jose_base64url.encode(secret)}
    jws = %{"alg" => "HS256", "typ" => "JWT"}
    {_, token} = JOSE.JWT.sign(jwk, jws, claims) |> JOSE.JWS.compact()
    token
  end
end
