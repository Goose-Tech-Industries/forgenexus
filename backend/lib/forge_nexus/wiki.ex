defmodule ForgeNexus.Wiki do
  @moduledoc """
  The Wiki context. Manages wiki categories, pages, revisions, and edit locks.
  """

  import Ecto.Query, warn: false
  alias ForgeNexus.Repo
  alias Ecto.Multi

  alias ForgeNexus.Wiki.{WikiCategory, WikiPage, WikiRevision, EditLock}

  # ── Categories ──

  def list_categories do
    WikiCategory
    |> where([c], c.is_visible == true)
    |> order_by([c], asc: c.position)
    |> preload([:children, :pages])
    |> Repo.all()
    |> Enum.map(fn cat ->
      Map.put(cat, :page_count, length(cat.pages))
    end)
  end

  def get_category!(id), do: Repo.get!(WikiCategory, id)

  def create_category(attrs \\ %{}) do
    %WikiCategory{}
    |> WikiCategory.changeset(attrs)
    |> Repo.insert()
  end

  def update_category(%WikiCategory{} = category, attrs) do
    category
    |> WikiCategory.changeset(attrs)
    |> Repo.update()
  end

  def delete_category(%WikiCategory{} = category) do
    Repo.delete(category)
  end

  # ── Pages ──

  def list_pages(category_id) do
    WikiPage
    |> where([p], p.category_id == ^category_id)
    |> where([p], p.is_published == true)
    |> order_by([p], asc: p.title)
    |> Repo.all()
  end

  def get_page!(id) do
    WikiPage
    |> Repo.get!(id)
    |> Repo.preload([:revisions, :created_by, :last_edited_by])
  end

  def get_page_by_slug!(slug) do
    WikiPage
    |> Repo.get_by!(slug: slug)
    |> Repo.preload([:revisions, :created_by, :last_edited_by])
  end

  def create_page(attrs, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Multi.new()
    |> Multi.insert(:page, fn _changes ->
      %WikiPage{}
      |> WikiPage.changeset(
        Map.merge(attrs, %{created_by_id: user_id, last_edited_by_id: user_id})
      )
    end)
    |> Multi.insert(:revision, fn %{page: page} ->
      %WikiRevision{}
      |> WikiRevision.changeset(%{
        body: page.body,
        body_html: page.body_html,
        edit_summary: "Initial version",
        revision_number: 1,
        page_id: page.id,
        edited_by_id: user_id,
        inserted_at: now
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{page: page}} -> {:ok, page}
      {:error, :page, changeset, _} -> {:error, changeset}
      {:error, :revision, changeset, _} -> {:error, changeset}
    end
  end

  def update_page(%WikiPage{} = page, attrs, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    latest_revision_number =
      WikiRevision
      |> where([r], r.page_id == ^page.id)
      |> select([r], max(r.revision_number))
      |> Repo.one() || 0

    Multi.new()
    |> Multi.update(:page, fn _changes ->
      page
      |> WikiPage.changeset(Map.merge(attrs, %{last_edited_by_id: user_id}))
    end)
    |> Multi.insert(:revision, fn %{page: updated_page} ->
      %WikiRevision{}
      |> WikiRevision.changeset(%{
        body: updated_page.body,
        body_html: updated_page.body_html,
        edit_summary: attrs[:edit_summary] || attrs["edit_summary"] || "Edit",
        revision_number: latest_revision_number + 1,
        page_id: page.id,
        edited_by_id: user_id,
        inserted_at: now
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{page: page}} -> {:ok, page}
      {:error, :page, changeset, _} -> {:error, changeset}
      {:error, :revision, changeset, _} -> {:error, changeset}
    end
  end

  # ── Revisions ──

  def get_revisions(page_id) do
    WikiRevision
    |> where([r], r.page_id == ^page_id)
    |> order_by([r], desc: r.revision_number)
    |> preload(:edited_by)
    |> Repo.all()
  end

  def get_revision!(id), do: Repo.get!(WikiRevision, id)

  def revert_to_revision(%WikiPage{} = page, revision_id) do
    revision = get_revision!(revision_id)

    update_page(
      page,
      %{
        body: revision.body,
        body_html: revision.body_html,
        edit_summary: "Reverted to revision ##{revision.revision_number}"
      },
      revision.edited_by_id
    )
  end

  # ── Edit Locks ──

  def acquire_edit_lock(page_id, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    expires_at = DateTime.add(now, 15 * 60, :second)

    case check_edit_lock(page_id) do
      nil ->
        %EditLock{}
        |> EditLock.changeset(%{
          page_id: page_id,
          user_id: user_id,
          locked_at: now,
          expires_at: expires_at
        })
        |> Repo.insert()

      %EditLock{user_id: ^user_id} = lock ->
        lock
        |> EditLock.changeset(%{locked_at: now, expires_at: expires_at})
        |> Repo.update()

      %EditLock{} = lock ->
        {:error, {:locked_by, lock.user_id}}
    end
  end

  def release_edit_lock(page_id) do
    EditLock
    |> where([l], l.page_id == ^page_id)
    |> Repo.delete_all()

    :ok
  end

  def check_edit_lock(page_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    lock =
      EditLock
      |> where([l], l.page_id == ^page_id)
      |> where([l], l.expires_at > ^now)
      |> Repo.one()

    case lock do
      nil ->
        # Clean up expired locks
        EditLock
        |> where([l], l.page_id == ^page_id)
        |> Repo.delete_all()

        nil

      lock ->
        lock
    end
  end

  # ── View Count ──

  def increment_view_count(%WikiPage{} = page) do
    WikiPage
    |> where([p], p.id == ^page.id)
    |> Repo.update_all(inc: [view_count: 1])
  end

  # ── Search ──

  def search_pages(query) do
    search_term = "%#{query}%"

    WikiPage
    |> where([p], p.is_published == true)
    |> where([p], ilike(p.title, ^search_term) or ilike(p.body, ^search_term))
    |> order_by([p], desc: p.view_count)
    |> Repo.all()
  end
end
