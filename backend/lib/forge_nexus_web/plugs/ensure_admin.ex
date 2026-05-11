defmodule ForgeNexusWeb.Plugs.EnsureAdmin do
  import Plug.Conn
  import Phoenix.Controller

  alias ForgeNexus.Moderation

  def init(opts), do: opts

  def call(conn, _opts) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
        |> halt()

      user ->
        if Moderation.is_admin?(user.id) do
          conn
        else
          conn
          |> put_status(:forbidden)
          |> json(%{error: "Administrator access required"})
          |> halt()
        end
    end
  end
end
