defmodule ForgeNexusWeb.EventController do
  use ForgeNexusWeb, :controller
  alias ForgeNexus.Events

  def index(conn, params) do
    month = if params["month"], do: safe_to_integer(params["month"], nil)
    year = if params["year"], do: safe_to_integer(params["year"], nil)
    events = Events.list_events(month: month, year: year)
    conn |> json(%{events: Enum.map(events, &event_json/1)})
  end

  def upcoming(conn, _params) do
    events = Events.list_upcoming(10)
    conn |> json(%{events: Enum.map(events, &event_json/1)})
  end

  def show(conn, %{"id" => id}) do
    event = Events.get_event!(id)
    counts = Events.rsvp_counts(id)
    conn |> json(%{event: event_json(event), rsvp_counts: counts, attendees: Enum.map(event.rsvps, fn r ->
      %{user_id: r.user_id, username: r.user.username, avatar_url: r.user.avatar_url, status: r.status}
    end)})
  end

  def create(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    attrs = Map.put(params, "created_by_id", user.id)
    case Events.create_event(attrs) do
      {:ok, event} -> conn |> put_status(:created) |> json(%{event: event_json(event)})
      {:error, cs} -> conn |> put_status(:unprocessable_entity) |> json(%{error: format_errors(cs)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)
    event = Events.get_event!(id)

    if event.created_by_id == user.id or ForgeNexus.Moderation.is_staff?(user) do
      case Events.update_event(id, params) do
        {:ok, event} -> conn |> json(%{event: event_json(event)})
        {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
      end
    else
      conn |> put_status(:forbidden) |> json(%{error: "You can only edit your own events"})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)
    event = Events.get_event!(id)

    if event.created_by_id == user.id or ForgeNexus.Moderation.is_staff?(user) do
      case Events.delete_event(id) do
        {:ok, _} -> conn |> json(%{ok: true})
        _ -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
      end
    else
      conn |> put_status(:forbidden) |> json(%{error: "You can only delete your own events"})
    end
  end

  def rsvp(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)
    status = params["status"] || "going"
    Events.rsvp(id, user.id, status)
    counts = Events.rsvp_counts(id)
    conn |> json(%{ok: true, rsvp_counts: counts})
  end

  def suggestions(conn, _params) do
    suggestions = Events.suggest_events()
    conn |> json(%{suggestions: suggestions})
  end

  defp event_json(e) do
    %{id: e.id, title: e.title, description: e.description, location: e.location,
      event_type: e.event_type, starts_at: e.starts_at, ends_at: e.ends_at,
      is_all_day: e.is_all_day, is_recurring: e.is_recurring, recurrence_rule: e.recurrence_rule,
      color: e.color, max_attendees: e.max_attendees, is_published: e.is_published,
      is_cancelled: e.is_cancelled,
      created_by: e.created_by && %{id: e.created_by.id, username: e.created_by.username},
      inserted_at: e.inserted_at}
  end

  defp format_errors(cs), do: Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)

  defp safe_to_integer(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> default
    end
  end
  defp safe_to_integer(val, _default) when is_integer(val), do: val
  defp safe_to_integer(_, default), do: default

end
