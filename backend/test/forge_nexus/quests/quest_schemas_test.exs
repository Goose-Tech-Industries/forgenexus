defmodule ForgeNexus.Quests.QuestSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Quests.{Quest, UserQuest}

  describe "Quest" do
    test "valid changeset and quest_type inclusions" do
      for qtype <- ~w(standard daily weekly chain) do
        cs =
          Quest.changeset(%Quest{}, %{
            name: "Tutorial Quest",
            quest_type: qtype,
            steps: [%{"task" => "Create profile"}]
          })

        assert cs.valid?
        assert get_field(cs, :quest_type) == qtype
      end

      req_cs = Quest.changeset(%Quest{}, %{steps: nil})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).steps

      bad_type_cs =
        Quest.changeset(%Quest{}, %{
          name: "Quest",
          quest_type: "impossible",
          steps: [%{}]
        })

      refute bad_type_cs.valid?
      assert "is invalid" in errors_on(bad_type_cs).quest_type
    end
  end

  describe "UserQuest" do
    @uid Ecto.UUID.generate()
    @qid Ecto.UUID.generate()

    test "valid changeset and status inclusions" do
      for status <- ~w(active completed abandoned failed) do
        cs =
          UserQuest.changeset(%UserQuest{}, %{
            user_id: @uid,
            quest_id: @qid,
            status: status
          })

        assert cs.valid?
        assert get_field(cs, :status) == status
      end

      req_cs = UserQuest.changeset(%UserQuest{}, %{status: nil})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).quest_id
      assert "can't be blank" in errors_on(req_cs).status

      bad_status_cs =
        UserQuest.changeset(%UserQuest{}, %{
          user_id: @uid,
          quest_id: @qid,
          status: "destroyed"
        })

      refute bad_status_cs.valid?
      assert "is invalid" in errors_on(bad_status_cs).status
    end
  end
end
