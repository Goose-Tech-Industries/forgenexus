defmodule ForgeNexusWeb.UserChannel do
  use ForgeNexusWeb, :channel

  @impl true
  def join("user:" <> user_id, _params, socket) do
    current_user = socket.assigns.current_user

    if current_user.id == user_id do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end
end
