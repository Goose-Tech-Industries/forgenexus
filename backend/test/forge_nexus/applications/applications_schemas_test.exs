defmodule ForgeNexus.Applications.ApplicationsSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Applications.{ApplicationForm, StaffApplication}

  describe "ApplicationForm" do
    test "valid changeset" do
      cs =
        ApplicationForm.changeset(%ApplicationForm{}, %{
          title: "Moderator Application 2026",
          description: "Apply to be a community moderator",
          fields: [%{"type" => "text", "label" => "Why do you want to join?"}]
        })

      assert cs.valid?
      assert get_field(cs, :title) == "Moderator Application 2026"

      req_cs = ApplicationForm.changeset(%ApplicationForm{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).title
    end
  end

  describe "StaffApplication" do
    @fid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset and status inclusions" do
      for status <- ~w(pending under_review accepted denied) do
        cs =
          StaffApplication.changeset(%StaffApplication{}, %{
            form_id: @fid,
            user_id: @uid,
            answers: [%{"question" => "Why?", "answer" => "I love the community"}],
            status: status
          })

        assert cs.valid?
        assert get_field(cs, :status) == status
      end

      req_cs = StaffApplication.changeset(%StaffApplication{}, %{answers: nil})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).form_id
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).answers

      bad_status_cs =
        StaffApplication.changeset(%StaffApplication{}, %{
          form_id: @fid,
          user_id: @uid,
          answers: [%{}],
          status: "hired"
        })

      refute bad_status_cs.valid?
      assert "is invalid" in errors_on(bad_status_cs).status
    end
  end
end
