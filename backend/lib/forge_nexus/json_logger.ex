defmodule ForgeNexus.JSONLogger do
  @moduledoc """
  Structured JSON log formatter for production.
  Outputs one JSON object per log line for easy parsing by log aggregators.
  """

  def format(level, message, timestamp, metadata) do
    {date, {h, m, s, _ms}} = timestamp

    log = %{
      timestamp: format_timestamp(date, {h, m, s}),
      level: level,
      message: IO.chardata_to_string(message)
    }

    log =
      metadata
      |> Enum.reduce(log, fn
        {:request_id, val}, acc -> Map.put(acc, :request_id, val)
        {:user_id, val}, acc -> Map.put(acc, :user_id, val)
        {:remote_ip, val}, acc -> Map.put(acc, :remote_ip, to_string(val))
        _, acc -> acc
      end)

    [Jason.encode_to_iodata!(log), "\n"]
  rescue
    _ -> "#{inspect(timestamp)} [#{level}] #{message}\n"
  end

  defp format_timestamp({year, month, day}, {h, m, s}) do
    "#{year}-#{pad(month)}-#{pad(day)}T#{pad(h)}:#{pad(m)}:#{pad(s)}Z"
  end

  defp pad(int), do: int |> Integer.to_string() |> String.pad_leading(2, "0")
end
