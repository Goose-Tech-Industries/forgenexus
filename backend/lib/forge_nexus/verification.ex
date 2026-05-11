defmodule ForgeNexus.Verification do
  @moduledoc "Verification challenges, onboarding checklists, and account criteria checks."
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Verification.{Challenge, OnboardingChecklist}

  # Challenges

  def create_challenge(user_id, challenge_type) do
    {challenge_data, expected_answer} = generate_challenge(challenge_type)
    expires_at = DateTime.utc_now() |> DateTime.add(300, :second) |> DateTime.truncate(:second)
    %Challenge{}
    |> Challenge.changeset(%{
      user_id: user_id,
      challenge_type: challenge_type,
      challenge_data: challenge_data,
      expected_answer: expected_answer,
      expires_at: expires_at
    })
    |> Repo.insert()
  end

  defp generate_challenge("math_captcha") do
    a = Enum.random(1..20)
    b = Enum.random(1..20)
    op = Enum.random([:+, :-])
    {result, symbol} = case op do
      :+ -> {a + b, "+"}
      :- -> {max(a, b) - min(a, b), "-"}
    end
    {%{"question" => "#{max(a, b)} #{symbol} #{min(a, b)} = ?", "a" => max(a, b), "b" => min(a, b), "op" => symbol}, to_string(result)}
  end

  defp generate_challenge("text_captcha") do
    words = ~w(apple banana cherry dragon eagle falcon grape)
    word = Enum.random(words)
    {%{"instruction" => "Type the following word: #{word}", "word" => word}, word}
  end

  defp generate_challenge(_type) do
    {%{"instruction" => "Complete verification"}, "verified"}
  end

  def verify_challenge(challenge_id, response) do
    challenge = Repo.get!(Challenge, challenge_id)
    now = DateTime.utc_now()
    cond do
      challenge.status != "pending" ->
        {:error, :already_completed}
      DateTime.compare(challenge.expires_at, now) == :lt ->
        challenge |> Challenge.changeset(%{status: "expired"}) |> Repo.update()
        {:error, :expired}
      challenge.attempts + 1 >= challenge.max_attempts and response != challenge.expected_answer ->
        challenge |> Challenge.changeset(%{status: "failed", attempts: challenge.attempts + 1}) |> Repo.update()
        {:error, :max_attempts_exceeded}
      response == challenge.expected_answer ->
        challenge |> Challenge.changeset(%{status: "completed", attempts: challenge.attempts + 1}) |> Repo.update()
      true ->
        challenge |> Challenge.changeset(%{attempts: challenge.attempts + 1}) |> Repo.update()
        {:error, :incorrect}
    end
  end

  # Onboarding

  def create_onboarding_checklist(user_id, tasks_list) do
    tasks = Enum.map(tasks_list, fn task_key ->
      %{"key" => task_key, "completed" => false}
    end)
    %OnboardingChecklist{}
    |> OnboardingChecklist.changeset(%{user_id: user_id, tasks: tasks})
    |> Repo.insert()
  end

  def update_onboarding_progress(user_id, task_key, completed?) do
    checklist = Repo.one!(from c in OnboardingChecklist, where: c.user_id == ^user_id)
    updated_tasks = Enum.map(checklist.tasks, fn task ->
      if Map.get(task, "key") == task_key do
        Map.put(task, "completed", completed?)
      else
        task
      end
    end)
    all_done = Enum.all?(updated_tasks, fn t -> Map.get(t, "completed", false) end)
    checklist |> OnboardingChecklist.changeset(%{tasks: updated_tasks, is_complete: all_done}) |> Repo.update()
  end

  def check_onboarding_complete?(user_id) do
    case Repo.one(from c in OnboardingChecklist, where: c.user_id == ^user_id, select: c.is_complete) do
      nil -> false
      complete -> complete
    end
  end

  # Account criteria

  def check_account_criteria(user_id, criteria) do
    user = ForgeNexus.Accounts.get_user!(user_id)
    Enum.all?(criteria, fn {key, value} ->
      check_criterion(user, key, value)
    end)
  end

  defp check_criterion(user, "min_age_days", days) do
    age = DateTime.diff(DateTime.utc_now(), user.inserted_at, :day)
    age >= days
  end

  defp check_criterion(user, "min_posts", count) do
    Map.get(user, :post_count, 0) >= count
  end

  defp check_criterion(user, "email_verified", true) do
    not is_nil(user.email_verified_at)
  end

  defp check_criterion(user, "has_avatar", true) do
    not is_nil(user.avatar_url) and user.avatar_url != ""
  end

  defp check_criterion(_user, _key, _value), do: true
end
