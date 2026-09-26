defmodule ForgeNexus.TelemetryAndInfraTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.TOTP
  alias ForgeNexus.JSONLogger
  alias ForgeNexus.Telemetry.SlowQueryLogger
  alias ForgeNexusWeb.Telemetry, as: WebTelemetry

  describe "ForgeNexus.TOTP" do
    test "generates base32 secret" do
      secret = TOTP.generate_secret()
      assert is_binary(secret)
      assert byte_size(secret) >= 32
      assert {:ok, _} = Base.decode32(secret, padding: false)
    end

    test "generates backup codes" do
      codes = TOTP.generate_backup_codes()
      assert length(codes) == 8
      assert Enum.all?(codes, fn c -> String.length(c) == 8 end)

      custom = TOTP.generate_backup_codes(4)
      assert length(custom) == 4
    end

    test "builds provisioning uri" do
      secret = TOTP.generate_secret()
      uri = TOTP.provisioning_uri(secret, "alice@example.com", "MyCommunity")

      assert uri =~ "otpauth://totp/MyCommunity:alice@example.com"
      assert uri =~ "secret=#{secret}"
      assert uri =~ "digits=6"
      assert uri =~ "period=30"
    end

    test "validates current time step code" do
      secret = TOTP.generate_secret()

      # Derive the code for the current time step using TOTP internals or period div
      period = 30
      time_step = div(System.os_time(:second), period)
      key = Base.decode32!(secret, padding: false)
      msg = <<time_step::unsigned-big-integer-size(64)>>
      hmac = :crypto.mac(:hmac, :sha, key, msg)
      import Bitwise
      offset = :binary.at(hmac, byte_size(hmac) - 1) &&& 0x0F
      <<_::binary-size(^offset), code_int::unsigned-big-integer-size(32), _::binary>> = hmac
      truncated = (code_int &&& 0x7FFFFFFF) |> rem(1_000_000)
      code = truncated |> Integer.to_string() |> String.pad_leading(6, "0")

      assert TOTP.valid?(secret, code)
      refute TOTP.valid?(secret, "999999")
      refute TOTP.valid?(secret, "000000")
    end
  end

  describe "ForgeNexus.JSONLogger" do
    test "formats log event to structured json" do
      timestamp = {{2026, 4, 15}, {12, 30, 45, 0}}
      metadata = [request_id: "req_abc", user_id: "usr_123", remote_ip: "127.0.0.1"]

      [json_iodata, "\n"] = JSONLogger.format(:info, "User logged in", timestamp, metadata)
      json_str = IO.iodata_to_binary(json_iodata)
      assert {:ok, parsed} = Jason.decode(json_str)

      assert parsed["timestamp"] == "2026-04-15T12:30:45Z"
      assert parsed["level"] == "info"
      assert parsed["message"] == "User logged in"
      assert parsed["request_id"] == "req_abc"
      assert parsed["user_id"] == "usr_123"
      assert parsed["remote_ip"] == "127.0.0.1"
    end

    test "rescues formatting errors gracefully" do
      # Pass an invalid timestamp structure to trigger rescue
      result = JSONLogger.format(:error, "Fatal failure", :invalid_timestamp, [])
      assert is_binary(result)
      assert result =~ "[error] Fatal failure"
    end
  end

  describe "ForgeNexus.Telemetry.SlowQueryLogger" do
    test "setup attaches handler without error" do
      assert SlowQueryLogger.setup() in [:ok, {:error, :already_exists}]
    end

    test "handles event above threshold with warning log and ignores below threshold" do
      # 500ms > threshold
      measurements_slow = %{
        total_time: System.convert_time_unit(500, :millisecond, :native),
        query_time: System.convert_time_unit(400, :millisecond, :native),
        queue_time: System.convert_time_unit(100, :millisecond, :native)
      }

      metadata = %{
        source: "users",
        query: "SELECT * FROM users",
        params: ["arg1"]
      }

      assert SlowQueryLogger.handle_event(
               [:forge_nexus, :repo, :query],
               measurements_slow,
               metadata,
               %{}
             ) == :ok

      # 1ms < threshold (ignored)
      measurements_fast = %{
        total_time: System.convert_time_unit(1, :millisecond, :native),
        query_time: System.convert_time_unit(1, :millisecond, :native),
        queue_time: 0
      }

      assert SlowQueryLogger.handle_event(
               [:forge_nexus, :repo, :query],
               measurements_fast,
               metadata,
               %{}
             ) == nil
    end

    test "rescues exceptions safely when metadata is malformed" do
      assert SlowQueryLogger.handle_event(
               [:forge_nexus, :repo, :query],
               %{total_time: 999_999_999},
               nil,
               %{}
             ) == :ok
    end
  end

  describe "ForgeNexusWeb.Telemetry" do
    test "metrics/0 returns valid telemetry metrics list" do
      metrics = WebTelemetry.metrics()
      assert is_list(metrics)
      assert length(metrics) > 0
    end
  end

  describe "ForgeNexus.Application" do
    test "config_change/3 forwards to Endpoint" do
      assert ForgeNexus.Application.config_change([], [], []) == :ok
    end
  end
end
