defmodule ForgeNexus.Channels.LinkEmbedTest do
  use ExUnit.Case, async: true

  alias ForgeNexus.Channels.LinkEmbed

  describe "HtmlEntities" do
    test "decodes common html entities" do
      assert HtmlEntities.decode("&amp; &lt; &gt; &quot; &#39; &apos;") == "& < > \" ' '"
      assert HtmlEntities.decode("plain text") == "plain text"
      assert HtmlEntities.decode(nil) == nil
    end
  end

  describe "LinkEmbed.extract_urls/1" do
    test "extracts valid http and https urls up to 5" do
      body = """
      Check these out:
      https://example.com/one
      http://example.org/two
      https://elixir-lang.org/three
      https://hex.pm/four
      https://github.com/five
      https://ignored.com/six
      """

      urls = LinkEmbed.extract_urls(body)
      assert length(urls) == 5
      assert "https://example.com/one" in urls
      assert "https://github.com/five" in urls
      refute "https://ignored.com/six" in urls
    end

    test "returns empty list for nil or non-binary" do
      assert LinkEmbed.extract_urls(nil) == []
      assert LinkEmbed.extract_urls(123) == []
      assert LinkEmbed.extract_urls("no links here") == []
    end
  end

  describe "LinkEmbed.fetch_metadata/1" do
    test "rejects unsafe hosts and private ip addresses safely" do
      for unsafe_url <- [
            "http://localhost:4000/secret",
            "http://127.0.0.1/admin",
            "http://0.0.0.0/debug",
            "http://10.0.0.1/internal",
            "http://192.168.1.100/router",
            "http://172.16.0.5/api"
          ] do
        meta = LinkEmbed.fetch_metadata(unsafe_url)
        assert meta.url == unsafe_url
        assert meta.title == nil
        assert meta.description == nil
        assert meta.image == nil
        assert meta.site_name == nil
      end
    end

    test "handles malformed urls gracefully" do
      meta = LinkEmbed.fetch_metadata("not_a_valid_url")
      assert meta.title == nil
    end
  end
end
