defmodule ForgeNexusWeb.ThreadRatingController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Forums

  # POST /api/threads/:thread_id/rating
  def rate(conn, %{"thread_id" => thread_id, "rating" => rating}) do
    user = Guardian.Plug.current_resource(conn)

    case Forums.rate_thread(thread_id, user.id, rating) do
      {:ok, _} ->
        stats = Forums.get_thread_rating_stats(thread_id)
        conn |> json(%{rating: stats})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  # GET /api/threads/:thread_id/rating
  def show(conn, %{"thread_id" => thread_id}) do
    user = Guardian.Plug.current_resource(conn)
    stats = Forums.get_thread_rating_stats(thread_id)
    user_rating = Forums.get_user_thread_rating(thread_id, user.id)

    conn |> json(%{
      rating: stats,
      user_rating: if(user_rating, do: user_rating.rating)
    })
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
