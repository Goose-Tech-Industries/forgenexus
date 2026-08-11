defmodule ForgeNexusWeb.CommunitySignupController do
  @moduledoc """
  Free-tier member signup on a creator's community. This is the OUTSIDER
  funnel — distinct from /signup (which creates a creator + tenant). A
  visitor lands on SLUG.forgenexus.com (or /c/SLUG) and joins that one
  community as a member with display_name scoped to the community.
  """
  use ForgeNexusWeb, :controller

  alias ForgeNexus.{Accounts, Communities, Guardian, Repo}
  alias ForgeNexus.Communities.Community

  require Logger

  # GET /api/communities/:slug — public lookup so the landing page can
  # render community name/banner before signup.
  def show_public(conn, %{"slug" => slug}) do
    case Communities.get_community_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Community not found"})

      %Community{is_active: false} ->
        conn |> put_status(:not_found) |> json(%{error: "Community not active"})

      %Community{} = c ->
        json(conn, %{
          community: %{
            id: c.id,
            slug: c.slug,
            name: c.name,
            description: c.description,
            banner_url: c.banner_url,
            logo_url: c.logo_url,
            plan: c.plan,
            member_count: c.member_count
          }
        })
    end
  end

  # POST /api/communities/:slug/members/signup
  # body: %{email, password, display_name}
  def signup(conn, %{"slug" => slug} = params) do
    with {:ok, attrs} <- normalize(params),
         {:ok, community} <- fetch_active(slug),
         attrs <- Map.put(attrs, :registered_ip, to_string(:inet.ntoa(conn.remote_ip))),
         {:ok, %{user: user}} <- create_member(community, attrs) do
      {:ok, token, _claims} = Guardian.encode_and_sign(user)

      conn
      |> put_resp_cookie("fn_token", token,
        http_only: true,
        secure: false,
        same_site: "Lax",
        max_age: 7 * 24 * 60 * 60,
        path: "/"
      )
      |> json(%{
        user_id: user.id,
        community_id: community.id,
        community_slug: community.slug,
        token: token,
        role: "member"
      })
    else
      {:error, :community_not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Community not found"})

      {:error, %Ecto.Changeset{} = cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(cs)})

      {:error, missing} when is_list(missing) ->
        conn |> put_status(:bad_request) |> json(%{error: "Missing fields", missing: missing})

      {:error, reason} ->
        Logger.error("[CommunitySignupController] signup failed: #{inspect(reason)}")
        conn |> put_status(:internal_server_error) |> json(%{error: "Signup failed"})
    end
  end

  defp normalize(params) do
    required = ~w(email password display_name)
    missing = Enum.filter(required, fn k -> blank?(params[k]) end)

    if missing == [] do
      display = String.trim(params["display_name"])
      # Derive a username slug from display name + entropy to avoid collisions.
      username =
        display
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9_-]/, "")
        |> String.slice(0, 18)
        |> case do
          "" -> "member"
          base -> base
        end

      username =
        username <>
          "-" <>
          (:crypto.strong_rand_bytes(3) |> Base.url_encode64(padding: false) |> String.downcase())

      {:ok,
       %{
         email: String.trim(params["email"]),
         password: params["password"],
         display_name: display,
         username: username
       }}
    else
      {:error, missing}
    end
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(v) when is_binary(v), do: String.trim(v) == ""
  defp blank?(_), do: false

  defp fetch_active(slug) do
    case Communities.get_community_by_slug(slug) do
      nil -> {:error, :community_not_found}
      %Community{is_active: false} -> {:error, :community_not_found}
      community -> {:ok, community}
    end
  end

  defp create_member(community, attrs) do
    Repo.transaction(fn ->
      with {:ok, user} <-
             Accounts.register_user(%{
               "email" => String.downcase(attrs.email),
               "password" => attrs.password,
               "username" => attrs.username,
               "display_name" => attrs.display_name,
               "registered_ip" => attrs.registered_ip
             }),
           {:ok, _member} <- Communities.join_community(community.id, user.id, "member") do
        %{user: user}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", to_string(v)) end)
    end)
  end
end
