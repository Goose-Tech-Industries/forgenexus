defmodule ForgeNexus.Workers.GovernanceWorker do
  use Oban.Worker, queue: :default, max_attempts: 1

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Governance.Proposal

  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now()

    # Transition discussion -> voting
    from(p in Proposal,
      where: p.status == "discussion" and p.voting_starts_at <= ^now
    )
    |> Repo.update_all(set: [status: "voting", updated_at: now])

    # Transition voting -> passed/failed
    expired_votes = from(p in Proposal,
      where: p.status == "voting" and p.voting_ends_at <= ^now
    ) |> Repo.all()

    Enum.each(expired_votes, fn proposal ->
      total_votes = proposal.yes_count + proposal.no_count + proposal.abstain_count
      meets_participation = total_votes >= proposal.min_participation

      passed = meets_participation && case proposal.threshold_type do
        "simple_majority" -> proposal.yes_count > proposal.no_count
        "two_thirds" -> proposal.yes_count >= (total_votes - proposal.abstain_count) * 2 / 3
        "three_quarters" -> proposal.yes_count >= (total_votes - proposal.abstain_count) * 3 / 4
        _ -> proposal.yes_count > proposal.no_count
      end

      status = if passed, do: "passed", else: "failed"
      summary = "Votes: #{proposal.yes_count} yes, #{proposal.no_count} no, #{proposal.abstain_count} abstain. #{if meets_participation, do: "Quorum met.", else: "Quorum not met."}"

      proposal
      |> Ecto.Changeset.change(%{status: status, result_summary: summary, updated_at: now})
      |> Repo.update()
    end)

    :ok
  end
end
