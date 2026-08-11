defmodule ForgeNexusWeb.AchievementController do
  @moduledoc "Controller for user achievements/milestones."
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Accounts

  def user_achievements(conn, %{"user_id" => user_id}) do
    achievements = Accounts.list_user_achievements(user_id)

    conn
    |> json(%{
      achievements:
        Enum.map(achievements, fn ua ->
          %{
            id: ua.id,
            unlocked_at: ua.unlocked_at,
            achievement: %{
              id: ua.achievement.id,
              name: ua.achievement.name,
              slug: ua.achievement.slug,
              description: ua.achievement.description,
              icon: ua.achievement.icon,
              category: ua.achievement.category,
              points: ua.achievement.points,
              criteria: ua.achievement.criteria
            }
          }
        end)
    })
  end

  def all_achievements(conn, _params) do
    achievements = Accounts.list_achievements()

    conn
    |> json(%{
      achievements:
        Enum.map(achievements, fn a ->
          %{
            id: a.id,
            name: a.name,
            slug: a.slug,
            description: a.description,
            icon: a.icon,
            category: a.category,
            points: a.points,
            criteria: a.criteria
          }
        end)
    })
  end
end
