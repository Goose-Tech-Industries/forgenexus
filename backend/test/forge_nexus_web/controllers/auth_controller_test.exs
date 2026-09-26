defmodule ForgeNexusWeb.AuthControllerTest do
  use ForgeNexusWeb.ConnCase, async: false

  alias ForgeNexus.Accounts
  alias ForgeNexus.Guardian

  defp create_user(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      username: "auth_user_#{unique}",
      email: "auth_user_#{unique}@example.com",
      password: "Fn9#xK8$mQ2!wZ7^vL4*",
      display_name: "Auth User #{unique}"
    }

    {:ok, user} = Accounts.register_user(Map.merge(default_attrs, attrs))
    user
  end

  defp fresh_conn(conn) do
    b3 = rem(System.unique_integer([:positive]), 250) + 1
    b4 = rem(System.unique_integer([:positive]), 250) + 1
    %{conn | remote_ip: {10, 0, b3, b4}}
  end

  defp auth_conn(conn, user) do
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    conn
    |> fresh_conn()
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_cookie("fn_token", token)
  end

  # =========================================================================
  # Registration
  # =========================================================================
  describe "POST /api/auth/register" do
    test "creates user and returns 201 with token and user json", %{conn: conn} do
      unique = System.unique_integer([:positive])

      params = %{
        "user" => %{
          "username" => "new_user_#{unique}",
          "email" => "new_user_#{unique}@example.com",
          "password" => "StrongP@ssw0rd!123",
          "display_name" => "New User"
        }
      }

      conn = post(fresh_conn(conn), ~p"/api/auth/register", params)
      response = json_response(conn, 201)

      assert is_binary(response["token"])
      assert response["user"]["username"] == "new_user_#{unique}"
      assert response["user"]["email"] == "new_user_#{unique}@example.com"
      assert conn.resp_cookies["fn_token"] != nil
    end

    test "returns 422 when required fields are missing", %{conn: conn} do
      params = %{"user" => %{"username" => ""}}

      conn = post(fresh_conn(conn), ~p"/api/auth/register", params)
      response = json_response(conn, 422)

      assert Map.has_key?(response, "errors")
    end

    test "returns 422 on duplicate username", %{conn: conn} do
      user = create_user()

      params = %{
        "user" => %{
          "username" => user.username,
          "email" => "different@example.com",
          "password" => "StrongP@ssw0rd!123"
        }
      }

      conn = post(fresh_conn(conn), ~p"/api/auth/register", params)
      response = json_response(conn, 422)

      assert Map.has_key?(response, "errors")
    end
  end

  # =========================================================================
  # Login
  # =========================================================================
  describe "POST /api/auth/login" do
    test "returns 200 with token and user when credentials are valid", %{conn: conn} do
      user = create_user(%{password: "CorrectP@ssword1"})

      conn =
        post(fresh_conn(conn), ~p"/api/auth/login", %{
          "email" => user.email,
          "password" => "CorrectP@ssword1"
        })

      response = json_response(conn, 200)
      assert is_binary(response["token"])
      assert response["user"]["id"] == user.id
      assert conn.resp_cookies["fn_token"] != nil
    end

    test "returns 401 when password is wrong", %{conn: conn} do
      user = create_user(%{password: "CorrectP@ssword1"})

      conn =
        post(fresh_conn(conn), ~p"/api/auth/login", %{
          "email" => user.email,
          "password" => "WrongPassword"
        })

      assert json_response(conn, 401)["error"] =~ "Invalid email or password"
    end

    test "returns 401 when email does not exist", %{conn: conn} do
      conn =
        post(fresh_conn(conn), ~p"/api/auth/login", %{
          "email" => "nonexistent@example.com",
          "password" => "WrongPassword"
        })

      assert json_response(conn, 401)["error"] =~ "Invalid email or password"
    end
  end

  # =========================================================================
  # Refresh & Logout
  # =========================================================================
  describe "POST /api/auth/refresh and /api/auth/logout" do
    test "refresh returns 200 with new token when cookie is valid", %{conn: conn} do
      user = create_user()
      {:ok, token, _} = Guardian.encode_and_sign(user)

      conn =
        conn
        |> fresh_conn()
        |> put_req_cookie("fn_token", token)
        |> post(~p"/api/auth/refresh")

      response = json_response(conn, 200)
      assert is_binary(response["token"])
      assert response["user"]["id"] == user.id
    end

    test "refresh returns 401 when cookie is missing", %{conn: conn} do
      conn = post(fresh_conn(conn), ~p"/api/auth/refresh")
      assert json_response(conn, 401)["error"] =~ "No refresh token"
    end

    test "refresh returns 401 when cookie is invalid", %{conn: conn} do
      conn =
        conn
        |> fresh_conn()
        |> put_req_cookie("fn_token", "invalid_jwt_string")
        |> post(~p"/api/auth/refresh")

      assert json_response(conn, 401)["error"] =~ "Invalid token"
    end

    test "logout clears cookie and returns ok: true", %{conn: conn} do
      user = create_user()
      conn = auth_conn(conn, user)

      conn = post(conn, ~p"/api/auth/logout")
      assert json_response(conn, 200) == %{"ok" => true}
      assert conn.resp_cookies["fn_token"] != nil
    end
  end

  # =========================================================================
  # Current User (Me)
  # =========================================================================
  describe "GET /api/auth/me" do
    test "returns current user json when authenticated", %{conn: conn} do
      user = create_user()
      conn = auth_conn(conn, user)

      conn = get(conn, ~p"/api/auth/me")
      response = json_response(conn, 200)
      assert response["user"]["id"] == user.id
      assert response["user"]["username"] == user.username
    end

    test "returns 401 when unauthenticated", %{conn: conn} do
      conn = get(fresh_conn(conn), ~p"/api/auth/me")
      assert json_response(conn, 401)["error"] =~ "Not authenticated"
    end
  end

  # =========================================================================
  # Email Verification
  # =========================================================================
  describe "POST /api/auth/verify-email" do
    test "verifies email when token is valid", %{conn: conn} do
      user = create_user()
      {:ok, token, _struct} = Accounts.create_email_verify_token(user)

      conn = post(fresh_conn(conn), ~p"/api/auth/verify-email", %{"token" => token})
      response = json_response(conn, 200)
      assert response["ok"] == true
      assert response["user"]["email_verified"] == true
    end

    test "returns 404 when token is invalid", %{conn: conn} do
      conn =
        post(fresh_conn(conn), ~p"/api/auth/verify-email", %{"token" => "invalid_token_here"})

      assert json_response(conn, 404)["error"] =~ "Invalid verification token"
    end

    test "returns 400 when token param is missing", %{conn: conn} do
      conn = post(fresh_conn(conn), ~p"/api/auth/verify-email", %{})
      assert json_response(conn, 400)["error"] =~ "Missing token"
    end
  end

  # =========================================================================
  # Password Reset
  # =========================================================================
  describe "POST /api/auth/forgot-password and /api/auth/reset-password" do
    test "forgot_password responds 200 for both existing and non-existing email", %{conn: conn} do
      user = create_user()

      conn1 = post(fresh_conn(conn), ~p"/api/auth/forgot-password", %{"email" => user.email})
      assert json_response(conn1, 200) == %{"ok" => true}

      conn2 =
        post(fresh_conn(conn), ~p"/api/auth/forgot-password", %{"email" => "nobody@example.com"})

      assert json_response(conn2, 200) == %{"ok" => true}
    end

    test "forgot_password returns 400 when email is missing", %{conn: conn} do
      conn = post(fresh_conn(conn), ~p"/api/auth/forgot-password", %{})
      assert json_response(conn, 400)["error"] =~ "Missing email"
    end

    test "reset_password resets password when token is valid", %{conn: conn} do
      user = create_user()
      {:ok, token, _struct} = Accounts.create_password_reset_token(user)

      conn =
        post(fresh_conn(conn), ~p"/api/auth/reset-password", %{
          "token" => token,
          "password" => "NewStrongPassw0rd!123"
        })

      assert json_response(conn, 200) == %{"ok" => true}
      assert {:ok, _} = Accounts.authenticate_user(user.email, "NewStrongPassw0rd!123")
    end

    test "reset_password returns 404 when token is invalid", %{conn: conn} do
      conn =
        post(fresh_conn(conn), ~p"/api/auth/reset-password", %{
          "token" => "nonexistent_token",
          "password" => "NewStrongPassw0rd!123"
        })

      assert json_response(conn, 404)["error"] =~ "Invalid reset token"
    end

    test "reset_password returns 400 when params are missing", %{conn: conn} do
      conn = post(fresh_conn(conn), ~p"/api/auth/reset-password", %{})
      assert json_response(conn, 400)["error"] =~ "Missing token or password"
    end
  end

  # =========================================================================
  # Email Change
  # =========================================================================
  describe "POST /api/auth/request-email-change and confirm" do
    test "request_email_change returns 401 when not authenticated", %{conn: conn} do
      conn =
        post(fresh_conn(conn), ~p"/api/auth/request-email-change", %{
          "new_email" => "new@example.com",
          "password" => "somepassword"
        })

      assert json_response(conn, 401)["error"] =~ "Not authenticated"
    end

    test "request_email_change returns 401 when password incorrect", %{conn: conn} do
      user = create_user(%{password: "RealPassword123!"})
      conn = auth_conn(conn, user)

      conn =
        post(conn, ~p"/api/auth/request-email-change", %{
          "new_email" => "new@example.com",
          "password" => "WrongPassword"
        })

      assert json_response(conn, 401)["error"] =~ "Password incorrect"
    end

    test "request_email_change returns 422 when new email equals current email", %{conn: conn} do
      user = create_user(%{password: "RealPassword123!"})
      conn = auth_conn(conn, user)

      conn =
        post(conn, ~p"/api/auth/request-email-change", %{
          "new_email" => user.email,
          "password" => "RealPassword123!"
        })

      assert json_response(conn, 422)["error"] =~ "New email must differ"
    end

    test "request_email_change queues change and returns 200 on valid input", %{conn: conn} do
      user = create_user(%{password: "RealPassword123!"})
      conn = auth_conn(conn, user)

      conn =
        post(conn, ~p"/api/auth/request-email-change", %{
          "new_email" => "brandnew_email_#{System.unique_integer([:positive])}@example.com",
          "password" => "RealPassword123!"
        })

      assert json_response(conn, 200) == %{"ok" => true}
    end

    test "confirm_email_change verifies and changes email when token is valid", %{conn: conn} do
      user = create_user()
      new_email = "changed_#{System.unique_integer([:positive])}@example.com"
      {:ok, token, _struct} = Accounts.create_email_change_token(user, new_email)

      conn = post(fresh_conn(conn), ~p"/api/auth/confirm-email-change", %{"token" => token})
      response = json_response(conn, 200)
      assert response["ok"] == true
      assert response["user"]["email"] == new_email
    end

    test "confirm_email_change returns 404 when token is invalid", %{conn: conn} do
      conn = post(fresh_conn(conn), ~p"/api/auth/confirm-email-change", %{"token" => "bad_token"})
      assert json_response(conn, 404)["error"] =~ "Invalid confirmation token"
    end
  end

  # =========================================================================
  # Resend Verification
  # =========================================================================
  describe "POST /api/auth/resend-verification" do
    test "resends verification email for unverified user", %{conn: conn} do
      user = create_user()
      conn = auth_conn(conn, user)

      conn = post(conn, ~p"/api/auth/resend-verification")
      assert json_response(conn, 200) == %{"ok" => true}
    end

    test "returns 409 when email already verified", %{conn: conn} do
      user = create_user()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, verified_user} =
        user
        |> Ecto.Changeset.change(%{email_verified_at: now})
        |> ForgeNexus.Repo.update()

      conn = auth_conn(conn, verified_user)

      conn = post(conn, ~p"/api/auth/resend-verification")
      assert json_response(conn, 409)["error"] =~ "Email already verified"
    end

    test "returns 401 when unauthenticated", %{conn: conn} do
      conn = post(fresh_conn(conn), ~p"/api/auth/resend-verification")
      assert json_response(conn, 401)["error"] =~ "Not authenticated"
    end
  end
end
