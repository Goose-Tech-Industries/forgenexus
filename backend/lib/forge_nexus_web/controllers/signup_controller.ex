defmodule ForgeNexusWeb.SignupController do
  @moduledoc """
  Public marketing-funnel signup endpoints. Handles the one-shot path from
  the /signup form: collect user + community + tier, create everything,
  return the Stripe Checkout URL when the trial is wired through Stripe,
  or the bare community URL when payment is deferred.
  """
  use ForgeNexusWeb, :controller

  alias ForgeNexus.{Guardian, Signup}

  require Logger

  @required_keys ~w(email password username community_slug community_name plan)

  # POST /api/signup/tier
  def tier(conn, params) do
    case normalize(params) do
      {:ok, attrs} ->
        attrs = Map.put(attrs, :registered_ip, to_string(:inet.ntoa(conn.remote_ip)))

        case Signup.provision(attrs) do
          {:ok,
           %{
             user: user,
             community: community,
             checkout_url: checkout_url,
             stripe_status: stripe_status
           }} ->
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
              plan: community.plan,
              plan_status: community.plan_status,
              token: token,
              checkout_url: checkout_url,
              stripe_status: stripe_status,
              community_url: community_url(community)
            })

          {:error, %Ecto.Changeset{} = cs} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_errors(cs)})

          {:error, :invalid_plan} ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: "Invalid tier"})

          {:error, reason} ->
            Logger.error("[SignupController] provision failed: #{inspect(reason)}")

            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Signup failed — try again"})
        end

      {:error, missing} ->
        conn |> put_status(:bad_request) |> json(%{error: "Missing fields", missing: missing})
    end
  end

  defp normalize(params) do
    missing = Enum.filter(@required_keys, fn k -> blank?(params[k]) end)

    if missing == [] do
      {:ok,
       %{
         email: String.trim(params["email"]),
         password: params["password"],
         username: String.trim(params["username"]),
         community_slug: params["community_slug"] |> String.trim() |> String.downcase(),
         community_name: String.trim(params["community_name"]),
         plan: String.trim(params["plan"])
       }}
    else
      {:error, missing}
    end
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(v) when is_binary(v), do: String.trim(v) == ""
  defp blank?(_), do: false

  defp community_url(community) do
    base = Application.get_env(:forge_nexus, :base_domain, "forgenexus.com")
    "https://#{community.subdomain || community.slug}.#{base}"
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", to_string(v)) end)
    end)
  end
end
