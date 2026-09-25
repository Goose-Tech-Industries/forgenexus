defmodule ForgeNexus.AutoMod.AutoModSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.AutoMod.AutoModRule

  describe "AutoModRule" do
    test "valid changeset and inclusions" do
      for rtype <- ~w(keyword spam regex rate_limit custom) do
        for act <- ~w(flag warn delete mute ban) do
          cs =
            AutoModRule.changeset(%AutoModRule{}, %{
              name: "Rule #{rtype}",
              rule_type: rtype,
              action: act
            })

          assert cs.valid?
          assert get_field(cs, :rule_type) == rtype
          assert get_field(cs, :action) == act
        end
      end

      req_cs = AutoModRule.changeset(%AutoModRule{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).rule_type

      bad_cs =
        AutoModRule.changeset(%AutoModRule{}, %{
          name: "Test",
          rule_type: "magic",
          action: "obliterate"
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).rule_type
      assert "is invalid" in errors_on(bad_cs).action
    end
  end
end
