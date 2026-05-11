defmodule ForgeNexusWeb.ThreadChannel do
  use ForgeNexusWeb, :channel
  require Logger

  @impl true
  def join("thread:" <> thread_id, _payload, socket) do
    user_id =
      case socket.assigns[:current_user] do
        %{id: id} -> id
        _ -> "anon"
      end

    Logger.info("[ThreadChannel] join thread:#{thread_id} by #{user_id}")
    {:ok, assign(socket, :thread_id, thread_id)}
  end

  # Catch-all so a malformed event from a buggy/older client doesn't kill the
  # thread subscription and silently break live post updates.
  @impl true
  def handle_in(event, payload, socket) do
    Logger.warning("[ThreadChannel] unhandled event #{inspect(event)} payload=#{inspect(payload)}")
    {:reply, {:error, %{reason: "unknown event", event: event}}, socket}
  end
end
