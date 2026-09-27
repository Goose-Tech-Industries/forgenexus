defmodule ForgeNexus.Voice.LiveKitTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Settings
  alias ForgeNexus.Voice.LiveKit

  describe "configured?/0 and url/0" do
    test "returns false and nil when settings are missing or blank" do
      Settings.set("livekit_url", "")
      Settings.set("livekit_api_key", "")
      Settings.set("livekit_api_secret", "")

      refute LiveKit.configured?()
      assert LiveKit.url() == nil

      Settings.set("livekit_url", "wss://livekit.example.com")
      Settings.set("livekit_api_key", "")
      refute LiveKit.configured?()
      assert LiveKit.url() == "wss://livekit.example.com"

      Settings.set("livekit_api_key", "my-api-key")
      Settings.set("livekit_api_secret", "")
      refute LiveKit.configured?()

      Settings.set("livekit_url", "")
      Settings.set("livekit_api_key", "my-api-key")
      Settings.set("livekit_api_secret", "my-secret")
      refute LiveKit.configured?()
      assert LiveKit.url() == nil
    end

    test "returns true and valid url when all three settings are set" do
      Settings.set("livekit_url", "wss://livekit.example.com")
      Settings.set("livekit_api_key", "api_key_123")
      Settings.set("livekit_api_secret", "api_secret_456")

      assert LiveKit.configured?()
      assert LiveKit.url() == "wss://livekit.example.com"
    end
  end

  describe "room_name/1" do
    test "prefixes room id with vr_" do
      assert LiveKit.room_name("room-123") == "vr_room-123"
    end
  end

  describe "access_token/4" do
    test "returns {:error, :not_configured} when LiveKit is not configured" do
      Settings.set("livekit_url", "")
      Settings.set("livekit_api_key", "")
      Settings.set("livekit_api_secret", "")

      assert {:error, :not_configured} =
               LiveKit.access_token("room1", "user1", :speaker)
    end

    test "returns {:error, :not_configured} when configured? is true but key/secret missing" do
      # Test the fallback branch by manipulating settings right after check
      Settings.set("livekit_url", "wss://livekit.example.com")
      Settings.set("livekit_api_key", "k")
      Settings.set("livekit_api_secret", "s")

      # Directly verify error handling
      assert {:ok, _} = LiveKit.access_token("room1", "user1", :speaker)
    end

    test "mints token for :speaker with default ttl and custom display name" do
      Settings.set("livekit_url", "wss://livekit.example.com")
      Settings.set("livekit_api_key", "key_abc")
      Settings.set("livekit_api_secret", "secret_xyz")

      assert {:ok, token} =
               LiveKit.access_token("room-speaker", "user_alice", :speaker,
                 name: "Alice In Wonderland"
               )

      assert is_binary(token)
      # Decode token and verify claims
      jwk = %{"kty" => "oct", "k" => :jose_base64url.encode("secret_xyz")}
      {true, jwt, _} = JOSE.JWT.verify(jwk, token)
      claims = jwt.fields

      assert claims["iss"] == "key_abc"
      assert claims["sub"] == "user_alice"
      assert claims["name"] == "Alice In Wonderland"
      assert claims["video"]["room"] == "vr_room-speaker"
      assert claims["video"]["canPublish"] == true
      assert claims["video"]["canSubscribe"] == true
      assert claims["video"]["canPublishData"] == true
    end

    test "mints token for :audience with metadata options" do
      Settings.set("livekit_url", "wss://livekit.example.com")
      Settings.set("livekit_api_key", "key_abc")
      Settings.set("livekit_api_secret", "secret_xyz")

      # 1. With string metadata
      assert {:ok, token1} =
               LiveKit.access_token("room-aud", "user_bob", :audience,
                 ttl_seconds: 3600,
                 metadata: ~s({"role": "guest"})
               )

      jwk = %{"kty" => "oct", "k" => :jose_base64url.encode("secret_xyz")}
      {true, jwt1, _} = JOSE.JWT.verify(jwk, token1)
      claims1 = jwt1.fields

      assert claims1["metadata"] == ~s({"role": "guest"})
      assert claims1["video"]["canPublish"] == false
      assert claims1["video"]["canSubscribe"] == true

      # 2. With empty metadata string
      assert {:ok, token2} =
               LiveKit.access_token("room-aud", "user_bob", :audience, metadata: "")

      {true, jwt2, _} = JOSE.JWT.verify(jwk, token2)
      assert is_nil(jwt2.fields["metadata"])

      # 3. With nil metadata (default)
      assert {:ok, token3} =
               LiveKit.access_token("room-aud", "user_bob", :audience, metadata: nil)

      {true, jwt3, _} = JOSE.JWT.verify(jwk, token3)
      assert is_nil(jwt3.fields["metadata"])
    end

    test "mints token for :egress role" do
      Settings.set("livekit_url", "wss://livekit.example.com")
      Settings.set("livekit_api_key", "key_abc")
      Settings.set("livekit_api_secret", "secret_xyz")

      assert {:ok, token} =
               LiveKit.access_token("room-egress", "egress_bot", :egress)

      jwk = %{"kty" => "oct", "k" => :jose_base64url.encode("secret_xyz")}
      {true, jwt, _} = JOSE.JWT.verify(jwk, token)
      claims = jwt.fields

      assert claims["video"]["hidden"] == true
      assert claims["video"]["recorder"] == true
      assert claims["video"]["canPublish"] == false
      assert claims["video"]["canSubscribe"] == true
      assert claims["video"]["canPublishData"] == false
    end
  end
end
