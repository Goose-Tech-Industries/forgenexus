defmodule ForgeNexus.LinkPreviewTest do
  use ExUnit.Case, async: false

  alias ForgeNexus.LinkPreview

  setup do
    Req.default_options(plug: {Req.Test, ForgeNexus.LinkPreview}, retry: false)
    # Clear the ETS table between tests if started
    if :ets.whereis(:link_preview_cache) != :undefined do
      :ets.delete_all_objects(:link_preview_cache)
    end

    on_exit(fn ->
      Req.default_options([])

      if :ets.whereis(:link_preview_cache) != :undefined do
        :ets.delete_all_objects(:link_preview_cache)
      end
    end)

    :ok
  end

  describe "fetch_preview/1" do
    test "returns nil for non-binary input" do
      assert LinkPreview.fetch_preview(nil) == nil
      assert LinkPreview.fetch_preview(123) == nil
      assert LinkPreview.fetch_preview(%{url: "http://example.com"}) == nil
    end

    test "fetches HTML and extracts OpenGraph meta tags" do
      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta property="og:title" content="ForgeNexus Blog Post" />
        <meta property="og:description" content="Discover modern community platforms built on Elixir." />
        <meta property="og:image" content="https://example.com/images/hero.png" />
        <meta property="og:site_name" content="ForgeNexus" />
      </head>
      <body><h1>Content</h1></body>
      </html>
      """

      Req.Test.stub(ForgeNexus.LinkPreview, fn conn ->
        Plug.Conn.send_resp(conn, 200, html)
      end)

      preview = LinkPreview.fetch_preview("https://example.com/blog/1")

      assert preview == %{
               url: "https://example.com/blog/1",
               title: "ForgeNexus Blog Post",
               description: "Discover modern community platforms built on Elixir.",
               image: "https://example.com/images/hero.png",
               site_name: "ForgeNexus"
             }

      # Test ETS cache hit: even if stub raises or returns 500, cached result is returned
      Req.Test.stub(ForgeNexus.LinkPreview, fn _conn ->
        raise "should not be called because it is cached"
      end)

      cached = LinkPreview.fetch_preview("https://example.com/blog/1")
      assert cached == preview
    end

    test "falls back to <title> and <meta name=description> when og tags are missing" do
      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <title>Standard Webpage Title</title>
        <meta name="description" content="Standard description without og prefixes." />
      </head>
      <body></body>
      </html>
      """

      Req.Test.stub(ForgeNexus.LinkPreview, fn conn ->
        Plug.Conn.send_resp(conn, 200, html)
      end)

      preview = LinkPreview.fetch_preview("https://example.com/fallback-page")

      assert preview.url == "https://example.com/fallback-page"
      assert preview.title == "Standard Webpage Title"
      assert preview.description == "Standard description without og prefixes."
      assert preview.image == nil
      assert preview.site_name == nil
    end

    test "handles inverted meta tag attributes (content before property/name)" do
      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta content="Inverted Title" property="og:title" />
        <meta content="Inverted Description" name="description" />
      </head>
      <body></body>
      </html>
      """

      Req.Test.stub(ForgeNexus.LinkPreview, fn conn ->
        Plug.Conn.send_resp(conn, 200, html)
      end)

      preview = LinkPreview.fetch_preview("https://example.com/inverted")

      assert preview.title == "Inverted Title"
      assert preview.description == "Inverted Description"
    end

    test "truncates excessively long titles (>200) and descriptions (>300)" do
      long_title = String.duplicate("TitleWords", 30)
      long_desc = String.duplicate("DescriptionContent", 40)

      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta property="og:title" content="#{long_title}" />
        <meta property="og:description" content="#{long_desc}" />
      </head>
      </html>
      """

      Req.Test.stub(ForgeNexus.LinkPreview, fn conn ->
        Plug.Conn.send_resp(conn, 200, html)
      end)

      preview = LinkPreview.fetch_preview("https://example.com/long-page")

      assert String.length(preview.title) <= 200
      assert String.ends_with?(preview.title, "...")
      assert String.length(preview.description) <= 300
      assert String.ends_with?(preview.description, "...")
    end

    test "returns nil when page has no title or og:title" do
      html = "<html><head><meta name=\"keywords\" content=\"test\" /></head></html>"

      Req.Test.stub(ForgeNexus.LinkPreview, fn conn ->
        Plug.Conn.send_resp(conn, 200, html)
      end)

      assert LinkPreview.fetch_preview("https://example.com/notitle") == nil
    end

    test "returns nil when HTTP status is not 200" do
      Req.Test.stub(ForgeNexus.LinkPreview, fn conn ->
        Plug.Conn.send_resp(conn, 404, "Not Found")
      end)

      assert LinkPreview.fetch_preview("https://example.com/404") == nil
    end

    test "returns nil and handles network errors or exceptions safely" do
      Req.Test.stub(ForgeNexus.LinkPreview, fn _conn ->
        raise "connection refused"
      end)

      assert LinkPreview.fetch_preview("https://example.com/exception") == nil
    end

    test "deletes and re-fetches when cache item has expired" do
      url = "https://example.com/expired-item"
      old_preview = %{url: url, title: "Old Title"}
      # Insert manually into ETS with past timestamp
      past_time = System.monotonic_time(:millisecond) - 10_000
      :ets.insert(:link_preview_cache, {url, old_preview, past_time})

      new_html = "<html><head><title>New Fresh Title</title></head></html>"

      Req.Test.stub(ForgeNexus.LinkPreview, fn conn ->
        Plug.Conn.send_resp(conn, 200, new_html)
      end)

      fresh = LinkPreview.fetch_preview(url)
      assert fresh.title == "New Fresh Title"
    end
  end
end
