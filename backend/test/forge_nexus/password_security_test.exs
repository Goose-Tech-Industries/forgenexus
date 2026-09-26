defmodule ForgeNexus.PasswordSecurityTest do
  use ExUnit.Case, async: false

  alias ForgeNexus.PasswordSecurity

  setup do
    Req.default_options(plug: {Req.Test, ForgeNexus.PasswordSecurity}, retry: false)

    on_exit(fn ->
      Req.default_options([])
    end)

    :ok
  end

  describe "check/1" do
    test "detects pwned password when suffix matches" do
      # Let password be "password123"
      # SHA1("password123") = CBFDAC6008F9CAB4083784CBD1874F76618D2A97
      # prefix: CBFDA, suffix: C6008F9CAB4083784CBD1874F76618D2A97
      <<prefix::binary-size(5), suffix::binary>> =
        :crypto.hash(:sha, "password123") |> Base.encode16(case: :upper)

      body =
        "00112233445566778899AABBCCDDEEFF00112233:10\r\n#{suffix}:45678\r\nFFEEDDCCBBAA99887766554433221100FFEEDDCC:5\r\n"

      Req.Test.stub(ForgeNexus.PasswordSecurity, fn conn ->
        assert conn.request_path == "/range/" <> prefix
        Plug.Conn.send_resp(conn, 200, body)
      end)

      assert PasswordSecurity.check("password123") == {:pwned, 45678}
    end

    test "handles malformed count string on match gracefully" do
      <<prefix::binary-size(5), suffix::binary>> =
        :crypto.hash(:sha, "weirdpass") |> Base.encode16(case: :upper)

      body = "#{suffix}:not_a_number\r\n"

      Req.Test.stub(ForgeNexus.PasswordSecurity, fn conn ->
        assert conn.request_path == "/range/" <> prefix
        Plug.Conn.send_resp(conn, 200, body)
      end)

      assert PasswordSecurity.check("weirdpass") == {:pwned, 0}
    end

    test "returns :ok when password hash is not in returned range" do
      <<prefix::binary-size(5), _suffix::binary>> =
        :crypto.hash(:sha, "super_secure_unpwned_pass_9999") |> Base.encode16(case: :upper)

      body = """
      0000000000000000000000000000000000000000:1
      1111111111111111111111111111111111111111:2
      """

      Req.Test.stub(ForgeNexus.PasswordSecurity, fn conn ->
        assert conn.request_path == "/range/" <> prefix
        Plug.Conn.send_resp(conn, 200, body)
      end)

      assert PasswordSecurity.check("super_secure_unpwned_pass_9999") == :ok
    end

    test "fails open with :ok when HIBP returns non-200 status" do
      Req.Test.stub(ForgeNexus.PasswordSecurity, fn conn ->
        Plug.Conn.send_resp(conn, 503, "Service Unavailable")
      end)

      assert PasswordSecurity.check("anypassword") == :ok
    end

    test "fails open with :ok when HTTP transport error occurs" do
      Req.Test.stub(ForgeNexus.PasswordSecurity, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert PasswordSecurity.check("anypassword") == :ok
    end
  end
end
