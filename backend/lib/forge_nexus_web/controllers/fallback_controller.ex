defmodule ForgeNexusWeb.FallbackController do
  use ForgeNexusWeb, :controller

  def not_found(conn, _params) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "Not found"})
  end
end
