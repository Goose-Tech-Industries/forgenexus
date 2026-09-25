defmodule ForgeNexus.ThreadTypes.ThreadTypesSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.ThreadTypes.{
    AmaSession,
    AnswerVote,
    DebatePosition,
    MarketplaceListing,
    ThreadAnswer,
    ThreadType,
    WikiEdit
  }

  describe "AmaSession" do
    @tid Ecto.UUID.generate()
    @hid Ecto.UUID.generate()

    test "valid changeset and status inclusions" do
      for status <- ["upcoming", "live", "ended"] do
        cs =
          AmaSession.changeset(%AmaSession{}, %{
            title: "Ask Me Anything!",
            thread_id: @tid,
            host_id: @hid,
            status: status
          })

        assert cs.valid?
        assert get_field(cs, :status) == status
      end

      req_cs = AmaSession.changeset(%AmaSession{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).title
      assert "can't be blank" in errors_on(req_cs).thread_id
      assert "can't be blank" in errors_on(req_cs).host_id

      bad_status_cs =
        AmaSession.changeset(%AmaSession{}, %{
          title: "AMA",
          thread_id: @tid,
          host_id: @hid,
          status: "postponed"
        })

      refute bad_status_cs.valid?
      assert "is invalid" in errors_on(bad_status_cs).status
    end
  end

  describe "AnswerVote" do
    @taid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset with 1 and -1" do
      for val <- [1, -1] do
        cs =
          AnswerVote.changeset(%AnswerVote{}, %{
            value: val,
            thread_answer_id: @taid,
            user_id: @uid
          })

        assert cs.valid?
        assert get_field(cs, :value) == val
      end

      req_cs = AnswerVote.changeset(%AnswerVote{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).value
      assert "can't be blank" in errors_on(req_cs).thread_answer_id
      assert "can't be blank" in errors_on(req_cs).user_id

      bad_val_cs =
        AnswerVote.changeset(%AnswerVote{}, %{
          value: 2,
          thread_answer_id: @taid,
          user_id: @uid
        })

      refute bad_val_cs.valid?
      assert "is invalid" in errors_on(bad_val_cs).value
    end
  end

  describe "DebatePosition" do
    @tid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset and side inclusions" do
      for side <- ["pro", "con", "neutral"] do
        cs =
          DebatePosition.changeset(%DebatePosition{}, %{
            side: side,
            thread_id: @tid,
            user_id: @uid
          })

        assert cs.valid?
        assert get_field(cs, :side) == side
      end

      req_cs = DebatePosition.changeset(%DebatePosition{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).side
      assert "can't be blank" in errors_on(req_cs).thread_id
      assert "can't be blank" in errors_on(req_cs).user_id

      bad_side_cs =
        DebatePosition.changeset(%DebatePosition{}, %{
          side: "abstain",
          thread_id: @tid,
          user_id: @uid
        })

      refute bad_side_cs.valid?
      assert "is invalid" in errors_on(bad_side_cs).side
    end
  end

  describe "MarketplaceListing" do
    @tid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset and inclusions" do
      for cond <- ["new", "like_new", "good", "fair", "poor"] do
        for status <- ["available", "pending", "sold", "withdrawn"] do
          cs =
            MarketplaceListing.changeset(%MarketplaceListing{}, %{
              price: Decimal.new("49.99"),
              condition: cond,
              status: status,
              thread_id: @tid,
              user_id: @uid
            })

          assert cs.valid?
          assert get_field(cs, :condition) == cond
          assert get_field(cs, :status) == status
        end
      end

      req_cs = MarketplaceListing.changeset(%MarketplaceListing{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).price
      assert "can't be blank" in errors_on(req_cs).condition
      assert "can't be blank" in errors_on(req_cs).thread_id
      assert "can't be blank" in errors_on(req_cs).user_id

      bad_cs =
        MarketplaceListing.changeset(%MarketplaceListing{}, %{
          price: Decimal.new("10.00"),
          condition: "broken",
          status: "lost",
          thread_id: @tid,
          user_id: @uid
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).condition
      assert "is invalid" in errors_on(bad_cs).status
    end
  end

  describe "ThreadAnswer" do
    @tid Ecto.UUID.generate()
    @pid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        ThreadAnswer.changeset(%ThreadAnswer{}, %{
          thread_id: @tid,
          post_id: @pid,
          is_accepted: true,
          vote_count: 10
        })

      assert cs.valid?
      assert get_field(cs, :is_accepted) == true

      req_cs = ThreadAnswer.changeset(%ThreadAnswer{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).thread_id
      assert "can't be blank" in errors_on(req_cs).post_id
    end
  end

  describe "ThreadType" do
    test "valid changeset" do
      cs =
        ThreadType.changeset(%ThreadType{}, %{
          name: "Question & Answer",
          slug: "qa",
          label: "Q&A",
          icon: "help-circle",
          description: "Ask a question and get answers from the community",
          is_active: true
        })

      assert cs.valid?
      assert get_field(cs, :slug) == "qa"

      req_cs = ThreadType.changeset(%ThreadType{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).slug
      assert "can't be blank" in errors_on(req_cs).label
    end
  end

  describe "WikiEdit" do
    @tid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        WikiEdit.changeset(%WikiEdit{}, %{
          body: "Updated wiki content",
          body_html: "<p>Updated wiki content</p>",
          edit_summary: "Fixed typo",
          revision_number: 2,
          thread_id: @tid,
          user_id: @uid
        })

      assert cs.valid?
      assert get_field(cs, :revision_number) == 2

      req_cs = WikiEdit.changeset(%WikiEdit{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).body
      assert "can't be blank" in errors_on(req_cs).revision_number
      assert "can't be blank" in errors_on(req_cs).thread_id
      assert "can't be blank" in errors_on(req_cs).user_id
    end
  end
end
