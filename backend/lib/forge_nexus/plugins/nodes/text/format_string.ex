defmodule ForgeNexus.Plugins.Nodes.Text.FormatString do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, inputs, ctx) do
    template = Map.get(config, "template", "")

    result =
      Enum.reduce(inputs, template, fn {key, value}, acc ->
        String.replace(acc, "{{#{key}}}", to_string(value))
      end)

    {:ok, %{result: result}, ctx}
  end

  @impl true
  def validate_config(config) do
    if Map.has_key?(config, "template"), do: :ok, else: {:error, ["template is required"]}
  end

  @impl true
  def schema do
    %{
      type: "text/format_string",
      category: "text",
      label: "Format String",
      description: "Replaces {{var}} placeholders in a template with input values. No code eval.",
      inputs: [%{name: "data", type: "map", required: true}],
      outputs: [%{name: "result", type: "string"}],
      config_fields: [
        %{
          name: "template",
          type: "text",
          default: "",
          description: "Template string with {{var}} placeholders"
        }
      ]
    }
  end
end
