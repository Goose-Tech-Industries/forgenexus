defmodule ForgeNexus.Plugins.Nodes.Text.RegexMatch do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, inputs, ctx) do
    pattern = Map.get(config, "pattern", "")
    flags = Map.get(config, "flags", "")
    text = Map.get(inputs, :text) || Map.get(inputs, "text", "")

    opts =
      flags
      |> String.graphemes()
      |> Enum.flat_map(fn
        "i" -> [:caseless]
        "m" -> [:multiline]
        "s" -> [:dotall]
        _ -> []
      end)

    case :re.compile(pattern, opts) do
      {:ok, compiled} ->
        case :re.run(text, compiled, [{:capture, :all, :binary}, {:match_limit, 10_000}]) do
          {:match, captures} ->
            {:ok, %{matched: true, captures: captures}, ctx}

          :nomatch ->
            {:ok, %{matched: false, captures: []}, ctx}

          {:error, _reason} ->
            {:ok, %{matched: false, captures: []}, ctx}
        end

      {:error, {reason, _pos}} ->
        {:error, "Invalid regex pattern: #{reason}", ctx}
    end
  end

  @impl true
  def validate_config(config) do
    pattern = Map.get(config, "pattern", "")

    case :re.compile(pattern) do
      {:ok, _} -> :ok
      {:error, {reason, _}} -> {:error, ["Invalid regex: #{reason}"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "text/regex_match",
      category: "text",
      label: "Regex Match",
      description: "Tests text against a regular expression pattern.",
      inputs: [%{name: "text", type: "string", required: true}],
      outputs: [
        %{name: "matched", type: "boolean"},
        %{name: "captures", type: "list"}
      ],
      config_fields: [
        %{name: "pattern", type: "string", default: "", description: "Regex pattern"},
        %{
          name: "flags",
          type: "string",
          default: "",
          description: "Flags: i=case-insensitive, m=multiline, s=dotall"
        }
      ]
    }
  end
end
