defmodule ForgeNexusWeb.ApplicationController do
  use ForgeNexusWeb, :controller
  alias ForgeNexus.Applications

  # Public — list open forms
  def open_forms(conn, _params) do
    forms = Applications.list_open_forms()
    conn |> json(%{forms: Enum.map(forms, &form_json/1)})
  end

  def show_form(conn, %{"id" => id}) do
    form = Applications.get_form!(id)
    conn |> json(%{form: form_json(form)})
  end

  def submit(conn, %{"form_id" => form_id, "answers" => answers}) do
    user = Guardian.Plug.current_resource(conn)
    form = Applications.get_form!(form_id)

    case Applications.can_apply?(form, user) do
      :ok ->
        case Applications.submit_application(form_id, user.id, answers) do
          {:ok, app} -> conn |> put_status(:created) |> json(%{application: app_json(app)})
          {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to submit"})
        end
      {:error, reason} ->
        conn |> put_status(:forbidden) |> json(%{error: to_string(reason)})
    end
  end

  def my_applications(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    apps = Applications.my_applications(user.id)
    conn |> json(%{applications: Enum.map(apps, &app_json/1)})
  end

  # Admin
  def admin_list_forms(conn, _params) do
    forms = Applications.list_all_forms()
    conn |> json(%{forms: Enum.map(forms, &form_json/1)})
  end

  def create_form(conn, params) do
    case Applications.create_form(params) do
      {:ok, form} -> conn |> put_status(:created) |> json(%{form: form_json(form)})
      {:error, cs} -> conn |> put_status(:unprocessable_entity) |> json(%{error: format_errors(cs)})
    end
  end

  def update_form(conn, %{"id" => id} = params) do
    case Applications.update_form(id, params) do
      {:ok, form} -> conn |> json(%{form: form_json(form)})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
    end
  end

  def delete_form(conn, %{"id" => id}) do
    case Applications.delete_form(id) do
      {:ok, _} -> conn |> json(%{ok: true})
      _ -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
    end
  end

  def list_applications(conn, params) do
    apps = Applications.list_applications(status: params["status"], form_id: params["form_id"])
    conn |> json(%{applications: Enum.map(apps, &app_json/1)})
  end

  def review(conn, %{"id" => id} = params) do
    admin = Guardian.Plug.current_resource(conn)
    case Applications.review_application(id, admin.id, params["status"], params["note"]) do
      {:ok, app} -> conn |> json(%{application: app_json(app)})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
    end
  end

  defp form_json(f) do
    %{id: f.id, title: f.title, description: f.description, fields: f.fields,
      is_open: f.is_open, min_posts: f.min_posts, min_days_member: f.min_days_member,
      target_group: f.target_group && %{id: f.target_group.id, name: f.target_group.name}}
  end

  defp app_json(a) do
    %{id: a.id, answers: a.answers, status: a.status, review_note: a.review_note,
      reviewed_at: a.reviewed_at, inserted_at: a.inserted_at,
      user: a.user && %{id: a.user.id, username: a.user.username},
      form: a.form && %{id: a.form.id, title: a.form.title},
      reviewer: a.reviewer && %{id: a.reviewer.id, username: a.reviewer.username}}
  end

  defp format_errors(cs), do: Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)
end
