defmodule ForgeNexus.Plugins.Nodes.Moderation.IpBan do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    ip_address = Map.get(inputs, :ip_address) || Map.get(inputs, "ip_address")
    reason = Map.get(inputs, :reason) || Map.get(inputs, "reason", "")
    duration_hours = Map.get(config, "duration_hours", 0) |> to_int()

    case ForgeNexus.Moderation.ban_ip(ip_address, reason, duration_hours) do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to ban IP: #{inspect(err)}", ctx}
    end
  end

  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_float(v), do: trunc(v)

  defp to_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      _ -> 0
    end
  end

  defp to_int(_), do: 0

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "moderation/ip_ban",
      category: "moderation",
      label: "IP Ban",
      description: "Bans an IP address for a specified duration (0 = permanent).",
      inputs: [
        %{name: "ip_address", type: "string", required: true},
        %{name: "reason", type: "string", required: false}
      ],
      outputs: [%{name: "success", type: "boolean"}],
      config_fields: [
        %{name: "duration_hours", type: "number", default: 0, description: "Ban duration in hours (0 = permanent)"}
      ]
    }
  end
end
