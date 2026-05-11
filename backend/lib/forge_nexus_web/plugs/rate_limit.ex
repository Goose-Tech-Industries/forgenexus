defmodule ForgeNexusWeb.Plugs.RateLimit do
  @moduledoc """
  ETS-based sliding window rate limiter.
  No external dependencies — uses :ets for O(1) lookups.

  Usage in router:
    plug RateLimit, max: 5, window: 60_000, by: :ip    # 5 req/min by IP
    plug RateLimit, max: 60, window: 60_000, by: :user  # 60 req/min by user
  """
  import Plug.Conn
  require Logger

  @table :forge_nexus_rate_limits

  def init(opts) do
    # Ensure ETS table exists
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:set, :public, :named_table, read_concurrency: true, write_concurrency: true])
    end

    %{
      max: Keyword.get(opts, :max, 60),
      window: Keyword.get(opts, :window, 60_000),
      by: Keyword.get(opts, :by, :ip),
      scope: Keyword.get(opts, :scope, "global")
    }
  end

  def call(conn, %{max: max, window: window, by: by, scope: scope}) do
    if bypass?(conn) do
      conn
      |> put_resp_header("x-ratelimit-limit", to_string(max))
      |> put_resp_header("x-ratelimit-remaining", to_string(max))
      |> put_resp_header("x-ratelimit-reset", to_string(div(window, 1000)))
    else
      do_call(conn, max, window, by, scope)
    end
  end

  # Optional env-driven bypass for automated test suites.
  # Set FN_RATE_LIMIT_BYPASS_TOKEN=<random> and have the test client send
  # that value in the `x-fn-ratelimit-bypass` header. No token = no bypass.
  defp bypass?(conn) do
    expected = System.get_env("FN_RATE_LIMIT_BYPASS_TOKEN")

    case {expected, get_req_header(conn, "x-fn-ratelimit-bypass")} do
      {nil, _} -> false
      {"", _} -> false
      {token, [header_val | _]} -> Plug.Crypto.secure_compare(token, header_val)
      _ -> false
    end
  end

  defp do_call(conn, max, window, by, scope) do
    key = build_key(conn, by, scope)
    now = System.monotonic_time(:millisecond)

    case check_rate(key, now, max, window) do
      {:allow, count} ->
        conn
        |> put_resp_header("x-ratelimit-limit", to_string(max))
        |> put_resp_header("x-ratelimit-remaining", to_string(max(max - count, 0)))
        |> put_resp_header("x-ratelimit-reset", to_string(div(window, 1000)))

      {:deny, retry_after_ms} ->
        retry_after = max(div(retry_after_ms, 1000), 1)

        conn
        |> put_resp_header("x-ratelimit-limit", to_string(max))
        |> put_resp_header("x-ratelimit-remaining", "0")
        |> put_resp_header("retry-after", to_string(retry_after))
        |> put_resp_content_type()
        |> send_resp(429, Jason.encode!(%{error: "Too many requests", retry_after: retry_after}))
        |> halt()
    end
  end

  defp build_key(conn, :ip, scope) do
    ip =
      case get_req_header(conn, "x-forwarded-for") do
        [forwarded | _] -> forwarded |> String.split(",") |> List.first() |> String.trim()
        _ -> conn.remote_ip |> :inet.ntoa() |> to_string()
      end

    "rate:#{scope}:ip:#{ip}"
  end

  defp build_key(conn, :user, scope) do
    case Guardian.Plug.current_resource(conn) do
      %{id: user_id} -> "rate:#{scope}:user:#{user_id}"
      _ -> build_key(conn, :ip, scope)
    end
  end

  defp check_rate(key, now, max, window) do
    window_start = now - window

    case :ets.lookup(@table, key) do
      [{^key, timestamps}] ->
        # Filter to only timestamps within the window
        recent = Enum.filter(timestamps, &(&1 > window_start))
        count = length(recent)

        if count < max do
          :ets.insert(@table, {key, [now | recent]})
          {:allow, count + 1}
        else
          oldest_in_window = Enum.min(recent)
          retry_after = oldest_in_window + window - now
          {:deny, retry_after}
        end

      [] ->
        :ets.insert(@table, {key, [now]})
        {:allow, 1}
    end
  end

  defp put_resp_content_type(conn) do
    put_resp_header(conn, "content-type", "application/json; charset=utf-8")
  end

  # Periodic cleanup — call from a scheduled job or GenServer
  def cleanup_expired(window \\ 120_000) do
    cutoff = System.monotonic_time(:millisecond) - window

    :ets.foldl(
      fn {key, timestamps}, acc ->
        recent = Enum.filter(timestamps, &(&1 > cutoff))
        if recent == [], do: :ets.delete(@table, key), else: :ets.insert(@table, {key, recent})
        acc
      end,
      :ok,
      @table
    )
  rescue
    _ -> :ok
  end
end
