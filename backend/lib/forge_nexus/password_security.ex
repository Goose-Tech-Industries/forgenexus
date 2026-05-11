defmodule ForgeNexus.PasswordSecurity do
  @moduledoc """
  Checks passwords against the HaveIBeenPwned Pwned Passwords database using the
  k-anonymity API. Only the first 5 chars of the SHA-1 hash ever leave the server;
  the full hash is compared locally against the returned range.

  Best-effort: if the HIBP API is unreachable or slow, we let the password through
  rather than blocking a user. Security hardening, not a hard gate.
  """
  require Logger

  @endpoint "https://api.pwnedpasswords.com/range/"
  @timeout_ms 1_500

  @doc """
  Returns `{:pwned, count}` if the password appears in a known breach,
  `:ok` if clean, `:ok` on API error (fail-open).
  """
  def check(password) when is_binary(password) do
    <<prefix::binary-size(5), rest::binary>> =
      :crypto.hash(:sha, password) |> Base.encode16(case: :upper)

    case Req.get(@endpoint <> prefix, receive_timeout: @timeout_ms, retry: false) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        find_match(body, rest)

      {:ok, %{status: status}} ->
        Logger.warning("HIBP returned status #{status} — allowing password")
        :ok

      {:error, reason} ->
        Logger.warning("HIBP unreachable (#{inspect(reason)}) — allowing password")
        :ok
    end
  end

  defp find_match(body, suffix) do
    body
    |> String.split("\r\n", trim: true)
    |> Enum.find_value(:ok, fn line ->
      case String.split(line, ":", parts: 2) do
        [hash_suffix, count_str] ->
          if hash_suffix == suffix do
            case Integer.parse(count_str) do
              {count, _} -> {:pwned, count}
              :error -> {:pwned, 0}
            end
          end

        _ ->
          nil
      end
    end)
  end
end
