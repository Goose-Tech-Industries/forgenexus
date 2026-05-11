defmodule ForgeNexus.Cooldowns do
  @moduledoc "Action cooldown tracking for users."
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Cooldowns.UserCooldown

  def check_cooldown(user_id, action_key) do
    now = DateTime.utc_now()
    case Repo.one(from cd in UserCooldown, where: cd.user_id == ^user_id and cd.action_key == ^action_key) do
      nil -> {:ok, :ready}
      %{expires_at: expires_at} ->
        if DateTime.compare(expires_at, now) == :gt do
          {:error, DateTime.diff(expires_at, now)}
        else
          {:ok, :ready}
        end
    end
  end

  def set_cooldown(user_id, action_key, duration_seconds) do
    expires_at = DateTime.utc_now() |> DateTime.add(duration_seconds, :second) |> DateTime.truncate(:second)
    attrs = %{user_id: user_id, action_key: action_key, expires_at: expires_at}
    case Repo.one(from cd in UserCooldown, where: cd.user_id == ^user_id and cd.action_key == ^action_key) do
      nil -> %UserCooldown{} |> UserCooldown.changeset(attrs) |> Repo.insert()
      existing -> existing |> UserCooldown.changeset(%{expires_at: expires_at}) |> Repo.update()
    end
  end

  def clear_cooldown(user_id, action_key) do
    from(cd in UserCooldown, where: cd.user_id == ^user_id and cd.action_key == ^action_key)
    |> Repo.delete_all()
    :ok
  end

  def get_remaining(user_id, action_key) do
    now = DateTime.utc_now()
    case Repo.one(from cd in UserCooldown, where: cd.user_id == ^user_id and cd.action_key == ^action_key, select: cd.expires_at) do
      nil -> 0
      expires_at ->
        diff = DateTime.diff(expires_at, now)
        if diff > 0, do: diff, else: 0
    end
  end

  def cleanup_expired do
    now = DateTime.utc_now()
    {count, _} = from(cd in UserCooldown, where: cd.expires_at < ^now) |> Repo.delete_all()
    {:ok, count}
  end
end
