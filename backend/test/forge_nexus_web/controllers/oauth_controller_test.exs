defmodule ForgeNexusWeb.OAuthControllerTest do
  use ForgeNexusWeb.ConnCase, async: false

  alias ForgeNexus.Accounts
  alias ForgeNexus.Guardian

  @sample_config [
    google: [
      client_id: "google_client_id",
      client_secret: "google_secret",
      redirect_uri: "http://localhost:5173/auth/oauth/google/callback"
    ],
    github: [
      client_id: "github_client_id",
      client_secret: "github_secret",
      redirect_uri: "http://localhost:5173/auth/oauth/github/callback"
    ],
    discord: [
      client_id: "discord_client_id",
      client_secret: "discord_secret",
      redirect_uri: "http://localhost:5173/auth/oauth/discord/callback"
    ]
  ]

  defp fresh_conn(conn) do
    b3 = rem(System.unique_integer([:positive]), 250) + 1
    b4 = rem(System.unique_integer([:positive]), 250) + 1
    %{conn | remote_ip: {10, 0, b3, b4}}
  end

  defp create_user(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      username: "oauth_user_#{unique}",
      email: "oauth_user_#{unique}@example.com",
      password: "Fn9#xK8$mQ2!wZ7^vL4*",
      display_name: "OAuth User #{unique}"
    }

    user =
      %Accounts.User{}
      |> Accounts.User.registration_changeset(Map.merge(default_attrs, attrs))
      |> ForgeNexus.Repo.insert!()

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, verified} =
      user |> Ecto.Changeset.change(email_verified_at: now) |> ForgeNexus.Repo.update()

    verified
  end

  defp auth_conn(conn, user) do
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    conn
    |> fresh_conn()
    |> put_req_header("authorization", "Bearer #{token}")
  end

  setup do
    Application.put_env(:forge_nexus, :oauth, @sample_config)
    Req.default_options(plug: {Req.Test, ForgeNexus.OAuth}, retry: false)

    # Set default stub so other Req calls fail-open gracefully
    Req.Test.stub(ForgeNexus.OAuth, fn conn ->
      Plug.Conn.send_resp(conn, 200, "")
    end)

    on_exit(fn ->
      Application.delete_env(:forge_nexus, :oauth)
      Req.default_options([])
    end)

    :ok
  end

  describe "GET /api/auth/oauth/:provider (redirect_to_provider)" do
    test "redirects to Google auth url and sets state cookie", %{conn: conn} do
      conn = fresh_conn(conn) |> get(~p"/api/auth/oauth/google")

      assert redirected_to(conn, 302) =~ "https://accounts.google.com/o/oauth2/v2/auth"
      assert conn.resp_cookies["oauth_state"] != nil
    end

    test "redirects with error when provider is unsupported", %{conn: conn} do
      conn = fresh_conn(conn) |> get(~p"/api/auth/oauth/unsupported_provider")

      assert redirected_to(conn, 302) =~ "/auth/oauth/callback?error=Unsupported+provider"
    end

    test "redirects with error when provider config is missing", %{conn: conn} do
      Application.put_env(:forge_nexus, :oauth, [])

      conn = fresh_conn(conn) |> get(~p"/api/auth/oauth/google")
      assert redirected_to(conn, 302) =~ "/auth/oauth/callback?error="
    end
  end

  describe "GET /api/auth/oauth/:provider/callback error conditions" do
    test "redirects with error when error query param is present", %{conn: conn} do
      conn =
        fresh_conn(conn)
        |> get(~p"/api/auth/oauth/google/callback", %{
          "error" => "access_denied",
          "error_description" => "User denied consent"
        })

      assert redirected_to(conn, 302) =~ "error=User+denied+consent"
    end

    test "redirects with error when only error param without description is present", %{
      conn: conn
    } do
      conn =
        fresh_conn(conn)
        |> get(~p"/api/auth/oauth/google/callback", %{"error" => "access_denied"})

      assert redirected_to(conn, 302) =~ "error=access_denied"
    end

    test "redirects with error when code is missing", %{conn: conn} do
      conn = fresh_conn(conn) |> get(~p"/api/auth/oauth/google/callback")
      assert redirected_to(conn, 302) =~ "error=Missing+authorization+code"
    end

    test "redirects with error when provider is invalid", %{conn: conn} do
      conn =
        fresh_conn(conn)
        |> put_req_cookie("oauth_state", "state_123")
        |> get(~p"/api/auth/oauth/unknown/callback", %{"code" => "c", "state" => "state_123"})

      assert redirected_to(conn, 302) =~ "error=Unsupported+provider"
    end

    test "redirects with error when state cookie is missing or mismatched", %{conn: conn} do
      # Missing state cookie
      conn1 =
        fresh_conn(conn)
        |> get(~p"/api/auth/oauth/google/callback", %{"code" => "c", "state" => "state_123"})

      assert redirected_to(conn1, 302) =~ "error=Invalid+state+parameter"

      # Mismatched state cookie
      conn2 =
        fresh_conn(conn)
        |> put_req_cookie("oauth_state", "different_state")
        |> get(~p"/api/auth/oauth/google/callback", %{"code" => "c", "state" => "state_123"})

      assert redirected_to(conn2, 302) =~ "error=Invalid+state+parameter"
    end
  end

  describe "GET /api/auth/oauth/:provider/callback success and link flows" do
    test "successfully logs in or signs up user and redirects with token", %{conn: conn} do
      unique = System.unique_integer([:positive])

      Req.Test.stub(ForgeNexus.OAuth, fn req_conn ->
        cond do
          req_conn.request_path =~ "/token" ->
            Req.Test.json(req_conn, %{
              "access_token" => "google_access_tok",
              "refresh_token" => "google_refresh_tok"
            })

          req_conn.request_path =~ "userinfo" ->
            Req.Test.json(req_conn, %{
              "id" => "gid_#{unique}",
              "email" => "guser#{unique}@example.com",
              "name" => "Google User #{unique}",
              "picture" => "https://example.com/photo.jpg"
            })

          true ->
            Plug.Conn.send_resp(req_conn, 200, "")
        end
      end)

      conn =
        fresh_conn(conn)
        |> put_req_cookie("oauth_state", "valid_state_123")
        |> get(~p"/api/auth/oauth/google/callback", %{
          "code" => "good_code",
          "state" => "valid_state_123"
        })

      location = redirected_to(conn, 302)
      assert location =~ "/auth/oauth/callback?token="
      assert conn.resp_cookies["fn_token"] != nil
    end

    test "links oauth provider to logged-in user when oauth_link_user cookie is set", %{
      conn: conn
    } do
      user = create_user()

      Req.Test.stub(ForgeNexus.OAuth, fn req_conn ->
        cond do
          req_conn.request_path =~ "access_token" or req_conn.request_path =~ "/token" ->
            Req.Test.json(req_conn, %{"access_token" => "github_tok"})

          req_conn.request_path =~ "/user" ->
            Req.Test.json(req_conn, %{
              "id" => 888_999,
              "email" => "ghlink@example.com",
              "login" => "ghlinkuser"
            })

          true ->
            Plug.Conn.send_resp(req_conn, 200, "")
        end
      end)

      conn =
        fresh_conn(conn)
        |> put_req_cookie("oauth_state", "link_state_456")
        |> put_req_cookie("oauth_link_user", user.id)
        |> get(~p"/api/auth/oauth/github/callback", %{
          "code" => "gh_code",
          "state" => "link_state_456"
        })

      assert redirected_to(conn, 302) =~ "/settings/account?oauth=linked&provider=github"
    end
  end

  describe "POST /api/auth/oauth/:provider/link" do
    test "returns 401 when unauthenticated", %{conn: conn} do
      conn = fresh_conn(conn) |> post(~p"/api/auth/oauth/google/link")
      assert json_response(conn, 401) == %{"error" => "Authentication required"}
    end

    test "returns 400 when provider is invalid", %{conn: conn} do
      user = create_user()

      conn =
        auth_conn(conn, user)
        |> post(~p"/api/auth/oauth/badprov/link")

      assert json_response(conn, 400) == %{"error" => "Unsupported provider"}
    end

    test "returns 200 with redirect_url and sets link cookie for valid provider", %{conn: conn} do
      user = create_user()

      conn =
        auth_conn(conn, user)
        |> post(~p"/api/auth/oauth/google/link")

      resp = json_response(conn, 200)
      assert resp["redirect_url"] =~ "https://accounts.google.com/o/oauth2/v2/auth"
      assert conn.resp_cookies["oauth_state"] != nil
      assert conn.resp_cookies["oauth_link_user"].value == user.id
    end
  end

  describe "DELETE /api/auth/oauth/:provider/unlink" do
    test "returns 401 when unauthenticated", %{conn: conn} do
      conn = fresh_conn(conn) |> delete(~p"/api/auth/oauth/google/unlink")
      assert json_response(conn, 401) == %{"error" => "Authentication required"}
    end

    test "unlinks provider when user has password and linked account", %{conn: conn} do
      user = create_user()

      # Link an OAuth account
      {:ok, _account} =
        Accounts.link_oauth_account(user.id, "google", %{
          provider_uid: "uid_to_unlink",
          email: "unlink@example.com"
        })

      conn =
        auth_conn(conn, user)
        |> delete(~p"/api/auth/oauth/google/unlink")

      assert json_response(conn, 200) == %{"message" => "Google account unlinked"}
    end

    test "returns 422 when unlinking only login method (no password)", %{conn: conn} do
      n = System.unique_integer([:positive])
      # OAuth-only user with no password_hash
      user =
        %Accounts.User{}
        |> Ecto.Changeset.change(%{
          username: "nopw_#{n}",
          slug: "nopw-#{n}",
          email: "nopw_#{n}@example.com",
          email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
          password_hash: nil
        })
        |> ForgeNexus.Repo.insert!()

      {:ok, _} =
        Accounts.link_oauth_account(user.id, "google", %{
          provider_uid: "uid_only_login",
          email: "only@example.com"
        })

      conn =
        auth_conn(conn, user)
        |> delete(~p"/api/auth/oauth/google/unlink")

      assert json_response(conn, 422) == %{
               "error" => "Cannot unlink your only login method. Set a password first."
             }
    end

    test "returns 404 when no linked account found for provider", %{conn: conn} do
      user = create_user()

      conn =
        auth_conn(conn, user)
        |> delete(~p"/api/auth/oauth/discord/unlink")

      assert json_response(conn, 404) == %{"error" => "No linked discord account found"}
    end
  end

  describe "GET /api/auth/oauth/accounts (linked_accounts)" do
    test "returns 401 when unauthenticated", %{conn: conn} do
      conn = fresh_conn(conn) |> get(~p"/api/auth/oauth/accounts")
      assert json_response(conn, 401) == %{"error" => "Authentication required"}
    end

    test "returns list of linked accounts for current user", %{conn: conn} do
      user = create_user()

      {:ok, _} =
        Accounts.link_oauth_account(user.id, "github", %{
          provider_uid: "uid_gh_list",
          email: "list@example.com",
          name: "List GH",
          avatar_url: "https://example.com/avatar.jpg"
        })

      conn =
        auth_conn(conn, user)
        |> get(~p"/api/auth/oauth/accounts")

      resp = json_response(conn, 200)
      assert is_list(resp["accounts"])
      assert length(resp["accounts"]) == 1
      account = hd(resp["accounts"])
      assert account["provider"] == "github"
      assert account["provider_email"] == "list@example.com"
      assert account["provider_name"] == "List GH"
      assert account["provider_avatar"] == "https://example.com/avatar.jpg"
    end
  end
end
