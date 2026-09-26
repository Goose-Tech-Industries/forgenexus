defmodule ForgeNexus.OAuthTest do
  use ExUnit.Case, async: false

  alias ForgeNexus.OAuth

  @sample_config [
    google: [
      client_id: "google_client_123",
      client_secret: "google_secret_123",
      redirect_uri: "http://localhost:5173/auth/oauth/google/callback"
    ],
    github: [
      client_id: "github_client_123",
      client_secret: "github_secret_123",
      redirect_uri: "http://localhost:5173/auth/oauth/github/callback"
    ],
    discord: [
      client_id: "discord_client_123",
      client_secret: "discord_secret_123",
      redirect_uri: "http://localhost:5173/auth/oauth/discord/callback"
    ]
  ]

  setup do
    Application.put_env(:forge_nexus, :oauth, @sample_config)
    Req.default_options(plug: {Req.Test, ForgeNexus.OAuth}, retry: false)

    on_exit(fn ->
      Application.delete_env(:forge_nexus, :oauth)
      Req.default_options([])
    end)

    :ok
  end

  describe "supported_providers/0 and valid_provider?/1" do
    test "lists and validates supported providers" do
      assert "google" in OAuth.supported_providers()
      assert "github" in OAuth.supported_providers()
      assert "discord" in OAuth.supported_providers()

      assert OAuth.valid_provider?("google")
      assert OAuth.valid_provider?("github")
      assert OAuth.valid_provider?("discord")
      refute OAuth.valid_provider?("twitter")
      refute OAuth.valid_provider?("unknown")
    end
  end

  describe "generate_state/0" do
    test "generates URL-safe random string" do
      state1 = OAuth.generate_state()
      state2 = OAuth.generate_state()

      assert is_binary(state1)
      assert String.length(state1) >= 24
      assert state1 != state2
    end
  end

  describe "authorize_url/2" do
    test "builds authorization URL with encoded params for google" do
      state = "random_state_xyz"
      {:ok, url} = OAuth.authorize_url("google", state)

      assert url =~ "https://accounts.google.com/o/oauth2/v2/auth"
      assert url =~ "client_id=google_client_123"
      assert url =~ "state=random_state_xyz"
      assert url =~ "response_type=code"
    end

    test "returns error for unconfigured provider" do
      Application.put_env(:forge_nexus, :oauth, [])
      assert OAuth.authorize_url("google", "st") == {:error, :provider_not_configured}
    end

    test "returns error for invalid provider" do
      assert OAuth.authorize_url("facebook", "st") == {:error, :invalid_provider}
    end
  end

  describe "exchange_code/2" do
    test "exchanges code for access and refresh tokens" do
      Req.Test.stub(ForgeNexus.OAuth, fn conn ->
        Req.Test.json(conn, %{
          "access_token" => "gho_test_token_123",
          "refresh_token" => "ghr_refresh_456"
        })
      end)

      assert {:ok, tokens} = OAuth.exchange_code("github", "test_code_abc")
      assert tokens.access_token == "gho_test_token_123"
      assert tokens.refresh_token == "ghr_refresh_456"
    end

    test "handles error returned by provider in JSON response" do
      Req.Test.stub(ForgeNexus.OAuth, fn conn ->
        Req.Test.json(conn, %{
          "error" => "bad_verification_code",
          "error_description" => "The code passed is incorrect or expired."
        })
      end)

      assert {:error, msg} = OAuth.exchange_code("github", "expired_code")
      assert msg == "The code passed is incorrect or expired."
    end

    test "handles generic error string when error_description is omitted" do
      Req.Test.stub(ForgeNexus.OAuth, fn conn ->
        Req.Test.json(conn, %{
          "error" => "invalid_grant"
        })
      end)

      assert {:error, msg} = OAuth.exchange_code("google", "bad_code")
      assert msg == "invalid_grant"
    end

    test "handles HTTP failure gracefully" do
      Req.Test.stub(ForgeNexus.OAuth, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, msg} = OAuth.exchange_code("google", "code")
      assert msg =~ "HTTP error"
    end
  end

  describe "get_user_info/2" do
    test "normalizes google user profile" do
      Req.Test.stub(ForgeNexus.OAuth, fn conn ->
        Req.Test.json(conn, %{
          "id" => "10987654321",
          "email" => "googleuser@example.com",
          "name" => "Google User",
          "picture" => "https://lh3.googleusercontent.com/avatar.jpg"
        })
      end)

      assert {:ok, profile} = OAuth.get_user_info("google", "tok_google")
      assert profile.email == "googleuser@example.com"
      assert profile.name == "Google User"
      assert profile.avatar_url == "https://lh3.googleusercontent.com/avatar.jpg"
      assert profile.provider_uid == "10987654321"
    end

    test "normalizes discord user profile with custom avatar" do
      Req.Test.stub(ForgeNexus.OAuth, fn conn ->
        Req.Test.json(conn, %{
          "id" => "20987654321",
          "email" => "discorduser@example.com",
          "username" => "discord_nick",
          "global_name" => "Discord Display",
          "avatar" => "a_123456789"
        })
      end)

      assert {:ok, profile} = OAuth.get_user_info("discord", "tok_discord")
      assert profile.email == "discorduser@example.com"
      assert profile.name == "Discord Display"

      assert profile.avatar_url =~
               "https://cdn.discordapp.com/avatars/20987654321/a_123456789.png"

      assert profile.provider_uid == "20987654321"
    end

    test "normalizes discord user profile without avatar" do
      Req.Test.stub(ForgeNexus.OAuth, fn conn ->
        Req.Test.json(conn, %{
          "id" => "30987654321",
          "email" => "noavatar@example.com",
          "username" => "plain_user",
          "global_name" => nil,
          "avatar" => nil
        })
      end)

      assert {:ok, profile} = OAuth.get_user_info("discord", "tok_discord")
      assert profile.avatar_url == nil
      assert profile.name == "plain_user"
    end

    test "normalizes github user profile and verifies user-agent" do
      Req.Test.stub(ForgeNexus.OAuth, fn conn ->
        [ua] = Plug.Conn.get_req_header(conn, "user-agent")
        assert ua == "ForgeNexus"

        Req.Test.json(conn, %{
          "id" => 40_987_654,
          "email" => "octocat@github.com",
          "login" => "octocat",
          "name" => "The Octocat",
          "avatar_url" => "https://avatars.githubusercontent.com/u/40987654"
        })
      end)

      assert {:ok, profile} = OAuth.get_user_info("github", "tok_github")
      assert profile.email == "octocat@github.com"
      assert profile.name == "The Octocat"
      assert profile.provider_uid == "40987654"
    end

    test "returns error when provider returns 401 unauthorized" do
      Req.Test.stub(ForgeNexus.OAuth, fn conn ->
        Plug.Conn.send_resp(conn, 401, Jason.encode!(%{"error" => "invalid_token"}))
      end)

      assert {:error, msg} = OAuth.get_user_info("google", "expired_token")
      assert msg =~ "Provider returned 401"
    end

    test "handles network error on user info fetch" do
      Req.Test.stub(ForgeNexus.OAuth, fn conn ->
        Req.Test.transport_error(conn, :nxdomain)
      end)

      assert {:error, msg} = OAuth.get_user_info("github", "tok")
      assert msg =~ "HTTP error"
    end
  end

  describe "get_github_email/1" do
    test "picks primary and verified email first" do
      Req.Test.stub(ForgeNexus.OAuth, fn conn ->
        Req.Test.json(conn, [
          %{"email" => "secondary@example.com", "primary" => false, "verified" => true},
          %{"email" => "primary@example.com", "primary" => true, "verified" => true},
          %{"email" => "unverified@example.com", "primary" => false, "verified" => false}
        ])
      end)

      assert {:ok, email} = OAuth.get_github_email("tok_gh")
      assert email == "primary@example.com"
    end

    test "falls back to verified non-primary email if no primary" do
      Req.Test.stub(ForgeNexus.OAuth, fn conn ->
        Req.Test.json(conn, [
          %{"email" => "unverified@example.com", "primary" => false, "verified" => false},
          %{"email" => "verified@example.com", "primary" => false, "verified" => true}
        ])
      end)

      assert {:ok, email} = OAuth.get_github_email("tok_gh")
      assert email == "verified@example.com"
    end

    test "falls back to first email if none verified" do
      Req.Test.stub(ForgeNexus.OAuth, fn conn ->
        Req.Test.json(conn, [
          %{"email" => "fallback@example.com", "primary" => false, "verified" => false}
        ])
      end)

      assert {:ok, email} = OAuth.get_github_email("tok_gh")
      assert email == "fallback@example.com"
    end

    test "returns nil when response is not a list or fails" do
      Req.Test.stub(ForgeNexus.OAuth, fn conn ->
        Plug.Conn.send_resp(conn, 500, "Error")
      end)

      assert {:ok, nil} = OAuth.get_github_email("tok_gh")
    end
  end
end
