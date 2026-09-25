defmodule ForgeNexus.UserStats.UserStatSchemaTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.UserStats.UserStat

  describe "UserStat" do
    @uid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        UserStat.changeset(%UserStat{}, %{
          user_id: @uid,
          stat_key: "posts_count",
          value: 42.0,
          min_value: 0.0,
          max_value: 1000.0
        })

      assert cs.valid?
      assert get_field(cs, :stat_key) == "posts_count"
      assert get_field(cs, :value) == 42.0

      req_cs = UserStat.changeset(%UserStat{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).stat_key
    end
  end
end
