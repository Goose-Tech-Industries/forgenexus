defmodule ForgeNexus.AI.ClipAutoHighlight do
  @moduledoc """
  Auto-generates clip highlights from voice recordings by analyzing
  transcripts for keyword frequency and energy patterns.
  """

  alias ForgeNexus.{Repo, Voice}
  alias ForgeNexus.Voice.Recording

  @highlight_keywords ~w(amazing insane clutch wow omg holy lets go no way
    incredible unbelievable what crazy)
  @min_highlight_duration_ms 5_000
  @max_highlight_duration_ms 60_000

  def generate_highlights(recording_id, opts \\ []) do
    max_clips = Keyword.get(opts, :max_clips, 5)

    case Repo.get(Recording, recording_id) do
      nil -> {:error, :not_found}
      %Recording{transcript: nil} -> {:error, :no_transcript}
      %Recording{transcript: ""} -> {:error, :no_transcript}
      recording -> analyze_and_clip(recording, max_clips)
    end
  end

  defp analyze_and_clip(recording, max_clips) do
    segments = segment_transcript(recording.transcript)
    scored = Enum.map(segments, &score_segment/1)

    top =
      scored
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.take(max_clips)
      |> Enum.filter(&(&1.score > 0))

    clips =
      Enum.map(top, fn seg ->
        {:ok, clip} =
          Voice.create_clip(%{
            recording_id: recording.id,
            title: generate_clip_title(seg),
            start_ms: seg.start_ms,
            end_ms: seg.end_ms,
            created_by_id: recording.host_user_id
          })

        clip
      end)

    {:ok, clips}
  end

  defp segment_transcript(transcript) do
    words = String.split(transcript)
    total_words = length(words)

    if total_words < 10 do
      [%{text: transcript, start_ms: 0, end_ms: @max_highlight_duration_ms, word_index: 0}]
    else
      chunk_size = max(div(total_words, 20), 5)

      words
      |> Enum.chunk_every(chunk_size, div(chunk_size, 2), :discard)
      |> Enum.with_index()
      |> Enum.map(fn {chunk, idx} ->
        text = Enum.join(chunk, " ")
        words_per_ms = total_words / (@max_highlight_duration_ms * 10)
        start_word = idx * div(chunk_size, 2)
        start_ms = round(start_word / max(words_per_ms, 0.001))

        end_ms =
          min(
            start_ms + @max_highlight_duration_ms,
            round(total_words / max(words_per_ms, 0.001))
          )

        %{
          text: text,
          start_ms: max(start_ms, 0),
          end_ms: max(end_ms, start_ms + @min_highlight_duration_ms),
          word_index: start_word
        }
      end)
    end
  end

  defp score_segment(segment) do
    text = String.downcase(segment.text)

    keyword_score =
      @highlight_keywords
      |> Enum.count(fn kw -> String.contains?(text, kw) end)
      |> Kernel.*(3)

    exclamation_score = (String.graphemes(text) |> Enum.count(&(&1 == "!"))) * 2

    caps_ratio =
      String.graphemes(segment.text)
      |> then(fn chars ->
        uppers = Enum.count(chars, fn c -> c == String.upcase(c) and c != String.downcase(c) end)
        if length(chars) > 0, do: uppers / length(chars), else: 0
      end)

    caps_score = if caps_ratio > 0.3, do: 5, else: 0

    Map.put(segment, :score, keyword_score + exclamation_score + caps_score)
  end

  defp generate_clip_title(segment) do
    words = String.split(segment.text) |> Enum.take(6) |> Enum.join(" ")
    if String.length(words) > 40, do: String.slice(words, 0, 40) <> "...", else: words
  end
end
