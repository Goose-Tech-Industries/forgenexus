defmodule ForgeNexus.UserStats do
  @moduledoc "Key-value user statistics with min/max clamping and level calculation."
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.UserStats.UserStat

  @xp_base 100
  @xp_factor 1.5

  def get_stat(user_id, stat_key) do
    case Repo.one(
           from s in UserStat,
             where: s.user_id == ^user_id and s.stat_key == ^stat_key,
             select: s.value
         ) do
      nil -> 0.0
      value -> value
    end
  end

  def set_stat(user_id, stat_key, value) do
    case Repo.one(from s in UserStat, where: s.user_id == ^user_id and s.stat_key == ^stat_key) do
      nil ->
        %UserStat{}
        |> UserStat.changeset(%{user_id: user_id, stat_key: stat_key, value: value})
        |> Repo.insert()

      existing ->
        clamped = clamp_value(value, existing.min_value, existing.max_value)
        existing |> UserStat.changeset(%{value: clamped}) |> Repo.update()
    end
  end

  def modify_stat(user_id, stat_key, delta) do
    current = get_stat(user_id, stat_key)
    set_stat(user_id, stat_key, current + delta)
  end

  def get_all_stats(user_id) do
    UserStat
    |> where([s], s.user_id == ^user_id)
    |> Repo.all()
    |> Map.new(fn s -> {s.stat_key, s.value} end)
  end

  def get_level(user_id) do
    xp = get_stat(user_id, "xp")
    calculate_level(xp)
  end

  defp calculate_level(xp) when xp <= 0, do: 1

  defp calculate_level(xp) do
    level = :math.log(xp / @xp_base) / :math.log(@xp_factor)
    max(1, trunc(level) + 1)
  end

  def check_stat(user_id, stat_key, threshold) do
    get_stat(user_id, stat_key) >= threshold
  end

  defp clamp_value(value, min_val, max_val) do
    value = if min_val, do: max(value, min_val), else: value
    if max_val, do: min(value, max_val), else: value
  end
end
