defmodule ForgeNexus.Governance do
  @moduledoc """
  The Governance context. Manages proposals, voting, comments, and elections.
  """

  import Ecto.Query, warn: false
  alias ForgeNexus.Repo

  alias ForgeNexus.Governance.{
    Proposal,
    ProposalVote,
    ProposalComment,
    Election,
    ElectionCandidate
  }

  # ── Proposals ──

  def list_proposals(opts \\ %{}) do
    Proposal
    |> maybe_filter_status(opts[:status])
    |> maybe_filter_type(opts[:type])
    |> order_by([p], desc: p.inserted_at)
    |> maybe_paginate(opts[:page], opts[:per_page])
    |> Repo.all()
  end

  defp maybe_filter_status(query, nil), do: query

  defp maybe_filter_status(query, status) do
    where(query, [p], p.status == ^status)
  end

  defp maybe_filter_type(query, nil), do: query

  defp maybe_filter_type(query, type) do
    where(query, [p], p.type == ^type)
  end

  defp maybe_paginate(query, nil, _), do: query

  defp maybe_paginate(query, page, per_page) do
    per_page = per_page || 20
    offset = (page - 1) * per_page

    query
    |> limit(^per_page)
    |> offset(^offset)
  end

  def get_proposal!(id) do
    Proposal
    |> Repo.get!(id)
    |> Repo.preload([:author])
  end

  def create_proposal(attrs \\ %{}) do
    %Proposal{}
    |> Proposal.changeset(attrs)
    |> Repo.insert()
  end

  def update_proposal(%Proposal{} = proposal, attrs) do
    proposal
    |> Proposal.changeset(attrs)
    |> Repo.update()
  end

  def withdraw_proposal(%Proposal{} = proposal) do
    proposal
    |> Proposal.changeset(%{status: "withdrawn"})
    |> Repo.update()
  end

  # ── Voting ──

  def cast_vote(proposal_id, user_id, vote) do
    case Repo.get_by(ProposalVote, proposal_id: proposal_id, user_id: user_id) do
      nil ->
        %ProposalVote{}
        |> ProposalVote.changeset(%{proposal_id: proposal_id, user_id: user_id, vote: vote})
        |> Repo.insert()

      existing ->
        existing
        |> ProposalVote.changeset(%{vote: vote})
        |> Repo.update()
    end
    |> case do
      {:ok, vote_record} ->
        update_vote_counts(proposal_id)
        {:ok, vote_record}

      error ->
        error
    end
  end

  defp update_vote_counts(proposal_id) do
    counts =
      ProposalVote
      |> where([v], v.proposal_id == ^proposal_id)
      |> group_by([v], v.vote)
      |> select([v], {v.vote, count(v.id)})
      |> Repo.all()
      |> Map.new()

    Repo.get!(Proposal, proposal_id)
    |> Proposal.changeset(%{
      yes_count: Map.get(counts, "yes", 0),
      no_count: Map.get(counts, "no", 0),
      abstain_count: Map.get(counts, "abstain", 0)
    })
    |> Repo.update()
  end

  def get_user_vote(proposal_id, user_id) do
    Repo.get_by(ProposalVote, proposal_id: proposal_id, user_id: user_id)
  end

  def get_vote_results(proposal_id) do
    proposal = Repo.get!(Proposal, proposal_id)

    %{
      yes: proposal.yes_count,
      no: proposal.no_count,
      abstain: proposal.abstain_count,
      total: proposal.yes_count + proposal.no_count + proposal.abstain_count
    }
  end

  # ── Comments ──

  def list_comments(proposal_id) do
    ProposalComment
    |> where([c], c.proposal_id == ^proposal_id)
    |> order_by([c], asc: c.inserted_at)
    |> preload(:user)
    |> Repo.all()
  end

  def create_comment(attrs \\ %{}) do
    %ProposalComment{}
    |> ProposalComment.changeset(attrs)
    |> Repo.insert()
  end

  # ── Status Transitions ──

  def check_proposal_status(%Proposal{} = proposal) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    cond do
      proposal.status == "discussion" && proposal.discussion_ends_at &&
          DateTime.compare(now, proposal.discussion_ends_at) == :gt ->
        update_proposal(proposal, %{status: "voting"})

      proposal.status == "voting" && proposal.voting_ends_at &&
          DateTime.compare(now, proposal.voting_ends_at) == :gt ->
        total_votes = proposal.yes_count + proposal.no_count + proposal.abstain_count
        min_met = is_nil(proposal.min_participation) || total_votes >= proposal.min_participation

        passed =
          case proposal.threshold_type do
            "simple_majority" ->
              proposal.yes_count > proposal.no_count && min_met

            "two_thirds" ->
              proposal.yes_count >= (total_votes - proposal.abstain_count) * 2 / 3 && min_met

            _ ->
              proposal.yes_count > proposal.no_count && min_met
          end

        new_status = if passed, do: "passed", else: "failed"

        result =
          "Yes: #{proposal.yes_count}, No: #{proposal.no_count}, Abstain: #{proposal.abstain_count}"

        update_proposal(proposal, %{status: new_status, result_summary: result})

      true ->
        {:ok, proposal}
    end
  end

  # ── Elections ──

  def create_election(attrs \\ %{}) do
    %Election{}
    |> Election.changeset(attrs)
    |> Repo.insert()
  end

  def nominate_candidate(attrs \\ %{}) do
    %ElectionCandidate{}
    |> ElectionCandidate.changeset(attrs)
    |> Repo.insert()
  end

  def accept_nomination(%ElectionCandidate{} = candidate) do
    candidate
    |> ElectionCandidate.changeset(%{is_accepted: true})
    |> Repo.update()
  end

  def vote_for_candidate(%ElectionCandidate{} = candidate, _user_id) do
    candidate
    |> ElectionCandidate.changeset(%{vote_count: candidate.vote_count + 1})
    |> Repo.update()
  end

  def get_election_results(election_id) do
    election = Repo.get!(Election, election_id) |> Repo.preload(:candidates)

    candidates =
      election.candidates
      |> Enum.filter(& &1.is_accepted)
      |> Enum.sort_by(& &1.vote_count, :desc)

    winners = Enum.take(candidates, election.max_winners)

    %{
      election: election,
      candidates: candidates,
      winners: winners
    }
  end
end
