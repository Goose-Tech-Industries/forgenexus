alias ForgeNexus.Voice.LiveKit
alias ForgeNexus.Settings

passed = 0
failed = 0

check = fn label, cond ->
  if cond do
    IO.puts("  ✓ #{label}")
    {passed + 1, failed}
  else
    IO.puts("  ✗ #{label}")
    {passed, failed + 1}
  end
end

IO.puts("\n=== LiveKit token minter smoke test ===\n")

# 1. Unconfigured state returns :not_configured
Settings.set("livekit_url", "")
Settings.set("livekit_api_key", "")
Settings.set("livekit_api_secret", "")

{passed, failed} = check.("configured?/0 is false with empty settings", LiveKit.configured?() == false)

{passed, failed} =
  case LiveKit.access_token("room-123", "user-abc", :speaker) do
    {:error, :not_configured} -> check.("access_token/4 returns :not_configured when unset", true)
    other -> check.("access_token/4 returns :not_configured when unset (got #{inspect(other)})", false)
  end

# 2. Configure with test values
Settings.set("livekit_url", "wss://test.livekit.cloud")
Settings.set("livekit_api_key", "APIkey123456")
Settings.set("livekit_api_secret", "supersecretvalueforhs256signingdontuseinprod")

{passed, failed} = check.("configured?/0 is true after setting url/key/secret", LiveKit.configured?() == true)
{passed, failed} = check.("url/0 returns configured ws URL", LiveKit.url() == "wss://test.livekit.cloud")
{passed, failed} = check.("room_name/1 prefixes with vr_", LiveKit.room_name("abc-def") == "vr_abc-def")

# 3. Mint a speaker token and verify it parses as a JWT with the right claims
{passed, failed} =
  case LiveKit.access_token("abc-def", "user-1", :speaker, name: "Alice") do
    {:ok, token} when is_binary(token) ->
      parts = String.split(token, ".")
      {passed, failed} = check.("token has 3 JWT parts", length(parts) == 3)

      [_header, payload_b64, _sig] = parts
      payload = payload_b64 |> Base.url_decode64!(padding: false) |> Jason.decode!()

      {passed, failed} = check.("iss == api key", payload["iss"] == "APIkey123456")
      {passed, failed} = check.("sub == identity", payload["sub"] == "user-1")
      {passed, failed} = check.("name is set", payload["name"] == "Alice")
      {passed, failed} = check.("video.room is vr_abc-def", payload["video"]["room"] == "vr_abc-def")
      {passed, failed} = check.("speaker can publish", payload["video"]["canPublish"] == true)
      {passed, failed} = check.("speaker can subscribe", payload["video"]["canSubscribe"] == true)
      {passed, failed} = check.("roomJoin grant set", payload["video"]["roomJoin"] == true)
      {passed, failed} = check.("exp is in the future", payload["exp"] > System.system_time(:second))
      {passed, failed}

    other ->
      check.("access_token/4 returned ok tuple (got #{inspect(other)})", false)
  end

# 4. Audience token cannot publish
{passed, failed} =
  case LiveKit.access_token("abc-def", "user-2", :audience) do
    {:ok, token} ->
      [_h, p, _s] = String.split(token, ".")
      payload = p |> Base.url_decode64!(padding: false) |> Jason.decode!()

      {passed, failed} = check.("audience canPublish=false", payload["video"]["canPublish"] == false)
      {passed, failed} = check.("audience canSubscribe=true", payload["video"]["canSubscribe"] == true)
      {passed, failed} = check.("audience canPublishData=true", payload["video"]["canPublishData"] == true)
      {passed, failed}

    other ->
      check.("audience access_token ok (got #{inspect(other)})", false)
  end

# 5. Egress token is hidden recorder
{passed, failed} =
  case LiveKit.access_token("abc-def", "egress-1", :egress) do
    {:ok, token} ->
      [_h, p, _s] = String.split(token, ".")
      payload = p |> Base.url_decode64!(padding: false) |> Jason.decode!()
      {passed, failed} = check.("egress hidden=true", payload["video"]["hidden"] == true)
      {passed, failed} = check.("egress recorder=true", payload["video"]["recorder"] == true)
      {passed, failed}

    other ->
      check.("egress access_token ok (got #{inspect(other)})", false)
  end

# Clean up test settings so we don't leave credentials in the dev DB
Settings.set("livekit_url", "")
Settings.set("livekit_api_key", "")
Settings.set("livekit_api_secret", "")

IO.puts("")

if failed == 0 do
  IO.puts("=== All LiveKit token checks passed (#{passed}) ===")
else
  IO.puts("=== #{failed} LiveKit token checks FAILED (#{passed} passed) ===")
  System.halt(1)
end
