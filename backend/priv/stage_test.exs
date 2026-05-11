import Ecto.Query
alias ForgeNexus.Voice
alias ForgeNexus.Voice.RoomServer
alias ForgeNexus.Repo
alias ForgeNexus.Accounts.User

IO.puts("=== Stage mode smoke test ===\n")

# Find or create a town_hall voice room
room =
  case Repo.get_by(ForgeNexus.Voice.Room, slug: "stage-smoke-test") do
    nil ->
      {:ok, r} =
        Voice.create_room(%{
          "name" => "Stage Smoke",
          "slug" => "stage-smoke-test",
          "type" => "town_hall",
          "max_participants" => 10,
          "is_active" => true,
          "position" => 99
        })

      r

    existing ->
      existing
  end

IO.puts("Room: #{room.name} (type=#{room.type}, id=#{room.id})")

# Kill any existing server so we start fresh
case GenServer.whereis({:via, Registry, {ForgeNexus.Voice.RoomRegistry, room.id}}) do
  nil -> :ok
  pid -> GenServer.stop(pid, :normal)
end

# Get two real users
[host_user, audience_user] = Repo.all(User) |> Enum.take(2)
IO.puts("Host user: #{host_user.username}")
IO.puts("Audience user: #{audience_user.username}")

# 1. Host joins first
{:ok, host_join} = Voice.join_room(room.id, host_user)
IO.inspect(host_join, label: "\n[1] host join")

unless host_join.is_host do
  IO.puts("FAIL: first joiner should be host")
  System.halt(1)
end

unless host_join.your_role == "speaker" do
  IO.puts("FAIL: host should be speaker, got #{host_join.your_role}")
  System.halt(1)
end

# 2. Second user joins — should be audience
{:ok, audience_join} = Voice.join_room(room.id, audience_user)
IO.inspect(audience_join, label: "\n[2] audience join")

unless audience_join.your_role == "audience" do
  IO.puts("FAIL: second joiner should be audience, got #{audience_join.your_role}")
  System.halt(1)
end

if audience_join.is_host do
  IO.puts("FAIL: audience should not be host")
  System.halt(1)
end

# 3. Audience member raises hand
:ok = Voice.set_hand_raised(room.id, audience_user.id, true)
IO.puts("\n[3] audience raised hand -> :ok")

participants = RoomServer.get_participants(room.id)
aud = Enum.find(participants, &(&1.user_id == audience_user.id))

unless aud.hand_raised do
  IO.puts("FAIL: hand not raised in state")
  System.halt(1)
end

# 4. Non-host speaker cannot promote if they're not the host (but they're speaker).
#    In our implementation, speakers CAN promote. Let's verify host can.
:ok = Voice.promote_to_speaker(room.id, audience_user.id, host_user.id)
IO.puts("[4] host promoted audience -> :ok")

participants = RoomServer.get_participants(room.id)
promoted = Enum.find(participants, &(&1.user_id == audience_user.id))

unless promoted.role == "speaker" do
  IO.puts("FAIL: promotion did not set role to speaker, got #{promoted.role}")
  System.halt(1)
end

if promoted.muted do
  IO.puts("FAIL: promoted user should be unmuted, still muted")
  System.halt(1)
end

if promoted.hand_raised do
  IO.puts("FAIL: promoted user should have hand lowered")
  System.halt(1)
end

# 5. Audience (now speaker) unmutes successfully
:ok = Voice.update_media_state(room.id, audience_user.id, %{muted: false})
IO.puts("[5] promoted user unmuted -> :ok")

# 6. Host demotes them back
:ok = Voice.demote_to_audience(room.id, audience_user.id, host_user.id)
IO.puts("[6] host demoted -> :ok")

participants = RoomServer.get_participants(room.id)
demoted = Enum.find(participants, &(&1.user_id == audience_user.id))

unless demoted.role == "audience" do
  IO.puts("FAIL: demotion did not set role to audience")
  System.halt(1)
end

unless demoted.muted do
  IO.puts("FAIL: demoted user should be force-muted in stage room")
  System.halt(1)
end

# 7. Audience member tries to unmute themselves -> rejected
case Voice.update_media_state(room.id, audience_user.id, %{muted: false}) do
  {:error, :audience_cannot_unmute} ->
    IO.puts("[7] audience unmute rejected (correct)")

  other ->
    IO.puts("FAIL: expected :audience_cannot_unmute, got #{inspect(other)}")
    System.halt(1)
end

# 8. Audience member CAN stay muted (no-op)
:ok = Voice.update_media_state(room.id, audience_user.id, %{muted: true})
IO.puts("[8] audience re-mute allowed (no-op)")

# 9. Non-host non-speaker cannot promote others.
#    audience_user is currently audience — try to promote... nobody else.
#    Instead, verify the permission check: if we create a third person as audience,
#    they can't promote anyone.
# Skipping — we only have 2 users.

# 10. Host leaves -> audience_user should become new host (they're the only one left,
#     will be promoted from audience to speaker)
Voice.leave_room(room.id, host_user.id)
Process.sleep(100)

participants = RoomServer.get_participants(room.id)
IO.inspect(participants, label: "\n[10] after host leave")

state = RoomServer.get_state(room.id)
IO.inspect(state, label: "[10] room state")

unless state.host_id == audience_user.id do
  IO.puts("FAIL: new host should be #{audience_user.id}, got #{state.host_id}")
  System.halt(1)
end

# 11. Cleanup — last user leaves, triggering log_call with metrics
Voice.leave_room(room.id, audience_user.id)
Process.sleep(300)

# 12. Verify the call log captured metrics
log =
  from(c in ForgeNexus.Voice.CallLog,
    where: c.room_id == ^room.id,
    order_by: [desc: c.inserted_at],
    limit: 1
  )
  |> Repo.one()

IO.puts("\n[12] latest call log:")
IO.inspect(log && Map.take(log, [
  :peak_participants, :peak_audience, :peak_speakers,
  :total_hand_raises, :total_promotions, :total_demotions,
  :host_user_id, :participant_ids
]))

if log do
  checks = [
    {log.peak_participants == 2, "peak_participants should be 2"},
    {log.total_hand_raises >= 1, "total_hand_raises should be >= 1"},
    {log.total_promotions >= 1, "total_promotions should be >= 1"},
    {log.total_demotions >= 1, "total_demotions should be >= 1"},
    {log.host_user_id != nil, "host_user_id should be set"},
    {length(log.participant_ids) == 2, "participant_ids should contain 2 users"}
  ]

  Enum.each(checks, fn {ok?, msg} ->
    if ok?, do: IO.puts("  ✓ #{msg}"), else: (IO.puts("  ✗ #{msg}"); System.halt(1))
  end)
else
  IO.puts("FAIL: no call log created")
  System.halt(1)
end

IO.puts("\n=== All stage mode checks passed ===")
