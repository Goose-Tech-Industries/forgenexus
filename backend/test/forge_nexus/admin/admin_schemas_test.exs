defmodule ForgeNexus.Admin.AdminSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Admin.{Announcement, AuditLog}

  describe "Announcement" do
    test "valid changeset and display_location inclusions" do
      for loc <- ~w(banner forum all) do
        cs =
          Announcement.changeset(%Announcement{}, %{
            title: "Maintenance Notice",
            body: "Server maintenance scheduled tonight",
            display_location: loc
          })

        assert cs.valid?
        assert get_field(cs, :display_location) == loc
      end

      req_cs = Announcement.changeset(%Announcement{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).title
      assert "can't be blank" in errors_on(req_cs).body

      bad_loc_cs =
        Announcement.changeset(%Announcement{}, %{
          title: "Title",
          body: "Body",
          display_location: "popup"
        })

      refute bad_loc_cs.valid?
      assert "is invalid" in errors_on(bad_loc_cs).display_location
    end
  end

  describe "AuditLog" do
    @aid Ecto.UUID.generate()
    @tid Ecto.UUID.generate()

    test "valid changeset, rollback_changeset and category inclusions" do
      for cat <- ~w(settings forums plugins themes permissions) do
        cs =
          AuditLog.changeset(%AuditLog{}, %{
            action: "update_theme",
            category: cat,
            admin_id: @aid,
            target_type: "theme",
            target_id: @tid
          })

        assert cs.valid?
        assert get_field(cs, :category) == cat
      end

      # Rollback changeset
      now = ~U[2026-03-01 12:00:00Z]

      rb_cs =
        AuditLog.rollback_changeset(%AuditLog{}, %{
          is_rolled_back: true,
          rolled_back_at: now,
          rolled_back_by_id: @aid
        })

      assert rb_cs.valid?
      assert get_field(rb_cs, :is_rolled_back) == true

      # Required fields
      req_cs = AuditLog.changeset(%AuditLog{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).action
      assert "can't be blank" in errors_on(req_cs).category
      assert "can't be blank" in errors_on(req_cs).admin_id

      # Invalid category
      bad_cat_cs =
        AuditLog.changeset(%AuditLog{}, %{
          action: "action",
          category: "billing",
          admin_id: @aid
        })

      refute bad_cat_cs.valid?
      assert "is invalid" in errors_on(bad_cat_cs).category
    end
  end
end
