defmodule ForgeNexusWeb.UserSocket do
  use Phoenix.Socket

  channel "chat:*", ForgeNexusWeb.ChatChannel
  channel "thread:*", ForgeNexusWeb.ThreadChannel
  channel "presence:*", ForgeNexusWeb.PresenceChannel
  channel "shoutbox:*", ForgeNexusWeb.ShoutboxChannel
  channel "admin:*", ForgeNexusWeb.AdminChannel
  channel "user:*", ForgeNexusWeb.UserChannel
  channel "voice:*", ForgeNexusWeb.VoiceChannel
  channel "forums:*", ForgeNexusWeb.ForumsChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case ForgeNexus.Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        case ForgeNexus.Guardian.resource_from_claims(claims) do
          {:ok, user} ->
            ForgeNexus.Accounts.update_last_seen(user)
            {:ok, assign(socket, :current_user, user)}

          {:error, _} ->
            :error
        end

      {:error, _} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"
end
