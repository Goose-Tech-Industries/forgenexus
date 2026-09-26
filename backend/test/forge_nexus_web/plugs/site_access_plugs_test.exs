defmodule ForgeNexusWeb.Plugs.SiteAccessPlugsTest do
  use ForgeNexusWeb.ConnCase, async: false

  alias ForgeNexus.Accounts
  alias ForgeNexus.Accounts.{User, UserGroup, UserGroupMembership}
  alias ForgeNexus.Communities.Community
  alias ForgeNexus.Settings

  alias ForgeNexusWeb.Plugs.{
    ClampPagination,
    CORS,
    FeatureGate,
    MaintenanceMode,
    SecurityHeaders,
    SetupRequired
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
  # MaintenanceMode
  # =========================================================================
  describe "MaintenanceMode plug" do
    setup do
      on_exit(fn ->
        Settings.set("maintenance_mode", "false")
      end)

      Settings.set("maintenance_mode", "false")
      :ok
    end

    test "init/1 returns options unchanged" do
      assert MaintenanceMode.init([]) == []
    end

    test "allows request through when maintenance_mode is disabled", %{conn: conn} do
      Settings.set("maintenance_mode", "false")

      conn =
        %{conn | request_path: "/api/posts"}
        |> MaintenanceMode.call([])

      refute conn.halted
      assert conn.status == nil
    end

    test "allows bypass paths through even when maintenance_mode is enabled", %{conn: conn} do
      Settings.set("maintenance_mode", "true")

      for path <- ["/api/auth/login", "/api/auth/me", "/api/settings/public"] do
        conn =
          %{conn | request_path: path}
          |> MaintenanceMode.call([])

        refute conn.halted
        assert conn.status == nil
      end

      Settings.set("maintenance_mode", "false")
    end

    test "allows staff users through when maintenance_mode is enabled", %{conn: conn} do
      Settings.set("maintenance_mode", "true")
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
        %{conn | request_path: "/api/forum/threads"}
        |> Guardian.Plug.put_current_resource(user)
        |> MaintenanceMode.call([])

      refute conn.halted
      assert conn.status == nil
      Settings.set("maintenance_mode", "false")
    end

    test "halts with 503 service_unavailable for regular user when maintenance_mode is enabled",
         %{conn: conn} do
      Settings.set("maintenance_mode", "true")
      Settings.set("maintenance_message", "Scheduled maintenance in progress.")
      user = create_user()

      conn =
        %{conn | request_path: "/api/forum/threads"}
        |> Guardian.Plug.put_current_resource(user)
        |> MaintenanceMode.call([])

      assert conn.halted
      assert conn.status == 503

      assert Jason.decode!(conn.resp_body) == %{
               "error" => "maintenance",
               "message" => "Scheduled maintenance in progress."
             }

      Settings.set("maintenance_mode", "false")
    end

    test "halts with 503 and default message for unauthenticated user when message is default", %{
      conn: conn
    } do
      Settings.set("maintenance_mode", "true")
      Settings.set("maintenance_message", "We'll be back soon.")

      conn =
        %{conn | request_path: "/api/forum/threads"}
        |> MaintenanceMode.call([])

      assert conn.halted
      assert conn.status == 503

      assert Jason.decode!(conn.resp_body) == %{
               "error" => "maintenance",
               "message" => "We'll be back soon."
             }

      Settings.set("maintenance_mode", "false")
    end
  end

  # =========================================================================
  # FeatureGate
  # =========================================================================
  describe "FeatureGate plug" do
    test "init/1 returns options unchanged" do
      opts = [feature: "streaming"]
      assert FeatureGate.init(opts) == opts
    end

    test "allows request through when community has feature enabled", %{conn: conn} do
      community = %Community{
        feature_flags: %{"streaming" => true}
      }

      conn =
        conn
        |> assign(:community, community)
        |> FeatureGate.call(feature: "streaming")

      refute conn.halted
      assert conn.status == nil
    end

    test "halts with 403 when community does not have the feature enabled", %{conn: conn} do
      community = %Community{
        feature_flags: %{"streaming" => false}
      }

      conn =
        conn
        |> assign(:community, community)
        |> FeatureGate.call(feature: "streaming")

      assert conn.halted
      assert conn.status == 403

      assert Jason.decode!(conn.resp_body) == %{
               "error" => "Feature 'streaming' is not enabled for this community",
               "upgrade_url" => "/upgrade"
             }
    end

    test "halts with 403 when no community is assigned to conn", %{conn: conn} do
      conn = FeatureGate.call(conn, feature: "marketplace")

      assert conn.halted
      assert conn.status == 403

      assert Jason.decode!(conn.resp_body) == %{
               "error" => "Feature 'marketplace' is not enabled for this community",
               "upgrade_url" => "/upgrade"
             }
    end
  end

  # =========================================================================
  # ClampPagination
  # =========================================================================
  describe "ClampPagination plug" do
    test "init/1 returns options unchanged" do
      assert ClampPagination.init([]) == []
    end

    test "leaves un-clamped and non-numeric params unchanged", %{conn: conn} do
      conn = %{
        conn
        | params: %{"search" => "elixir", "page" => "invalid"},
          query_params: %{"search" => "elixir", "page" => "invalid"}
      }

      result = ClampPagination.call(conn, [])

      assert result.params["search"] == "elixir"
      assert result.params["page"] == "invalid"
      assert result.query_params["search"] == "elixir"
      assert result.query_params["page"] == "invalid"
    end

    test "clamps lower and upper bounds on offset, limit, page, and days", %{conn: conn} do
      conn = %{
        conn
        | params: %{
            "offset" => "-50",
            "limit" => "9999",
            "page" => "0",
            "days" => "50000"
          },
          query_params: %{
            "offset" => "2000000",
            "limit" => "-10",
            "page" => "500",
            "days" => "-1"
          }
      }

      result = ClampPagination.call(conn, [])

      # "offset" clamped between 0 and 1_000_000
      assert result.params["offset"] == "0"
      assert result.query_params["offset"] == "1000000"

      # "limit" clamped between 1 and 200
      assert result.params["limit"] == "200"
      assert result.query_params["limit"] == "1"

      # "page" clamped between 1 and 1_000_000
      assert result.params["page"] == "1"
      assert result.query_params["page"] == "500"

      # "days" clamped between 1 and 3650
      assert result.params["days"] == "3650"
      assert result.query_params["days"] == "1"
    end

    test "handles integer input directly in params", %{conn: conn} do
      conn = %{
        conn
        | params: %{"limit" => 500, "page" => -3},
          query_params: %{"limit" => 500, "page" => -3}
      }

      result = ClampPagination.call(conn, [])

      assert result.params["limit"] == "200"
      assert result.params["page"] == "1"
      assert result.query_params["limit"] == "200"
      assert result.query_params["page"] == "1"
    end
  end

  # =========================================================================
  # SecurityHeaders
  # =========================================================================
  describe "SecurityHeaders plug" do
    test "init/1 returns options unchanged" do
      assert SecurityHeaders.init([]) == []
    end

    test "sets all required security headers and CSP", %{conn: conn} do
      result = SecurityHeaders.call(conn, [])

      assert get_resp_header(result, "x-content-type-options") == ["nosniff"]
      assert get_resp_header(result, "x-frame-options") == ["DENY"]
      assert get_resp_header(result, "x-xss-protection") == ["0"]
      assert get_resp_header(result, "referrer-policy") == ["strict-origin-when-cross-origin"]
      assert get_resp_header(result, "cross-origin-opener-policy") == ["same-origin"]
      assert get_resp_header(result, "cross-origin-resource-policy") == ["same-origin"]

      [perm_policy] = get_resp_header(result, "permissions-policy")
      assert String.contains?(perm_policy, "camera=()")
      assert String.contains?(perm_policy, "geolocation=()")

      [csp] = get_resp_header(result, "content-security-policy")
      assert String.contains?(csp, "default-src 'self'")
      assert String.contains?(csp, "script-src 'self' 'unsafe-inline'")
      assert String.contains?(csp, "object-src 'none'")
      assert String.contains?(csp, "frame-ancestors 'none'")
    end

    test "ws_origin correctly replaces http and https schemes", %{conn: conn} do
      # Test with non-localhost host setting
      orig_endpoint = Application.get_env(:forge_nexus, ForgeNexusWeb.Endpoint)

      try do
        Application.put_env(
          :forge_nexus,
          ForgeNexusWeb.Endpoint,
          Keyword.merge(orig_endpoint || [], url: [host: "forgenexus.com"])
        )

        result = SecurityHeaders.call(conn, [])
        [csp] = get_resp_header(result, "content-security-policy")
        assert String.contains?(csp, "https://forgenexus.com")
        assert String.contains?(csp, "wss://forgenexus.com")
      after
        Application.put_env(:forge_nexus, ForgeNexusWeb.Endpoint, orig_endpoint)
      end
    end
  end

  # =========================================================================
  # CORS
  # =========================================================================
  describe "CORS plug" do
    test "init/1 returns options unchanged" do
      assert CORS.init([]) == []
    end

    test "handles OPTIONS preflight for allowed dev origin", %{conn: conn} do
      conn =
        conn
        |> put_req_header("origin", "http://localhost:5173")
        |> Map.put(:method, "OPTIONS")
        |> CORS.call([])

      assert conn.halted
      assert conn.status == 200
      assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:5173"]
      assert get_resp_header(conn, "access-control-allow-credentials") == ["true"]

      assert get_resp_header(conn, "access-control-allow-methods") == [
               "GET, POST, PUT, PATCH, DELETE, OPTIONS"
             ]

      assert get_resp_header(conn, "access-control-max-age") == ["86400"]
    end

    test "does not put cors headers on OPTIONS request from disallowed origin", %{conn: conn} do
      conn =
        conn
        |> put_req_header("origin", "http://malicious-site.com")
        |> Map.put(:method, "OPTIONS")
        |> CORS.call([])

      refute conn.halted
      assert get_resp_header(conn, "access-control-allow-origin") == []
    end

    test "puts cors headers on regular GET request from allowed origin", %{conn: conn} do
      conn =
        conn
        |> put_req_header("origin", "http://localhost:5173")
        |> Map.put(:method, "GET")
        |> CORS.call([])

      refute conn.halted
      assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:5173"]
    end

    test "allows wildcard origin when cors_origins is configured as ['*']", %{conn: conn} do
      orig_cors = Application.get_env(:forge_nexus, :cors_origins)

      try do
        Application.put_env(:forge_nexus, :cors_origins, ["*"])

        conn =
          conn
          |> put_req_header("origin", "http://any-domain.example.com")
          |> Map.put(:method, "OPTIONS")
          |> CORS.call([])

        assert conn.halted
        assert conn.status == 200

        assert get_resp_header(conn, "access-control-allow-origin") == [
                 "http://any-domain.example.com"
               ]
      after
        Application.put_env(:forge_nexus, :cors_origins, orig_cors)
      end
    end
  end

  # =========================================================================
  # SetupRequired
  # =========================================================================
  describe "SetupRequired plug" do
    test "init/1 returns options unchanged" do
      assert SetupRequired.init([]) == []
    end

    test "allows bypass paths like /api/setup and /api/health through", %{conn: conn} do
      for path <- ["/api/setup/wizard", "/api/setup/database", "/api/health"] do
        conn =
          %{conn | request_path: path}
          |> SetupRequired.call([])

        refute conn.halted
        assert conn.status == nil
      end
    end

    test "allows regular requests when site is installed (admin exists)", %{conn: conn} do
      _admin =
        create_user()
        |> Ecto.Changeset.change(%{trust_level: 4})
        |> ForgeNexus.Repo.update!()

      conn =
        %{conn | request_path: "/api/posts"}
        |> SetupRequired.call([])

      refute conn.halted
      assert conn.status == nil
    end

    test "halts with 503 service_unavailable when site is not installed", %{conn: conn} do
      # Ensure no user exists with trust_level >= 4 or in staff group
      ForgeNexus.Repo.delete_all(UserGroupMembership)
      ForgeNexus.Repo.delete_all(User)

      conn =
        %{conn | request_path: "/api/posts"}
        |> SetupRequired.call([])

      assert conn.halted
      assert conn.status == 503

      assert Jason.decode!(conn.resp_body) == %{
               "error" => "Setup required",
               "setup_url" => "/setup"
             }
    end
  end
end
