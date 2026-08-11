defmodule ForgeNexus.Houses do
  @moduledoc """
  Houses — multi-creator collectives. A House is structurally a Community
  with `plan = "houses"`; this context layers on top of Communities to
  handle the founder + N invited creators ergonomics.

  Pricing model (informational — actual Stripe pricing lives in the
  dashboard):
    * Base: $149/mo (founder + first 1 creator slot)
    * Each additional creator: +$25/mo
    * Enterprise Houses: $450+/mo (custom)
  """

  alias ForgeNexus.{Accounts, Communities, Repo}
  alias ForgeNexus.Houses.HouseInvitation

  import Ecto.Query
  require Logger

  @invite_ttl_seconds 14 * 86400
  # Houses base price + per-additional-creator add-on, in cents.
  @base_cents 14_900
  @per_creator_cents 2_500

  @doc """
  Compute the monthly price for a House with `invited_creators` creators
  invited on top of the founder. Returns cents.

  The base price already includes the founder + first creator slot (see
  moduledoc), so only creators beyond that first one are billed at
  @per_creator_cents. `monthly_cents(0)` and `monthly_cents(1)` are both
  just the base price.
  """
  def monthly_cents(invited_creators)
      when is_integer(invited_creators) and invited_creators >= 0 do
    billable_creators = max(invited_creators - 1, 0)
    @base_cents + billable_creators * @per_creator_cents
  end

  @doc """
  Provision a new House: create founder user, create the House Community,
  enroll the founder as owner, and queue invitation tokens for each
  additional creator email.

  Returns `{:ok, %{user, community, invitations: [%{email, accept_url}]}}`.
  Each `accept_url` is the only place the plaintext token ever appears;
  the DB stores only the hash. Founder should deliver these links to the
  creators (email-side delivery best-effort; links are also surfaced in
  the API response so the founder can copy-paste if mail isn't wired).
  """
  def found_house(
        %{
          founder_email: founder_email,
          founder_password: founder_password,
          founder_username: founder_username,
          house_name: house_name,
          house_slug: house_slug,
          creator_emails: creator_emails
        } = attrs
      ) do
    creator_emails =
      creator_emails
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    Repo.transaction(fn ->
      with {:ok, user} <-
             create_founder(
               founder_email,
               founder_password,
               founder_username,
               Map.get(attrs, :registered_ip)
             ),
           {:ok, community} <- create_house_community(user, house_name, house_slug),
           {:ok, _} <- enroll_founder(community.id, user.id),
           {:ok, invitations} <- queue_invitations(community.id, user.id, creator_emails) do
        %{user: user, community: community, invitations: invitations}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def list_invitations(community_id) do
    from(i in HouseInvitation,
      where: i.community_id == ^community_id and is_nil(i.accepted_at),
      order_by: [asc: :inserted_at]
    )
    |> Repo.all()
  end

  def accept_invitation(plaintext_token, %{id: user_id} = _user) do
    hash = HouseInvitation.hash(plaintext_token)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case Repo.get_by(HouseInvitation, token_hash: hash) do
      nil ->
        {:error, :not_found}

      %HouseInvitation{accepted_at: t} when not is_nil(t) ->
        {:error, :already_accepted}

      %HouseInvitation{expires_at: exp} = invite ->
        if DateTime.compare(exp, now) == :lt do
          {:error, :expired}
        else
          {:ok, _member} = Communities.join_community(invite.community_id, user_id, invite.role)

          invite
          |> HouseInvitation.changeset(%{accepted_at: now, accepted_by_user_id: user_id})
          |> Repo.update()
        end
    end
  end

  # -- helpers ------------------------------------------------------------

  defp create_founder(email, password, username, registered_ip) do
    Accounts.register_user(%{
      "email" => String.downcase(email),
      "password" => password,
      "username" => username,
      "display_name" => username,
      "registered_ip" => registered_ip
    })
  end

  defp create_house_community(user, name, slug) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Communities.create_community(%{
      "name" => name,
      "slug" => slug,
      "subdomain" => slug,
      "owner_id" => user.id,
      "plan" => "houses",
      "plan_status" => "trialing",
      "current_period_end" => DateTime.add(now, 14 * 86400, :second)
    })
  end

  defp enroll_founder(community_id, user_id) do
    Communities.join_community(community_id, user_id, "owner")
  end

  defp queue_invitations(community_id, inviter_id, emails) do
    expires_at =
      DateTime.utc_now()
      |> DateTime.add(@invite_ttl_seconds, :second)
      |> DateTime.truncate(:second)

    base_url = Application.get_env(:forge_nexus, :public_base_url, "https://forgenexus.com")

    results =
      Enum.map(emails, fn email ->
        plaintext = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

        case %HouseInvitation{}
             |> HouseInvitation.changeset(%{
               community_id: community_id,
               inviter_id: inviter_id,
               email: String.downcase(email),
               token_hash: HouseInvitation.hash(plaintext),
               expires_at: expires_at
             })
             |> Repo.insert() do
          {:ok, _row} ->
            {:ok,
             %{email: email, accept_url: "#{base_url}/signup/houses/accept?token=#{plaintext}"}}

          {:error, cs} ->
            {:error, {email, cs}}
        end
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> {:ok, Enum.map(results, fn {:ok, m} -> m end)}
      {:error, reason} -> {:error, reason}
    end
  end
end
