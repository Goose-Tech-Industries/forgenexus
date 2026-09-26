defmodule ForgeNexusWeb.ShoutboxChannelTest do
  use ForgeNexusWeb.ChannelCase

  alias ForgeNexus.Accounts
  alias ForgeNexusWeb.{ShoutboxChannel, UserSocket}

  defp create_user(attrs) do
    unique_suffix = System.unique_integer([:positive])

    defaults = %{
      username: "shout_user_#{unique_suffix}",
      email: "shout_user_#{unique_suffix}@example.com",
      password: "SecurePass!987654#Alpha",
      password_confirmation: "SecurePass!987654#Alpha"
    }

    {:ok, user} =
      defaults
      |> Accounts.register_user()

    user
    |> Ecto.Changeset.change(attrs)
    |> Repo.update!()
  end

  setup do
    user = create_user(%{username_color: "#00ff00", username_effect: "bold"})
    socket = socket(UserSocket, "user_socket:#{user.id}", %{current_user: user})
    {:ok, _, channel_socket} = subscribe_and_join(socket, ShoutboxChannel, "shoutbox:lobby")
    %{socket: channel_socket, user: user}
  end

  test "sends new message and broadcasts to lobby", %{socket: socket, user: user} do
    ref = push(socket, "new_message", %{"body" => "Hello shoutbox!"})
    assert_reply ref, :ok, %{id: message_id}
    assert is_binary(message_id)

    assert_broadcast "new_message", %{
      id: ^message_id,
      body: "Hello shoutbox!",
      user: %{
        id: uid,
        username: uname,
        username_color: "#00ff00",
        username_effect: "bold"
      }
    }

    assert uid == user.id
    assert uname == user.username
  end

  test "handles invalid/empty message gracefully", %{socket: socket} do
    ref = push(socket, "new_message", %{"body" => ""})
    assert_reply ref, :error, %{errors: errors}
    assert errors[:body] || errors["body"]
  end
end
