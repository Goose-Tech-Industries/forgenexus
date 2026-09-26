defmodule ForgeNexusWeb.HealthAndPreferencesControllerTest do
  use ForgeNexusWeb.ConnCase, async: false

  alias ForgeNexus.Accounts
  alias ForgeNexus.Guardian

  defp create_user(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      username: "pref_user_#{unique}",
      email: "pref_user_#{unique}@example.com",
      password: "Fn9#xK8$mQ2!wZ7^vL4*",
      display_name: "Pref User #{unique}"
    }

    {:ok, user} = Accounts.register_user(Map.merge(default_attrs, attrs))

    {:ok, verified} =
      user
      |> Ecto.Changeset.change(%{
        email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> ForgeNexus.Repo.update()

    verified
  end

  defp auth_conn(conn, user) do
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    conn
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_cookie("fn_token", token)
  end

  # =========================================================================
  # HealthController
  # =========================================================================
  describe "GET /api/health" do
    test "returns system health check and component statuses", %{conn: conn} do
      conn = get(conn, ~p"/api/health")
      response = json_response(conn, 200)

      assert response["status"] == "ok"
      assert response["checks"]["database"]["status"] == "ok"
      assert is_map(response["system"])
      assert is_integer(response["system"]["uptime_seconds"])
    end
  end

  # =========================================================================
  # PreferencesController
  # =========================================================================
  describe "GET and PUT /api/preferences" do
    test "index returns 401 when unauthenticated", %{conn: conn} do
      conn = get(conn, ~p"/api/preferences")
      assert json_response(conn, 401)["error"] =~ "Not authenticated"
    end

    test "index returns user preferences when authenticated", %{conn: conn} do
      user = create_user()
      conn = auth_conn(conn, user)

      conn = get(conn, ~p"/api/preferences")
      response = json_response(conn, 200)
      assert is_map(response["preferences"])
      assert Map.has_key?(response["preferences"], "posts_per_page")
    end

    test "update updates user preferences", %{conn: conn} do
      user = create_user()
      conn = auth_conn(conn, user)

      params = %{
        "preferences" => %{
          "posts_per_page" => 50,
          "content_density" => "compact",
          "pagination_mode" => "infinite_scroll"
        }
      }

      conn = put(conn, ~p"/api/preferences", params)
      response = json_response(conn, 200)
      assert response["preferences"]["posts_per_page"] == 50
      assert response["preferences"]["content_density"] == "compact"
    end

    test "update returns 400 when preferences parameter is missing", %{conn: conn} do
      user = create_user()
      conn = auth_conn(conn, user)

      conn = put(conn, ~p"/api/preferences", %{})
      assert json_response(conn, 400)["error"] =~ "Missing preferences"
    end

    test "update returns 422 on invalid preference attributes", %{conn: conn} do
      user = create_user()
      conn = auth_conn(conn, user)

      params = %{
        "preferences" => %{
          "posts_per_page" => -5
        }
      }

      conn = put(conn, ~p"/api/preferences", params)
      assert json_response(conn, 422)["errors"] != nil
    end
  end

  # =========================================================================
  # UserPreferenceController
  # =========================================================================
  describe "GET and PUT /api/user/preferences" do
    test "show returns preferences for authenticated user", %{conn: conn} do
      user = create_user()
      conn = auth_conn(conn, user)

      conn = get(conn, ~p"/api/user/preferences")
      response = json_response(conn, 200)
      assert is_map(response["preferences"])
    end

    test "update updates preferences via /api/user/preferences", %{conn: conn} do
      user = create_user()
      conn = auth_conn(conn, user)

      params = %{
        "preferences" => %{
          "posts_per_page" => 25,
          "reduced_motion" => true
        }
      }

      conn = put(conn, ~p"/api/user/preferences", params)
      response = json_response(conn, 200)
      assert response["preferences"]["posts_per_page"] == 25
      assert response["preferences"]["reduced_motion"] == true
    end

    test "update returns 422 on invalid values", %{conn: conn} do
      user = create_user()
      conn = auth_conn(conn, user)

      params = %{
        "preferences" => %{
          "pagination_mode" => "invalid_mode"
        }
      }

      conn = put(conn, ~p"/api/user/preferences", params)
      assert json_response(conn, 422)["errors"] != nil
    end
  end
end
