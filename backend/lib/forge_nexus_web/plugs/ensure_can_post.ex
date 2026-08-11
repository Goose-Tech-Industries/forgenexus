defmodule ForgeNexusWeb.Plugs.EnsureCanPost do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:user_restriction] do
      :read_only ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Your account is in read-only mode. You cannot post at this time."})
        |> halt()

      :cooldown ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error: "Your account is on a posting cooldown. Please wait before posting again."
        })
        |> halt()

      _ ->
        conn
    end
  end
end
