defmodule ForgeNexus.Verification do
  @moduledoc "Verification challenges, onboarding checklists, and account criteria checks."
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Verification.{Challenge, OnboardingChecklist}

  # Challenges

  def create_challenge(user_id, challenge_type) do
    {challenge_data, expected_answer} = generate_challenge(challenge_type)
    expires_at = DateTime.utc_now() |> DateTime.add(300, :second) |> DateTime.truncate(:second)

    full_challenge_data =
      challenge_data
      |> Map.put("expected_answer", expected_answer)
      |> Map.put("attempts", 0)
      |> Map.put("max_attempts", 3)

    case %Challenge{}
         |> Challenge.changeset(%{
           user_id: user_id,
           challenge_type: challenge_type,
           challenge_data: full_challenge_data,
           expires_at: expires_at
         })
         |> Repo.insert() do
      {:ok, challenge} ->
        {:ok, populate_virtuals(challenge)}

      error ->
        error
    end
  end

  defp populate_virtuals(%Challenge{} = c) do
    data = c.challenge_data || %{}

    %{
      c
      | expected_answer: Map.get(data, "expected_answer"),
        attempts: Map.get(data, "attempts", 0),
        max_attempts: Map.get(data, "max_attempts", 3)
    }
  end

  defp generate_challenge(type) when type in ["math", "math_captcha"] do
    a = Enum.random(1..20)
    b = Enum.random(1..20)
    op = Enum.random([:+, :-])

    {result, symbol} =
      case op do
        :+ -> {a + b, "+"}
        :- -> {max(a, b) - min(a, b), "-"}
      end

    {%{
       "question" => "#{max(a, b)} #{symbol} #{min(a, b)} = ?",
       "a" => max(a, b),
       "b" => min(a, b),
       "op" => symbol
     }, to_string(result)}
  end

  defp generate_challenge(type) when type in ["text", "text_captcha"] do
    words = ~w(apple banana cherry dragon eagle falcon grape)
    word = Enum.random(words)
    {%{"instruction" => "Type the following word: #{word}", "word" => word}, word}
  end

  defp generate_challenge(_type) do
    {%{"instruction" => "Complete verification"}, "verified"}
  end

  def verify_challenge(challenge_id, response) do
    challenge = Repo.get!(Challenge, challenge_id) |> populate_virtuals()
    now = DateTime.utc_now()

    cond do
      challenge.status != "pending" ->
        {:error, :already_completed}

      DateTime.compare(challenge.expires_at, now) == :lt ->
        challenge |> Challenge.changeset(%{status: "expired"}) |> Repo.update()
        {:error, :expired}

      challenge.attempts + 1 >= challenge.max_attempts and response != challenge.expected_answer ->
        updated_data =
          Map.put(challenge.challenge_data || %{}, "attempts", challenge.attempts + 1)

        challenge
        |> Challenge.changeset(%{status: "failed", challenge_data: updated_data})
        |> Repo.update()

        {:error, :max_attempts_exceeded}

      response == challenge.expected_answer ->
        now_dt = DateTime.utc_now() |> DateTime.truncate(:second)

        updated_data =
          Map.put(challenge.challenge_data || %{}, "attempts", challenge.attempts + 1)

        case challenge
             |> Challenge.changeset(%{
               status: "completed",
               completed_at: now_dt,
               challenge_data: updated_data
             })
             |> Repo.update() do
          {:ok, updated} -> {:ok, populate_virtuals(updated)}
          error -> error
        end

      true ->
        updated_data =
          Map.put(challenge.challenge_data || %{}, "attempts", challenge.attempts + 1)

        challenge |> Challenge.changeset(%{challenge_data: updated_data}) |> Repo.update()
        {:error, :incorrect}
    end
  end

  # Onboarding

  def create_onboarding_checklist(user_id, tasks_list) do
    if Repo.exists?(from c in OnboardingChecklist, where: c.user_id == ^user_id) do
      {:error, :already_exists}
    else
      tasks =
        Enum.map(tasks_list, fn
          %{"key" => _} = map ->
            map

          %{key: key} = map ->
            %{"key" => to_string(key), "completed" => Map.get(map, :completed, false)}

          task_key ->
            %{"key" => to_string(task_key), "completed" => false}
        end)

      %OnboardingChecklist{}
      |> OnboardingChecklist.changeset(%{
        user_id: user_id,
        checklist_data: %{"tasks" => tasks},
        total_count: length(tasks),
        completed_count: 0
      })
      |> Repo.insert()
    end
  end

  def update_onboarding_progress(user_id, task_key, completed?) do
    checklist = Repo.one!(from c in OnboardingChecklist, where: c.user_id == ^user_id)
    current_tasks = Map.get(checklist.checklist_data || %{}, "tasks", [])

    updated_tasks =
      Enum.map(current_tasks, fn task ->
        if Map.get(task, "key") == to_string(task_key) do
          Map.put(task, "completed", completed?)
        else
          task
        end
      end)

    done_count = Enum.count(updated_tasks, fn t -> Map.get(t, "completed", false) end)
    total = length(updated_tasks)
    all_done = total > 0 and done_count >= total

    completed_at = if all_done, do: DateTime.utc_now() |> DateTime.truncate(:second), else: nil

    checklist
    |> OnboardingChecklist.changeset(%{
      checklist_data: %{"tasks" => updated_tasks},
      completed_count: done_count,
      total_count: total,
      completed_at: completed_at
    })
    |> Repo.update()
  end

  def check_onboarding_complete?(user_id) do
    case Repo.one(
           from c in OnboardingChecklist,
             where: c.user_id == ^user_id,
             select: {c.completed_count, c.total_count}
         ) do
      {done, total} when total > 0 and done >= total -> true
      _ -> false
    end
  end

  # Account criteria

  def check_account_criteria(user_id, criteria) do
    user = ForgeNexus.Accounts.get_user!(user_id)

    results =
      Enum.into(criteria, %{}, fn {key, value} ->
        passed = check_criterion(user, to_string(key), value)
        {to_string(key), %{passed: passed, required: value}}
      end)

    {:ok, results}
  rescue
    _ -> {:error, :user_not_found}
  end

  defp check_criterion(user, "min_age_days", days) when is_number(days) do
    now = NaiveDateTime.utc_now()
    age = NaiveDateTime.diff(now, user.inserted_at) / 86400.0
    age >= days
  end

  defp check_criterion(user, "min_posts", count) when is_number(count) do
    Map.get(user, :post_count, 0) >= count
  end

  defp check_criterion(user, "require_avatar", true) do
    not is_nil(user.avatar_url) and user.avatar_url != ""
  end

  defp check_criterion(user, "require_bio", true) do
    not is_nil(user.bio) and user.bio != ""
  end

  defp check_criterion(user, "email_verified", true) do
    not is_nil(user.email_verified_at)
  end

  defp check_criterion(user, "has_avatar", true) do
    not is_nil(user.avatar_url) and user.avatar_url != ""
  end

  defp check_criterion(_user, _key, _value), do: true
end
