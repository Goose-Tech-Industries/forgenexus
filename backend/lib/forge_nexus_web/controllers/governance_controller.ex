defmodule ForgeNexusWeb.GovernanceController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Governance

  def index(conn, params) do
    proposals = Governance.list_proposals(params)

    conn
    |> json(%{proposals: Enum.map(proposals, &proposal_json/1)})
  end

  def show(conn, %{"id" => id}) do
    case safe_get(fn -> Governance.get_proposal!(id) end) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "proposal not found"})

      proposal ->
        results = Governance.get_vote_results(id)
        conn |> json(%{proposal: proposal_json(proposal, detailed: true), results: results})
    end
  end

  def comments(conn, %{"id" => id}) do
    comments = Governance.list_comments(id)

    conn
    |> json(%{
      comments:
        Enum.map(comments, fn c ->
          %{
            id: c.id,
            body: Map.get(c, :body),
            author_id: Map.get(c, :author_id),
            inserted_at: c.inserted_at
          }
        end)
    })
  end

  def show_election(conn, %{"id" => id}) do
    results = Governance.get_election_results(id)
    conn |> json(%{election_id: id, results: results})
  end

  defp safe_get(fun) do
    fun.()
  rescue
    Ecto.NoResultsError -> nil
  end

  defp proposal_json(p, opts \\ []) do
    base = %{
      id: p.id,
      title: p.title,
      type: p.type,
      status: p.status,
      yes_count: p.yes_count,
      no_count: p.no_count,
      abstain_count: p.abstain_count,
      voting_starts_at: p.voting_starts_at,
      voting_ends_at: p.voting_ends_at,
      is_binding: p.is_binding,
      author_id: p.author_id,
      inserted_at: p.inserted_at
    }

    if Keyword.get(opts, :detailed, false) do
      Map.merge(base, %{body: p.body, body_html: p.body_html, result_summary: p.result_summary})
    else
      base
    end
  end
end
