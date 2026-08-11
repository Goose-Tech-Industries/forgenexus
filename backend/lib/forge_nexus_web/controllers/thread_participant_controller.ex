defmodule ForgeNexusWeb.ThreadParticipantController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Forums

  def index(conn, %{"slug" => slug}) do
    thread = Forums.get_thread_by_slug!(slug)
    user = Guardian.Plug.current_resource(conn)

    unless Forums.can_view_thread?(thread, user) do
      conn |> put_status(:forbidden) |> json(%{error: "Access denied"})
    else
      participants = Forums.list_thread_participants(thread.id)
      conn |> json(%{participants: participants})
    end
  end

  def add(conn, %{"slug" => slug} = params) do
    thread = Forums.get_thread_by_slug!(slug)
    user = Guardian.Plug.current_resource(conn)

    cond do
      not thread.is_private ->
        conn |> put_status(:bad_request) |> json(%{error: "Thread is not private"})

      thread.user_id != user.id and not user.is_staff ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Only the thread creator or staff can add participants"})

      true ->
        user_id = params["user_id"]

        case Forums.add_thread_participant(thread.id, user_id) do
          {:ok, _} ->
            participants = Forums.list_thread_participants(thread.id)
            conn |> json(%{ok: true, participants: participants})

          {:error, _} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to add participant"})
        end
    end
  end

  def remove(conn, %{"slug" => slug, "user_id" => target_user_id}) do
    thread = Forums.get_thread_by_slug!(slug)
    user = Guardian.Plug.current_resource(conn)

    cond do
      not thread.is_private ->
        conn |> put_status(:bad_request) |> json(%{error: "Thread is not private"})

      thread.user_id != user.id and not user.is_staff ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Only the thread creator or staff can remove participants"})

      target_user_id == thread.user_id ->
        conn |> put_status(:bad_request) |> json(%{error: "Cannot remove the thread creator"})

      true ->
        case Forums.remove_thread_participant(thread.id, target_user_id) do
          {:ok, _} ->
            participants = Forums.list_thread_participants(thread.id)
            conn |> json(%{ok: true, participants: participants})

          {:error, :not_found} ->
            conn |> put_status(:not_found) |> json(%{error: "Participant not found"})
        end
    end
  end
end
