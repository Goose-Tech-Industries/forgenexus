defmodule ForgeNexus.AI.LiveTranslator do
  @moduledoc """
  Real-time voice room translation. Takes transcribed text from Whisper
  and translates it to the target language via Claude. Results are broadcast
  to the room as subtitle events.

  Pipeline: LiveKit audio → Whisper transcription → Claude translation → Channel broadcast
  """

  require Logger
  alias ForgeNexus.{Repo, Settings}

  @supported_languages ~w(en es fr de ja ko zh pt ru ar hi it nl pl sv tr)

  def translate(room_id, user_id, source_text, target_language) do
    if not Settings.get_bool("voice_translation_enabled") do
      {:error, :disabled}
    else
      case do_translate(source_text, target_language) do
        {:ok, translated} ->
          now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

          Repo.insert_all("voice_translations", [
            %{
              id: Ecto.UUID.generate(),
              room_id: room_id,
              user_id: user_id,
              source_text: source_text,
              target_language: target_language,
              translated_text: translated,
              model: Settings.get("voice_translation_model") || "claude-haiku-4-5-20251001",
              inserted_at: now,
              updated_at: now
            }
          ])

          ForgeNexusWeb.Endpoint.broadcast("voice:#{room_id}", "subtitle", %{
            user_id: user_id,
            original: source_text,
            translated: translated,
            language: target_language
          })

          {:ok, translated}

        error ->
          error
      end
    end
  end

  def supported_languages, do: @supported_languages

  defp do_translate(text, target_lang) do
    api_key = System.get_env("ANTHROPIC_API_KEY")

    if is_nil(api_key) or api_key == "" do
      {:error, :no_api_key}
    else
      model = Settings.get("voice_translation_model") || "claude-haiku-4-5-20251001"
      lang_name = language_name(target_lang)

      prompt =
        "Translate the following text to #{lang_name}. Return ONLY the translation, nothing else.\n\n#{text}"

      body = %{model: model, max_tokens: 512, messages: [%{role: "user", content: prompt}]}

      headers = [
        {"x-api-key", api_key},
        {"anthropic-version", "2023-06-01"},
        {"content-type", "application/json"}
      ]

      try do
        case Req.post("https://api.anthropic.com/v1/messages",
               headers: headers,
               json: body,
               receive_timeout: 15_000
             ) do
          {:ok, %{status: 200, body: %{"content" => [%{"text" => translated} | _]}}} ->
            {:ok, String.trim(translated)}

          {:ok, %{status: status}} ->
            {:error, {:http, status}}

          {:error, reason} ->
            {:error, {:request_failed, reason}}
        end
      rescue
        e -> {:error, {:exception, Exception.message(e)}}
      end
    end
  end

  defp language_name("en"), do: "English"
  defp language_name("es"), do: "Spanish"
  defp language_name("fr"), do: "French"
  defp language_name("de"), do: "German"
  defp language_name("ja"), do: "Japanese"
  defp language_name("ko"), do: "Korean"
  defp language_name("zh"), do: "Chinese"
  defp language_name("pt"), do: "Portuguese"
  defp language_name("ru"), do: "Russian"
  defp language_name("ar"), do: "Arabic"
  defp language_name("hi"), do: "Hindi"
  defp language_name("it"), do: "Italian"
  defp language_name("nl"), do: "Dutch"
  defp language_name("pl"), do: "Polish"
  defp language_name("sv"), do: "Swedish"
  defp language_name("tr"), do: "Turkish"
  defp language_name(code), do: code
end
