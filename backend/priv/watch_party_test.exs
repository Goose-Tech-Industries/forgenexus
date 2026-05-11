alias ForgeNexus.Voice
alias ForgeNexus.Voice.WatchParty
alias ForgeNexus.Repo
alias ForgeNexus.Accounts.User

IO.puts("=== Watch Party smoke test ===\n")

# --- URL parser unit tests ---
IO.puts("## URL parser")

parser_cases = [
  {"https://www.youtube.com/watch?v=dQw4w9WgXcQ", :youtube, "dQw4w9WgXcQ"},
  {"https://youtu.be/dQw4w9WgXcQ", :youtube, "dQw4w9WgXcQ"},
  {"https://www.youtube.com/shorts/abc123DEFGH", :youtube, "abc123DEFGH"},
  {"https://youtube.com/embed/XxxYYYzzz12", :youtube, "XxxYYYzzz12"},
  {"https://www.youtube.com/watch?feature=share&v=dQw4w9WgXcQ", :youtube, "dQw4w9WgXcQ"},
  {"https://www.twitch.tv/videos/1234567890", :twitch_video, "1234567890"},
  {"https://clips.twitch.tv/SuperCleverClipName", :twitch_clip, "SuperCleverClipName"},
  {"https://www.twitch.tv/someuser/clip/SuperCleverClipName", :twitch_clip, "SuperCleverClipName"},
  {"https://www.twitch.tv/shroud", :twitch_channel, "shroud"},
  {"https://vimeo.com/123456789", :vimeo, "123456789"},
  {"https://not-a-video-site.example/video", :error, nil},
  {"not even a url", :error, nil}
]

Enum.each(parser_cases, fn
  {url, :error, _} ->
    case WatchParty.parse_url(url) do
      {:error, _} -> IO.puts("  ✓ rejected: #{url}")
      {:ok, m} -> IO.puts("  ✗ expected rejection, got #{inspect(m)} for: #{url}"); System.halt(1)
    end

  {url, expected_type, expected_id} ->
    case WatchParty.parse_url(url) do
      {:ok, %{type: ^expected_type, id: ^expected_id}} ->
        IO.puts("  ✓ parsed #{expected_type}/#{expected_id}: #{url}")

      other ->
        IO.puts("  ✗ expected {#{expected_type}, #{expected_id}}, got #{inspect(other)} for: #{url}")
        System.halt(1)
    end
end)

# --- Integration: through the RoomServer ---
IO.puts("\n## RoomServer integration")

# Find or create a lounge room
room =
  case Repo.get_by(ForgeNexus.Voice.Room, slug: "watch-party-smoke") do
    nil ->
      {:ok, r} =
        Voice.create_room(%{
          "name" => "Watch Party Smoke",
          "slug" => "watch-party-smoke",
          "type" => "lounge",
          "max_participants" => 10,
          "is_active" => true,
          "position" => 99
        })

      r

    existing ->
      existing
  end

# Reset GenServer if running
case GenServer.whereis({:via, Registry, {ForgeNexus.Voice.RoomRegistry, room.id}}) do
  nil -> :ok
  pid -> GenServer.stop(pid, :normal)
end

[u1, u2] = Repo.all(User) |> Enum.take(2)
IO.puts("  Host: #{u1.username}")
IO.puts("  Guest: #{u2.username}")

{:ok, _} = Voice.join_room(room.id, u1)
{:ok, guest_join} = Voice.join_room(room.id, u2)

if guest_join.watch_party == nil do
  IO.puts("  ✓ guest join has no watch party when none active")
else
  IO.puts("  ✗ guest join unexpectedly has a watch party")
  System.halt(1)
end

# Start watch party as u1
case Voice.start_watch_party(room.id, "https://www.youtube.com/watch?v=dQw4w9WgXcQ", u1.id) do
  {:ok, party} ->
    IO.puts("  ✓ u1 started watch party: #{party.media.type}/#{party.media.id}")

    unless party.media.type == "youtube" and party.media.id == "dQw4w9WgXcQ" do
      IO.puts("  ✗ wrong media in party: #{inspect(party)}")
      System.halt(1)
    end

    unless party.is_playing, do: (IO.puts("  ✗ expected is_playing true"); System.halt(1))
    unless party.host_user_id == u1.id, do: (IO.puts("  ✗ wrong host"); System.halt(1))

  {:error, reason} ->
    IO.puts("  ✗ start failed: #{inspect(reason)}")
    System.halt(1)
