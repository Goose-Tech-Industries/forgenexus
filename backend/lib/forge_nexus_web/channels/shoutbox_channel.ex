defmodule ForgeNexusWeb.ShoutboxChannel do
  use ForgeNexusWeb, :channel

  alias ForgeNexus.Chat

  @impl true
  def join("shoutbox:lobby", _payload, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_in("new_message", %{"body" => body}, socket) do
    user = socket.assigns.current_user

    case Chat.send_shoutbox_message(user.id, body) do
      {:ok, message} ->
        # Preload user with primary group for color info
        message = ForgeNexus.Repo.preload(message, user: :primary_group)

        broadcast!(socket, "new_message", %{
          id: message.id,
          body: message.body,
          inserted_at: message.inserted_at,
          user: user_json(message.user)
        })

        # Ack the sender so client .receive("ok") fires.
        {:reply, {:ok, %{id: message.id}}, socket}

      {:error, %Ecto.Changeset{} = cs} ->
        errors = Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)
        {:reply, {:error, %{errors: errors}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  defp user_json(user) do
    group = user.primary_group

    %{
      id: user.id,
      username: user.username,
      avatar_url: user.avatar_url,
      username_color:
        user.username_color || (group && group.username_color) || (group && group.color),
      username_effect: user.username_effect || (group && group.username_effect) || "none"
    }
  end
end
