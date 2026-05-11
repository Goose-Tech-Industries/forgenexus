defmodule ForgeNexusWeb.Plugs.RequireVerifiedEmail do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        # No user — let other plugs handle auth
        conn

      user ->
        if user.email_verified_at do
          conn
        else
          conn
          |> put_status(:forbidden)
          |> json(%{error: "Please verify your email before posting", code: "email_not_verified"})
          |> halt()
        end
    end
  end
end
