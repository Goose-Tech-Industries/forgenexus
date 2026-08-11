defmodule ForgeNexus.AutoMod do
  @moduledoc "Automated content moderation with keyword, spam, regex, and rate-limit rules."
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.AutoMod.AutoModRule

  def list_rules do
    AutoModRule |> order_by(:sort_order) |> Repo.all()
  end

  def get_rule!(id), do: Repo.get!(AutoModRule, id)

  def create_rule(attrs), do: %AutoModRule{} |> AutoModRule.changeset(attrs) |> Repo.insert()

  def update_rule(rule_or_id, attrs) do
    rule = if is_binary(rule_or_id), do: get_rule!(rule_or_id), else: rule_or_id
    rule |> AutoModRule.changeset(attrs) |> Repo.update()
  end

  def delete_rule(rule_or_id) do
    rule = if is_binary(rule_or_id), do: get_rule!(rule_or_id), else: rule_or_id
    Repo.delete(rule)
  end

  def check_content(content, user) do
    rules = AutoModRule |> where([r], r.is_enabled == true) |> order_by(:sort_order) |> Repo.all()

    Enum.map(rules, fn rule ->
      triggered = evaluate_rule(rule, content, user)
      {rule, triggered}
    end)
  end

  defp evaluate_rule(%{rule_type: "keyword"} = rule, content, _user) do
    words = Map.get(rule.config, "words", [])
    keyword_check(content, words)
  end

  defp evaluate_rule(%{rule_type: "spam"} = rule, content, _user) do
    threshold = Map.get(rule.config, "threshold", 0.7)
    spam_score(content) >= threshold
  end

  defp evaluate_rule(%{rule_type: "regex"} = rule, content, _user) do
    pattern = Map.get(rule.config, "pattern", "")

    case Regex.compile(pattern, "i") do
      {:ok, regex} -> Regex.match?(regex, content)
      _ -> false
    end
  end

  defp evaluate_rule(%{rule_type: "rate_limit"} = rule, _content, user) do
    action = Map.get(rule.config, "action", "post")
    rate_limit_check(user.id, action)
  end

  defp evaluate_rule(_rule, _content, _user), do: false

  def keyword_check(content, word_list) do
    normalized = String.downcase(content)

    Enum.any?(word_list, fn word ->
      String.contains?(normalized, String.downcase(word))
    end)
  end

  def spam_score(content) do
    scores = []
    len = String.length(content)

    # Caps percentage
    caps_count =
      content
      |> String.graphemes()
      |> Enum.count(&(&1 == String.upcase(&1) and &1 != String.downcase(&1)))

    caps_ratio = if len > 0, do: caps_count / len, else: 0
    scores = [caps_ratio * 0.3 | scores]

    # Link count
    link_count = length(Regex.scan(~r/https?:\/\//, content))
    link_score = min(link_count * 0.15, 0.3)
    scores = [link_score | scores]

    # Repetition
    words = String.split(content)
    unique_ratio = if length(words) > 0, do: length(Enum.uniq(words)) / length(words), else: 1
    repetition_score = (1 - unique_ratio) * 0.2
    scores = [repetition_score | scores]

    # Very short or very long
    length_score =
      cond do
        len < 5 -> 0.1
        len > 5000 -> 0.1
        true -> 0.0
      end

    scores = [length_score | scores]

    Enum.sum(scores)
  end

  def rate_limit_check(user_id, action) do
    case ForgeNexus.Cooldowns.check_cooldown(user_id, "rate_limit:" <> action) do
      {:error, _remaining} -> true
      {:ok, :ready} -> false
    end
  end
end
