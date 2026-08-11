defmodule ForgeNexus.AI.ModQueueTriage do
  @moduledoc """
  AI-powered pre-triage for the moderation queue. Categorizes reports by
  severity and type before mods see them. Uses Claude Haiku for cost efficiency.
  """

  require Logger
  alias ForgeNexus.Settings

  @severity_levels ~w(critical high medium low info)
  @categories ~w(spam harassment hate_speech nsfw self_harm doxxing copyright off_topic other)

  def triage(report_text, context \\ %{}) do
    if not Settings.get_bool("ai_mod_triage_enabled") do
      {:ok,
       %{severity: "medium", category: "other", confidence: 0.0, reason: "AI triage disabled"}}
    else
      api_key = System.get_env("ANTHROPIC_API_KEY")

      if is_nil(api_key) or api_key == "" do
        {:ok, %{severity: "medium", category: "other", confidence: 0.0, reason: "No API key"}}
      else
        do_triage(api_key, report_text, context)
      end
    end
  end

  defp do_triage(api_key, text, context) do
    prompt = """
    You are a content moderation assistant. Analyze this reported content and classify it.

    Reported content: "#{String.slice(text, 0, 2000)}"
    #{if context[:reporter_reason], do: "Reporter's reason: #{context[:reporter_reason]}", else: ""}

    Respond with ONLY a JSON object (no markdown, no explanation):
    {"severity": "critical|high|medium|low|info", "category": "spam|harassment|hate_speech|nsfw|self_harm|doxxing|copyright|off_topic|other", "confidence": 0.0-1.0, "reason": "one sentence explanation"}
    """

    url = "https://api.anthropic.com/v1/messages"
    model = Settings.get("ai_mod_triage_model") || "claude-haiku-4-5-20251001"

    body = %{model: model, max_tokens: 256, messages: [%{role: "user", content: prompt}]}

    headers = [
      {"x-api-key", api_key},
      {"anthropic-version", "2023-06-01"},
      {"content-type", "application/json"}
    ]

    try do
      case Req.post(url, headers: headers, json: body, receive_timeout: 30_000) do
        {:ok, %{status: 200, body: %{"content" => [%{"text" => text} | _]}}} ->
          parse_triage_response(text)

        _ ->
          {:ok, %{severity: "medium", category: "other", confidence: 0.0, reason: "API error"}}
      end
    rescue
      _ -> {:ok, %{severity: "medium", category: "other", confidence: 0.0, reason: "Exception"}}
    end
  end

  defp parse_triage_response(text) do
    case Jason.decode(String.trim(text)) do
      {:ok, %{"severity" => sev, "category" => cat} = result}
      when sev in @severity_levels and cat in @categories ->
        {:ok,
         %{
           severity: sev,
           category: cat,
           confidence: result["confidence"] || 0.5,
           reason: result["reason"] || ""
         }}

      _ ->
        {:ok, %{severity: "medium", category: "other", confidence: 0.0, reason: "Parse error"}}
    end
  end
end
