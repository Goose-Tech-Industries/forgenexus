defmodule ForgeNexus.Quests do
  @moduledoc "Quest system with steps, progress tracking, rewards, and daily quests."
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Quests.{Quest, UserQuest}

  def list_quests do
    Quest |> where([q], q.is_active == true) |> order_by(:sort_order) |> Repo.all()
  end

  def get_quest!(id), do: Repo.get!(Quest, id)

  def start_quest(user_id, quest_id) do
    case Repo.one(from uq in UserQuest, where: uq.user_id == ^user_id and uq.quest_id == ^quest_id and uq.status == "active") do
      nil ->
        %UserQuest{} |> UserQuest.changeset(%{user_id: user_id, quest_id: quest_id, status: "active", current_step: 0, progress_data: %{}}) |> Repo.insert()
      _existing -> {:error, :quest_already_active}
    end
  end

  def check_step_progress(user_quest_id, progress_data) do
    uq = Repo.get!(UserQuest, user_quest_id) |> Repo.preload(:quest)
    quest = uq.quest
    steps = quest.steps
    current_step = Enum.at(steps, uq.current_step)
    if is_nil(current_step) do
      {:ok, :all_steps_complete}
    else
      criteria_type = Map.get(current_step, "type", "count")
      target = Map.get(current_step, "target", 1)
      current = Map.get(progress_data, "count", 0)
      case criteria_type do
        "count" ->
          if current >= target, do: {:ok, :step_complete}, else: {:ok, :in_progress}
        "flag" ->
          if Map.get(progress_data, "completed", false), do: {:ok, :step_complete}, else: {:ok, :in_progress}
        _ -> {:ok, :in_progress}
      end
    end
  end

  def advance_quest(user_quest_id) do
    uq = Repo.get!(UserQuest, user_quest_id) |> Repo.preload(:quest)
    next_step = uq.current_step + 1
    if next_step >= length(uq.quest.steps) do
      complete_quest(user_quest_id)
    else
      uq |> UserQuest.changeset(%{current_step: next_step}) |> Repo.update()
    end
  end

  def complete_quest(user_quest_id) do
    uq = Repo.get!(UserQuest, user_quest_id) |> Repo.preload(:quest)
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    Repo.transaction(fn ->
      uq |> UserQuest.changeset(%{status: "completed", completed_at: now}) |> Repo.update!()
      # Return rewards for caller to distribute
      uq.quest.rewards
    end)
  end

  def get_user_quests(user_id) do
    UserQuest
    |> where([uq], uq.user_id == ^user_id and uq.status == "active")
    |> preload(:quest)
    |> order_by(:inserted_at)
    |> Repo.all()
  end

  def generate_daily_quests(user_id) do
    daily_pool = Quest |> where([q], q.is_daily == true and q.is_active == true) |> Repo.all()
    already_active = Repo.all(from uq in UserQuest, where: uq.user_id == ^user_id and uq.status == "active", select: uq.quest_id) |> MapSet.new()
    available = Enum.reject(daily_pool, fn q -> MapSet.member?(already_active, q.id) end)
    selected = Enum.take_random(available, 3)
    Enum.map(selected, fn quest ->
      {:ok, uq} = start_quest(user_id, quest.id)
      uq
    end)
  end

  def abandon_quest(user_quest_id) do
    uq = Repo.get!(UserQuest, user_quest_id)
    uq |> UserQuest.changeset(%{status: "abandoned"}) |> Repo.update()
  end
end
