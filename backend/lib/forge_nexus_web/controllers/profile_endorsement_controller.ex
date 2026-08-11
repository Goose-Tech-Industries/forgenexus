defmodule ForgeNexusWeb.ProfileEndorsementController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.{Accounts, Profiles}

  # POST /api/profiles/:slug/endorse  {"emoji": "🔥"}
  def create(conn, %{"slug" => slug, "emoji" => emoji}) do
    user = Guardian.Plug.current_resource(conn)

    case Accounts.get_user_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Profile not found"})

      profile_user ->
        case Profiles.endorse(profile_user.id, user.id, emoji) do
          {:ok, _} ->
            counts = Profiles.endorsement_counts(profile_user.id)
            mine = Profiles.my_endorsements(profile_user.id, user.id)
            conn |> put_status(:created) |> json(%{counts: counts, mine: mine})

          {:error, :already_endorsed} ->
            conn |> put_status(:conflict) |> json(%{error: "You already used that emoji"})

          {:error, :cannot_endorse_self} ->
            conn |> put_status(:forbidden) |> json(%{error: "You can't endorse your own profile"})

          {:error, %Ecto.Changeset{}} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Invalid emoji (must be from the allowed set)"})
        end
    end
  end

  # DELETE /api/profiles/:slug/endorse  {"emoji": "🔥"}
  def delete(conn, %{"slug" => slug, "emoji" => emoji}) do
    user = Guardian.Plug.current_resource(conn)

    case Accounts.get_user_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Profile not found"})

      profile_user ->
        case Profiles.revoke_endorsement(profile_user.id, user.id, emoji) do
          :ok ->
            counts = Profiles.endorsement_counts(profile_user.id)
            mine = Profiles.my_endorsements(profile_user.id, user.id)
            conn |> json(%{counts: counts, mine: mine})

          {:error, :not_found} ->
            conn |> put_status(:not_found) |> json(%{error: "Endorsement not found"})
        end
    end
  end
end
