defmodule ForgeNexus.Plugins.Nodes.Text.Split do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, inputs, ctx) do
    delimiter = Map.get(config, "delimiter", ",")
    text = to_string(Map.get(inputs, :text) || Map.get(inputs, "text", ""))

    parts = String.split(text, delimiter)

    {:ok, %{parts: parts}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "text/split",
      category: "text",
      label: "Split",
      description: "Splits text into a list by a delimiter.",
      inputs: [%{name: "text", type: "string", required: true}],
      outputs: [%{name: "parts", type: "list"}],
      config_fields: [
        %{name: "delimiter", type: "string", default: ",", description: "Delimiter to split on"}
      ]
    }
  end
end
