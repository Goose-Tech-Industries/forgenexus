defmodule ForgeNexusWeb.LinkPreviewController do
  @moduledoc "Controller for fetching OpenGraph link previews."
  use ForgeNexusWeb, :controller

  alias ForgeNexus.LinkPreview

  @doc "GET /api/link-preview?url=..."
  def show(conn, %{"url" => url}) do
    with true <- valid_url?(url),
         preview when not is_nil(preview) <- LinkPreview.fetch_preview(url) do
      conn |> json(%{preview: preview})
    else
      false ->
        conn |> put_status(:bad_request) |> json(%{error: "Invalid URL. Must be http or https."})

      nil ->
        conn |> json(%{preview: nil})
    end
  end

  def show(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "Missing url parameter"})
  end

  defp valid_url?(url) do
    uri = URI.parse(url)
    uri.scheme in ["http", "https"] and not is_nil(uri.host) and uri.host != ""
  end
end
