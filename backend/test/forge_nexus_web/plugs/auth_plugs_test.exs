defmodule ForgeNexusWeb.Plugs.AuthPlugsTest do
  use ForgeNexusWeb.ConnCase, async: true

  alias ForgeNexus.Accounts
  alias ForgeNexus.Accounts.{UserGroup, UserGroupMembership}
  alias ForgeNexus.Moderation.{Ban, Warning}

  alias ForgeNexusWeb.Plugs.{
    CheckBan,
    EnsureAdmin,
    EnsureAuthenticated,
    EnsureCanPost,
    EnsureStaff,
    RequireVerifiedEmail
  }

  defp create_user(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      username: "user_#{unique}",
      email: "user_#{unique}@example.com",
      password: "Fn9#xK8$mQ2!wZ7^vL4*",
      display_name: "User #{unique}"
    }

    {:ok, user} = Accounts.register_user(Map.merge(default_attrs, attrs))
    user
  end

  # =========================================================================
  # EnsureAuthenticated
  # =========================================================================
  describe "EnsureAuthenticated plug" do
    test "init/1 returns given options unchanged" do
      opts = [foo: :bar]
      assert EnsureAuthenticated.init(opts) == opts
    end

    test "halts with 401 unauthorized when no user is authenticated", %{conn: conn} do
      conn = EnsureAuthenticated.call(conn, [])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body) == %{"error" => "Authentication required"}
    end

    test "allows request through and updates presence when user is authenticated", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> Guardian.Plug.put_current_resource(user)
        |> EnsureAuthenticated.call([])

      refute conn.halted
      assert conn.status == nil
    end
  end

  # =========================================================================
  # EnsureAdmin
  # =========================================================================
  describe "EnsureAdmin plug" do
    test "init/1 returns given options unchanged" do
      opts = [scope: :admin]
      assert EnsureAdmin.init(opts) == opts
    end

    test "halts with 401 unauthorized when unauthenticated", %{conn: conn} do
      conn = EnsureAdmin.call(conn, [])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body) == %{"error" => "Authentication required"}
    end

    test "halts with 403 forbidden when user is not an administrator", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> Guardian.Plug.put_current_resource(user)
        |> EnsureAdmin.call([])

      assert conn.halted
      assert conn.status == 403
      assert Jason.decode!(conn.resp_body) == %{"error" => "Administrator access required"}
    end

    test "allows request through when user belongs to Administrators group", %{conn: conn} do
      user = create_user()

      {:ok, group} =
        %UserGroup{}
        |> UserGroup.changeset(%{name: "Administrators", is_staff: true})
        |> ForgeNexus.Repo.insert()

      {:ok, _membership} =
        %UserGroupMembership{}
        |> UserGroupMembership.changeset(%{user_id: user.id, group_id: group.id})
        |> ForgeNexus.Repo.insert()

      conn =
        conn
        |> Guardian.Plug.put_current_resource(user)
        |> EnsureAdmin.call([])

      refute conn.halted
      assert conn.status == nil
    end
  end

  # =========================================================================
  # EnsureStaff
  # =========================================================================
  describe "EnsureStaff plug" do
    test "init/1 returns given options unchanged" do
      assert EnsureStaff.init([]) == []
    end

    test "halts with 401 unauthorized when unauthenticated", %{conn: conn} do
      conn = EnsureStaff.call(conn, [])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body) == %{"error" => "Authentication required"}
    end

    test "halts with 403 forbidden when user is not staff", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> Guardian.Plug.put_current_resource(user)
        |> EnsureStaff.call([])

      assert conn.halted
      assert conn.status == 403
      assert Jason.decode!(conn.resp_body) == %{"error" => "Staff access required"}
    end

    test "allows request through when user belongs to staff group", %{conn: conn} do
      user = create_user()

      {:ok, group} =
        %UserGroup{}
        |> UserGroup.changeset(%{name: "Moderators", is_staff: true})
        |> ForgeNexus.Repo.insert()

      {:ok, _membership} =
        %UserGroupMembership{}
        |> UserGroupMembership.changeset(%{user_id: user.id, group_id: group.id})
        |> ForgeNexus.Repo.insert()

      conn =
        conn
        |> Guardian.Plug.put_current_resource(user)
        |> EnsureStaff.call([])

      refute conn.halted
      assert conn.status == nil
    end
  end

  # =========================================================================
  # EnsureCanPost
  # =========================================================================
  describe "EnsureCanPost plug" do
    test "init/1 returns given options unchanged" do
      assert EnsureCanPost.init([]) == []
    end

    test "allows request when user has no restrictions", %{conn: conn} do
      conn =
        conn
        |> assign(:user_restriction, :none)
        |> EnsureCanPost.call([])

      refute conn.halted
      assert conn.status == nil
    end

    test "allows request when user_restriction is nil", %{conn: conn} do
      conn = EnsureCanPost.call(conn, [])
      refute conn.halted
      assert conn.status == nil
    end

    test "halts with 403 forbidden when user is in read-only mode", %{conn: conn} do
      conn =
        conn
        |> assign(:user_restriction, :read_only)
        |> EnsureCanPost.call([])

      assert conn.halted
      assert conn.status == 403

      assert Jason.decode!(conn.resp_body) == %{
               "error" => "Your account is in read-only mode. You cannot post at this time."
             }
    end

    test "halts with 403 forbidden when user is on cooldown", %{conn: conn} do
      conn =
        conn
        |> assign(:user_restriction, :cooldown)
        |> EnsureCanPost.call([])

      assert conn.halted
      assert conn.status == 403

      assert Jason.decode!(conn.resp_body) == %{
               "error" =>
                 "Your account is on a posting cooldown. Please wait before posting again."
             }
    end
  end

  # =========================================================================
  # CheckBan
  # =========================================================================
  describe "CheckBan plug" do
    test "init/1 returns given options unchanged" do
      assert CheckBan.init(foo: 1) == [foo: 1]
    end

    test "assigns :user_restriction to :none when unauthenticated", %{conn: conn} do
      conn = CheckBan.call(conn, [])
      refute conn.halted
      assert conn.assigns[:user_restriction] == :none
    end

    test "assigns :user_restriction to :none for clean user", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> Guardian.Plug.put_current_resource(user)
        |> CheckBan.call([])

      refute conn.halted
      assert conn.assigns[:user_restriction] == :none
    end

    test "halts with 403 forbidden and ban details when user has an active ban", %{conn: conn} do
      banned_user = create_user()
      banner_admin = create_user()
      expires = DateTime.utc_now() |> DateTime.add(86_400, :second) |> DateTime.truncate(:second)

      {:ok, _ban} =
        %Ban{}
        |> Ban.changeset(%{
          user_id: banned_user.id,
          banned_by_id: banner_admin.id,
          reason: "Violated terms of service",
          type: "temporary",
          is_active: true,
          expires_at: expires
        })
        |> ForgeNexus.Repo.insert()

      conn =
        conn
        |> Guardian.Plug.put_current_resource(banned_user)
        |> CheckBan.call([])

      assert conn.halted
      assert conn.status == 403
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "You are banned"
      assert body["ban"]["reason"] == "Violated terms of service"
      assert body["ban"]["type"] == "temporary"
      assert body["ban"]["banned_by"] == banner_admin.username
      assert body["ban"]["expires_at"] == DateTime.to_iso8601(expires)
    end

    test "assigns warning restriction (:cooldown) to conn and does not halt", %{
      conn: conn
    } do
      user = create_user()
      admin = create_user()

      {:ok, _warning} =
        %Warning{}
        |> Warning.changeset(%{
          user_id: user.id,
          issued_by_id: admin.id,
          reason: "Too many rapid posts",
          type: "cooldown",
          points: 3,
          is_active: true,
          expires_at: DateTime.utc_now() |> DateTime.add(1800, :second)
        })
        |> ForgeNexus.Repo.insert()

      conn =
        conn
        |> Guardian.Plug.put_current_resource(user)
        |> CheckBan.call([])

      refute conn.halted
      assert conn.assigns[:user_restriction] == :cooldown
    end

    test "assigns warning restriction (:read_only or :cooldown) to conn and does not halt", %{
      conn: conn
    } do
      user = create_user()
      admin = create_user()

      {:ok, _warning} =
        %Warning{}
        |> Warning.changeset(%{
          user_id: user.id,
          issued_by_id: admin.id,
          reason: "Spam warning",
          type: "read_only",
          points: 5,
          is_active: true,
          expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
        })
        |> ForgeNexus.Repo.insert()

      conn =
        conn
        |> Guardian.Plug.put_current_resource(user)
        |> CheckBan.call([])

      refute conn.halted
      assert conn.assigns[:user_restriction] == :read_only
    end
  end

  # =========================================================================
  # RequireVerifiedEmail
  # =========================================================================
  describe "RequireVerifiedEmail plug" do
    test "init/1 returns given options unchanged" do
      assert RequireVerifiedEmail.init(test: true) == [test: true]
    end

    test "allows unauthenticated connection through to let other auth plugs handle it", %{
      conn: conn
    } do
      conn = RequireVerifiedEmail.call(conn, [])
      refute conn.halted
    end

    test "allows user with email_verified_at through", %{conn: conn} do
      user =
        create_user()
        |> Ecto.Changeset.change(%{
          email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> ForgeNexus.Repo.update!()

      conn =
        conn
        |> Guardian.Plug.put_current_resource(user)
        |> RequireVerifiedEmail.call([])

      refute conn.halted
    end

    test "halts with 403 forbidden when user email is not verified", %{conn: conn} do
      user = create_user(%{email_verified_at: nil})

      conn =
        conn
        |> Guardian.Plug.put_current_resource(user)
        |> RequireVerifiedEmail.call([])

      assert conn.halted
      assert conn.status == 403

      assert Jason.decode!(conn.resp_body) == %{
               "error" => "Please verify your email before posting",
               "code" => "email_not_verified"
             }
    end
  end
end
