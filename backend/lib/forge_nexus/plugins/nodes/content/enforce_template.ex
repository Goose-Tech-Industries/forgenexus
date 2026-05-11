defmodule ForgeNexus.Plugins.Nodes.Content.EnforceTemplate do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  require Logger

  @impl true
  def execute(config, inputs, ctx) do
    content = Map.get(inputs, :content) || Map.get(inputs, "content", "")
    required_sections_raw = Map.get(config, "required_sections", "")

    required_sections =
      required_sections_raw
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    content_lower = String.downcase(content)

    missing_sections =
      Enum.filter(required_sections, fn section ->
        !String.contains?(content_lower, String.downcase(section))
      end)

    Logger.info("[PluginFlow] content/enforce_template: required=#{length(required_sections)}, missing=#{length(missing_sections)}")

    if missing_sections == [] do
      {:branch, "valid", %{missing_sections: []}, ctx}
    else
      {:branch, "invalid", %{missing_sections: missing_sections}, ctx}
    end
  end

  @impl true
  def validate_config(config) do
    case Map.get(config, "required_sections") do
      nil -> {:error, ["required_sections is required"]}
      "" -> {:error, ["required_sections cannot be empty"]}
      _ -> :ok
    end
  end

  @impl true
  def schema do
    %{
      type: "content/enforce_template",
      category: "content",
      label: "Enforce Template",
      description: "Branches based on whether content contains all required sections.",
      inputs: [
        %{name: "content", type: "string", required: true}
      ],
      outputs: [
        %{name: "valid", type: "branch", fields: [%{name: "missing_sections", type: "list"}]},
        %{name: "invalid", type: "branch", fields: [%{name: "missing_sections", type: "list"}]}
      ],
      config_fields: [
        %{name: "required_sections", type: "string", default: "", description: "Comma-separated required section headers (e.g. \"Description,Steps to Reproduce,Expected Behavior\")"}
      ]
    }
  end
end
