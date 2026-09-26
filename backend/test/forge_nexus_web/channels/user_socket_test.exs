defmodule ForgeNexusWeb.UserSocketTest do
  use ForgeNexusWeb.ChannelCase, async: true

  alias ForgeNexus.Accounts
  alias ForgeNexus.Guardian
  alias ForgeNexusWeb.UserSocket

  defp create_user(attrs \\ %{}) do
    unique_suffix = System.unique_integer([:positive])

    defaults = %{
      username: "socket_user_#{unique_suffix}",
      email: "socket_user_#{unique_suffix}@example.com",
      password: "SecurePass!987654#Alpha",
      password_confirmation: "SecurePass!987654#Alpha"
    }

    {:ok, user} =
      attrs
      |> Enum.into(defaults)
      |> Accounts.register_user()

    user
  end

  describe "connect/3" do
    test "authenticates with valid guardian token and updates last_seen" do
      user = create_user()
      {:ok, token, _claims} = Guardian.encode_and_sign(user)

      assert {:ok, socket} = connect(UserSocket, %{"token" => token})
      assert socket.assigns.current_user.id == user.id

      # Verify socket id contains user id
      assert UserSocket.id(socket) == "user_socket:#{user.id}"
    end

    test "rejects invalid token" do
      assert :error = connect(UserSocket, %{"token" => "completely_invalid_jwt_token"})
    end

    test "rejects missing token param" do
      assert :error = connect(UserSocket, %{})
      assert :error = connect(UserSocket, %{"other" => "param"})
    end

    test "rejects valid token whose user no longer exists in database" do
      user = create_user()
      {:ok, token, _claims} = Guardian.encode_and_sign(user)

      # Delete user
      Repo.delete(user)

      assert :error = connect(UserSocket, %{"token" => token})
    end
  end
end