end

# Starting a second one while active: currently our implementation REPLACES the party.
# Verify the second start succeeds and replaces.
{:ok, _} = Voice.start_watch_party(room.id, "https://youtu.be/abc123DEFGH", u1.id)
party_now = Voice.get_watch_party(room.id)

if party_now.media.id == "abc123DEFGH" do
  IO.puts("  ✓ restart replaces the existing party")
else
  IO.puts("  ✗ restart did not replace: #{inspect(party_now)}")
  System.halt(1)
end

# u2 (not the party host) tries to control — should be denied
case Voice.control_watch_party(room.id, u2.id, :pause, %{}) do
  {:error, :permission_denied} ->
    IO.puts("  ✓ non-host control denied")

  other ->
    IO.puts("  ✗ expected permission_denied, got #{inspect(other)}")
    System.halt(1)
end

# u1 pauses
{:ok, after_pause} = Voice.control_watch_party(room.id, u1.id, :pause, %{})
unless after_pause.is_playing == false do
  IO.puts("  ✗ pause did not set is_playing false")
  System.halt(1)
end
IO.puts("  ✓ u1 paused")

# u1 seeks to 120s
{:ok, after_seek} = Voice.control_watch_party(room.id, u1.id, :seek, %{time: 120.5})
unless after_seek.current_time == 120.5 do
  IO.puts("  ✗ seek did not set current_time to 120.5, got #{after_seek.current_time}")
  System.halt(1)
end
IO.puts("  ✓ u1 seeked to 120.5s")

# u1 sync (catch-up broadcast)
{:ok, after_sync} = Voice.control_watch_party(room.id, u1.id, :sync, %{time: 300.0, playing: true})
unless after_sync.current_time == 300.0 and after_sync.is_playing == true do
  IO.puts("  ✗ sync state wrong: #{inspect(after_sync)}")
  System.halt(1)
end
IO.puts("  ✓ u1 synced to 300.0s playing")

# New joiner should receive the watch party in their join payload
# Stop and rejoin u2 to simulate
Voice.leave_room(room.id, u2.id)
Process.sleep(50)
{:ok, rejoin} = Voice.join_room(room.id, u2)
if rejoin.watch_party && rejoin.watch_party.media.id == "abc123DEFGH" do
  IO.puts("  ✓ new joiner receives active watch party in join payload")
else
  IO.puts("  ✗ new joiner missing watch party: #{inspect(rejoin.watch_party)}")
  System.halt(1)
end

# u2 tries to stop — should be denied
case Voice.stop_watch_party(room.id, u2.id) do
  {:error, :permission_denied} ->
    IO.puts("  ✓ non-host stop denied")

  other ->
    IO.puts("  ✗ expected permission_denied, got #{inspect(other)}")
    System.halt(1)
end

# u1 stops
:ok = Voice.stop_watch_party(room.id, u1.id)
if Voice.get_watch_party(room.id) == nil do
  IO.puts("  ✓ u1 stopped; watch party cleared")
else
  IO.puts("  ✗ watch party should be nil after stop")
  System.halt(1)
end

# Start again, then u1 (party host) leaves — party should end automatically
{:ok, _} = Voice.start_watch_party(room.id, "https://www.youtube.com/watch?v=zzzYYYxxx12", u1.id)
Voice.leave_room(room.id, u1.id)
Process.sleep(100)

if Voice.get_watch_party(room.id) == nil do
  IO.puts("  ✓ watch party ended when host left the room")
else
  IO.puts("  ✗ watch party should have ended with host departure: #{inspect(Voice.get_watch_party(room.id))}")
  System.halt(1)
end

# Stop control with no party
case Voice.control_watch_party(room.id, u2.id, :pause, %{}) do
  {:error, :no_watch_party} -> IO.puts("  ✓ control-without-party returns :no_watch_party")
  other -> IO.puts("  ✗ expected :no_watch_party, got #{inspect(other)}"); System.halt(1)
end

# Cleanup: last user leaves (u2 still in)
Voice.leave_room(room.id, u2.id)
Process.sleep(100)

IO.puts("\n=== All watch party checks passed ===")
