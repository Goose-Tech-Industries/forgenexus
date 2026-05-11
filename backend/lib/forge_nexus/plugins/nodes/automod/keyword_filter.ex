defmodule ForgeNexus.Plugins.Nodes.Automod.KeywordFilter do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, inputs, ctx) do
    content = Map.get(inputs, :content) || Map.get(inputs, "content", "")
    words_raw = Map.get(config, "words", "")
    match_type = Map.get(config, "match_type", "contains")

    words =
      words_raw
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    matched_word = find_match(content, words, match_type)

    if matched_word do
      {:branch, "match", %{matched_word: matched_word, content: content}, ctx}
    else
      {:branch, "no_match", %{content: content}, ctx}
    end
  end

  defp find_match(content, words, "exact") do
    content_words =
      content
      |> String.downcase()
      |> String.split(~r/\s+/)
      |> MapSet.new()

    Enum.find(words, fn word ->
      MapSet.member?(content_words, String.downcase(word))
    end)
  end

  defp find_match(content, words, "contains") do
    lower_content = String.downcase(content)

    Enum.find(words, fn word ->
      String.contains?(lower_content, String.downcase(word))
    end)
  end

  defp find_match(content, words, "regex") do
    Enum.find(words, fn pattern ->
      case Regex.compile(pattern, [:caseless]) do
        {:ok, regex} -> Regex.match?(regex, content)
        _ -> false
      end
    end)
  end

  defp find_match(_content, _words, _), do: nil

  @impl true
  def validate_config(config) do
    errors = []

    errors =
      case Map.get(config, "words") do
        nil -> ["words is required" | errors]
        "" -> ["words cannot be empty" | errors]
        _ -> errors
      end

    errors =
      if Map.get(config, "match_type", "contains") in ~w(exact contains regex),
        do: errors,
        else: ["match_type must be exact, contains, or regex" | errors]

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "automod/keyword_filter",
      category: "automod",
      label: "Keyword Filter",
      description: "Checks content against a list of keywords and branches on match.",
      inputs: [
        %{name: "content", type: "string", required: true}
      ],
      outputs: [
        %{name: "match", type: "branch", fields: [
          %{name: "matched_word", type: "string"},
          %{name: "content", type: "string"}
        ]},
        %{name: "no_match", type: "branch", fields: [
          %{name: "content", type: "string"}
        ]}
      ],
      config_fields: [
        %{name: "words", type: "string", default: "", description: "Comma-separated list of keywords to filter"},
        %{name: "match_type", type: "select", options: ~w(exact contains regex), default: "contains", description: "How to match keywords"}
      ]
    }
  end
end
