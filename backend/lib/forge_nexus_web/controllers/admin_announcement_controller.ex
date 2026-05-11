defmodule ForgeNexusWeb.AdminAnnouncementController do
  use ForgeNexusWeb, :controller

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Admin
  alias ForgeNexus.Admin.Announcement

  def index(conn, _params) do
    announcements = Repo.all(from a in Announcement, order_by: [desc: :priority, desc: :inserted_at], preload: [:created_by])
    conn |> json(%{announcements: Enum.map(announcements, &ann_json/1)})
  end

  def create(conn, %{"announcement" => params}) do
    user = Guardian.Plug.current_resource(conn)
    attrs = params |> atomize_keys() |> Map.put(:created_by_id, user.id)

    case Repo.insert(Announcement.changeset(%Announcement{}, attrs)) do
      {:ok, ann} ->
        Admin.log_admin_action(user.id, %{action: "announcement_created", category: "settings", target_type: "announcement", target_id: ann.id, description: "Created announcement: #{ann.title}"})
        conn |> put_status(:created) |> json(%{announcement: ann_json(Repo.preload(ann, :created_by))})
      {:error, cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: cs_errors(cs)})
    end
  end

  def update(conn, %{"id" => id, "announcement" => params}) do
    ann = Repo.get!(Announcement, id)
    case Repo.update(Announcement.changeset(ann, atomize_keys(params))) do
      {:ok, updated} ->
        conn |> json(%{announcement: ann_json(Repo.preload(updated, :created_by))})
      {:error, cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: cs_errors(cs)})
    end
  end

  def delete(conn, %{"id" => id}) do
    ann = Repo.get!(Announcement, id)
    case Repo.delete(ann) do
      {:ok, _} -> conn |> json(%{ok: true})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete"})
    end
  end

  def active(conn, _params) do
    now = DateTime.utc_now()
    announcements = Repo.all(
      from a in Announcement,
        where: a.is_active == true,
        where: is_nil(a.starts_at) or a.starts_at <= ^now,
        where: is_nil(a.ends_at) or a.ends_at > ^now,
        order_by: [desc: :priority],
        preload: [:created_by]
    )
    conn |> json(%{announcements: Enum.map(announcements, &ann_json/1)})
  end

  defp ann_json(a) do
    %{id: a.id, title: a.title, body: a.body, body_html: a.body_html, priority: a.priority, display_location: a.display_location, forum_id: a.forum_id, target_group_ids: a.target_group_ids, is_dismissible: a.is_dismissible, is_active: a.is_active, starts_at: a.starts_at, ends_at: a.ends_at, inserted_at: a.inserted_at,
      created_by: if(Ecto.assoc_loaded?(a.created_by) && a.created_by, do: %{id: a.created_by.id, username: a.created_by.username})}
  end

  defp atomize_keys(map), do: Map.new(map, fn {k, v} when is_binary(k) -> (try do {String.to_existing_atom(k), v} rescue _ -> {k, v} end); {k, v} -> {k, v} end)
  defp cs_errors(%Ecto.Changeset{} = cs), do: Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)
  defp cs_errors(err), do: inspect(err)
end
