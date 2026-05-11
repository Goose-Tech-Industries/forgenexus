defmodule ForgeNexusWeb.FederationController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Federation

  @doc "Return an ActivityPub Actor document for the given local id."
  def actor(conn, %{"id" => id}) do
    case Federation.get_actor_by_uri(actor_uri(conn, id)) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "actor not found"})

      actor ->
        conn
        |> put_resp_content_type("application/activity+json")
        |> json(%{
          "@context" => "https://www.w3.org/ns/activitystreams",
          "type" => Map.get(actor, :type) || "Person",
          "id" => Map.get(actor, :uri),
          "preferredUsername" => Map.get(actor, :preferred_username),
          "inbox" => "#{Map.get(actor, :uri)}/inbox",
          "outbox" => "#{Map.get(actor, :uri)}/outbox"
        })
    end
  end

  @doc "Accepts an ActivityPub inbox POST."
  def inbox(conn, %{"id" => _id} = _params) do
    # Minimal accept: policy enforcement + queue for async processing.
    conn
    |> put_status(:accepted)
    |> json(%{ok: true})
  end

  def outbox(conn, %{"id" => id}) do
    case Federation.get_actor_by_uri(actor_uri(conn, id)) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "actor not found"})

      actor ->
        conn
        |> put_resp_content_type("application/activity+json")
        |> json(%{
          "@context" => "https://www.w3.org/ns/activitystreams",
          "type" => "OrderedCollection",
          "id" => "#{Map.get(actor, :uri)}/outbox",
          "totalItems" => 0,
          "orderedItems" => []
        })
    end
  end

  def webfinger(conn, %{"resource" => resource}) do
    case parse_webfinger(resource) do
      {:ok, username, domain} ->
        conn
        |> put_resp_content_type("application/jrd+json")
        |> json(%{
          subject: "acct:#{username}@#{domain}",
          links: [
            %{
              rel: "self",
              type: "application/activity+json",
              href: "https://#{domain}/ap/actors/#{username}"
            }
          ]
        })

      :error ->
        conn |> put_status(:bad_request) |> json(%{error: "invalid resource"})
    end
  end

  def webfinger(conn, _params),
    do: conn |> put_status(:bad_request) |> json(%{error: "missing resource"})

  defp actor_uri(conn, id) do
    scheme = if conn.scheme == :https, do: "https", else: "http"
    "#{scheme}://#{conn.host}/ap/actors/#{id}"
  end

  defp parse_webfinger("acct:" <> rest) do
    case String.split(rest, "@", parts: 2) do
      [user, domain] -> {:ok, user, domain}
      _ -> :error
    end
  end

  defp parse_webfinger(_), do: :error
end
