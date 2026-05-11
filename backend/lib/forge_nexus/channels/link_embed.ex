defmodule ForgeNexus.Channels.LinkEmbed do
  @moduledoc """
  Extracts metadata from URLs for link previews in chat messages.
  Uses simple HTTP fetch + HTML parsing to extract OpenGraph/meta tags.
  """

  @url_regex ~r/https?:\/\/[^\s<>"]+/

  def extract_urls(body) when is_binary(body) do
    Regex.scan(@url_regex, body) |> Enum.map(fn [url] -> url end) |> Enum.take(5)
  end

  def extract_urls(_), do: []

  @doc """
  Fetches URL metadata. Returns a map with title, description, image, site_name, url.
  Falls back gracefully on errors.
  """
  def fetch_metadata(url) when is_binary(url) do
    # Restrict to public URLs only (no private IPs)
    uri = URI.parse(url)

    if safe_host?(uri.host) do
      case :httpc.request(:get, {String.to_charlist(url), [{~c"user-agent", ~c"ForgeNexus/1.0 LinkPreview"}]}, [{:timeout, 5_000}, {:connect_timeout, 3_000}], [{:body_format, :binary}]) do
        {:ok, {{_, 200, _}, _headers, body}} ->
          parse_html_meta(body, url)

        _ ->
          %{url: url, title: nil, description: nil, image: nil, site_name: nil}
      end
    else
      %{url: url, title: nil, description: nil, image: nil, site_name: nil}
    end
  end

  defp safe_host?(nil), do: false
  defp safe_host?(host) do
    not String.starts_with?(host, "10.") and
    not String.starts_with?(host, "192.168.") and
    not String.starts_with?(host, "172.") and
    host != "localhost" and
    host != "127.0.0.1" and
    host != "0.0.0.0"
  end

  defp parse_html_meta(html, url) when is_binary(html) do
    # Simple regex-based extraction (no external HTML parser dependency)
    title = extract_meta(html, "og:title") || extract_title_tag(html)
    description = extract_meta(html, "og:description") || extract_meta_name(html, "description")
    image = extract_meta(html, "og:image")
    site_name = extract_meta(html, "og:site_name")

    %{
      url: url,
      title: title && String.slice(title, 0, 200),
      description: description && String.slice(description, 0, 400),
      image: image,
      site_name: site_name
    }
  end

  defp extract_meta(html, property) do
    case Regex.run(~r/<meta[^>]*property="#{Regex.escape(property)}"[^>]*content="([^"]*)"[^>]*>/is, html) do
      [_, content] -> HtmlEntities.decode(content)
      nil ->
        case Regex.run(~r/<meta[^>]*content="([^"]*)"[^>]*property="#{Regex.escape(property)}"[^>]*>/is, html) do
          [_, content] -> HtmlEntities.decode(content)
          nil -> nil
        end
    end
  end

  defp extract_meta_name(html, name) do
    case Regex.run(~r/<meta[^>]*name="#{Regex.escape(name)}"[^>]*content="([^"]*)"[^>]*>/is, html) do
      [_, content] -> HtmlEntities.decode(content)
      nil -> nil
    end
  end

  defp extract_title_tag(html) do
    case Regex.run(~r/<title[^>]*>(.*?)<\/title>/is, html) do
      [_, title] -> HtmlEntities.decode(String.trim(title))
      nil -> nil
    end
  end
end

# Simple HTML entity decoder (no external dep needed)
defmodule HtmlEntities do
  def decode(string) when is_binary(string) do
    string
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&apos;", "'")
  end

  def decode(other), do: other
end
