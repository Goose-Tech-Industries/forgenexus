defmodule ForgeNexusWeb.AdminChannelTest do
  use ForgeNexusWeb.ChannelCase

  alias ForgeNexus.Accounts
  alias ForgeNexus.Accounts.{UserGroup, UserGroupMembership}
  alias ForgeNexusWeb.{AdminChannel, UserSocket}

  defp create_user(attrs \\ %{}) do
    unique_suffix = System.unique_integer([:positive])

    defaults = %{
      username: "admin_user_#{unique_suffix}",
      email: "admin_user_#{unique_suffix}@example.com",
      password: "SecurePass!987654#Alpha",
      password_confirmation: "SecurePass!987654#Alpha"
    }

    {:ok, user} =
      attrs
      |> Enum.into(defaults)
      |> Accounts.register_user()

    user
  end

  defp make_admin(user) do
    admin_group =
      case Repo.get_by(UserGroup, name: "Administrators") do
        nil ->
          %UserGroup{}
          |> UserGroup.changeset(%{
            name: "Administrators",
            description: "System Administrators",
            color: "#ff0000"
          })
          |> Repo.insert!()

        group ->
          group
      end

    %UserGroupMembership{}
    |> UserGroupMembership.changeset(%{
      user_id: user.id,
      group_id: admin_group.id
    })
    |> Repo.insert!()

    user
  end

  describe "admin:war_room" do
    test "non-admin user is rejected with unauthorized" do
      user = create_user()
      socket = socket(UserSocket, "user_socket:#{user.id}", %{current_user: user})

      assert {:error, %{reason: "unauthorized"}} =
               subscribe_and_join(socket, AdminChannel, "admin:war_room")
    end

    test "admin user joins, receives initial tick with stats_update, and handles unknown events" do
      admin = create_user() |> make_admin()
      socket = socket(UserSocket, "user_socket:#{admin.id}", %{current_user: admin})

      assert {:ok, _, channel_socket} =
               subscribe_and_join(socket, AdminChannel, "admin:war_room")

      # Initial :tick is sent on join
      assert_push "stats_update", stats
      assert is_map(stats)

      # Test handling unhandled client event
      ref = push(channel_socket, "unsupported_ping", %{"test" => true})
      assert_reply ref, :error, %{reason: "unknown event", event: "unsupported_ping"}
    end
  end
end
