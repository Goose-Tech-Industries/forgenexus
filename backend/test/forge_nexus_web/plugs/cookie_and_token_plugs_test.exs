defmodule ForgeNexusWeb.Plugs.CookieAndTokenPlugsTest do
  use ForgeNexusWeb.ConnCase, async: false

  alias ForgeNexus.Accounts
  alias ForgeNexus.Platform.ApiKey

  alias ForgeNexusWeb.Plugs.{
    ApiKeyAuth,
    AuthCookie,
    AuthErrorHandler,
    AuthPipeline,
    RateLimit,
    VerifyCookie,
    VerifyTokenCookie
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

  setup %{conn: conn} do
    {:ok, conn: Plug.Conn.fetch_cookies(conn)}
  end

  defp create_api_key(user, attrs) do
    {raw_key, prefix, hash} = ApiKey.generate_key()

    default_attrs = %{
      name: "Test API Key",
      key_prefix: prefix,
      key_hash: hash,
      user_id: user.id,
      scopes: ["read"],
      is_active: true
    }

    {:ok, key} =
      %ApiKey{}
      |> ApiKey.changeset(Map.merge(default_attrs, attrs))
      |> ForgeNexus.Repo.insert()

    {raw_key, key}
  end

  # =========================================================================
  # ApiKeyAuth
  # =========================================================================
  describe "ApiKeyAuth plug" do
    test "init/1 returns options unchanged" do
      assert ApiKeyAuth.init(scope: "write") == [scope: "write"]
    end

    test "allows request through unchanged when x-api-key header is absent", %{conn: conn} do
      conn = ApiKeyAuth.call(conn, [])
      refute conn.halted
      assert conn.status == nil
      assert conn.assigns[:api_key] == nil
    end

    test "halts with 401 when API key is not found in database", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-api-key", "fnx_invalid_key_value_1234567890")
        |> ApiKeyAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body) == %{"error" => "Invalid API key"}
    end

    test "halts with 401 when API key is inactive", %{conn: conn} do
      user = create_user()
      {raw_key, _key} = create_api_key(user, %{is_active: false})

      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> ApiKeyAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body) == %{"error" => "Invalid API key"}
    end

    test "halts with 401 when API key has expired", %{conn: conn} do
      user = create_user()
      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)
      {raw_key, _key} = create_api_key(user, %{expires_at: past})

      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> ApiKeyAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body) == %{"error" => "API key expired"}
    end

    test "halts with 403 when API key does not have the required scope", %{conn: conn} do
      user = create_user()
      {raw_key, _key} = create_api_key(user, %{scopes: ["read"]})

      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> ApiKeyAuth.call(scope: "admin")

      assert conn.halted
      assert conn.status == 403
      assert Jason.decode!(conn.resp_body) == %{"error" => "Insufficient scope"}
    end

    test "authenticates request, updates total_requests, and assigns api_key details", %{
      conn: conn
    } do
      user = create_user()
      {raw_key, key} = create_api_key(user, %{scopes: ["read", "write"]})

      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> ApiKeyAuth.call(scope: "write")

      refute conn.halted
      assert conn.assigns[:api_key].id == key.id
      assert conn.assigns[:api_key_user_id] == user.id

      updated_key = ForgeNexus.Repo.get!(ApiKey, key.id)
      assert updated_key.total_requests == 1
      assert updated_key.last_used_at != nil
    end
  end

  # =========================================================================
  # RateLimit
  # =========================================================================
  describe "RateLimit plug" do
    setup do
      # Clear the table before each rate limit test to prevent cross-test interference
      if :ets.whereis(:forge_nexus_rate_limits) != :undefined do
        :ets.delete_all_objects(:forge_nexus_rate_limits)
      end

      :ok
    end

    test "init/1 configures max, window, by, and scope with defaults" do
      opts = RateLimit.init([])
      assert opts.max == 60
      assert opts.window == 60_000
      assert opts.by == :ip
      assert opts.scope == "global"
    end

    test "allows requests under max limit and sets ratelimit headers", %{conn: conn} do
      opts = RateLimit.init(max: 5, window: 60_000, scope: "test_allow")

      conn = RateLimit.call(conn, opts)

      refute conn.halted
      assert get_resp_header(conn, "x-ratelimit-limit") == ["5"]
      assert get_resp_header(conn, "x-ratelimit-remaining") == ["4"]
      assert get_resp_header(conn, "x-ratelimit-reset") == ["60"]
    end

    test "denies request and returns 429 when max limit is exceeded", %{conn: conn} do
      opts = RateLimit.init(max: 2, window: 60_000, scope: "test_deny")

      conn1 = RateLimit.call(conn, opts)
      refute conn1.halted

      conn2 = RateLimit.call(conn, opts)
      refute conn2.halted

      conn3 = RateLimit.call(conn, opts)
      assert conn3.halted
      assert conn3.status == 429
      assert get_resp_header(conn3, "x-ratelimit-remaining") == ["0"]
      assert get_resp_header(conn3, "retry-after") != []

      body = Jason.decode!(conn3.resp_body)
      assert body["error"] == "Too many requests"
      assert is_integer(body["retry_after"])
    end

    test "uses x-forwarded-for header when present", %{conn: conn} do
      opts = RateLimit.init(max: 1, window: 60_000, scope: "test_forwarded")

      conn_client1 =
        conn
        |> put_req_header("x-forwarded-for", "203.0.113.195, 70.41.3.18")
        |> RateLimit.call(opts)

      refute conn_client1.halted

      conn_client2 =
        conn
        |> put_req_header("x-forwarded-for", "198.51.100.44")
        |> RateLimit.call(opts)

      refute conn_client2.halted
    end

    test "uses authenticated user id when by: :user is specified", %{conn: conn} do
      user = create_user()
      opts = RateLimit.init(max: 1, window: 60_000, by: :user, scope: "test_user")

      conn =
        conn
        |> Guardian.Plug.put_current_resource(user)
        |> RateLimit.call(opts)

      refute conn.halted
      assert get_resp_header(conn, "x-ratelimit-remaining") == ["0"]
    end

    test "bypasses rate limit when FN_RATE_LIMIT_BYPASS_TOKEN matches header", %{conn: conn} do
      System.put_env("FN_RATE_LIMIT_BYPASS_TOKEN", "secret-test-bypass-key")
      opts = RateLimit.init(max: 1, window: 60_000, scope: "test_bypass")

      try do
        conn =
          conn
          |> put_req_header("x-fn-ratelimit-bypass", "secret-test-bypass-key")
          |> RateLimit.call(opts)

        refute conn.halted
        assert get_resp_header(conn, "x-ratelimit-limit") == ["1"]
        assert get_resp_header(conn, "x-ratelimit-remaining") == ["1"]
      after
        System.delete_env("FN_RATE_LIMIT_BYPASS_TOKEN")
      end
    end

    test "cleanup_expired/1 clears old entries from ETS table" do
      stale_ts = System.monotonic_time(:millisecond) - 200_000
      :ets.insert(:forge_nexus_rate_limits, {"test_key_stale", [stale_ts]})
      assert :ets.lookup(:forge_nexus_rate_limits, "test_key_stale") != []

      assert RateLimit.cleanup_expired(1_000) == :ok
      assert :ets.lookup(:forge_nexus_rate_limits, "test_key_stale") == []
    end
  end

  # =========================================================================
  # AuthErrorHandler
  # =========================================================================
  describe "AuthErrorHandler plug" do
    test "auth_error/3 formats error as JSON and returns 401 status", %{conn: conn} do
      conn = AuthErrorHandler.auth_error(conn, {:invalid_token, "Signature invalid"}, [])

      assert conn.status == 401
      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
      assert Jason.decode!(conn.resp_body) == %{"error" => "invalid_token"}
    end
  end

  # =========================================================================
  # AuthCookie
  # =========================================================================
  describe "AuthCookie helper module" do
    test "set_cookie/2 sets fn_token cookie on conn", %{conn: conn} do
      conn = AuthCookie.set_cookie(conn, "test-access-token")
      assert conn.resp_cookies["fn_token"].value == "test-access-token"
      assert conn.resp_cookies["fn_token"].http_only == true
      assert conn.resp_cookies["fn_token"].max_age == 86_400
      assert conn.resp_cookies["fn_token"].path == "/"
    end

    test "set_refresh_cookie/2 sets fn_refresh cookie on conn", %{conn: conn} do
      conn = AuthCookie.set_refresh_cookie(conn, "test-refresh-token")
      assert conn.resp_cookies["fn_refresh"].value == "test-refresh-token"
      assert conn.resp_cookies["fn_refresh"].http_only == true
      assert conn.resp_cookies["fn_refresh"].max_age == 2_592_000
      assert conn.resp_cookies["fn_refresh"].path == "/api/auth"
    end

    test "set_both/3 sets both access and refresh cookies", %{conn: conn} do
      conn = AuthCookie.set_both(conn, "acc-token", "ref-token")
      assert conn.resp_cookies["fn_token"].value == "acc-token"
      assert conn.resp_cookies["fn_refresh"].value == "ref-token"
    end

    test "get_refresh_token/1 retrieves fn_refresh from conn.cookies", %{conn: conn} do
      conn = %{conn | cookies: %{"fn_refresh" => "my_refresh_cookie"}}
      assert AuthCookie.get_refresh_token(conn) == "my_refresh_cookie"
    end

    test "clear_cookie/1 deletes both access and refresh cookies", %{conn: conn} do
      conn = AuthCookie.clear_cookie(conn)
      assert conn.resp_cookies["fn_token"].max_age == 0
      assert conn.resp_cookies["fn_refresh"].max_age == 0
    end

    test "refresh_cookie_name/0 returns cookie name constant" do
      assert AuthCookie.refresh_cookie_name() == "fn_refresh"
    end
  end

  # =========================================================================
  # VerifyCookie
  # =========================================================================
  describe "VerifyCookie plug" do
    test "init/1 returns options unchanged" do
      assert VerifyCookie.init([]) == []
    end

    test "skips verification if Guardian current_resource is already loaded", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> Guardian.Plug.put_current_resource(user)
        |> VerifyCookie.call([])

      assert Guardian.Plug.current_resource(conn) == user
    end

    test "returns unchanged conn when no cookie is present", %{conn: conn} do
      conn = VerifyCookie.call(conn, [])
      assert Guardian.Plug.current_resource(conn) == nil
    end

    test "verifies valid JWT token from cookie and populates resource", %{conn: conn} do
      user = create_user()
      {:ok, token, _claims} = ForgeNexus.Guardian.encode_and_sign(user)

      conn = %{conn | cookies: %{"fn_token" => token}}
      conn = VerifyCookie.call(conn, [])

      loaded_user = Guardian.Plug.current_resource(conn)
      assert loaded_user != nil
      assert loaded_user.id == user.id
    end

    test "handles malformed or invalid token from cookie without crashing", %{conn: conn} do
      conn = %{conn | cookies: %{"fn_token" => "completely_invalid_jwt_token"}}
      conn = VerifyCookie.call(conn, [])

      assert Guardian.Plug.current_resource(conn) == nil
    end
  end

  # =========================================================================
  # VerifyTokenCookie
  # =========================================================================
  describe "VerifyTokenCookie plug" do
    test "init/1 returns options unchanged" do
      assert VerifyTokenCookie.init(abc: 1) == [abc: 1]
    end

    test "skips when current_resource is already set", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> Guardian.Plug.put_current_resource(user)
        |> VerifyTokenCookie.call([])

      assert Guardian.Plug.current_resource(conn) == user
    end

    test "skips when cookie is empty or missing", %{conn: conn} do
      conn1 = VerifyTokenCookie.call(conn, [])
      assert Guardian.Plug.current_resource(conn1) == nil

      conn2 = %{conn | cookies: %{"fn_token" => ""}}
      conn2 = VerifyTokenCookie.call(conn2, [])
      assert Guardian.Plug.current_resource(conn2) == nil
    end

    test "authenticates user from fn_token in req_cookies", %{conn: conn} do
      user = create_user()
      {:ok, token, _claims} = ForgeNexus.Guardian.encode_and_sign(user)

      conn = %{conn | req_cookies: %{"fn_token" => token}}
      conn = VerifyTokenCookie.call(conn, [])

      loaded = Guardian.Plug.current_resource(conn)
      assert loaded != nil
      assert loaded.id == user.id
    end

    test "handles unknown token gracefully", %{conn: conn} do
      conn = %{conn | req_cookies: %{"fn_token" => "bogus-jwt-payload"}}
      conn = VerifyTokenCookie.call(conn, [])

      assert Guardian.Plug.current_resource(conn) == nil
    end
  end

  # =========================================================================
  # AuthPipeline
  # =========================================================================
  describe "AuthPipeline plug" do
    test "executes pipeline on unauthenticated conn without error", %{conn: conn} do
      opts = AuthPipeline.init([])
      conn = AuthPipeline.call(conn, opts)

      assert Guardian.Plug.current_resource(conn) == nil
      refute conn.halted
    end

    test "authenticates user via Bearer header in pipeline", %{conn: conn} do
      user = create_user()
      {:ok, token, _claims} = ForgeNexus.Guardian.encode_and_sign(user)

      opts = AuthPipeline.init([])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> AuthPipeline.call(opts)

      loaded = Guardian.Plug.current_resource(conn)
      assert loaded != nil
      assert loaded.id == user.id
      refute conn.halted
    end
  end
end
