defmodule ForgeNexusWeb.AdminChannel do
  @moduledoc """
  Phoenix Channel for the admin War Room dashboard.
  Pushes real-time stats every 5 seconds.
  """

  use ForgeNexusWeb, :channel
  require Logger

  alias ForgeNexus.Admin
  alias ForgeNexus.Moderation

  @tick_interval 5_000

  @impl true
  def join("admin:war_room", _payload, socket) do
    user = socket.assigns.current_user

    if Moderation.is_admin?(user.id) do
      send(self(), :tick)
      Logger.info("[AdminChannel] #{user.username} joined war room")
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info(:tick, socket) do
    stats = Admin.war_room_stats()
    push(socket, "stats_update", stats)
    Process.send_after(self(), :tick, @tick_interval)
    {:noreply, socket}
  end

  # Catch-all so an unknown client event doesn't kill the admin dashboard
  # socket and stop the live stats stream.
  @impl true
  def handle_in(event, payload, socket) do
    Logger.warning("[AdminChannel] unhandled event #{inspect(event)} payload=#{inspect(payload)}")
    {:reply, {:error, %{reason: "unknown event", event: event}}, socket}
  end
end
