defmodule ForgeNexus.Plugins.Nodes.Automod.MediaFilter do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, inputs, ctx) do
    attachments = Map.get(inputs, :attachments) || Map.get(inputs, "attachments", [])
    attachments = if is_list(attachments), do: attachments, else: []

    max_count = Map.get(config, "max_count", 10) |> to_number() |> trunc()
    allowed_types_raw = Map.get(config, "allowed_types", "")
    max_size_mb = Map.get(config, "max_size_mb", 10) |> to_number()

    allowed_types =
      allowed_types_raw
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.downcase/1)
      |> Enum.reject(&(&1 == ""))

    violations = []

    violations =
      if length(attachments) > max_count do
        ["Too many attachments (#{length(attachments)}/#{max_count})" | violations]
      else
        violations
      end

    violations =
      if allowed_types != [] do
        bad_types =
          Enum.filter(attachments, fn att ->
            content_type = Map.get(att, :content_type) || Map.get(att, "content_type", "")
            String.downcase(content_type) not in allowed_types
          end)

        if bad_types != [] do
          ["Disallowed file types detected" | violations]
        else
          violations
        end
      else
        violations
      end

    violations =
      Enum.reduce(attachments, violations, fn att, acc ->
        size = Map.get(att, :size) || Map.get(att, "size", 0)
        size_mb = size / (1024 * 1024)

        if size_mb > max_size_mb do
          ["File exceeds max size (#{Float.round(size_mb, 1)}MB > #{max_size_mb}MB)" | acc]
        else
          acc
        end
      end)

    if violations == [] do
      {:branch, "valid", %{attachments: attachments}, ctx}
    else
      {:branch, "invalid", %{reason: Enum.join(violations, "; "), violations: violations}, ctx}
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
      type: "automod/media_filter",
      category: "automod",
      label: "Media Filter",
      description: "Validates attachments against count, type, and size limits.",
      inputs: [
        %{name: "attachments", type: "list", required: true}
      ],
      outputs: [
        %{name: "valid", type: "branch", fields: [%{name: "attachments", type: "list"}]},
        %{
          name: "invalid",
          type: "branch",
          fields: [
            %{name: "reason", type: "string"},
            %{name: "violations", type: "list"}
          ]
        }
      ],
      config_fields: [
        %{
          name: "max_count",
          type: "number",
          default: 10,
          description: "Maximum number of attachments"
        },
        %{
          name: "allowed_types",
          type: "string",
          default: "",
          description: "Comma-separated allowed MIME types (empty = allow all)"
        },
        %{
          name: "max_size_mb",
          type: "number",
          default: 10,
          description: "Maximum file size in MB"
        }
      ]
    }
  end
end
