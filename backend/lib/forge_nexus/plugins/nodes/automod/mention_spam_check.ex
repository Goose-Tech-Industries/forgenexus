defmodule ForgeNexus.Plugins.Nodes.Automod.MentionSpamCheck do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @mention_regex ~r/@[\w.-]+/

  @impl true
  def execute(config, inputs, ctx) do
    content = Map.get(inputs, :content) || Map.get(inputs, "content", "")
    max_mentions = Map.get(config, "max_mentions", 5) |> to_number() |> trunc()

    mentions = Regex.scan(@mention_regex, content)
    mention_count = length(mentions)

    if mention_count <= max_mentions do
      {:branch, "ok", %{mention_count: mention_count}, ctx}
    else
      {:branch, "spam", %{mention_count: mention_count}, ctx}
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
      type: "automod/mention_spam_check",
      category: "automod",
      label: "Mention Spam Check",
      description: "Detects excessive @mentions in content.",
      inputs: [
        %{name: "content", type: "string", required: true}
      ],
      outputs: [
        %{name: "ok", type: "branch", fields: [%{name: "mention_count", type: "number"}]},
        %{name: "spam", type: "branch", fields: [%{name: "mention_count", type: "number"}]}
      ],
      config_fields: [
        %{name: "max_mentions", type: "number", default: 5, description: "Maximum allowed mentions"}
      ]
    }
  end
end
