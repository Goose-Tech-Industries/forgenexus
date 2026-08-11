defmodule ForgeNexusWeb.AIController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.AI

  def thread_summary(conn, %{"thread_id" => thread_id}) do
    case AI.get_thread_summary(thread_id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "no summary available"})

      summary ->
        conn |> json(%{summary: Map.from_struct(summary) |> Map.drop([:__meta__, :thread])})
    end
  end

  def tag_suggestions(conn, %{"thread_id" => thread_id}) do
    suggestions =
      case AI.get_tag_suggestions(thread_id) do
        nil -> []
        s -> [s]
      end

    conn
    |> json(%{
      suggestions:
        Enum.map(suggestions, fn s ->
          %{
            id: s.id,
            thread_id: s.thread_id,
            suggested_tags: Map.get(s, :suggested_tags) || [],
            confidence: Map.get(s, :confidence),
            inserted_at: s.inserted_at
          }
        end)
    })
  end

  def translate(conn, %{"id" => post_id} = params) do
    lang = Map.get(params, "lang", "en")

    case AI.get_translation(post_id, lang) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "no translation available"})

      translation ->
        conn
        |> json(%{
          translation: %{
            post_id: post_id,
            target_language: lang,
            translated_text:
              Map.get(translation, :translated_text) || Map.get(translation, :content)
          }
        })
    end
  end
end
