defmodule ForgeNexus.Voice.WatchParty do
  @moduledoc """
  Watch-party state management. Parses YouTube and Twitch URLs into a
  structured media reference and tracks playback state in memory alongside
  the voice room.

  A watch party is ephemeral — it lives in the RoomServer GenServer for as
  long as the voice room has participants. When the room empties, the
  party ends with it. Persistent history can be layered on later.
  """

  @typedoc "Parsed media reference."
  @type media :: %{
          type: :youtube | :twitch_video | :twitch_clip | :twitch_channel | :vimeo,
          id: String.t(),
          url: String.t(),
          label: String.t()
        }

  @typedoc "Live watch-party state broadcast to all participants."
  @type state :: %{
          media: media(),
          host_user_id: binary(),
          current_time: float(),
          is_playing: boolean(),
          started_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @doc """
  Parse a video URL into a %{type, id, url, label} map.
  Supports YouTube, Twitch VODs / clips / live channels, and Vimeo.
  """
  @spec parse_url(String.t()) :: {:ok, media()} | {:error, atom()}
  def parse_url(url) when is_binary(url) do
    trimmed = String.trim(url)

    cond do
      yt = match_youtube(trimmed) -> {:ok, %{type: :youtube, id: yt, url: trimmed, label: "YouTube"}}
      tv = match_twitch_video(trimmed) -> {:ok, %{type: :twitch_video, id: tv, url: trimmed, label: "Twitch VOD"}}
      tc = match_twitch_clip(trimmed) -> {:ok, %{type: :twitch_clip, id: tc, url: trimmed, label: "Twitch Clip"}}
      tch = match_twitch_channel(trimmed) -> {:ok, %{type: :twitch_channel, id: tch, url: trimmed, label: "Twitch Live"}}
      vm = match_vimeo(trimmed) -> {:ok, %{type: :vimeo, id: vm, url: trimmed, label: "Vimeo"}}
      true -> {:error, :unsupported_url}
    end
  end

  def parse_url(_), do: {:error, :invalid_url}

  # --- YouTube ---
  # Supported:
  #   https://www.youtube.com/watch?v=VIDEO_ID
  #   https://youtu.be/VIDEO_ID
  #   https://youtube.com/shorts/VIDEO_ID
  #   https://www.youtube.com/embed/VIDEO_ID
  defp match_youtube(url) do
    patterns = [
      ~r/youtube\.com\/watch\?(?:[^&]*&)*v=([A-Za-z0-9_\-]{11})/,
      ~r/youtu\.be\/([A-Za-z0-9_\-]{11})/,
      ~r/youtube\.com\/shorts\/([A-Za-z0-9_\-]{11})/,
      ~r/youtube\.com\/embed\/([A-Za-z0-9_\-]{11})/
    ]

    Enum.find_value(patterns, fn re ->
      case Regex.run(re, url) do
        [_, id] -> id
        _ -> nil
      end
    end)
  end

  # --- Twitch VOD: https://www.twitch.tv/videos/1234567890 ---
  defp match_twitch_video(url) do
    case Regex.run(~r/twitch\.tv\/videos\/(\d+)/, url) do
      [_, id] -> id
      _ -> nil
    end
  end

  # --- Twitch Clip ---
  # https://clips.twitch.tv/SlugHere
  # https://www.twitch.tv/CHANNEL/clip/SlugHere
  defp match_twitch_clip(url) do
    cond do
      m = Regex.run(~r/clips\.twitch\.tv\/([A-Za-z0-9_\-]+)/, url) -> Enum.at(m, 1)
      m = Regex.run(~r/twitch\.tv\/[^\/]+\/clip\/([A-Za-z0-9_\-]+)/, url) -> Enum.at(m, 1)
      true -> nil
    end
  end

  # --- Twitch Live Channel: https://www.twitch.tv/CHANNEL ---
  # Reject if the path looks like /videos/ or /clip/ (already matched above)
  defp match_twitch_channel(url) do
    case Regex.run(~r/twitch\.tv\/([A-Za-z0-9_][A-Za-z0-9_\-]{2,24})(?:\/|$|\?)/, url) do
      [_, name] when name not in ["videos", "directory", "settings", "subscriptions"] ->
        if String.contains?(url, "/videos/") or String.contains?(url, "/clip/") do
          nil
        else
          name
        end

      _ ->
        nil
    end
  end

  # --- Vimeo: https://vimeo.com/123456789 ---
  defp match_vimeo(url) do
    case Regex.run(~r/vimeo\.com\/(\d+)/, url) do
      [_, id] -> id
      _ -> nil
    end
  end
end
