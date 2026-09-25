defmodule ForgeNexus.Moderation.ModerationSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Moderation.{
    Appeal,
    Ban,
    ContentPolicy,
    ImpersonationLog,
    ModNote,
    ModerationLog,
    QuarantineRecord,
    Reaction,
    Report,
    SoftBlock,
    SuspiciousAccount,
    Warning
  }

  describe "Appeal" do
    @uid Ecto.UUID.generate()
    @tid Ecto.UUID.generate()
    @rid Ecto.UUID.generate()

    test "valid changeset and review_changeset" do
      cs =
        Appeal.changeset(%Appeal{}, %{
          type: "ban",
          target_id: @tid,
          reason: "Misunderstanding in thread",
          user_id: @uid
        })

      assert cs.valid?
      assert get_field(cs, :type) == "ban"
      assert get_field(cs, :status) == "pending"

      review_cs =
        Appeal.review_changeset(cs, %{
          status: "approved",
          reviewer_id: @rid,
          decided_at: ~U[2026-03-01 12:00:00Z],
          decision_note: "Accepted after explanation"
        })

      assert review_cs.valid?
      assert get_field(review_cs, :status) == "approved"
      assert get_field(review_cs, :reviewer_id) == @rid
    end

    test "validates required fields and type inclusion" do
      cs = Appeal.changeset(%Appeal{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).type
      assert "can't be blank" in errors_on(cs).target_id
      assert "can't be blank" in errors_on(cs).reason
      assert "can't be blank" in errors_on(cs).user_id

      invalid_type_cs =
        Appeal.changeset(%Appeal{}, %{
          type: "mute",
          target_id: @tid,
          reason: "text",
          user_id: @uid
        })

      refute invalid_type_cs.valid?
      assert "is invalid" in errors_on(invalid_type_cs).type
    end

    test "review_changeset validates required fields and status inclusion" do
      cs = Appeal.review_changeset(%Appeal{}, %{status: nil})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).status
      assert "can't be blank" in errors_on(cs).reviewer_id
      assert "can't be blank" in errors_on(cs).decided_at

      # Explicit invalid status fails inclusion
      bad_status_cs =
        Appeal.review_changeset(%Appeal{}, %{
          status: "invalid_status",
          reviewer_id: @rid,
          decided_at: ~U[2026-03-01 12:00:00Z]
        })

      refute bad_status_cs.valid?
      assert "is invalid" in errors_on(bad_status_cs).status
    end
  end

  describe "Ban" do
    @uid Ecto.UUID.generate()

    test "valid changeset with default and custom types" do
      cs =
        Ban.changeset(%Ban{}, %{
          reason: "Severe spamming",
          banned_by_id: @uid
        })

      assert cs.valid?
      assert get_field(cs, :type) == "temporary"
      assert get_field(cs, :is_active) == true

      for type <- ["temporary", "permanent", "ip"] do
        type_cs =
          Ban.changeset(%Ban{}, %{
            reason: "Violations",
            banned_by_id: @uid,
            type: type
          })

        assert type_cs.valid?
        assert get_field(type_cs, :type) == type
      end
    end

    test "validates required fields and type inclusion" do
      cs = Ban.changeset(%Ban{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).reason
      assert "can't be blank" in errors_on(cs).banned_by_id

      invalid_cs =
        Ban.changeset(%Ban{}, %{
          reason: "Reason",
          banned_by_id: @uid,
          type: "shadowban"
        })

      refute invalid_cs.valid?
      assert "is invalid" in errors_on(invalid_cs).type
    end
  end

  describe "ContentPolicy" do
    test "valid changeset" do
      cs =
        ContentPolicy.changeset(%ContentPolicy{}, %{
          name: "Standard Safety Policy",
          description: "Rules for safe community posting",
          is_active: true,
          ai_moderation_enabled: true,
          rules: %{"toxicity_threshold" => 0.8},
          escalation_overrides: %{"auto_ban" => false}
        })

      assert cs.valid?
      assert get_field(cs, :name) == "Standard Safety Policy"
    end

    test "validates required name" do
      cs = ContentPolicy.changeset(%ContentPolicy{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).name
    end
  end

  describe "ImpersonationLog" do
    @admin_id Ecto.UUID.generate()
    @target_id Ecto.UUID.generate()

    test "valid changeset and end_changeset" do
      start_time = ~U[2026-03-01 10:00:00Z]

      cs =
        ImpersonationLog.changeset(%ImpersonationLog{}, %{
          admin_id: @admin_id,
          target_user_id: @target_id,
          reason: "Investigating bug report #42",
          started_at: start_time
        })

      assert cs.valid?
      assert get_field(cs, :reason) == "Investigating bug report #42"

      end_time = ~U[2026-03-01 10:30:00Z]
      end_cs = ImpersonationLog.end_changeset(cs, %{ended_at: end_time})
      assert end_cs.valid?
      assert get_field(end_cs, :ended_at) == end_time
    end

    test "validates required fields" do
      cs = ImpersonationLog.changeset(%ImpersonationLog{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).admin_id
      assert "can't be blank" in errors_on(cs).target_user_id
      assert "can't be blank" in errors_on(cs).reason
      assert "can't be blank" in errors_on(cs).started_at

      end_cs = ImpersonationLog.end_changeset(%ImpersonationLog{}, %{})
      refute end_cs.valid?
      assert "can't be blank" in errors_on(end_cs).ended_at
    end
  end

  describe "ModNote" do
    @uid Ecto.UUID.generate()
    @aid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        ModNote.changeset(%ModNote{}, %{
          body: "User agreed to calm down",
          user_id: @uid,
          author_id: @aid
        })

      assert cs.valid?
      assert get_field(cs, :body) == "User agreed to calm down"
    end

    test "validates required fields" do
      cs = ModNote.changeset(%ModNote{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).body
      assert "can't be blank" in errors_on(cs).user_id
      assert "can't be blank" in errors_on(cs).author_id
    end
  end

  describe "ModerationLog" do
    @tid Ecto.UUID.generate()
    @mid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        ModerationLog.changeset(%ModerationLog{}, %{
          action: "soft_block",
          reason: "Rule 1 breach",
          metadata: %{"post_length" => 250},
          target_type: "post",
          target_id: @tid,
          moderator_id: @mid
        })

      assert cs.valid?
      assert get_field(cs, :action) == "soft_block"
    end

    test "validates required fields" do
      cs = ModerationLog.changeset(%ModerationLog{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).action
      assert "can't be blank" in errors_on(cs).target_type
      assert "can't be blank" in errors_on(cs).target_id
      assert "can't be blank" in errors_on(cs).moderator_id
    end
  end

  describe "QuarantineRecord" do
    @uid Ecto.UUID.generate()
    @gid Ecto.UUID.generate()

    test "valid changeset" do
      now = DateTime.utc_now()

      cs =
        QuarantineRecord.changeset(%QuarantineRecord{}, %{
          user_id: @uid,
          quarantined_at: now,
          reason: "Suspected raid account",
          original_group_ids: [@gid]
        })

      assert cs.valid?
      assert get_field(cs, :reason) == "Suspected raid account"
    end

    test "validates required fields" do
      cs = QuarantineRecord.changeset(%QuarantineRecord{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).user_id
      assert "can't be blank" in errors_on(cs).quarantined_at
    end
  end

  describe "Reaction" do
    @uid Ecto.UUID.generate()
    @pid Ecto.UUID.generate()

    test "valid changeset with valid type and reactable_type" do
      for type <- ["like", "thanks", "haha", "wow", "sad", "angry"] do
        for rtype <- ["post", "message"] do
          cs =
            Reaction.changeset(%Reaction{}, %{
              type: type,
              reactable_type: rtype,
              reactable_id: @pid,
              user_id: @uid
            })

          assert cs.valid?
          assert get_field(cs, :type) == type
          assert get_field(cs, :reactable_type) == rtype
        end
      end
    end

    test "validates required fields and invalid inclusions" do
      cs = Reaction.changeset(%Reaction{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).reactable_type
      assert "can't be blank" in errors_on(cs).reactable_id
      assert "can't be blank" in errors_on(cs).user_id

      bad_type_cs =
        Reaction.changeset(%Reaction{}, %{
          type: "confused",
          reactable_type: "thread",
          reactable_id: @pid,
          user_id: @uid
        })

      refute bad_type_cs.valid?
      assert "is invalid" in errors_on(bad_type_cs).type
      assert "is invalid" in errors_on(bad_type_cs).reactable_type
    end
  end

  describe "Report" do
    @uid Ecto.UUID.generate()
    @pid Ecto.UUID.generate()
    @rid Ecto.UUID.generate()

    test "valid changeset, resolve_changeset, assign_changeset, and dismiss_changeset" do
      cs =
        Report.changeset(%Report{}, %{
          reason: "spam",
          description: "Advertises scam sites",
          reportable_type: "post",
          reportable_id: @pid,
          reporter_id: @uid
        })

      assert cs.valid?
      assert get_field(cs, :reason) == "spam"
      assert get_field(cs, :status) == "open"

      # Assign changeset
      assign_cs = Report.assign_changeset(cs, %{assigned_to_id: @rid})
      assert assign_cs.valid?
      assert get_field(assign_cs, :assigned_to_id) == @rid

      # Resolve changeset
      resolve_cs =
        Report.resolve_changeset(cs, %{
          resolver_id: @rid,
          resolution_note: "Post was removed"
        })

      assert resolve_cs.valid?
      assert get_change(resolve_cs, :status) == "resolved"
      assert %DateTime{} = get_change(resolve_cs, :resolved_at)
      assert get_field(resolve_cs, :resolution_note) == "Post was removed"

      # Dismiss changeset
      dismiss_cs =
        Report.dismiss_changeset(cs, %{
          resolver_id: @rid,
          resolution_note: "False report"
        })

      assert dismiss_cs.valid?
      assert get_change(dismiss_cs, :status) == "dismissed"
      assert %DateTime{} = get_change(dismiss_cs, :resolved_at)
    end

    test "validates required fields and reason inclusion" do
      cs = Report.changeset(%Report{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).reason
      assert "can't be blank" in errors_on(cs).reportable_type
      assert "can't be blank" in errors_on(cs).reportable_id
      assert "can't be blank" in errors_on(cs).reporter_id

      bad_reason_cs =
        Report.changeset(%Report{}, %{
          reason: "boring",
          reportable_type: "post",
          reportable_id: @pid,
          reporter_id: @uid
        })

      refute bad_reason_cs.valid?
      assert "is invalid" in errors_on(bad_reason_cs).reason
    end

    test "resolve and dismiss require resolver_id" do
      res_cs = Report.resolve_changeset(%Report{}, %{})
      refute res_cs.valid?
      assert "can't be blank" in errors_on(res_cs).resolver_id

      dis_cs = Report.dismiss_changeset(%Report{}, %{})
      refute dis_cs.valid?
      assert "can't be blank" in errors_on(dis_cs).resolver_id
    end
  end

  describe "SoftBlock" do
    @pid Ecto.UUID.generate()
    @mid Ecto.UUID.generate()
    @aid Ecto.UUID.generate()

    test "valid changeset with valid status" do
      for status <- ~w(pending edited expired deleted) do
        cs =
          SoftBlock.changeset(%SoftBlock{}, %{
            post_id: @pid,
            moderator_id: @mid,
            author_id: @aid,
            reason: "Needs tone adjustment",
            rule_violated: "Be civil",
            expires_at: ~U[2026-04-01 00:00:00Z],
            status: status
          })

        assert cs.valid?
        assert get_field(cs, :status) == status
      end
    end

    test "validates required fields and invalid status" do
      cs = SoftBlock.changeset(%SoftBlock{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).post_id
      assert "can't be blank" in errors_on(cs).moderator_id
      assert "can't be blank" in errors_on(cs).author_id
      assert "can't be blank" in errors_on(cs).reason
      assert "can't be blank" in errors_on(cs).expires_at

      bad_status_cs =
        SoftBlock.changeset(%SoftBlock{}, %{
          post_id: @pid,
          moderator_id: @mid,
          author_id: @aid,
          reason: "Reason",
          expires_at: ~U[2026-04-01 00:00:00Z],
          status: "invalid_status"
        })

      refute bad_status_cs.valid?
      assert "is invalid" in errors_on(bad_status_cs).status
    end
  end

  describe "SuspiciousAccount" do
    @uid Ecto.UUID.generate()
    @luid Ecto.UUID.generate()
    @mid Ecto.UUID.generate()

    test "valid changeset and review_changeset" do
      for match_type <- ["ip_exact", "ip_range", "email_pattern", "fingerprint"] do
        cs =
          SuspiciousAccount.changeset(%SuspiciousAccount{}, %{
            user_id: @uid,
            linked_user_id: @luid,
            match_type: match_type,
            confidence: 0.95
          })

        assert cs.valid?
        assert get_field(cs, :match_type) == match_type
      end

      review_cs =
        SuspiciousAccount.review_changeset(%SuspiciousAccount{}, %{
          reviewed: true,
          reviewed_by_id: @mid,
          reviewed_at: ~U[2026-03-01 15:00:00Z]
        })

      assert review_cs.valid?
      assert get_field(review_cs, :reviewed) == true
    end

    test "validates required fields and ranges" do
      cs = SuspiciousAccount.changeset(%SuspiciousAccount{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).user_id
      assert "can't be blank" in errors_on(cs).linked_user_id
      assert "can't be blank" in errors_on(cs).match_type

      bad_conf_cs =
        SuspiciousAccount.changeset(%SuspiciousAccount{}, %{
          user_id: @uid,
          linked_user_id: @luid,
          match_type: "ip_exact",
          confidence: 1.5
        })

      refute bad_conf_cs.valid?
      assert "must be less than or equal to 1.0" in errors_on(bad_conf_cs).confidence

      rev_cs = SuspiciousAccount.review_changeset(%SuspiciousAccount{}, %{reviewed: nil})
      refute rev_cs.valid?
      assert "can't be blank" in errors_on(rev_cs).reviewed
      assert "can't be blank" in errors_on(rev_cs).reviewed_by_id
      assert "can't be blank" in errors_on(rev_cs).reviewed_at
    end
  end

  describe "Warning" do
    @uid Ecto.UUID.generate()
    @mid Ecto.UUID.generate()

    test "valid changeset with valid type" do
      for type <- ["warning", "cooldown", "read_only", "temp_ban"] do
        cs =
          Warning.changeset(%Warning{}, %{
            reason: "Minor violation",
            user_id: @uid,
            issued_by_id: @mid,
            type: type,
            points: 2
          })

        assert cs.valid?
        assert get_field(cs, :type) == type
        assert get_field(cs, :points) == 2
      end
    end

    test "validates required fields and invalid type" do
      cs = Warning.changeset(%Warning{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).reason
      assert "can't be blank" in errors_on(cs).user_id
      assert "can't be blank" in errors_on(cs).issued_by_id

      bad_type_cs =
        Warning.changeset(%Warning{}, %{
          reason: "Violation",
          user_id: @uid,
          issued_by_id: @mid,
          type: "jail"
        })

      refute bad_type_cs.valid?
      assert "is invalid" in errors_on(bad_type_cs).type
    end
  end
end
