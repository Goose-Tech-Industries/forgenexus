defmodule ForgeNexus.Platform do
  @moduledoc """
  Platform-level operations: API keys, ledger, infra tracking.
  """

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Platform.ApiKey

  # --- API Keys ---

  def create_api_key(user_id, community_id, name, plan \\ "free") do
    {raw_key, prefix, hash} = ApiKey.generate_key()
    plan_config = Map.get(ApiKey.plans(), plan, %{rate_limit: 100, scopes: ["read"]})

    attrs = %{
      user_id: user_id,
      community_id: community_id,
      name: name,
      key_hash: hash,
      key_prefix: prefix,
      plan: plan,
      rate_limit_per_minute: plan_config.rate_limit,
      scopes: plan_config.scopes
    }

    case %ApiKey{} |> ApiKey.changeset(attrs) |> Repo.insert() do
      {:ok, key} -> {:ok, key, raw_key}
      error -> error
    end
  end

  def list_api_keys(user_id) do
    ApiKey
    |> where([k], k.user_id == ^user_id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  def revoke_api_key(key_id, user_id) do
    case get_api_key(key_id, user_id) do
      nil -> {:error, :not_found}
      key -> key |> ApiKey.changeset(%{is_active: false}) |> Repo.update()
    end
  end

  def get_api_key(key_id, user_id) do
    case Ecto.UUID.cast(key_id) do
      {:ok, uuid} -> Repo.get_by(ApiKey, id: uuid, user_id: user_id)
      :error -> nil
    end
  end

  def get_api_key_usage(key_id, days \\ 30) do
    case Ecto.UUID.cast(key_id) do
      :error ->
        []

      {:ok, uuid} ->
        since = Date.utc_today() |> Date.add(-days)

        from(u in "api_usage_daily",
          where: u.api_key_id == type(^uuid, :binary_id) and u.date >= ^since,
          order_by: [asc: :date],
          select: %{date: u.date, requests: u.request_count, errors: u.error_count}
        )
        |> Repo.all()
    end
  end
end
