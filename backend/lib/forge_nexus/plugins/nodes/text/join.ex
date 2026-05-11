defmodule ForgeNexus.Plugins.Nodes.Text.Join do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, inputs, ctx) do
    delimiter = Map.get(config, "delimiter", ",")
    parts = Map.get(inputs, :parts) || Map.get(inputs, "parts", [])

    result =
      parts
      |> Enum.map(&to_string/1)
      |> Enum.join(delimiter)

    {:ok, %{result: result}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "text/join",
      category: "text",
      label: "Join",
      description: "Joins a list of strings with a delimiter.",
      inputs: [%{name: "parts", type: "list", required: true}],
      outputs: [%{name: "result", type: "string"}],
      config_fields: [
        %{name: "delimiter", type: "string", default: ",", description: "Delimiter to join with"}
      ]
    }
  end
end
