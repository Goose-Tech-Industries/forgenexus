defmodule ForgeNexus.TOTP do
  @moduledoc "TOTP (Time-based One-Time Password) implementation using :crypto."
  import Bitwise

  @digits 6
  @period 30

  def generate_secret do
    :crypto.strong_rand_bytes(20) |> Base.encode32(padding: false)
  end

  def generate_backup_codes(count \\ 8) do
    Enum.map(1..count, fn _ ->
      :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    end)
  end

  def provisioning_uri(secret, username, issuer \\ "ForgeNexus") do
    "otpauth://totp/#{URI.encode(issuer)}:#{URI.encode(username)}?secret=#{secret}&issuer=#{URI.encode(issuer)}&digits=#{@digits}&period=#{@period}"
  end

  def valid?(secret, code) do
    time_step = div(System.os_time(:second), @period)
    # Check current and adjacent time steps (clock skew tolerance)
    Enum.any?(-1..1, fn offset ->
      generate_code(secret, time_step + offset) == String.pad_leading(code, @digits, "0")
    end)
  end

  defp generate_code(secret, time_step) do
    key = Base.decode32!(secret, padding: false)
    msg = <<time_step::unsigned-big-integer-size(64)>>
    hmac = :crypto.mac(:hmac, :sha, key, msg)
    offset = :binary.at(hmac, byte_size(hmac) - 1) &&& 0x0F
    <<_::binary-size(offset), code::unsigned-big-integer-size(32), _::binary>> = hmac
    truncated = (code &&& 0x7FFFFFFF) |> rem(round(:math.pow(10, @digits)))
    truncated |> Integer.to_string() |> String.pad_leading(@digits, "0")
  end
end
