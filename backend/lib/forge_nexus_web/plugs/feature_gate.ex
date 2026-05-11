defmodule ForgeNexusWeb.Plugs.FeatureGate do
  @moduledoc """
  Plug that gates access to routes based on the community's enabled features.
  Returns 403 if the required feature is not enabled for the current community.

  Usage in router:

      plug ForgeNexusWeb.Plugs.FeatureGate, feature: "streaming"
  """

  import Plug.Conn
  alias ForgeNexus.Communities.Community

  def init(opts), do: opts

  def call(conn, opts) do
    feature = Keyword.fetch!(opts, :feature)
    community = conn.assigns[:community]

    if community && Community.has_feature?(community, feature) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.json(%{error: "Feature '#{feature}' is not enabled for this community", upgrade_url: "/upgrade"})
      |> halt()
    end
  end
end
