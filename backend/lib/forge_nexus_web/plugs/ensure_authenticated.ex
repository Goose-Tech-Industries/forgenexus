defmodule ForgeNexusWeb.Plugs.EnsureAuthenticated do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
        |> halt()

      user ->
        # Update ETS presence on every authenticated request
        ForgeNexus.PresenceTracker.track(user.id, %{
          username: user.username,
          avatar_url: user.avatar_url,
          current_page: conn.request_path
        })

        conn
    end
  end
end
