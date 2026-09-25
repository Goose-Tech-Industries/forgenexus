defmodule ForgeNexus.Settings.SiteSettingSchemaTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Settings.SiteSetting

  describe "SiteSetting" do
    test "valid changeset" do
      cs =
        SiteSetting.changeset(%SiteSetting{}, %{
          key: "site_name",
          value: "ForgeNexus",
          value_type: "string"
        })

      assert cs.valid?
      assert get_field(cs, :key) == "site_name"

      req_cs = SiteSetting.changeset(%SiteSetting{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).key
    end
  end
end
