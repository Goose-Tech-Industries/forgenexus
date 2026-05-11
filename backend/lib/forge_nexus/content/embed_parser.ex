defmodule ForgeNexus.Content.EmbedParser do
  @moduledoc """
  Parses platform embed tags in post/thread content and replaces them
  with structured embed data. Supports:

    * `[clip:UUID]`     — voice clip player
    * `[room:UUID]`     — live voice room status card
    * `[poll:UUID]`     — interactive poll embed
    * `[thread:UUID]`   — thread preview card
    * `[user:UUID]`     — user hover card
    * `[achievement:UUID]` — achievement badge display
    * `[gift:TIER]`     — gift tier animation preview

  Returns the original text with embeds replaced by HTML placeholders
  that the frontend hydrates into interactive components.
  """

  @embed_pattern ~r/\[(clip|room|poll|thread|user|achievement|gift):([a-zA-Z0-9\-]+)\]/

  def parse(nil), do: nil
  def parse(""), do: ""

  def parse(text) when is_binary(text) do
    Regex.replace(@embed_pattern, text, fn _full, type, id ->
      "<div class=\"platform-embed\" data-embed-type=\"#{type}\" data-embed-id=\"#{id}\"></div>"
    end)
  end

  def extract_embeds(text) when is_binary(text) do
    Regex.scan(@embed_pattern, text)
    |> Enum.map(fn [_full, type, id] -> %{type: type, id: id} end)
  end

  def extract_embeds(_), do: []

  def resolve_embeds(embeds) when is_list(embeds) do
    Enum.map(embeds, fn %{type: type, id: id} ->
      data = resolve(type, id)
      %{type: type, id: id, data: data}
    end)
  end

  defp resolve("clip", id) do
    case ForgeNexus.Voice.get_clip(id) do
      nil -> %{error: "clip not found"}
      clip -> %{title: clip.title, start_ms: clip.start_ms, end_ms: clip.end_ms, view_count: clip.view_count}
    end
  end

  defp resolve("poll", id) do
    case ForgeNexus.Repo.get(ForgeNexus.Forums.Poll, id) do
      nil -> %{error: "poll not found"}
      poll -> %{question: poll.question, status: poll.status}
    end
  end

  defp resolve("thread", id) do
    try do
      thread = ForgeNexus.Forums.get_thread!(id)
      %{title: thread.title, slug: thread.slug, reply_count: thread.reply_count}
    rescue
      _ -> %{error: "thread not found"}
    end
  end

  defp resolve(_, _), do: %{}
end
