defmodule ForgeNexusWeb.PresenceChannel do
  use ForgeNexusWeb, :channel

  alias ForgeNexusWeb.Presence

  @impl true
  def join("presence:lobby", _payload, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    user = socket.assigns.current_user |> ForgeNexus.Repo.preload(:primary_group)
    group = user.primary_group

    color =
      user.username_color ||
        (group && group.username_color) ||
        (group && group.color)

    effect = user.username_effect || (group && group.username_effect) || "none"

    {:ok, _} =
      Presence.track(socket, user.id, %{
        username: user.username,
        slug: user.slug,
        avatar_url: user.avatar_url,
        username_color: color,
        username_effect: effect,
        online_at: System.system_time(:second)
      })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end
end
