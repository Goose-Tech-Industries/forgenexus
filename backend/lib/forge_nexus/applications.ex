defmodule ForgeNexus.Applications do
  @moduledoc "Staff application forms and submissions."
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Applications.{ApplicationForm, StaffApplication}

  def list_open_forms do
    ApplicationForm |> where([f], f.is_open == true) |> order_by(asc: :title) |> Repo.all()
  end

  def list_all_forms,
    do: ApplicationForm |> order_by(asc: :title) |> preload(:target_group) |> Repo.all()

  def get_form!(id), do: Repo.get!(ApplicationForm, id) |> Repo.preload(:target_group)

  def create_form(attrs),
    do: %ApplicationForm{} |> ApplicationForm.changeset(attrs) |> Repo.insert()

  def update_form(id, attrs),
    do: get_form!(id) |> ApplicationForm.changeset(attrs) |> Repo.update()

  def delete_form(id), do: Repo.get!(ApplicationForm, id) |> Repo.delete()

  def can_apply?(form, user) do
    days_member = DateTime.diff(DateTime.utc_now(), user.inserted_at, :second) / 86400

    cond do
      not form.is_open -> {:error, :form_closed}
      user.post_count < form.min_posts -> {:error, :insufficient_posts}
      days_member < form.min_days_member -> {:error, :too_new}
      has_pending_application?(form.id, user.id) -> {:error, :already_applied}
      true -> :ok
    end
  end

  def submit_application(form_id, user_id, answers) do
    %StaffApplication{}
    |> StaffApplication.changeset(%{form_id: form_id, user_id: user_id, answers: answers})
    |> Repo.insert()
  end

  def list_applications(opts \\ []) do
    status = Keyword.get(opts, :status)
    form_id = Keyword.get(opts, :form_id)

    query =
      StaffApplication
      |> order_by(desc: :inserted_at)
      |> preload([:user, :form, :reviewer])

    query = if status, do: where(query, [a], a.status == ^status), else: query
    query = if form_id, do: where(query, [a], a.form_id == ^form_id), else: query

    Repo.all(query)
  end

  def my_applications(user_id) do
    StaffApplication
    |> where([a], a.user_id == ^user_id)
    |> order_by(desc: :inserted_at)
    |> preload([:form])
    |> Repo.all()
  end

  def review_application(app_id, reviewer_id, status, note \\ nil) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    app = Repo.get!(StaffApplication, app_id) |> Repo.preload([:user, :form])

    result =
      app
      |> StaffApplication.changeset(%{
        status: status,
        reviewer_id: reviewer_id,
        review_note: note,
        reviewed_at: now
      })
      |> Repo.update()

    # Auto-add to target group on acceptance
    case {result, status} do
      {{:ok, updated_app}, "accepted"} ->
        if app.form.target_group_id do
          ForgeNexus.Accounts.add_user_to_group(app.user_id, app.form.target_group_id)
        end

        {:ok, updated_app}

      _ ->
        result
    end
  end

  defp has_pending_application?(form_id, user_id) do
    StaffApplication
    |> where(
      [a],
      a.form_id == ^form_id and a.user_id == ^user_id and a.status in ["pending", "under_review"]
    )
    |> Repo.exists?()
  end
end
