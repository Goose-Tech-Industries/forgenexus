defmodule ForgeNexus.AccountsTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Accounts
  alias ForgeNexus.Accounts.User

  @valid_attrs %{
    username: "test_pilot",
    email: "test.pilot@example.com",
    password: "Fn9#xK8$mQ2!wZ7^vL4*",
    display_name: "Test Pilot"
  }

  describe "register_user/1" do
    test "creates user with valid attributes and hashes password" do
      assert {:ok, %User{} = user} = Accounts.register_user(@valid_attrs)
      assert user.username == "test_pilot"
      assert user.email == "test.pilot@example.com"
      assert user.slug == "test-pilot"
      assert is_binary(user.password_hash)
      assert String.starts_with?(user.password_hash, "$2b$")
    end

    test "rejects registration with short username" do
      attrs = %{@valid_attrs | username: "ab"}
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert "should be at least 3 character(s)" in errors_on(changeset).username
    end

    test "rejects registration with invalid username characters" do
      attrs = %{@valid_attrs | username: "invalid name!"}
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert "only letters, numbers, underscores, and hyphens" in errors_on(changeset).username
    end

    test "rejects invalid email address format" do
      attrs = %{@valid_attrs | email: "not-an-email"}
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert "must be a valid email" in errors_on(changeset).email
    end

    test "rejects short password under 8 characters" do
      attrs = %{@valid_attrs | password: "short"}
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end

    test "enforces unique username and email constraints" do
      assert {:ok, _} = Accounts.register_user(@valid_attrs)

      duplicate_username = %{@valid_attrs | email: "other@example.com"}
      assert {:error, cs1} = Accounts.register_user(duplicate_username)
      assert "has already been taken" in errors_on(cs1).username

      duplicate_email = %{@valid_attrs | username: "different_user"}
      assert {:error, cs2} = Accounts.register_user(duplicate_email)
      assert "has already been taken" in errors_on(cs2).email
    end
  end

  describe "authenticate_user/2" do
    test "authenticates with valid credentials" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      assert {:ok, auth_user} = Accounts.authenticate_user(user.email, @valid_attrs.password)
      assert auth_user.id == user.id
    end

    test "rejects authentication with invalid password" do
      {:ok, user} = Accounts.register_user(@valid_attrs)

      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user(user.email, "wrongpass12345")
    end

    test "rejects authentication for non-existent user" do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user("ghost@example.com", "anypassword")
    end
  end

  describe "get_user_by_* functions" do
    test "retrieves user by id, email, username, and slug" do
      {:ok, user} = Accounts.register_user(@valid_attrs)

      assert Accounts.get_user!(user.id).id == user.id
      assert Accounts.get_user(user.id).id == user.id
      assert Accounts.get_user_by_email(user.email).id == user.id
      assert Accounts.get_user_by_username(user.username).id == user.id
      assert Accounts.get_user_by_slug(user.slug).id == user.id
    end
  end

  describe "update_user_fields/2" do
    test "updates arbitrary user fields such as bio and theme" do
      {:ok, user} = Accounts.register_user(@valid_attrs)

      assert {:ok, updated} =
               Accounts.update_user_fields(user.id, %{bio: "Hello world", theme: "cyber"})

      assert updated.bio == "Hello world"
      assert updated.theme == "cyber"
    end
  end
end
