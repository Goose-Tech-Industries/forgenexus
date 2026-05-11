defmodule ForgeNexusWeb.AdminLoginEventController do
  @moduledoc "Admin view of login attempts for security auditing."
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Accounts

  def index(conn, params) do
    opts = [
      user_id: Map.get(params, "user_id"),
      email: Map.get(params, "email"),
      ip_address: Map.get(params, "ip"),
      success: parse_bool(Map.get(params, "success")),
      since: parse_since(Map.get(params, "since")),
      limit: parse_int(Map.get(params, "limit"), 100)
    ]

    events = Accounts.list_login_events(opts)
    conn |> json(%{events: Enum.map(events, &event_json/1)})
  end

  defp event_json(e) do
    %{
      id: e.id,
      email: e.email,
      ip_address: e.ip_address,
      user_agent: e.user_agent,
      success: e.success,
      failure_reason: e.failure_reason,
      user_id: e.user_id,
      username: e.user && e.user.username,
      occurred_at: e.occurred_at,
      inserted_at: e.inserted_at
    }
  end

  defp parse_bool("true"), do: true
  defp parse_bool("false"), do: false
  defp parse_bool(_), do: nil

  defp parse_since(nil), do: nil
  defp parse_since(""), do: nil

  defp parse_since(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ ->
        case Integer.parse(str) do
          {hours, _} when hours > 0 ->
            DateTime.utc_now() |> DateTime.add(-hours * 3600, :second)

          _ ->
            nil
        end
    end
  end

  defp parse_int(nil, default), do: default

  defp parse_int(str, default) when is_binary(str) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_int(_, default), do: default
end
