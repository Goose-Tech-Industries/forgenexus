defmodule ForgeNexus.Achievements do
  @moduledoc "Achievement definitions, criteria evaluation, and user unlocks."
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Achievements.{Achievement, UserAchievement}
  alias ForgeNexus.UserStats

  def list_achievements do
    Achievement |> where([a], a.is_active == true) |> order_by(:sort_order) |> Repo.all()
  end

  @doc "Lists all achievements including inactive ones — for admin use."
  def list_all_achievements do
    Achievement |> order_by([:sort_order, :name]) |> Repo.all()
  end

  def list_user_achievements(user_id), do: get_user_achievements(user_id)

  def get_achievement!(id), do: Repo.get!(Achievement, id)

  def get_achievement(id), do: Repo.get(Achievement, id)

  def create_achievement(attrs),
    do: %Achievement{} |> Achievement.changeset(attrs) |> Repo.insert()

  def update_achievement(%Achievement{} = achievement, attrs) do
    achievement |> Achievement.changeset(attrs) |> Repo.update()
  end

  def update_achievement(id, attrs) when is_binary(id) do
    case get_achievement(id) do
      nil -> {:error, :not_found}
      achievement -> update_achievement(achievement, attrs)
    end
  end

  def delete_achievement(%Achievement{} = achievement), do: Repo.delete(achievement)

  def delete_achievement(id) when is_binary(id) do
    case get_achievement(id) do
      nil -> {:error, :not_found}
      achievement -> delete_achievement(achievement)
    end
  end

  @doc "Admin-only: count how many users have unlocked a given achievement."
  def unlock_count(achievement_id) do
    Repo.one(
      from ua in UserAchievement,
        where: ua.achievement_id == ^achievement_id,
        select: count(ua.id)
    )
  end

  @doc "Admin-only: manually revoke a user's unlock of an achievement."
  def revoke_user_achievement(user_id, achievement_id) do
    case Repo.get_by(UserAchievement, user_id: user_id, achievement_id: achievement_id) do
      nil -> {:error, :not_found}
      ua -> Repo.delete(ua)
    end
  end

  def check_achievement(user_id, achievement_id) do
    achievement = get_achievement!(achievement_id)
    evaluate_criteria(user_id, achievement.criteria)
  end

  defp evaluate_criteria(user_id, %{
         "type" => "stat_threshold",
         "stat_key" => key,
         "threshold" => threshold
       }) do
    UserStats.check_stat(user_id, key, threshold)
  end

  defp evaluate_criteria(user_id, %{"type" => "count", "target" => target, "stat_key" => key}) do
    UserStats.get_stat(user_id, key) >= target
  end

  defp evaluate_criteria(_user_id, _criteria), do: false

  def unlock_achievement(user_id, achievement_id) do
    if already_unlocked?(user_id, achievement_id) do
      {:error, :already_unlocked}
    else
      achievement = get_achievement!(achievement_id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Repo.transaction(fn ->
        %UserAchievement{}
        |> UserAchievement.changeset(%{
          user_id: user_id,
          achievement_id: achievement_id,
          unlocked_at: now
        })
        |> Repo.insert!()

        if achievement.points > 0 do
          ForgeNexus.Economy.award_points(user_id, "achievement_unlocked",
            amount: achievement.points
          )
        end

        achievement
      end)
    end
  end

  defp already_unlocked?(user_id, achievement_id) do
    Repo.exists?(
      from ua in UserAchievement,
        where: ua.user_id == ^user_id and ua.achievement_id == ^achievement_id
    )
  end

  def get_user_achievements(user_id) do
    UserAchievement
    |> where([ua], ua.user_id == ^user_id)
    |> preload(:achievement)
    |> order_by(desc: :unlocked_at)
    |> Repo.all()
  end

  def check_all_achievements(user_id) do
    achievements = list_achievements()

    unlocked_ids =
      Repo.all(
        from ua in UserAchievement, where: ua.user_id == ^user_id, select: ua.achievement_id
      )
      |> MapSet.new()

    Enum.reduce(achievements, [], fn achievement, acc ->
      if MapSet.member?(unlocked_ids, achievement.id) do
        acc
      else
        if evaluate_criteria(user_id, achievement.criteria) do
          {:ok, _} = unlock_achievement(user_id, achievement.id)
          [achievement | acc]
        else
          acc
        end
      end
    end)
  end

  # --- Badge delegation helpers (used by plugin nodes) ---

  def award_badge(user_id, badge_id) do
    existing =
      Repo.exists?(
        from ub in ForgeNexus.Forums.UserBadge,
          where: ub.user_id == ^user_id and ub.badge_id == ^badge_id
      )

    case ForgeNexus.Forums.award_badge(user_id, badge_id) do
      {:ok, ub} -> {:ok, %{user_badge: ub, was_new: not existing}}
      {:error, _} = err -> err
    end
  end

  def revoke_badge(user_id, badge_id) do
    ForgeNexus.Forums.revoke_badge(user_id, badge_id)
  end

  def has_badge?(user_id, badge_id) do
    Repo.exists?(
      from ub in ForgeNexus.Forums.UserBadge,
        where: ub.user_id == ^user_id and ub.badge_id == ^badge_id
    )
  end

  def get_user_badges(user_id) do
    badges = ForgeNexus.Forums.user_badges(user_id)
    {:ok, badges}
  end

  def set_badge_display(user_id, badge_id, position) do
    case Repo.get_by(ForgeNexus.Forums.UserBadge, user_id: user_id, badge_id: badge_id) do
      nil ->
        {:error, :not_found}

      ub ->
        ub
        |> Ecto.Changeset.change(%{is_featured: position != nil and position >= 0})
        |> Repo.update()
    end
  end

  def check_progress(user_id, achievement_id) do
    achievement = Repo.get(Achievement, achievement_id)

    if achievement do
      progress = evaluate_criteria(user_id, achievement.criteria)
      {:ok, %{complete: progress, achievement: achievement}}
    else
      {:error, :not_found}
    end
  end

  def define_achievement(attrs) do
    %Achievement{}
    |> Achievement.changeset(attrs)
    |> Repo.insert()
  end

  def create_milestones(
        %{stat_type: stat_type, milestones: milestones, reward_points_per: reward} = params
      ) do
    community_id = Map.get(params, :community_id)

    results =
      Enum.map(milestones, fn threshold ->
        attrs = %{
          name: "#{String.capitalize(stat_type)} #{threshold}",
          slug: "#{stat_type}-#{threshold}-#{community_id || "global"}",
          description: "Reach #{threshold} #{stat_type}",
          criteria: %{
            "type" => "stat_threshold",
            "stat_key" => stat_type,
            "threshold" => threshold
          },
          points: reward,
          is_active: true
        }

        %Achievement{} |> Achievement.changeset(attrs) |> Repo.insert()
      end)

    successes = Enum.count(results, fn {s, _} -> s == :ok end)
    {:ok, successes}
  end

  def check_milestones(user_id, stat_type) do
    achievements =
      Achievement
      |> where([a], a.is_active == true)
      |> Repo.all()
      |> Enum.filter(fn a ->
        Map.get(a.criteria, "stat_key") == stat_type
      end)

    unlocked_ids =
      Repo.all(
        from ua in UserAchievement, where: ua.user_id == ^user_id, select: ua.achievement_id
      )
      |> MapSet.new()

    Enum.reduce(achievements, [], fn achievement, acc ->
      if not MapSet.member?(unlocked_ids, achievement.id) and
           evaluate_criteria(user_id, achievement.criteria) do
        {:ok, _} = unlock_achievement(user_id, achievement.id)
        [achievement | acc]
      else
        acc
      end
    end)
  end
end
