defmodule ForgeNexusWeb.RssController do
  use ForgeNexusWeb, :controller

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Forums.{Thread, Post}
  alias ForgeNexus.Settings

  @base_url "http://localhost:5173"

  # GET /api/rss/threads
  def threads(conn, params) do
    forum_id = params["forum_id"]
    limit = 25

    query = from(t in Thread,
      where: t.is_hidden == false,
      order_by: [desc: :last_post_at],
      limit: ^limit,
      preload: [:user, :forum]
    )

    query = if forum_id, do: where(query, [t], t.forum_id == ^forum_id), else: query
    threads = Repo.all(query)

    site_name = Settings.get("site_name")

    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
    <channel>
      <title>#{escape_xml(site_name)} - Recent Threads</title>
      <link>#{@base_url}</link>
      <description>Latest threads from #{escape_xml(site_name)}</description>
      <atom:link href="#{@base_url}/api/rss/threads" rel="self" type="application/rss+xml" />
    #{Enum.map(threads, fn t -> """
      <item>
        <title>#{escape_xml(t.title)}</title>
        <link>#{@base_url}/threads/#{t.slug}</link>
        <guid>#{@base_url}/threads/#{t.slug}</guid>
        <pubDate>#{format_rfc822(t.inserted_at)}</pubDate>
        <author>#{escape_xml(t.user.username)}</author>
        <category>#{escape_xml(t.forum.name)}</category>
      </item>
    """ end) |> Enum.join()}
    </channel>
    </rss>
    """

    conn
    |> put_resp_content_type("application/rss+xml")
    |> send_resp(200, xml)
  end

  # GET /api/rss/posts
  def posts(conn, _params) do
    posts = from(p in Post,
      where: p.is_hidden == false,
      order_by: [desc: :inserted_at],
      limit: 25,
      preload: [:user, thread: :forum]
    ) |> Repo.all()

    site_name = Settings.get("site_name")

    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
    <channel>
      <title>#{escape_xml(site_name)} - Recent Posts</title>
      <link>#{@base_url}</link>
      <description>Latest posts from #{escape_xml(site_name)}</description>
    #{Enum.map(posts, fn p -> """
      <item>
        <title>Re: #{escape_xml(p.thread.title)}</title>
        <link>#{@base_url}/threads/#{p.thread.slug}#post-#{p.id}</link>
        <guid>#{@base_url}/threads/#{p.thread.slug}#post-#{p.id}</guid>
        <pubDate>#{format_rfc822(p.inserted_at)}</pubDate>
        <author>#{escape_xml(p.user.username)}</author>
        <description>#{escape_xml(String.slice(p.body || "", 0, 500))}</description>
      </item>
    """ end) |> Enum.join()}
    </channel>
    </rss>
    """

    conn
    |> put_resp_content_type("application/rss+xml")
    |> send_resp(200, xml)
  end

  defp escape_xml(nil), do: ""
  defp escape_xml(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp format_rfc822(nil), do: ""
  defp format_rfc822(dt) do
    Calendar.strftime(dt, "%a, %d %b %Y %H:%M:%S +0000")
  end
end
