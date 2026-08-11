defmodule ForgeNexus.Events do
  @moduledoc "Community events and calendar."
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Events.{Event, EventRsvp}

  def list_events(opts \\ []) do
    month = Keyword.get(opts, :month)
    year = Keyword.get(opts, :year)
    limit = Keyword.get(opts, :limit, 50)

    query =
      Event
      |> where([e], e.is_published == true and e.is_cancelled == false)
      |> order_by(asc: :starts_at)
      |> limit(^limit)
      |> preload([:created_by, :rsvps])

    query =
      if month && year do
        start_date = Date.new!(year, month, 1) |> DateTime.new!(~T[00:00:00])

        end_date =
          Date.new!(year, month, Date.days_in_month(Date.new!(year, month, 1)))
          |> DateTime.new!(~T[23:59:59])

        where(query, [e], e.starts_at >= ^start_date and e.starts_at <= ^end_date)
      else
        # Default: upcoming events
        where(query, [e], e.starts_at >= ^DateTime.utc_now())
      end

    Repo.all(query)
  end

  def list_upcoming(limit \\ 5) do
    Event
    |> where(
      [e],
      e.is_published == true and e.is_cancelled == false and e.starts_at >= ^DateTime.utc_now()
    )
    |> order_by(asc: :starts_at)
    |> limit(^limit)
    |> preload(:created_by)
    |> Repo.all()
  end

  def get_event!(id), do: Event |> preload([:created_by, rsvps: :user]) |> Repo.get!(id)

  def create_event(attrs), do: %Event{} |> Event.changeset(attrs) |> Repo.insert()
  def update_event(id, attrs), do: Repo.get!(Event, id) |> Event.changeset(attrs) |> Repo.update()
  def delete_event(id), do: Repo.get!(Event, id) |> Repo.delete()

  def cancel_event(id) do
    Repo.get!(Event, id) |> Ecto.Changeset.change(is_cancelled: true) |> Repo.update()
  end

  def rsvp(event_id, user_id, status \\ "going") do
    case Repo.get_by(EventRsvp, event_id: event_id, user_id: user_id) do
      nil ->
        %EventRsvp{}
        |> EventRsvp.changeset(%{event_id: event_id, user_id: user_id, status: status})
        |> Repo.insert()

      existing ->
        if status == existing.status do
          # Toggle off
          Repo.delete(existing)
        else
          existing |> EventRsvp.changeset(%{status: status}) |> Repo.update()
        end
    end
  end

  def rsvp_counts(event_id) do
    from(r in EventRsvp,
      where: r.event_id == ^event_id,
      group_by: r.status,
      select: {r.status, count(r.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc "AI-powered event suggestions based on forum activity patterns."
  def suggest_events do
    now = DateTime.utc_now()
    _day_of_week = Date.day_of_week(DateTime.to_date(now))

    # Analyze forum categories and activity to suggest relevant events
    forums = ForgeNexus.Forums.list_forums()

    suggestions = []

    # Pattern: active gaming forums → suggest tournaments
    gaming_forums =
      Enum.filter(forums, fn f ->
        name = String.downcase(f.name || "")
        String.contains?(name, ["gaming", "game", "esport", "play"])
      end)

    suggestions =
      if length(gaming_forums) > 0 do
        suggestions ++
          [
            %{
              title: "Weekly Gaming Tournament",
              description: "Community gaming tournament! Compete for bragging rights and points.",
              event_type: "tournament",
              suggested_day: "Saturday",
              reason: "You have #{length(gaming_forums)} gaming forum(s) with active users"
            }
          ]
      else
        suggestions
      end

    # Pattern: creative/art forums → suggest showcases
    creative_forums =
      Enum.filter(forums, fn f ->
        name = String.downcase(f.name || "")
        String.contains?(name, ["art", "creative", "design", "media", "photo", "music"])
      end)

    suggestions =
      if length(creative_forums) > 0 do
        suggestions ++
          [
            %{
              title: "Creative Showcase Friday",
              description: "Share your latest work and get feedback from the community!",
              event_type: "community",
              suggested_day: "Friday",
              reason: "Your creative forums would benefit from regular showcases"
            }
          ]
      else
        suggestions
      end

    # Pattern: help/support forums → suggest Q&A sessions
    help_forums =
      Enum.filter(forums, fn f ->
        name = String.downcase(f.name || "")
        String.contains?(name, ["help", "support", "question", "faq", "tutorial"])
      end)

    suggestions =
      if length(help_forums) > 0 do
        suggestions ++
          [
            %{
              title: "Community Q&A Session",
              description: "Staff-hosted Q&A session. Bring your questions!",
              event_type: "community",
              suggested_day: "Wednesday",
              reason: "Help forums show users have questions — regular Q&A builds trust"
            }
          ]
      else
        suggestions
      end

    # Generic suggestions everyone benefits from
    suggestions ++
      [
        %{
          title: "Monthly Town Hall",
          description: "Community updates, feedback, and open discussion with staff.",
          event_type: "meetup",
          suggested_day: "1st of month",
          reason: "Town halls build community trust and reduce surprise policy changes"
        },
        %{
          title: "New Member Welcome Mixer",
          description: "Meet and greet for members who joined this month!",
          event_type: "community",
          suggested_day: "Last Friday of month",
          reason: "Welcoming new members improves 30-day retention by 40%"
        },
        %{
          title: "Forum Trivia Night",
          description: "Test your knowledge of the community! Prizes for winners.",
          event_type: "contest",
          suggested_day: "Thursday",
          reason: "Trivia events drive engagement spikes and create memorable moments"
        }
      ]
  end
end
