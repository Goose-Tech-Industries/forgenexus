defmodule ForgeNexusWeb.Plugs.Compress do
  @moduledoc """
  Gzip/deflate compression for API responses.
  Nginx handles static files, but dynamic JSON responses need app-level compression.
  Only compresses responses larger than 1KB.
  """
  @behaviour Plug

  @min_size 1024

  def init(opts), do: opts

  def call(conn, _opts) do
    Plug.Conn.register_before_send(conn, fn conn ->
      if should_compress?(conn) do
        accept_encoding = Plug.Conn.get_req_header(conn, "accept-encoding") |> List.first() || ""

        cond do
          String.contains?(accept_encoding, "gzip") ->
            body = :zlib.gzip(conn.resp_body)

            conn
            |> Plug.Conn.put_resp_header("content-encoding", "gzip")
            |> Plug.Conn.put_resp_header("vary", "Accept-Encoding")
            |> then(&%{&1 | resp_body: body})

          String.contains?(accept_encoding, "deflate") ->
            body = :zlib.compress(conn.resp_body)

            conn
            |> Plug.Conn.put_resp_header("content-encoding", "deflate")
            |> Plug.Conn.put_resp_header("vary", "Accept-Encoding")
            |> then(&%{&1 | resp_body: body})

          true ->
            conn
        end
      else
        conn
      end
    end)
  end

  defp should_compress?(conn) do
    content_type = Plug.Conn.get_resp_header(conn, "content-type") |> List.first() || ""
    already_encoded = Plug.Conn.get_resp_header(conn, "content-encoding") |> List.first()
    body_size = if is_binary(conn.resp_body), do: byte_size(conn.resp_body), else: 0

    is_nil(already_encoded) and
      body_size > @min_size and
      compressible_type?(content_type)
  end

  defp compressible_type?(type) do
    String.contains?(type, "json") or
      String.contains?(type, "text") or
      String.contains?(type, "javascript") or
      String.contains?(type, "xml") or
      String.contains?(type, "svg")
  end
end
