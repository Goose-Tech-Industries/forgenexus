defmodule ForgeNexusWeb.ForumsAndPresenceChannelsTest do
  use ForgeNexusWeb.ChannelCase

  alias ForgeNexus.Accounts

  alias ForgeNexusWeb.{
    ForumsChannel,
    PresenceChannel,
    ThreadChannel,
    UserChannel,
    UserSocket
  }

  defp create_user(attrs \\ %{}) do
    unique_suffix = System.unique_integer([:positive])

    defaults = %{
      username: "chan_user_#{unique_suffix}",
      email: "chan_user_#{unique_suffix}@example.com",
      password: "SecurePass!987654#Alpha",
      password_confirmation: "SecurePass!987654#Alpha"
    }

    {:ok, user} =
      attrs
      |> Enum.into(defaults)
      |> Accounts.register_user()

    user
  end

  describe "ForumsChannel" do
    setup do
      user = create_user()
      socket = socket(UserSocket, "user_socket:#{user.id}", %{current_user: user})
      %{socket: socket, user: user}
    end

    test "successfully joins forums:index", %{socket: socket} do
      assert {:ok, _, %Phoenix.Socket{}} =
               subscribe_and_join(socket, ForumsChannel, "forums:index")
    end

    test "rejects invalid forum topic", %{socket: socket} do
      assert {:error, %{reason: "unknown topic"}} =
               subscribe_and_join(socket, ForumsChannel, "forums:invalid_sub")
    end
  end

  describe "PresenceChannel" do
    test "joins lobby, tracks presence with user styling, and pushes presence_state" do
      user = create_user(%{username_color: "#ff0000", username_effect: "glow"})
      socket = socket(UserSocket, "user_socket:#{user.id}", %{current_user: user})

      {:ok, _, _socket} = subscribe_and_join(socket, PresenceChannel, "presence:lobby")

      # PresenceChannel sends :after_join to self, which pushes presence_state
      assert_push "presence_state", %{}
    end
  end

  describe "ThreadChannel" do
    test "authenticated user joins thread channel and handles unknown events gracefully" do
      user = create_user()
      socket = socket(UserSocket, "user_socket:#{user.id}", %{current_user: user})

      {:ok, _, channel_socket} =
        subscribe_and_join(socket, ThreadChannel, "thread:sample-thread-slug")

      assert channel_socket.assigns.thread_id == "sample-thread-slug"

      ref = push(channel_socket, "random_event", %{"foo" => "bar"})
      assert_reply ref, :error, %{reason: "unknown event", event: "random_event"}
    end

    test "anonymous user joins thread channel successfully" do
      socket = socket(UserSocket, "anon_socket", %{})

      assert {:ok, _, channel_socket} =
               subscribe_and_join(socket, ThreadChannel, "thread:public-thread-123")

      assert channel_socket.assigns.thread_id == "public-thread-123"
    end
  end

  describe "UserChannel" do
    setup do
      user = create_user()
      socket = socket(UserSocket, "user_socket:#{user.id}", %{current_user: user})
      %{socket: socket, user: user}
    end

    test "joins own user channel successfully", %{socket: socket, user: user} do
      assert {:ok, _, %Phoenix.Socket{}} =
               subscribe_and_join(socket, UserChannel, "user:#{user.id}")
    end

    test "rejects joining another user's channel", %{socket: socket} do
      other_user = create_user()

      assert {:error, %{reason: "unauthorized"}} =
               subscribe_and_join(socket, UserChannel, "user:#{other_user.id}")
    end
  end
end
