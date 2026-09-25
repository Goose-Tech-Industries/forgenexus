defmodule ForgeNexus.Accounts.UserGroupTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Accounts.{UserGroup, UserGroupMembership, User}

  describe "UserGroup.changeset/2" do
    test "valid attributes generate slug from name" do
      changeset = UserGroup.changeset(%UserGroup{}, %{name: "Super Moderators"})
      assert changeset.valid?
      assert get_change(changeset, :slug) == "super-moderators"
    end

    test "respects explicit slug" do
      changeset =
        UserGroup.changeset(%UserGroup{}, %{name: "Super Moderators", slug: "custom-mods"})

      assert changeset.valid?
      assert get_change(changeset, :slug) == "custom-mods"
    end

    test "requires name" do
      changeset = UserGroup.changeset(%UserGroup{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "supports all group metadata fields" do
      attrs = %{
        name: "VIP Members",
        description: "Special supporters",
        color: "#ffd700",
        icon: "star",
        is_default: false,
        is_staff: false,
        position: 10,
        permissions: %{"can_view_vip" => true}
      }

      changeset = UserGroup.changeset(%UserGroup{}, attrs)
      assert changeset.valid?
      assert get_change(changeset, :color) == "#ffd700"
      assert get_change(changeset, :position) == 10
      assert get_change(changeset, :permissions) == %{"can_view_vip" => true}
    end
  end

  describe "UserGroup.admin_changeset/2" do
    test "accepts admin fields including username styling" do
      attrs = %{
        name: "Administrators",
        username_color: "#ff0000",
        username_effect: "glow",
        is_staff: true,
        is_default: false,
        position: 100
      }

      changeset = UserGroup.admin_changeset(%UserGroup{}, attrs)
      assert changeset.valid?
      assert get_change(changeset, :username_color) == "#ff0000"
      assert get_change(changeset, :username_effect) == "glow"
      assert get_change(changeset, :is_staff) == true
      assert get_change(changeset, :slug) == "administrators"
    end

    test "requires name in admin_changeset" do
      changeset = UserGroup.admin_changeset(%UserGroup{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end
  end

  describe "UserGroupMembership.changeset/2" do
    test "valid attributes produce valid changeset" do
      user_id = Ecto.UUID.generate()
      group_id = Ecto.UUID.generate()

      changeset =
        UserGroupMembership.changeset(%UserGroupMembership{}, %{
          user_id: user_id,
          group_id: group_id
        })

      assert changeset.valid?
      assert get_change(changeset, :user_id) == user_id
      assert get_change(changeset, :group_id) == group_id
    end

    test "requires user_id and group_id" do
      changeset = UserGroupMembership.changeset(%UserGroupMembership{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
      assert "can't be blank" in errors_on(changeset).group_id
    end
  end

  describe "database constraints" do
    test "enforces slug uniqueness on user_groups" do
      attrs = %{name: "Unique Group", slug: "unique-group"}
      assert {:ok, _} = %UserGroup{} |> UserGroup.changeset(attrs) |> Repo.insert()

      assert {:error, changeset} = %UserGroup{} |> UserGroup.changeset(attrs) |> Repo.insert()
      assert "has already been taken" in errors_on(changeset).slug
    end

    test "enforces composite uniqueness on membership (user_id, group_id)" do
      n = System.unique_integer([:positive])

      user =
        %User{
          username: "group_user_#{n}",
          slug: "group-user-#{n}",
          email: "group_#{n}@example.com",
          password_hash: "$2b$12$dummyhash"
        }
        |> Repo.insert!()

      {:ok, group} =
        %UserGroup{}
        |> UserGroup.changeset(%{name: "Test Group #{n}", slug: "test-group-#{n}"})
        |> Repo.insert()

      assert {:ok, _} =
               %UserGroupMembership{}
               |> UserGroupMembership.changeset(%{user_id: user.id, group_id: group.id})
               |> Repo.insert()

      assert {:error, changeset} =
               %UserGroupMembership{}
               |> UserGroupMembership.changeset(%{user_id: user.id, group_id: group.id})
               |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).user_id
    end
  end
end
