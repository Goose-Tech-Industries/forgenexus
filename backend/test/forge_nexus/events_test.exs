defmodule ForgeNexus.EventsTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Events
  alias ForgeNexus.Events.{Event, EventRsvp}
  alias ForgeNexus.Accounts
  alias ForgeNexus.Forums

  defp create_user do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "evt_u_#{unique}",
        email: "evt_u_#{unique}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp event_attrs(user_id, attrs \\ %{}) do
    unique = System.unique_integer([:positive])
    starts = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)
    ends = DateTime.add(starts, 7200, :second)

    Enum.into(attrs, %{
      title: "Community Meetup #{unique}",
      description: "Gather around for chat",
      event_type: "community",
      starts_at: starts,
      ends_at: ends,
      created_by_id: user_id,
      is_published: true,
      is_cancelled: false
    })
  end

  describe "events CRUD and listing" do
    test "create, get, list_events, update, delete, and cancel" do
      user = create_user()
      attrs = event_attrs(user.id)

      assert {:ok, %Event{} = event} = Events.create_event(attrs)
      assert event.title == attrs.title

      assert %Event{id: id} = Events.get_event!(event.id)
      assert id == event.id

      events = Events.list_events()
      assert Enum.any?(events, &(&1.id == event.id))

      assert {:ok, updated} = Events.update_event(event.id, %{title: "Renamed Meetup"})
      assert updated.title == "Renamed Meetup"

      assert {:ok, cancelled} = Events.cancel_event(event.id)
      assert cancelled.is_cancelled == true
      refute Enum.any?(Events.list_events(), &(&1.id == event.id))

      assert {:ok, %Event{}} = Events.delete_event(event.id)
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(event.id) end
    end

    test "list_events/1 with month and year options and list_upcoming/1" do
      user = create_user()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      start_of_month = Date.new!(now.year, now.month, 15) |> DateTime.new!(~T[12:00:00])

      {:ok, event} = Events.create_event(event_attrs(user.id, %{starts_at: start_of_month}))

      month_events = Events.list_events(month: now.month, year: now.year)
      assert Enum.any?(month_events, &(&1.id == event.id))

      upcoming = Events.list_upcoming(10)
      assert is_list(upcoming)
    end
  end

  describe "RSVP workflows" do
    test "rsvp/3 inserts, toggles off when repeated, updates on change, and computes rsvp_counts/1" do
      user1 = create_user()
      user2 = create_user()
      {:ok, event} = Events.create_event(event_attrs(user1.id))

      # User 1 RSVPs going
      assert {:ok, %EventRsvp{} = rsvp1} = Events.rsvp(event.id, user1.id, "going")
      assert rsvp1.status == "going"

      # User 2 RSVPs maybe
      assert {:ok, %EventRsvp{}} = Events.rsvp(event.id, user2.id, "maybe")

      counts = Events.rsvp_counts(event.id)
      assert counts["going"] == 1
      assert counts["maybe"] == 1

      # User 2 changes status to going
      assert {:ok, %EventRsvp{status: "going"}} = Events.rsvp(event.id, user2.id, "going")
      assert Events.rsvp_counts(event.id)["going"] == 2

      # User 1 repeats status "going" -> toggles off (deletes)
      assert {:ok, %EventRsvp{}} = Events.rsvp(event.id, user1.id, "going")
      assert Events.rsvp_counts(event.id)["going"] == 1
    end
  end

  describe "suggest_events/0" do
    test "returns recommendations for gaming, creative, support forums, and general" do
      {:ok, cat} = Forums.create_category(%{name: "Main", position: 1})

      {:ok, _gaming} = Forums.create_forum(%{name: "PC Gaming Lounge", category_id: cat.id})

      {:ok, _creative} =
        Forums.create_forum(%{name: "Art and Design Studio", category_id: cat.id})

      {:ok, _help} = Forums.create_forum(%{name: "Help and Support Desk", category_id: cat.id})

      suggestions = Events.suggest_events()
      assert is_list(suggestions)
      assert length(suggestions) >= 4

      types = Enum.map(suggestions, & &1.event_type)
      assert "tournament" in types
      assert "meetup" in types
    end
  end
end
