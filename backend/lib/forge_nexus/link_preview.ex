defmodule ForgeNexus.LinkPreview do
  @moduledoc """
  Fetches and caches OpenGraph link previews for URLs.
  Uses an ETS table for caching to avoid re-fetching.
  """
  use GenServer

  @cache_table :link_preview_cache
  @cache_ttl :timer.hours(1)
  @fetch_timeout 5_000
  @max_body_size 512_000

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Fetches an OpenGraph preview for the given URL.
  Returns a map with :url, :title, :description, :image, :site_name
  or nil on failure.
  """
  def fetch_preview(url) when is_binary(url) do
    case get_cached(url) do
      {:ok, preview} ->
        preview

      :miss ->
        preview = do_fetch(url)
        cache_result(url, preview)
        preview
    end
  end

  def fetch_preview(_), do: nil

  # Server callbacks

  @impl true
  def init(_) do
    :ets.new(@cache_table, [:named_table, :public, read_concurrency: true])
    {:ok, %{}}
  end

  # Private

  defp get_cached(url) do
    case :ets.lookup(@cache_table, url) do
      [{^url, preview, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at do
          {:ok, preview}
        else
          :ets.delete(@cache_table, url)
          :miss
        end

      [] ->
        :miss
    end
  end

  defp cache_result(url, preview) do
    expires_at = System.monotonic_time(:millisecond) + @cache_ttl
    :ets.insert(@cache_table, {url, preview, expires_at})
  end

  defp do_fetch(url) do
    try do
      case Req.get(url,
             connect_options: [timeout: @fetch_timeout],
             receive_timeout: @fetch_timeout,
             max_retries: 0,
             redirect: true,
             max_redirects: 3,
             headers: [{"user-agent", "ForgeNexus LinkPreview/1.0"}],
             into: nil
           ) do
        {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
          body
          |> String.slice(0, @max_body_size)
          |> parse_og_tags(url)

        _ ->
          nil
      end
    rescue
      _ -> nil
    catch
      _, _ -> nil
    end
  end

  defp parse_og_tags(html, url) do
    title = extract_meta(html, "og:title") || extract_title_tag(html)
    description = extract_meta(html, "og:description") || extract_meta_name(html, "description")
    image = extract_meta(html, "og:image")
    site_name = extract_meta(html, "og:site_name")

    if title do
      %{
        url: url,
        title: truncate(title, 200),
        description: truncate(description, 300),
        image: image,
        site_name: site_name
      }
    else
      nil
    end
  end

  defp extract_meta(html, property) do
    escaped = Regex.escape(property)

    patterns = [
      ~r/<meta[^>]*property="#{escaped}"[^>]*content="([^"]*)"[^>]*\/?>/i,
      ~r/<meta[^>]*content="([^"]*)"[^>]*property="#{escaped}"[^>]*\/?>/i
    ]

    Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, html) do
        [_, value] -> String.trim(value)
        _ -> nil
      end
    end)
  end

  defp extract_meta_name(html, name) do
    escaped = Regex.escape(name)

    patterns = [
      ~r/<meta[^>]*name="#{escaped}"[^>]*content="([^"]*)"[^>]*\/?>/i,
      ~r/<meta[^>]*content="([^"]*)"[^>]*name="#{escaped}"[^>]*\/?>/i
    ]

    Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, html) do
        [_, value] -> String.trim(value)
        _ -> nil
      end
    end)
  end

  defp extract_title_tag(html) do
    case Regex.run(~r/<title[^>]*>([^<]+)<\/title>/i, html) do
      [_, title] -> String.trim(title)
      _ -> nil
    end
  end

  defp truncate(nil, _max), do: nil

  defp truncate(str, max) when byte_size(str) > max do
    String.slice(str, 0, max - 3) <> "..."
  end

  defp truncate(str, _max), do: str
end
