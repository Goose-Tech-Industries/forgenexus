defmodule ForgeNexus.AntiSpamTest do
  use ExUnit.Case, async: false

  alias ForgeNexus.AntiSpam

  setup do
    Req.default_options(plug: {Req.Test, ForgeNexus.AntiSpam}, retry: false)
    on_exit(fn -> Req.default_options([]) end)
    :ok
  end

  describe "check_registration/3" do
    test "returns clean report when StopForumSpam reports not appearing" do
      Req.Test.stub(ForgeNexus.AntiSpam, fn conn ->
        assert conn.request_path == "/api"
        assert conn.query_string =~ "ip=1.2.3.4"
        assert conn.query_string =~ "email=innocent%40example.com"
        assert conn.query_string =~ "username=gooduser"

        Req.Test.json(conn, %{
          "ip" => %{"appears" => 0, "frequency" => 0, "confidence" => 0},
          "email" => %{"appears" => 0, "frequency" => 0, "confidence" => 0},
          "username" => %{"appears" => 0, "frequency" => 0, "confidence" => 0}
        })
      end)

      result = AntiSpam.check_registration("1.2.3.4", "innocent@example.com", "gooduser")

      assert result.ip == :clean
      assert result.email == :clean
      assert result.username == :clean
      assert result.score == 0
      refute AntiSpam.suspicious?(result)
    end

    test "identifies spammer when StopForumSpam returns appears=1 with high confidence" do
      Req.Test.stub(ForgeNexus.AntiSpam, fn conn ->
        Req.Test.json(conn, %{
          "ip" => %{"appears" => 1, "frequency" => 15, "confidence" => 90.0},
          "email" => %{"appears" => 1, "frequency" => 30, "confidence" => 95.0},
          "username" => %{"appears" => 1, "frequency" => 5, "confidence" => 80.0}
        })
      end)

      result = AntiSpam.check_registration("5.6.7.8", "spammer@evil.com", "badspammer")

      assert result.ip == :spam
      assert result.email == :spam
      assert result.username == :spam
      assert result.score > 50
      assert AntiSpam.suspicious?(result)
    end

    test "fails open when service returns error status or malformed body" do
      Req.Test.stub(ForgeNexus.AntiSpam, fn conn ->
        Plug.Conn.send_resp(conn, 500, "Internal Server Error")
      end)

      result = AntiSpam.check_registration("1.2.3.4", "user@example.com", "user")

      assert result == %{ip: :clean, email: :clean, username: :clean, score: 0}
      refute AntiSpam.suspicious?(result)
    end

    test "fails open when HTTP request raises exception" do
      Req.Test.stub(ForgeNexus.AntiSpam, fn _conn ->
        raise "network timeout"
      end)

      result = AntiSpam.check_registration("1.2.3.4", "user@example.com", "user")

      assert result == %{ip: :clean, email: :clean, username: :clean, score: 0}
      refute AntiSpam.suspicious?(result)
    end
  end

  describe "suspicious?/1" do
    test "evaluates score threshold of 50" do
      refute AntiSpam.suspicious?(%{score: 50})
      refute AntiSpam.suspicious?(%{score: 0})
      assert AntiSpam.suspicious?(%{score: 51})
      assert AntiSpam.suspicious?(%{score: 100})
    end
  end
end
