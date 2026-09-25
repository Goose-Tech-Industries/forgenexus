defmodule ForgeNexus.Governance.GovernanceSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Governance.{
    Election,
    ElectionCandidate,
    Proposal,
    ProposalComment,
    ProposalVote
  }

  describe "Proposal" do
    @uid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        Proposal.changeset(%Proposal{}, %{
          title: "Community Guidelines Update",
          body: "Proposal body text",
          type: "policy",
          author_id: @uid,
          status: "voting"
        })

      assert cs.valid?
      assert get_field(cs, :title) == "Community Guidelines Update"

      req_cs = Proposal.changeset(%Proposal{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).title
      assert "can't be blank" in errors_on(req_cs).body
      assert "can't be blank" in errors_on(req_cs).type
      assert "can't be blank" in errors_on(req_cs).author_id
    end
  end

  describe "Election" do
    @pid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        Election.changeset(%Election{}, %{
          position: "Lead Moderator",
          proposal_id: @pid,
          max_winners: 2
        })

      assert cs.valid?
      assert get_field(cs, :position) == "Lead Moderator"

      req_cs = Election.changeset(%Election{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).position
      assert "can't be blank" in errors_on(req_cs).proposal_id
    end
  end

  describe "ElectionCandidate" do
    @eid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        ElectionCandidate.changeset(%ElectionCandidate{}, %{
          election_id: @eid,
          user_id: @uid,
          platform: "Fair moderation for everyone",
          is_accepted: true
        })

      assert cs.valid?
      assert get_field(cs, :platform) == "Fair moderation for everyone"

      req_cs = ElectionCandidate.changeset(%ElectionCandidate{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).election_id
      assert "can't be blank" in errors_on(req_cs).user_id
    end
  end

  describe "ProposalComment" do
    @pid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        ProposalComment.changeset(%ProposalComment{}, %{
          body: "I fully support this proposal",
          proposal_id: @pid,
          user_id: @uid
        })

      assert cs.valid?
      assert get_field(cs, :body) == "I fully support this proposal"

      req_cs = ProposalComment.changeset(%ProposalComment{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).body
      assert "can't be blank" in errors_on(req_cs).proposal_id
      assert "can't be blank" in errors_on(req_cs).user_id
    end
  end

  describe "ProposalVote" do
    @pid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset and vote inclusions" do
      for vote <- ["yes", "no", "abstain"] do
        cs =
          ProposalVote.changeset(%ProposalVote{}, %{
            vote: vote,
            proposal_id: @pid,
            user_id: @uid
          })

        assert cs.valid?
        assert get_field(cs, :vote) == vote
      end

      req_cs = ProposalVote.changeset(%ProposalVote{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).vote
      assert "can't be blank" in errors_on(req_cs).proposal_id
      assert "can't be blank" in errors_on(req_cs).user_id

      bad_vote_cs =
        ProposalVote.changeset(%ProposalVote{}, %{
          vote: "maybe",
          proposal_id: @pid,
          user_id: @uid
        })

      refute bad_vote_cs.valid?
      assert "is invalid" in errors_on(bad_vote_cs).vote
    end
  end
end
