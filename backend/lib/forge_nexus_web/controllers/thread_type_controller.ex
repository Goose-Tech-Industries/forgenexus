defmodule ForgeNexusWeb.ThreadTypeController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.ThreadTypes

  def index(conn, _params) do
    types = ThreadTypes.list_thread_types()

    conn
    |> json(%{thread_types: Enum.map(types, &type_json/1)})
  end

  def show(conn, %{"slug" => slug}) do
    case ThreadTypes.get_thread_type_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "thread type not found"})

      type ->
        conn |> json(%{thread_type: type_json(type)})
    end
  end

  def list_answers(conn, %{"thread_id" => thread_id}) do
    answers = ThreadTypes.get_answers(thread_id)

    conn
    |> json(%{
      answers:
        Enum.map(answers, fn a ->
          %{
            id: a.id,
            post_id: a.post_id,
            is_accepted: a.is_accepted,
            vote_count: a.vote_count,
            accepted_at: a.accepted_at
          }
        end)
    })
  end

  def debate_positions(conn, %{"thread_id" => thread_id}) do
    positions = ThreadTypes.get_positions(thread_id)
    counts = ThreadTypes.get_position_counts(thread_id)

    conn
    |> json(%{
      positions:
        Enum.map(positions, fn p ->
          %{id: p.id, user_id: p.user_id, position: p.position, inserted_at: p.inserted_at}
        end),
      counts: counts
    })
  end

  def ama_session(conn, %{"thread_id" => thread_id}) do
    case ThreadTypes.get_ama_session(thread_id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "no AMA session for thread"})

      session ->
        conn
        |> json(%{
          ama_session:
            Map.take(session, [:id, :thread_id, :status, :host_id, :starts_at, :ends_at])
        })
    end
  end

  def marketplace_listing(conn, %{"thread_id" => thread_id}) do
    case ThreadTypes.get_listing(thread_id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "no marketplace listing for thread"})

      listing ->
        conn
        |> json(%{listing: Map.from_struct(listing) |> Map.drop([:__meta__, :thread, :seller])})
    end
  end

  def wiki_edits(conn, %{"thread_id" => thread_id}) do
    edits = ThreadTypes.get_wiki_edits(thread_id)
    latest = ThreadTypes.get_latest_wiki_content(thread_id)

    conn
    |> json(%{
      edits:
        Enum.map(edits, fn e ->
          %{
            id: e.id,
            editor_id: e.editor_id,
            edit_summary: e.edit_summary,
            revision_number: e.revision_number,
            inserted_at: e.inserted_at
          }
        end),
      latest_content: latest
    })
  end

  defp type_json(t) do
    %{
      id: t.id,
      name: t.name,
      slug: t.slug,
      label: t.label,
      icon: t.icon,
      description: t.description,
      is_builtin: t.is_builtin,
      is_active: t.is_active,
      position: t.position
    }
  end
end
