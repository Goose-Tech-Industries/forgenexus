defmodule ForgeNexus.Guardian do
  use Guardian, otp_app: :forge_nexus

  alias ForgeNexus.Accounts

  def subject_for_token(user, _claims) do
    {:ok, to_string(user.id)}
  end

  # Stamp the current session_generation into every token so we can invalidate
  # all outstanding JWTs for a user by bumping the counter (on password reset,
  # email change, etc.).
  def build_claims(claims, %{session_generation: gen}, _opts) when is_integer(gen) do
    {:ok, Map.put(claims, "gen", gen)}
  end

  def build_claims(claims, _resource, _opts) do
    {:ok, Map.put(claims, "gen", 0)}
  end

  def resource_from_claims(%{"sub" => id} = claims) do
    case Accounts.get_user(id) do
      nil ->
        {:error, :resource_not_found}

      user ->
        current_gen = user.session_generation || 0
        token_gen = Map.get(claims, "gen", 0)

        if token_gen == current_gen do
          {:ok, user}
        else
          {:error, :session_revoked}
        end
    end
  end
end
