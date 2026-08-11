defmodule ForgeNexusWeb.PollController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Forums.Polls

  def show(conn, %{"thread_id" => thread_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Polls.get_poll_for_thread(thread_id) do
      nil -> conn |> json(%{poll: nil})
      poll -> conn |> json(%{poll: Polls.get_results(poll.id, user && user.id)})
    end
  end

  def create(conn, %{"thread_id" => thread_id} = params) do
    user = Guardian.Plug.current_resource(conn)
    options = params["options"] || []

    if length(options) < 2 do
      conn |> put_status(:unprocessable_entity) |> json(%{error: "At least 2 options required"})
    else
      attrs = %{
        question: params["question"],
        thread_id: thread_id,
        created_by_id: user.id,
        is_multiple_choice: params["is_multiple_choice"] || false,
        max_choices: params["max_choices"] || 1,
        is_anonymous: params["is_anonymous"] || false,
        hide_results_until_voted: params["hide_results_until_voted"] || false,
        closes_at: params["closes_at"]
      }

      case Polls.create_poll(attrs, options) do
        {:ok, poll} ->
          conn |> put_status(:created) |> json(%{poll: Polls.get_results(poll.id, user.id)})

        {:error, _} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to create poll"})
      end
    end
  end

  def vote(conn, %{"poll_id" => poll_id} = params) do
    user = Guardian.Plug.current_resource(conn)
    option_ids = params["option_ids"] || []

    case Polls.vote(poll_id, user.id, option_ids) do
      {:ok, _} ->
        conn |> json(%{poll: Polls.get_results(poll_id, user.id)})

      {:error, :already_voted} ->
        conn |> put_status(:conflict) |> json(%{error: "Already voted"})

      {:error, :poll_closed} ->
        conn |> put_status(:forbidden) |> json(%{error: "Poll is closed"})

      {:error, :single_choice_only} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Only one choice allowed"})

      {:error, :too_many_choices} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Too many choices selected"})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to vote"})
    end
  end

  def close(conn, %{"poll_id" => poll_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Polls.close_poll(poll_id) do
      {:ok, _} ->
        conn |> json(%{poll: Polls.get_results(poll_id, user.id)})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to close poll"})
    end
  end
end
