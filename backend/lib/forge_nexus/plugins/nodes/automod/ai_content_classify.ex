defmodule ForgeNexus.Plugins.Nodes.Automod.AiContentClassify do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, inputs, ctx) do
    content = Map.get(inputs, :content) || Map.get(inputs, "content", "")
    categories_raw = Map.get(config, "categories", "spam,toxic,nsfw,off_topic")

    categories =
      categories_raw
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    case ForgeNexus.Moderation.ai_flag_content(content, categories: categories) do
      {:ok, %{flagged: true, reason: reason}} ->
        scores = Enum.into(categories, %{}, fn c -> {c, if(c == reason, do: 1.0, else: 0.0)} end)
        {:ok, %{classification: reason || "flagged", confidence: 1.0, scores: scores}, ctx}

      {:ok, %{flagged: false}} ->
        scores = Enum.into(categories, %{}, fn c -> {c, 0.0} end)
        {:ok, %{classification: "safe", confidence: 1.0, scores: scores}, ctx}

      _ ->
        scores = Enum.into(categories, %{}, fn c -> {c, 0.0} end)
        {:ok, %{classification: "unknown", confidence: 0.0, scores: scores}, ctx}
    end
  end

  @impl true
  def validate_config(config) do
    case Map.get(config, "categories") do
      nil -> {:error, ["categories is required"]}
      "" -> {:error, ["categories cannot be empty"]}
      _ -> :ok
    end
  end

  @impl true
  def schema do
    %{
      type: "automod/ai_content_classify",
      category: "automod",
      label: "AI Content Classify",
      description: "Classifies content using the AI moderation hook.",
      inputs: [%{name: "content", type: "string", required: true}],
      outputs: [
        %{name: "classification", type: "string"},
        %{name: "confidence", type: "number"},
        %{name: "scores", type: "map"}
      ],
      config_fields: [
        %{name: "categories", type: "string", default: "spam,toxic,nsfw,off_topic", description: "Comma-separated categories to classify content into"}
      ]
    }
  end
end
