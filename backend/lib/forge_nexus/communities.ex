defmodule ForgeNexus.Communities do
  @moduledoc """
  Multi-tenancy context. Every community is an isolated tenant with its own
  subdomain, feature flags, and plan. All content queries are scoped by
  `community_id`.
  """

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Communities.Community

  @default_community_id "00000000-0000-0000-0000-000000000001"

  def default_community_id, do: @default_community_id

  def get_community!(id), do: Repo.get!(Community, id)

  def get_community_by_slug(slug) do
    Repo.get_by(Community, slug: slug)
  end

  def get_community_by_subdomain(subdomain) do
    Repo.get_by(Community, subdomain: subdomain, is_active: true)
  end

  def get_community_by_custom_domain(domain) do
    Repo.get_by(Community, custom_domain: domain, is_active: true)
  end

  def resolve_host(host) do
    cond do
      community = get_community_by_custom_domain(host) ->
        {:ok, community}

      subdomain = extract_subdomain(host) ->
        case get_community_by_subdomain(subdomain) do
          nil -> {:error, :not_found}
          community -> {:ok, community}
        end

      true ->
        {:ok, get_community!(@default_community_id)}
    end
  end

  defp extract_subdomain(host) do
    base_domain = Application.get_env(:forge_nexus, :base_domain, "forgenexus.com")

    if String.ends_with?(host, "." <> base_domain) do
      host
      |> String.replace("." <> base_domain, "")
      |> case do
        "" -> nil
        "www" -> nil
        sub -> sub
      end
    else
      nil
    end
  end

  def create_community(attrs) do
    %Community{}
    |> Community.changeset(attrs)
    |> maybe_set_plan_features()
    |> Repo.insert()
  end

  def update_community(%Community{} = community, attrs) do
    community
    |> Community.changeset(attrs)
    |> maybe_set_plan_features()
    |> Repo.update()
  end

  def delete_community(%Community{} = community) do
    Repo.delete(community)
  end

  def list_communities(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    active_only = Keyword.get(opts, :active_only, true)

    query = from(c in Community, order_by: [desc: :member_count], limit: ^limit)
    query = if active_only, do: where(query, [c], c.is_active == true), else: query
    Repo.all(query)
  end

  def has_feature?(%Community{} = community, feature) do
    Community.has_feature?(community, feature)
  end

  def increment_member_count(community_id) do
    from(c in Community, where: c.id == ^community_id)
    |> Repo.update_all(inc: [member_count: 1])
  end

  def decrement_member_count(community_id) do
    from(c in Community, where: c.id == ^community_id and c.member_count > 0)
    |> Repo.update_all(inc: [member_count: -1])
  end

  def join_community(community_id, user_id, role \\ "member") do
    %ForgeNexus.Communities.CommunityMember{}
    |> ForgeNexus.Communities.CommunityMember.changeset(%{
      community_id: community_id,
      user_id: user_id,
      role: role,
      joined_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert(on_conflict: :nothing)
    |> case do
      {:ok, member} ->
        increment_member_count(community_id)
        {:ok, member}

      error ->
        error
    end
  end

  def leave_community(community_id, user_id) do
    from(m in ForgeNexus.Communities.CommunityMember,
      where: m.community_id == ^community_id and m.user_id == ^user_id
    )
    |> Repo.delete_all()
    |> case do
      {1, _} ->
        decrement_member_count(community_id)
        :ok

      _ ->
        {:error, :not_member}
    end
  end

  def list_members(community_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    from(m in ForgeNexus.Communities.CommunityMember,
      where: m.community_id == ^community_id,
      order_by: [asc: :joined_at],
      limit: ^limit,
      offset: ^offset,
      preload: [:user]
    )
    |> Repo.all()
  end

  def is_member?(community_id, user_id) do
    from(m in ForgeNexus.Communities.CommunityMember,
      where: m.community_id == ^community_id and m.user_id == ^user_id
    )
    |> Repo.exists?()
  end

  defp maybe_set_plan_features(changeset) do
    case Ecto.Changeset.get_change(changeset, :plan) do
      nil ->
        changeset

      plan ->
        features = Map.get(Community.plan_features(), plan, Community.default_features())
        Ecto.Changeset.put_change(changeset, :feature_flags, features)
    end
  end
end
