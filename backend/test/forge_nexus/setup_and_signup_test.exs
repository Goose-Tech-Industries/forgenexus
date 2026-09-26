defmodule ForgeNexus.SetupAndSignupTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.{Setup, Signup, Repo}
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Communities.Community

  describe "ForgeNexus.Setup" do
    test "preflight_checks/0 returns checks for Postgres, Meilisearch, Elixir, OTP" do
      Req.default_options(plug: {Req.Test, ForgeNexus.Setup}, retry: false)

      Req.Test.stub(ForgeNexus.Setup, fn conn ->
        Req.Test.json(conn, %{"status" => "available"})
      end)

      on_exit(fn -> Req.default_options([]) end)

      checks = Setup.preflight_checks()
      names = Enum.map(checks, & &1.name)

      assert "PostgreSQL" in names
      assert "Meilisearch" in names
      assert "Elixir" in names
      assert "Erlang/OTP" in names

      pg = Enum.find(checks, &(&1.name == "PostgreSQL"))
      assert pg.status == "ok"
    end

    test "validate_setup_params/1 validates required admin fields" do
      valid = %{
        "admin_username" => "admin",
        "admin_email" => "admin@example.com",
        "admin_password" => "Password123!",
        "site_name" => "ForgeNexus Site"
      }

      assert Setup.validate_setup_params(valid) == :ok

      # Missing admin_email
      invalid = Map.delete(valid, "admin_email")
      assert {:error, msgs} = Setup.validate_setup_params(invalid)
      assert "admin_email is required" in msgs
    end

    test "installed?/0 detects when an admin user with trust_level >= 4 exists" do
      refute Setup.installed?()

      n = System.unique_integer([:positive])

      %User{}
      |> User.registration_changeset(%{
        username: "admin_inst_#{n}",
        email: "admin_inst_#{n}@example.com",
        password: "Password123!"
      })
      |> Ecto.Changeset.put_change(:trust_level, 4)
      |> Repo.insert!()

      assert Setup.installed?()
    end

    test "run_setup/1 fails when already installed" do
      n = System.unique_integer([:positive])

      %User{}
      |> User.registration_changeset(%{
        username: "adm_exist_#{n}",
        email: "adm_exist_#{n}@example.com",
        password: "Password123!"
      })
      |> Ecto.Changeset.put_change(:trust_level, 4)
      |> Repo.insert!()

      params = %{
        "admin_username" => "new_admin",
        "admin_email" => "new_admin@example.com",
        "admin_password" => "Password123!",
        "site_name" => "ForgeNexus"
      }

      assert Setup.run_setup(params) == {:error, :already_installed}
    end
  end

  describe "ForgeNexus.Signup" do
    test "provision/1 rejects invalid plan" do
      assert Signup.provision(%{plan: "unsupported_tier"}) == {:error, :invalid_plan}
    end

    test "provision/1 provisions user and community tenant in trialing mode when stripe not configured" do
      n = System.unique_integer([:positive])

      attrs = %{
        email: "signup_owner_#{n}@example.com",
        password: "Fn9#xK8$mQ2!wZ7^vL4*",
        username: "owner_#{n}",
        community_slug: "tenant-#{n}",
        community_name: "Tenant #{n}",
        plan: "community",
        registered_ip: "127.0.0.1"
      }

      assert {:ok, result} = Signup.provision(attrs)
      assert result.user.username == "owner_#{n}"
      assert result.community.slug == "tenant-#{n}"
      assert result.community.plan == "community"
      assert result.community.plan_status == "trialing"
      assert result.checkout_url == nil
      assert result.stripe_status == :not_configured

      # Check membership
      member =
        Repo.get_by(ForgeNexus.Communities.CommunityMember,
          community_id: result.community.id,
          user_id: result.user.id
        )

      assert member != nil
      assert member.role == "owner"
    end

    test "provision/1 rolls back on invalid user parameters" do
      n = System.unique_integer([:positive])

      attrs = %{
        email: "invalid_email",
        password: "short",
        username: "x",
        community_slug: "rollback-#{n}",
        community_name: "Rollback #{n}",
        plan: "community"
      }

      assert {:error, %Ecto.Changeset{}} = Signup.provision(attrs)
      assert Repo.get_by(Community, slug: "rollback-#{n}") == nil
    end
  end
end
