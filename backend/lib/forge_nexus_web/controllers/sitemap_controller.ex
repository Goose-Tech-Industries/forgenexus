defmodule ForgeNexusWeb.SitemapController do
  use ForgeNexusWeb, :controller

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Forums.{Forum, Thread}

  @base_url "http://localhost:5173"

  # GET /api/sitemap.xml
  def index(conn, _params) do
    forums =
      from(f in Forum,
        where: f.is_visible == true,
        select: %{slug: f.slug, updated_at: f.updated_at}
      )
      |> Repo.all()

    threads =
      from(t in Thread,
        where: t.is_hidden == false,
        order_by: [desc: :last_post_at],
        limit: 1000,
        select: %{slug: t.slug, last_post_at: t.last_post_at, updated_at: t.updated_at}
      )
      |> Repo.all()

    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <url>
        <loc>#{@base_url}/</loc>
        <changefreq>hourly</changefreq>
        <priority>1.0</priority>
      </url>
    #{Enum.map(forums, fn f -> """
        <url>
          <loc>#{@base_url}/forums/#{f.slug}</loc>
          <changefreq>daily</changefreq>
          <priority>0.8</priority>
        </url>
      """ end) |> Enum.join()}
    #{Enum.map(threads, fn t -> """
        <url>
          <loc>#{@base_url}/threads/#{t.slug}</loc>
          <lastmod>#{format_date(t.last_post_at || t.updated_at)}</lastmod>
          <changefreq>weekly</changefreq>
          <priority>0.6</priority>
        </url>
      """ end) |> Enum.join()}
    </urlset>
    """

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, xml)
  end

  defp format_date(nil), do: ""
  defp format_date(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_date(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt) <> "Z"
end
