defmodule ForgeNexusWeb.Plugs.ClampPagination do
  @moduledoc """
  Clamps common pagination query params (offset, page, limit) so adversarial
  or buggy clients can't crash list endpoints. Postgres rejects negative
  OFFSET; many controllers parse params directly into Ecto queries without
  bounds checks, so we normalize at the edge.
  """
  @behaviour Plug

  @clamps %{
    "offset" => {0, 1_000_000},
    "limit" => {1, 200},
    "page" => {1, 1_000_000},
    "days" => {1, 3650}
  }

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    params =
      Enum.reduce(@clamps, conn.params, fn {key, {min, max}}, acc ->
        case Map.get(acc, key) do
          nil ->
            acc

          value ->
            case parse_int(value) do
              nil -> acc
              n -> Map.put(acc, key, clamp(n, min, max) |> Integer.to_string())
            end
        end
      end)

    query_params =
      Enum.reduce(@clamps, conn.query_params, fn {key, {min, max}}, acc ->
        case Map.get(acc, key) do
          nil ->
            acc

          value ->
            case parse_int(value) do
              nil -> acc
              n -> Map.put(acc, key, clamp(n, min, max) |> Integer.to_string())
            end
        end
      end)

    %{conn | params: params, query_params: query_params}
  end

  defp parse_int(v) when is_integer(v), do: v

  defp parse_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_int(_), do: nil

  defp clamp(n, lo, hi) do
    n
    |> Kernel.max(lo)
    |> Kernel.min(hi)
  end
end
