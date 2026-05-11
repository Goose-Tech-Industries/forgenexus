defmodule ForgeNexusWeb.StatusController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Accounts

  def update(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    result =
      cond do
        params["status"] ->
          Accounts.update_status(user, params["status"])

        true ->
          {:ok, user}
      end

    case result do
      {:ok, updated_user} ->
        # Also handle custom status if provided
        updated_user =
          cond do
            Map.has_key?(params, "custom_text") ->
              {:ok, u} = Accounts.set_custom_status(updated_user, params["custom_text"], params["custom_emoji"])
              u

            Map.has_key?(params, "clear_custom") ->
              {:ok, u} = Accounts.clear_custom_status(updated_user)
              u

            true ->
              updated_user
          end

        # Broadcast status change to presence channel
        ForgeNexusWeb.Endpoint.broadcast("presence:lobby", "status_changed", %{
          user_id: updated_user.id,
          presence_status: Accounts.get_visible_status(updated_user),
          custom_status_text: updated_user.custom_status_text,
          custom_status_emoji: updated_user.custom_status_emoji
        })

        conn
        |> json(%{
          status: Accounts.get_visible_status(updated_user),
          custom_status_text: updated_user.custom_status_text,
          custom_status_emoji: updated_user.custom_status_emoji
        })

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Invalid status"})
    end
  end
end
