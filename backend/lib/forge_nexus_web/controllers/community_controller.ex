defmodule ForgeNexusWeb.CommunityController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Communities

  def index(conn, _params) do
    communities = Communities.list_communities()

    conn |> json(%{communities: Enum.map(communities, &community_json/1)})
  end

  def show(conn, %{"id" => id}) do
    community = Communities.get_community!(id)
    conn |> json(%{community: community_json(community)})
  end

  def create(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    attrs = Map.put(params, "owner_id", user && user.id)

    case Communities.create_community(attrs) do
      {:ok, community} ->
        if user, do: Communities.join_community(community.id, user.id, "owner")
        conn |> put_status(:created) |> json(%{community: community_json(community)})

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
        conn |> put_status(:unprocessable_entity) |> json(%{error: errors})
    end
  end

  def update(conn, %{"id" => id} = params) do
    community = Communities.get_community!(id)

    case Communities.update_community(community, params) do
      {:ok, community} ->
        conn |> json(%{community: community_json(community)})

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
        conn |> put_status(:unprocessable_entity) |> json(%{error: errors})
    end
  end

  def delete(conn, %{"id" => id}) do
    community = Communities.get_community!(id)

    case Communities.delete_community(community) do
      {:ok, _} ->
        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete"})
    end
  end

  defp community_json(community) do
    %{
      id: community.id,
      name: community.name,
      slug: community.slug,
      subdomain: community.subdomain,
      custom_domain: community.custom_domain,
      description: community.description,
      logo_url: community.logo_url,
      plan: community.plan,
      feature_flags: community.feature_flags,
      is_active: community.is_active,
      member_count: community.member_count,
      inserted_at: community.inserted_at
    }
  end
end
