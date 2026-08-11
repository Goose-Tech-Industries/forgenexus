defmodule ForgeNexus.Plugins.Nodes.Automod.SpamScore do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, inputs, ctx) do
    content = Map.get(inputs, :content) || Map.get(inputs, "content", "")

    caps_ratio = calculate_caps_ratio(content)
    link_count = count_links(content)
    repetition_score = calculate_repetition(content)

    # Weighted heuristic spam score (0-100)
    score =
      (caps_ratio * 25 + min(link_count * 10, 30) + repetition_score * 25 +
         excess_length_score(content))
      |> min(100)
      |> max(0)
      |> round()

    {:ok,
     %{
       score: score,
       caps_ratio: Float.round(caps_ratio, 2),
       link_count: link_count,
       repetition_score: Float.round(repetition_score, 2)
     }, ctx}
  end

  defp calculate_caps_ratio(""), do: 0.0

  defp calculate_caps_ratio(content) do
    letters = String.replace(content, ~r/[^a-zA-Z]/, "")
    total = String.length(letters)

    if total == 0 do
      0.0
    else
      uppers = letters |> String.replace(~r/[^A-Z]/, "") |> String.length()
      uppers / total
    end
  end

  defp count_links(content) do
    Regex.scan(~r{https?://}i, content) |> length()
  end

  defp calculate_repetition(content) do
    words = content |> String.downcase() |> String.split(~r/\s+/) |> Enum.reject(&(&1 == ""))
    total = length(words)

    if total <= 1 do
      0.0
    else
      unique = words |> MapSet.new() |> MapSet.size()
      1.0 - unique / total
    end
  end

  defp excess_length_score(content) do
    len = String.length(content)
    if len > 5000, do: 20, else: 0
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "automod/spam_score",
      category: "automod",
      label: "Spam Score",
      description: "Calculates a heuristic spam score (0-100) from content characteristics.",
      inputs: [
        %{name: "content", type: "string", required: true}
      ],
      outputs: [
        %{name: "score", type: "number"},
        %{name: "caps_ratio", type: "number"},
        %{name: "link_count", type: "number"},
        %{name: "repetition_score", type: "number"}
      ],
      config_fields: []
    }
  end
end
