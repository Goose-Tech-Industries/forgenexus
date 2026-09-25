defmodule ForgeNexus.Verification.VerificationSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Verification.{Challenge, OnboardingChecklist}

  describe "Challenge" do
    @uid Ecto.UUID.generate()

    test "valid changeset and inclusions" do
      for ctype <- ~w(math_captcha text_captcha email_verify question) do
        for status <- ~w(pending completed failed expired) do
          cs =
            Challenge.changeset(%Challenge{}, %{
              challenge_type: ctype,
              expected_answer: "42",
              user_id: @uid,
              status: status
            })

          assert cs.valid?
          assert get_field(cs, :challenge_type) == ctype
          assert get_field(cs, :status) == status
        end
      end

      req_cs = Challenge.changeset(%Challenge{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).challenge_type
      assert "can't be blank" in errors_on(req_cs).expected_answer
      assert "can't be blank" in errors_on(req_cs).user_id

      bad_cs =
        Challenge.changeset(%Challenge{}, %{
          challenge_type: "biometric",
          expected_answer: "pass",
          user_id: @uid,
          status: "cancelled"
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).challenge_type
      assert "is invalid" in errors_on(bad_cs).status
    end
  end

  describe "OnboardingChecklist" do
    @uid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        OnboardingChecklist.changeset(%OnboardingChecklist{}, %{
          user_id: @uid,
          tasks: [%{"id" => "avatar", "completed" => true}],
          is_complete: true
        })

      assert cs.valid?
      assert get_field(cs, :is_complete) == true

      req_cs = OnboardingChecklist.changeset(%OnboardingChecklist{}, %{tasks: nil})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).tasks
    end
  end
end
