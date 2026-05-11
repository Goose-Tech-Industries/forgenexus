defmodule ForgeNexus.Plugins.Nodes.Logic.Delay do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @max_seconds 10

  @impl true
  def execute(config, inputs, ctx) do
    seconds = min(Map.get(config, "seconds", 1), @max_seconds)

    Sandbox.check_timeout!(ctx)
    Process.sleep(seconds * 1000)
    Sandbox.check_timeout!(ctx)

    {:ok, inputs, ctx}
  end

  @impl true
  def validate_config(config) do
    seconds = Map.get(config, "seconds", 1)

    cond do
      not is_number(seconds) -> {:error, ["seconds must be a number"]}
      seconds < 0 -> {:error, ["seconds must be non-negative"]}
      seconds > @max_seconds -> {:error, ["seconds cannot exceed #{@max_seconds}"]}
      true -> :ok
    end
  end

  @impl true
  def schema do
    %{
      type: "logic/delay",
      category: "logic",
      label: "Delay",
      description: "Pauses execution for a number of seconds (max 10).",
      inputs: [%{name: "input", type: "any", required: false}],
      outputs: [%{name: "output", type: "any"}],
      config_fields: [
        %{name: "seconds", type: "number", default: 1, description: "Seconds to delay (max 10)"}
      ]
    }
  end
end
