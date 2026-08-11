defmodule ForgeNexus.Plugins.Nodes.Automod.ContentLengthCheck do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, inputs, ctx) do
    content = Map.get(inputs, :content) || Map.get(inputs, "content", "")
    min_length = Map.get(config, "min_length", 0) |> to_number()
    max_length = Map.get(config, "max_length", 10_000) |> to_number()

    length = String.length(content)

    cond do
      length < min_length ->
        {:branch, "invalid", %{length: length, reason: "Content too short (min: #{min_length})"},
         ctx}

      length > max_length ->
        {:branch, "invalid", %{length: length, reason: "Content too long (max: #{max_length})"},
         ctx}

      true ->
        {:branch, "valid", %{length: length}, ctx}
    end
  end

  defp to_number(val) when is_number(val), do: val

  defp to_number(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp to_number(_), do: 0

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "automod/content_length_check",
      category: "automod",
      label: "Content Length Check",
      description: "Validates content length against min/max bounds.",
      inputs: [
        %{name: "content", type: "string", required: true}
      ],
      outputs: [
        %{name: "valid", type: "branch", fields: [%{name: "length", type: "number"}]},
        %{
          name: "invalid",
          type: "branch",
          fields: [
            %{name: "length", type: "number"},
            %{name: "reason", type: "string"}
          ]
        }
      ],
      config_fields: [
        %{name: "min_length", type: "number", default: 0, description: "Minimum content length"},
        %{
          name: "max_length",
          type: "number",
          default: 10000,
          description: "Maximum content length"
        }
      ]
    }
  end
end
