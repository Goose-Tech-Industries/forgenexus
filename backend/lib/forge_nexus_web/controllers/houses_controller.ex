defmodule ForgeNexusWeb.HousesController do
  @moduledoc """
  Houses signup. Founder + N invited creators in one round-trip; returns
  invitation links the founder can hand off (and the backend best-effort
  emails them too — but the link in the response is the authoritative
  fallback for when mail isn't wired).
  """
  use ForgeNexusWeb, :controller

  alias ForgeNexus.{Guardian, Houses}

  require Logger

  # POST /api/signup/houses
  # body: %{founder_email, founder_password, founder_username, house_name,
  #         house_slug, creator_emails: [..]}
  def signup(conn, params) do
    case normalize(params) do
      {:ok, attrs} ->
        attrs = Map.put(attrs, :registered_ip, to_string(:inet.ntoa(conn.remote_ip)))

        case Houses.found_house(attrs) do
          {:ok, %{user: user, community: community, invitations: invitations}} ->
            {:ok, token, _claims} = Guardian.encode_and_sign(user)

            # Best-effort: try to email each invitation. We do NOT depend on
            # this succeeding — the founder always gets the URLs back in the
            # response so they can copy-paste if mail isn't deliverable.
            best_effort_email(user, community, invitations)

            extra = length(invitations)

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
              monthly_cents: Houses.monthly_cents(extra),
              creator_count: extra,
              invitations: invitations,
              # Houses Stripe price is not yet wired — surface this so the
              # frontend can show "set up billing" guidance.
              stripe_status: :not_configured
            })

          {:error, %Ecto.Changeset{} = cs} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_errors(cs)})

          {:error, {email, %Ecto.Changeset{} = cs}} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Invitation to #{email} failed", errors: format_errors(cs)})

          {:error, reason} ->
            Logger.error("[HousesController] found_house failed: #{inspect(reason)}")
            conn |> put_status(:internal_server_error) |> json(%{error: "House provisioning failed"})
        end

      {:error, missing} ->
        conn |> put_status(:bad_request) |> json(%{error: "Missing fields", missing: missing})
    end
  end

  defp normalize(params) do
    required = ~w(founder_email founder_password founder_username house_name house_slug)
    missing = Enum.filter(required, fn k -> blank?(params[k]) end)

    if missing == [] do
      creator_emails =
        case params["creator_emails"] do
          list when is_list(list) -> list
          str when is_binary(str) -> String.split(str, ~r/[,\n;]+/, trim: true)
          _ -> []
        end

      {:ok,
       %{
         founder_email: String.trim(params["founder_email"]),
         founder_password: params["founder_password"],
         founder_username: String.trim(params["founder_username"]),
         house_name: String.trim(params["house_name"]),
         house_slug: params["house_slug"] |> String.trim() |> String.downcase(),
         creator_emails: creator_emails
       }}
    else
      {:error, missing}
    end
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(v) when is_binary(v), do: String.trim(v) == ""
  defp blank?(_), do: false

  defp best_effort_email(founder, community, invitations) do
    # Fire-and-forget. Each invitation row already holds the hash; the
    # plaintext URL only lives in this in-memory list and the email body.
    Enum.each(invitations, fn %{email: email, accept_url: url} ->
      Task.start(fn ->
        try do
          import Swoosh.Email
          alias ForgeNexus.Mailer

          new()
          |> to(email)
          |> from({"ForgeNexus", "noreply@forgenexus.com"})
          |> subject("You've been invited to join the House of #{community.name}")
          |> html_body("""
          <p>#{founder.display_name || founder.username} has invited you to join the House of <strong>#{community.name}</strong> on ForgeNexus.</p>
          <p><a href="#{url}">Accept the invitation</a></p>
          <p>The link expires in 14 days.</p>
          """)
          |> text_body("""
          #{founder.display_name || founder.username} has invited you to join the House of #{community.name} on ForgeNexus.

          Accept here: #{url}

          The link expires in 14 days.
          """)
          |> Mailer.deliver()
        rescue
          err -> Logger.warning("[HousesController] invite email to #{email} failed: #{Exception.message(err)}")
        end
      end)
    end)
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", to_string(v)) end)
    end)
  end
end
