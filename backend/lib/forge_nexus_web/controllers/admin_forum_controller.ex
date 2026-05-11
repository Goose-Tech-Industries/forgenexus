defmodule ForgeNexusWeb.AdminForumController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.{Forums, Admin}

  def list_all(conn, _params) do
    import Ecto.Query

    children_query = from(c in Forums.Forum, where: is_nil(c.parent_id) == false, order_by: [asc: :position])

    categories = ForgeNexus.Repo.all(
      from c in Forums.Category,
        order_by: [asc: :position],
        preload: [forums: ^from(f in Forums.Forum, where: is_nil(f.parent_id), order_by: [asc: :position], preload: [children: ^children_query])]
    )
    conn |> json(%{categories: Enum.map(categories, &category_json/1)})
  end

  # Categories

  def create_category(conn, %{"category" => params}) do
    case Forums.create_category(atomize_keys(params)) do
      {:ok, cat} ->
        admin = Guardian.Plug.current_resource(conn)
        Admin.log_admin_action(admin.id, %{action: "category_created", category: "forums", target_type: "category", target_id: cat.id, description: "Created category #{cat.name}", new_state: params})
        conn |> put_status(:created) |> json(%{category: category_json(ForgeNexus.Repo.preload(cat, :forums))})
      {:error, cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: cs_errors(cs)})
    end
  end

  def update_category(conn, %{"id" => id, "category" => params}) do
    cat = Forums.get_category!(id)
    previous = %{"name" => cat.name, "description" => cat.description, "position" => cat.position, "is_visible" => cat.is_visible}
    case ForgeNexus.Repo.update(Forums.Category.changeset(cat, atomize_keys(params))) do
      {:ok, updated} ->
        admin = Guardian.Plug.current_resource(conn)
        Admin.log_admin_action(admin.id, %{action: "category_updated", category: "forums", target_type: "category", target_id: id, description: "Updated category #{cat.name}", previous_state: previous, new_state: params})
        conn |> json(%{category: category_json(ForgeNexus.Repo.preload(updated, :forums))})
      {:error, cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: cs_errors(cs)})
    end
  end

  def delete_category(conn, %{"id" => id}) do
    cat = Forums.get_category!(id)
    case ForgeNexus.Repo.delete(cat) do
      {:ok, _} ->
        admin = Guardian.Plug.current_resource(conn)
        Admin.log_admin_action(admin.id, %{action: "category_deleted", category: "forums", target_type: "category", target_id: id, description: "Deleted category #{cat.name}"})
        conn |> json(%{ok: true})
      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete category"})
    end
  end

  # Forums

  def create_forum(conn, %{"forum" => params}) do
    slug = (Map.get(params, "name") || "") |> String.downcase() |> String.replace(~r/[^a-z0-9\s-]/, "") |> String.replace(~r/\s+/, "-") |> String.trim("-")
    case Forums.create_forum(atomize_keys(params) |> Map.put(:slug, slug)) do
      {:ok, forum} ->
        admin = Guardian.Plug.current_resource(conn)
        Admin.log_admin_action(admin.id, %{action: "forum_created", category: "forums", target_type: "forum", target_id: forum.id, description: "Created forum #{forum.name}", new_state: params})
        conn |> put_status(:created) |> json(%{forum: forum_json(forum)})
      {:error, cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: cs_errors(cs)})
    end
  end

  def update_forum(conn, %{"id" => id, "forum" => params}) do
    forum = Forums.get_forum!(id)
    previous = %{"name" => forum.name, "description" => forum.description, "is_visible" => forum.is_visible, "is_locked" => forum.is_locked}
    case ForgeNexus.Repo.update(Forums.Forum.changeset(forum, atomize_keys(params))) do
      {:ok, updated} ->
        admin = Guardian.Plug.current_resource(conn)
        Admin.log_admin_action(admin.id, %{action: "forum_updated", category: "forums", target_type: "forum", target_id: id, description: "Updated forum #{forum.name}", previous_state: previous, new_state: params})
        conn |> json(%{forum: forum_json(updated)})
      {:error, cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: cs_errors(cs)})
    end
  end

  def delete_forum(conn, %{"id" => id}) do
    forum = Forums.get_forum!(id)
    case ForgeNexus.Repo.delete(forum) do
      {:ok, _} ->
        admin = Guardian.Plug.current_resource(conn)
        Admin.log_admin_action(admin.id, %{action: "forum_deleted", category: "forums", target_type: "forum", target_id: id, description: "Deleted forum #{forum.name}"})
        conn |> json(%{ok: true})
      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete forum"})
    end
  end

  # JSON helpers

  defp category_json(c) do
    %{id: c.id, name: c.name, slug: c.slug, description: c.description, icon: c.icon, color: c.color, position: c.position, is_visible: c.is_visible, inserted_at: c.inserted_at,
      forums: if(Ecto.assoc_loaded?(c.forums), do: Enum.map(c.forums, &forum_json/1), else: [])}
  end

  defp forum_json(f) do
    base = %{id: f.id, name: f.name, slug: f.slug, description: f.description, icon: f.icon, color: f.color, position: f.position, is_visible: f.is_visible, is_locked: f.is_locked, thread_count: f.thread_count, post_count: f.post_count, category_id: f.category_id, parent_id: f.parent_id, inserted_at: f.inserted_at, rules: f.rules}

    if Ecto.assoc_loaded?(f.children) do
      Map.put(base, :children, Enum.map(f.children, &forum_json/1))
    else
      base
    end
  end

  defp atomize_keys(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) ->
        try do {String.to_existing_atom(k), v} rescue _ -> {k, v} end
      {k, v} -> {k, v}
    end)
  end

  defp cs_errors(%Ecto.Changeset{} = cs), do: Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)
  defp cs_errors(err), do: inspect(err)
end
