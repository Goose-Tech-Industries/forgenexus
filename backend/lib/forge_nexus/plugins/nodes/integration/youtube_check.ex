defmodule ForgeNexus.Plugins.Nodes.Integration.YoutubeCheck do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  require Logger

  @impl true
  def execute(config, _inputs, ctx) do
    Sandbox.check_http_limit!(ctx)

    channel_url = Map.get(config, "channel_url", "")

    if channel_url == "" do
      {:error, "channel_url is required", ctx}
    else
      # Convert channel URL to RSS feed URL
      rss_url = to_rss_url(channel_url)

      :inets.start()
      :ssl.start()

      case :httpc.request(:get, {String.to_charlist(rss_url), []}, [{:timeout, 10_000}], []) do
        {:ok, {{_ver, 200, _reason}, _headers, body}} ->
          ctx = Sandbox.increment_http_requests(ctx)

          # Simple XML parsing for YouTube RSS feed
          body_str = to_string(body)
          latest_video = parse_latest_video(body_str)

          has_new = latest_video != nil

          {:ok,
           %{
             latest_video: latest_video || %{},
             has_new: has_new
           }, ctx}

        {:ok, {{_ver, status, _reason}, _headers, _body}} ->
          ctx = Sandbox.increment_http_requests(ctx)
          {:error, "YouTube RSS returned status #{status}", ctx}

        {:error, reason} ->
          ctx = Sandbox.increment_http_requests(ctx)
          {:error, "Failed to fetch YouTube RSS: #{inspect(reason)}", ctx}
      end
    end
  end

  defp to_rss_url(url) do
    cond do
      String.contains?(url, "/channel/") ->
        channel_id = url |> String.split("/channel/") |> List.last() |> String.split("/") |> List.first()
        "https://www.youtube.com/feeds/videos.xml?channel_id=#{channel_id}"

      String.contains?(url, "/@") ->
        # For handle-based URLs, use the handle
        handle = url |> String.split("/@") |> List.last() |> String.split("/") |> List.first()
        "https://www.youtube.com/feeds/videos.xml?user=#{handle}"

      true ->
        "https://www.youtube.com/feeds/videos.xml?channel_id=#{url}"
    end
  end

  defp parse_latest_video(xml_str) do
    # Simple regex-based extraction of the first <entry> from YouTube Atom feed
    with [_, title] <- Regex.run(~r/<entry>.*?<title>(.*?)<\/title>/s, xml_str),
         [_, url] <- Regex.run(~r/<entry>.*?<link rel="alternate" href="(.*?)"/s, xml_str),
         [_, published] <- Regex.run(~r/<entry>.*?<published>(.*?)<\/published>/s, xml_str) do
      %{title: title, url: url, published_at: published}
    else
      _ -> nil
    end
  end

  @impl true
  def validate_config(config) do
    case Map.get(config, "channel_url") do
      nil -> {:error, ["channel_url is required"]}
      "" -> {:error, ["channel_url is required"]}
      _ -> :ok
    end
  end

  @impl true
  def schema do
    %{
      type: "integration/youtube_check",
      category: "integration",
      label: "YouTube Check",
      description: "Checks a YouTube channel for new videos via RSS feed.",
      inputs: [],
      outputs: [
        %{name: "latest_video", type: "map"},
        %{name: "has_new", type: "boolean"}
      ],
      config_fields: [
        %{name: "channel_url", type: "string", default: "", description: "YouTube channel URL or channel ID"}
      ]
    }
  end
end
