defmodule ForgeNexus.GovernanceTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Governance

  alias ForgeNexus.Governance.{
    Proposal,
    ProposalVote,
    ProposalComment,
    Election,
    ElectionCandidate
  }

  alias ForgeNexus.Accounts

  defp create_user do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "gov_u_#{unique}",
        email: "gov_u_#{unique}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp proposal_attrs(author_id, attrs) do
    unique = System.unique_integer([:positive])

    Enum.into(attrs, %{
      title: "Proposal #{unique}",
      body: "Description of the community proposal",
      type: "rule_change",
      status: "discussion",
      author_id: author_id
    })
  end

  describe "proposals CRUD, listing, pagination, and withdrawal" do
    test "create, get, list_proposals with status/type/pagination filters, update, and withdraw" do
      user = create_user()

      assert {:ok, %Proposal{} = p1} =
               Governance.create_proposal(
                 proposal_attrs(user.id, %{type: "feature", status: "discussion"})
               )

      assert {:ok, %Proposal{} = p2} =
               Governance.create_proposal(
                 proposal_attrs(user.id, %{type: "rule_change", status: "voting"})
               )

      assert %Proposal{id: id} = Governance.get_proposal!(p1.id)
      assert id == p1.id

      # List all
      all = Governance.list_proposals()
      ids = Enum.map(all, & &1.id)
      assert p1.id in ids
      assert p2.id in ids

      # Filter by status
      voting = Governance.list_proposals(%{status: "voting"})
      assert Enum.map(voting, & &1.id) == [p2.id]

      # Filter by type
      features = Governance.list_proposals(%{type: "feature"})
      assert Enum.map(features, & &1.id) == [p1.id]

      # Pagination
      paged = Governance.list_proposals(%{page: 1, per_page: 1})
      assert length(paged) == 1

      # Update
      assert {:ok, updated} = Governance.update_proposal(p1, %{title: "Updated Title"})
      assert updated.title == "Updated Title"

      # Withdraw
      assert {:ok, withdrawn} = Governance.withdraw_proposal(p1)
      assert withdrawn.status == "withdrawn"
    end
  end

  describe "voting on proposals" do
    test "cast_vote, get_user_vote, and get_vote_results" do
      author = create_user()
      voter1 = create_user()
      voter2 = create_user()
      voter3 = create_user()

      {:ok, proposal} = Governance.create_proposal(proposal_attrs(author.id, %{status: "voting"}))

      assert {:ok, %ProposalVote{}} = Governance.cast_vote(proposal.id, voter1.id, "yes")
      assert {:ok, %ProposalVote{}} = Governance.cast_vote(proposal.id, voter2.id, "no")
      assert {:ok, %ProposalVote{}} = Governance.cast_vote(proposal.id, voter3.id, "abstain")

      # Check user vote
      vote1 = Governance.get_user_vote(proposal.id, voter1.id)
      assert vote1.vote == "yes"

      # Voter 1 changes vote to no
      assert {:ok, %ProposalVote{}} = Governance.cast_vote(proposal.id, voter1.id, "no")

      results = Governance.get_vote_results(proposal.id)
      assert results.yes == 0
      assert results.no == 2
      assert results.abstain == 1
      assert results.total == 3
    end
  end

  describe "comments on proposals" do
    test "create_comment and list_comments" do
      author = create_user()
      commenter = create_user()
      {:ok, proposal} = Governance.create_proposal(proposal_attrs(author.id, %{}))

      assert {:ok, %ProposalComment{} = comment} =
               Governance.create_comment(%{
                 proposal_id: proposal.id,
                 user_id: commenter.id,
                 body: "I support this proposal!"
               })

      assert comment.body == "I support this proposal!"

      comments = Governance.list_comments(proposal.id)
      assert length(comments) == 1
      assert hd(comments).user.id == commenter.id
    end
  end

  describe "check_proposal_status/1 status transitions" do
    test "transitions from discussion to voting when discussion_ends_at is past" do
      author = create_user()
      past_time = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      {:ok, proposal} =
        Governance.create_proposal(
          proposal_attrs(author.id, %{
            status: "discussion",
            discussion_ends_at: past_time
          })
        )

      assert {:ok, updated} = Governance.check_proposal_status(proposal)
      assert updated.status == "voting"
    end

    test "resolves voting to passed when simple majority threshold met" do
      author = create_user()
      voter = create_user()
      past_time = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      {:ok, proposal} =
        Governance.create_proposal(
          proposal_attrs(author.id, %{
            status: "voting",
            voting_ends_at: past_time,
            threshold_type: "simple_majority"
          })
        )

      {:ok, _} = Governance.cast_vote(proposal.id, voter.id, "yes")
      reloaded = Governance.get_proposal!(proposal.id)

      assert {:ok, updated} = Governance.check_proposal_status(reloaded)
      assert updated.status == "passed"
      assert String.contains?(updated.result_summary, "Yes: 1")
    end

    test "resolves voting to failed when two_thirds threshold not met" do
      author = create_user()
      voter1 = create_user()
      voter2 = create_user()
      past_time = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      {:ok, proposal} =
        Governance.create_proposal(
          proposal_attrs(author.id, %{
            status: "voting",
            voting_ends_at: past_time,
            threshold_type: "two_thirds",
            min_participation: 2
          })
        )

      {:ok, _} = Governance.cast_vote(proposal.id, voter1.id, "yes")
      {:ok, _} = Governance.cast_vote(proposal.id, voter2.id, "no")
      reloaded = Governance.get_proposal!(proposal.id)

      assert {:ok, updated} = Governance.check_proposal_status(reloaded)
      assert updated.status == "failed"
    end
  end

  describe "elections workflow" do
    test "create_election, nominate_candidate, accept, vote, and get_election_results" do
      author = create_user()
      cand1_user = create_user()
      cand2_user = create_user()
      voter = create_user()

      {:ok, proposal} = Governance.create_proposal(proposal_attrs(author.id, %{}))

      assert {:ok, %Election{} = election} =
               Governance.create_election(%{
                 position: "Moderator",
                 max_winners: 1,
                 proposal_id: proposal.id
               })

      assert {:ok, %ElectionCandidate{} = c1} =
               Governance.nominate_candidate(%{
                 election_id: election.id,
                 user_id: cand1_user.id,
                 nominated_by_id: author.id,
                 platform: "More transparency"
               })

      assert {:ok, %ElectionCandidate{} = c2} =
               Governance.nominate_candidate(%{
                 election_id: election.id,
                 user_id: cand2_user.id,
                 nominated_by_id: author.id,
                 platform: "Better events"
               })

      # Both candidates accept nominations
      assert {:ok, c1_accepted} = Governance.accept_nomination(c1)
      assert {:ok, c2_accepted} = Governance.accept_nomination(c2)
      assert c1_accepted.is_accepted
      assert c2_accepted.is_accepted

      # Vote for c1 twice
      assert {:ok, voted_c1} = Governance.vote_for_candidate(c1_accepted, voter.id)
      assert {:ok, voted_c1_again} = Governance.vote_for_candidate(voted_c1, voter.id)
      assert voted_c1_again.vote_count == 2

      # Get results
      results = Governance.get_election_results(election.id)
      assert length(results.candidates) == 2
      assert length(results.winners) == 1
      assert hd(results.winners).id == c1.id
    end
  end
end
