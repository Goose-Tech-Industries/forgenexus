defmodule ForgeNexusWeb.Plugs.CommunityResolver do
  @moduledoc """
  Plug that resolves the current community from the request hostname.

  Resolution order:
  1. Custom domain lookup (e.g. `forum.theirdomain.com`)
  2. Subdomain extraction from `*.forgenexus.com`
  3. Falls back to the default community

  Sets `conn.assigns.community` and `conn.assigns.community_id` for use
  by all downstream controllers, channels, and contexts.
  """

  import Plug.Conn
  alias ForgeNexus.Communities

  def init(opts), do: opts

  def call(conn, _opts) do
    host = conn.host || "localhost"

    case Communities.resolve_host(host) do
      {:ok, community} ->
        conn
        |> assign(:community, community)
        |> assign(:community_id, community.id)

      {:error, :not_found} ->
        default = Communities.get_community!(Communities.default_community_id())

        conn
        |> assign(:community, default)
        |> assign(:community_id, default.id)
    end
  end
end
