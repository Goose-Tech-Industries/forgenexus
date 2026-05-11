defmodule ForgeNexusWeb.Plugs.EnsureStaff do
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
        if Moderation.is_staff?(user) do
          conn
        else
          conn
          |> put_status(:forbidden)
          |> json(%{error: "Staff access required"})
          |> halt()
        end
    end
  end
end
