defmodule ForgeNexus.Plugins.Nodes.Text.Contains do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, inputs, ctx) do
    case_sensitive = Map.get(config, "case_sensitive", true)
    text = to_string(Map.get(inputs, :text) || Map.get(inputs, "text", ""))
    search = to_string(Map.get(inputs, :search) || Map.get(inputs, "search", ""))

    result =
      if case_sensitive do
        String.contains?(text, search)
      else
        String.contains?(String.downcase(text), String.downcase(search))
      end

    {:ok, %{result: result}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "text/contains",
      category: "text",
      label: "Contains",
      description: "Checks if text contains a search string.",
      inputs: [
        %{name: "text", type: "string", required: true},
        %{name: "search", type: "string", required: true}
      ],
      outputs: [%{name: "result", type: "boolean"}],
      config_fields: [
        %{
          name: "case_sensitive",
          type: "boolean",
          default: true,
          description: "Case-sensitive search"
        }
      ]
    }
  end
end
