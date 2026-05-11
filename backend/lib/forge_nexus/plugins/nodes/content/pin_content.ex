defmodule ForgeNexus.Plugins.Nodes.Content.PinContent do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    target_type = Map.get(inputs, :target_type) || Map.get(inputs, "target_type", "thread")
    target_id = Map.get(inputs, :target_id) || Map.get(inputs, "target_id")

    case ForgeNexus.Forums.pin_target(target_type, target_id) do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to pin: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "content/pin_content",
      category: "content",
      label: "Pin Content",
      description: "Pins a thread or message to the top of its container.",
      inputs: [
        %{name: "target_type", type: "string", required: true},
        %{name: "target_id", type: "string", required: true}
      ],
      outputs: [%{name: "success", type: "boolean"}],
      config_fields: []
    }
  end
end
