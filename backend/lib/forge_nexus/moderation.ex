defmodule ForgeNexus.Moderation do
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Accounts.{User, UserGroupMembership}
  alias ForgeNexus.Moderation.{Ban, Warning, Report, ModerationLog, ModNote, Appeal, SuspiciousAccount, ImpersonationLog, ContentPolicy}
  alias ForgeNexus.Forums.Post

  # --- Auto-escalation thresholds ---
  # {points_threshold, sanction_type, duration_hours (nil = permanent)}
  @escalation_thresholds [
    {3, "cooldown", 24},
    {6, "read_only", 72},
    {10, "temp_ban", 168},
    {15, "permanent_ban", nil}
  ]

  # =====================
  # Staff Checks
  # =====================

  def is_staff?(nil), do: false
  def is_staff?(%User{} = user), do: is_staff?(user.id)

  def is_staff?(user_id) when is_binary(user_id) do
    Repo.exists?(
      from m in UserGroupMembership,
        join: g in assoc(m, :group),
        where: m.user_id == ^user_id and g.is_staff == true
    )
  end

  def is_staff?(_), do: false

  # =====================
  # Bans
  # =====================

  def ban_user(user_id, attrs, %User{} = banned_by) do
    result =
      %Ban{}
      |> Ban.changeset(Map.merge(attrs, %{user_id: user_id, banned_by_id: banned_by.id}))
      |> Repo.insert()

    case result do
      {:ok, ban} ->
        log_action(banned_by, "ban", "user", user_id, %{
          reason: ban.reason,
          type: ban.type,
          expires_at: ban.expires_at
        })

        # Revoke all active sessions for the banned user — they're logged out everywhere.
        ForgeNexus.Accounts.revoke_all_sessions(user_id)

        # Notify the banned user by email (non-blocking, via Oban).
        %{
          template: "ban_notice",
          user_id: user_id,
          ban_id: ban.id,
          type: ban.type,
          reason: ban.reason,
          expires_at: ban.expires_at && DateTime.to_iso8601(ban.expires_at)
        }
        |> ForgeNexus.Workers.TransactionalEmailer.new()
        |> Oban.insert()

        {:ok, ban}

      error ->
        error
    end
  end

  def unban_user(ban_id, %User{} = moderator) do
    ban = Repo.get!(Ban, ban_id)

    result =
      ban
      |> Ecto.Changeset.change(is_active: false)
      |> Repo.update()

    case result do
      {:ok, ban} ->
        log_action(moderator, "unban", "user", ban.user_id, %{ban_id: ban.id})

        %{template: "ban_lifted_notice", user_id: ban.user_id, ban_id: ban.id}
        |> ForgeNexus.Workers.TransactionalEmailer.new()
        |> Oban.insert()

        {:ok, ban}

      error ->
        error
    end
  end

  def get_active_ban(user_id) do
    now = DateTime.utc_now()

    Repo.one(
      from b in Ban,
        where: b.user_id == ^user_id and b.is_active == true,
        where: is_nil(b.expires_at) or b.expires_at > ^now,
        order_by: [desc: :inserted_at],
        limit: 1,
        preload: [:banned_by]
    )
  end

  def is_banned?(user_id), do: get_active_ban(user_id) != nil

  def list_bans(opts \\ []) do
    user_id = Keyword.get(opts, :user_id)
    active_only = Keyword.get(opts, :active_only, false)
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from b in Ban,
        order_by: [desc: :inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:user, :banned_by]

    query = if user_id, do: where(query, [b], b.user_id == ^user_id), else: query
    query = if active_only, do: where(query, [b], b.is_active == true), else: query

    Repo.all(query)
  end

  def expire_bans do
    now = DateTime.utc_now()

    from(b in Ban,
      where: b.is_active == true and not is_nil(b.expires_at) and b.expires_at <= ^now
    )
    |> Repo.update_all(set: [is_active: false])
  end

  # =====================
  # Warnings / Sanctions
  # =====================

  def issue_warning(user_id, attrs, %User{} = issued_by) do
    result =
      %Warning{}
      |> Warning.changeset(Map.merge(attrs, %{user_id: user_id, issued_by_id: issued_by.id}))
      |> Repo.insert()

    case result do
      {:ok, warning} ->
        log_action(issued_by, "warn", "user", user_id, %{
          reason: warning.reason,
          type: warning.type,
          points: warning.points
        })

        %{
          template: "warning_notice",
          user_id: user_id,
          warning_id: warning.id,
          reason: warning.reason,
          points: warning.points
        }
        |> ForgeNexus.Workers.TransactionalEmailer.new()
        |> Oban.insert()

        check_auto_escalation(user_id, issued_by)
        {:ok, warning}

      error ->
        error
    end
  end

  def revoke_warning(warning_id, %User{} = moderator) do
    warning = Repo.get!(Warning, warning_id)

    %{template: "warning_revoked_notice", user_id: warning.user_id, reason: warning.reason}
    |> ForgeNexus.Workers.TransactionalEmailer.new()
    |> Oban.insert()

    result =
      warning
      |> Ecto.Changeset.change(is_active: false)
      |> Repo.update()

    case result do
      {:ok, warning} ->
        log_action(moderator, "revoke_warning", "user", warning.user_id, %{
          warning_id: warning.id
        })

        {:ok, warning}

      error ->
        error
    end
  end

  def list_warnings(user_id, opts \\ []) do
    active_only = Keyword.get(opts, :active_only, false)
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from w in Warning,
        where: w.user_id == ^user_id,
        order_by: [desc: :inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:issued_by]

    query = if active_only, do: where(query, [w], w.is_active == true), else: query

    Repo.all(query)
  end

  def active_warning_points(user_id) do
    now = DateTime.utc_now()

    Repo.one(
      from w in Warning,
        where: w.user_id == ^user_id and w.is_active == true,
        where: is_nil(w.expires_at) or w.expires_at > ^now,
        select: coalesce(sum(w.points), 0)
    )
  end

  def expire_warnings do
    now = DateTime.utc_now()

    from(w in Warning,
      where: w.is_active == true and not is_nil(w.expires_at) and w.expires_at <= ^now
    )
    |> Repo.update_all(set: [is_active: false])
  end

  def check_auto_escalation(user_id, %User{} = moderator) do
    points = active_warning_points(user_id)

    case find_escalation_level(points) do
      nil ->
        {:ok, :no_action}

      {_threshold, "permanent_ban", _hours} ->
        unless is_banned?(user_id) do
          ban_user(
            user_id,
            %{
              type: "permanent",
              reason: "Auto-escalation: accumulated #{points} warning points"
            },
            moderator
          )
        end

        {:ok, :permanent_ban}

      {_threshold, "temp_ban", hours} ->
        unless is_banned?(user_id) do
          ban_user(
            user_id,
            %{
              type: "temporary",
              reason: "Auto-escalation: accumulated #{points} warning points",
              expires_at: DateTime.add(DateTime.utc_now(), hours * 3600, :second)
            },
            moderator
          )
        end

        {:ok, :temp_ban}

      {_threshold, type, hours} ->
        already_has =
          Repo.exists?(
            from w in Warning,
              where: w.user_id == ^user_id and w.type == ^type and w.is_active == true
          )

        unless already_has do
          %Warning{}
          |> Warning.changeset(%{
            type: type,
            reason: "Auto-escalation: accumulated #{points} warning points",
            points: 0,
            user_id: user_id,
            issued_by_id: moderator.id,
            expires_at: DateTime.add(DateTime.utc_now(), hours * 3600, :second)
          })
          |> Repo.insert()
        end

        {:ok, String.to_atom(type)}
    end
  end

  defp find_escalation_level(points) do
    @escalation_thresholds
    |> Enum.reverse()
    |> Enum.find(fn {threshold, _type, _hours} -> points >= threshold end)
  end

  def get_user_restriction(user_id) do
    if is_banned?(user_id) do
      :banned
    else
      now = DateTime.utc_now()

      restriction =
        Repo.one(
          from w in Warning,
            where: w.user_id == ^user_id and w.is_active == true,
            where: w.type in ["read_only", "cooldown"],
            where: is_nil(w.expires_at) or w.expires_at > ^now,
            order_by:
              fragment(
                "CASE WHEN type = 'read_only' THEN 1 WHEN type = 'cooldown' THEN 2 ELSE 3 END"
              ),
            limit: 1,
            select: w.type
        )

      case restriction do
        "read_only" -> :read_only
        "cooldown" -> :cooldown
        _ -> :none
      end
    end
  end

  # =====================
  # Reports
  # =====================

  def create_report(attrs, %User{} = reporter) do
    %Report{}
    |> Report.changeset(Map.put(attrs, :reporter_id, reporter.id))
    |> Repo.insert()
  end

  def list_reports(opts \\ []) do
    status = Keyword.get(opts, :status)
    assigned_to_id = Keyword.get(opts, :assigned_to_id)
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from r in Report,
        order_by: [desc: :priority, asc: :inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:reporter, :resolver, :assigned_to]

    query = if status, do: where(query, [r], r.status == ^status), else: query

    query =
      if assigned_to_id,
        do: where(query, [r], r.assigned_to_id == ^assigned_to_id),
        else: query

    Repo.all(query)
  end

  def get_report!(id) do
    Repo.get!(Report, id) |> Repo.preload([:reporter, :resolver, :assigned_to])
  end

  def get_report_with_context!(id) do
    report = get_report!(id)

    context =
      case report.reportable_type do
        "post" ->
          post =
            ForgeNexus.Forums.get_post!(report.reportable_id)

          thread =
            ForgeNexus.Forums.get_thread!(post.thread_id)

          %{
            type: "post",
            post: %{
              id: post.id,
              body: post.body,
              inserted_at: post.inserted_at,
              user: %{id: post.user.id, username: post.user.username, slug: post.user.slug}
            },
            thread: %{id: thread.id, title: thread.title, slug: thread.slug},
            reported_user_id: post.user_id
          }

        "thread" ->
          thread =
            ForgeNexus.Forums.get_thread!(report.reportable_id)

          %{
            type: "thread",
            thread: %{id: thread.id, title: thread.title, slug: thread.slug},
            reported_user_id: thread.user_id
          }

        "user" ->
          user = ForgeNexus.Accounts.get_user!(report.reportable_id)

          %{
            type: "user",
            user: %{id: user.id, username: user.username, slug: user.slug},
            reported_user_id: user.id
          }

        _ ->
          %{type: report.reportable_type, reported_user_id: nil}
      end

    # Load infractions for the reported user if we know who they are
    infractions =
      if context[:reported_user_id] do
        %{
          warnings: list_warnings(context.reported_user_id, active_only: true),
          active_points: active_warning_points(context.reported_user_id),
          restriction: get_user_restriction(context.reported_user_id)
        }
      else
        nil
      end

    %{report: report, context: context, reported_user_infractions: infractions}
  end

  def assign_report(report_id, moderator_id, %User{} = assigner) do
    report = Repo.get!(Report, report_id)

    result =
      report
      |> Report.assign_changeset(%{assigned_to_id: moderator_id})
      |> Repo.update()

    case result do
      {:ok, report} ->
        log_action(assigner, "assign_report", "report", report.id, %{
          assigned_to: moderator_id
        })

        {:ok, Repo.preload(report, [:reporter, :resolver, :assigned_to])}

      error ->
        error
    end
  end

  def resolve_report(report_id, attrs, %User{} = resolver) do
    report = Repo.get!(Report, report_id)

    result =
      report
      |> Report.resolve_changeset(Map.put(attrs, :resolver_id, resolver.id))
      |> Repo.update()

    case result do
      {:ok, report} ->
        log_action(resolver, "resolve_report", "report", report.id, %{
          resolution_note: report.resolution_note
        })

        {:ok, Repo.preload(report, [:reporter, :resolver, :assigned_to])}

      error ->
        error
    end
  end

  def dismiss_report(report_id, attrs, %User{} = resolver) do
    report = Repo.get!(Report, report_id)

    result =
      report
      |> Report.dismiss_changeset(Map.put(attrs, :resolver_id, resolver.id))
      |> Repo.update()

    case result do
      {:ok, report} ->
        log_action(resolver, "dismiss_report", "report", report.id, %{
          resolution_note: report.resolution_note
        })

        {:ok, Repo.preload(report, [:reporter, :resolver, :assigned_to])}

      error ->
        error
    end
  end

  def report_counts_by_status do
    Repo.all(
      from r in Report,
        group_by: r.status,
        select: {r.status, count(r.id)}
    )
    |> Map.new()
  end

  def my_reports(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    Repo.all(
      from r in Report,
        where: r.reporter_id == ^user_id,
        order_by: [desc: :inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:resolver]
    )
  end

  # =====================
  # Mod Notes
  # =====================

  def create_mod_note(user_id, body, %User{} = author) do
    %ModNote{}
    |> ModNote.changeset(%{body: body, user_id: user_id, author_id: author.id})
    |> Repo.insert()
  end

  def list_mod_notes(user_id) do
    Repo.all(
      from n in ModNote,
        where: n.user_id == ^user_id,
        order_by: [desc: :inserted_at],
        preload: [:author]
    )
  end

  def delete_mod_note(note_id, %User{} = author) do
    note = Repo.get!(ModNote, note_id)

    if note.author_id == author.id do
      Repo.delete(note)
    else
      {:error, :unauthorized}
    end
  end

  # =====================
  # Moderation Log
  # =====================

  def log_action(%User{} = moderator, action, target_type, target_id, metadata \\ %{}) do
    %ModerationLog{}
    |> ModerationLog.changeset(%{
      action: action,
      reason: Map.get(metadata, :reason),
      metadata: metadata,
      target_type: target_type,
      target_id: target_id,
      moderator_id: moderator.id
    })
    |> Repo.insert()
  end

  def list_mod_logs(opts \\ []) do
    moderator_id = Keyword.get(opts, :moderator_id)
    action = Keyword.get(opts, :action)
    target_type = Keyword.get(opts, :target_type)
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from l in ModerationLog,
        order_by: [desc: :inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:moderator]

    query =
      if moderator_id, do: where(query, [l], l.moderator_id == ^moderator_id), else: query

    query = if action, do: where(query, [l], l.action == ^action), else: query
    query = if target_type, do: where(query, [l], l.target_type == ^target_type), else: query

    Repo.all(query)
  end

  # =====================
  # User Infractions Summary
  # =====================

  def user_infractions(user_id) do
    %{
      bans: list_bans(user_id: user_id),
      warnings: list_warnings(user_id),
      active_points: active_warning_points(user_id),
      restriction: get_user_restriction(user_id),
      reports_against:
        Repo.all(
          from r in Report,
            where: r.reportable_type == "user" and r.reportable_id == ^user_id,
            order_by: [desc: :inserted_at],
            preload: [:reporter, :resolver]
        )
    }
  end

  # =====================
  # Appeals
  # =====================

  def create_appeal(user_id, type, target_id, reason) do
    # Check for existing pending/under_review appeal on same target
    existing =
      Repo.one(
        from a in Appeal,
          where:
            a.user_id == ^user_id and a.type == ^type and a.target_id == ^target_id and
              a.status in ["pending", "under_review"],
          limit: 1
      )

    if existing do
      {:error, :appeal_already_exists}
    else
      %Appeal{}
      |> Appeal.changeset(%{type: type, target_id: target_id, reason: reason, user_id: user_id})
      |> Repo.insert()
    end
  end

  def list_appeals(opts \\ []) do
    status = Keyword.get(opts, :status)
    user_id = Keyword.get(opts, :user_id)
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from a in Appeal,
        order_by: [asc: :inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:user, :reviewer]

    query = if status, do: where(query, [a], a.status == ^status), else: query
    query = if user_id, do: where(query, [a], a.user_id == ^user_id), else: query

    Repo.all(query)
  end

  def get_appeal!(id) do
    Repo.get!(Appeal, id) |> Repo.preload([:user, :reviewer])
  end

  def my_appeals(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    Repo.all(
      from a in Appeal,
        where: a.user_id == ^user_id,
        order_by: [desc: :inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:reviewer]
    )
  end

  def review_appeal(appeal_id, decision, decision_note, %User{} = reviewer) do
    appeal = get_appeal!(appeal_id)

    # Reviewer cannot be the mod who issued the original sanction
    original_issuer_id = get_original_issuer_id(appeal)

    if original_issuer_id == reviewer.id do
      {:error, :cannot_review_own_sanction}
    else
      result =
        appeal
        |> Appeal.review_changeset(%{
          status: decision,
          decision_note: decision_note,
          reviewer_id: reviewer.id,
          decided_at: DateTime.utc_now()
        })
        |> Repo.update()

      case result do
        {:ok, appeal} ->
          log_action(reviewer, "review_appeal", "appeal", appeal.id, %{
            decision: decision,
            appeal_type: appeal.type,
            target_id: appeal.target_id
          })

          # Auto-revoke the sanction on approval
          if decision == "approved" do
            revoke_sanction_for_appeal(appeal, reviewer)
          end

          {:ok, Repo.preload(appeal, [:user, :reviewer])}

        error ->
          error
      end
    end
  end

  defp get_original_issuer_id(%Appeal{type: "ban", target_id: target_id}) do
    case Repo.get(Ban, target_id) do
      nil -> nil
      ban -> ban.banned_by_id
    end
  end

  defp get_original_issuer_id(%Appeal{type: "warning", target_id: target_id}) do
    case Repo.get(Warning, target_id) do
      nil -> nil
      warning -> warning.issued_by_id
    end
  end

  defp revoke_sanction_for_appeal(%Appeal{type: "ban", target_id: target_id}, moderator) do
    case Repo.get(Ban, target_id) do
      nil -> :ok
      ban -> if ban.is_active, do: unban_user(ban.id, moderator)
    end
  end

  defp revoke_sanction_for_appeal(%Appeal{type: "warning", target_id: target_id}, moderator) do
    case Repo.get(Warning, target_id) do
      nil -> :ok
      warning -> if warning.is_active, do: revoke_warning(warning.id, moderator)
    end
  end

  # =====================
  # Workload & Queue Stats
  # =====================

  def mod_workload_stats(moderator_id) do
    now = DateTime.utc_now()
    thirty_days_ago = DateTime.add(now, -30 * 86400, :second)

    assigned_reports =
      Repo.one(
        from r in Report,
          where: r.assigned_to_id == ^moderator_id and r.status in ["open", "assigned"],
          select: count(r.id)
      )

    actions_30d =
      Repo.one(
        from l in ModerationLog,
          where: l.moderator_id == ^moderator_id and l.inserted_at >= ^thirty_days_ago,
          select: count(l.id)
      )

    resolved_30d =
      Repo.one(
        from r in Report,
          where:
            r.resolver_id == ^moderator_id and r.status in ["resolved", "dismissed"] and
              r.updated_at >= ^thirty_days_ago,
          select: count(r.id)
      )

    %{
      assigned_reports: assigned_reports,
      actions_30d: actions_30d,
      resolved_30d: resolved_30d
    }
  end

  def report_queue_stats do
    now = DateTime.utc_now()

    open_count =
      Repo.one(
        from r in Report,
          where: r.status in ["open", "assigned"],
          select: count(r.id)
      )

    oldest =
      Repo.one(
        from r in Report,
          where: r.status in ["open", "assigned"],
          order_by: [asc: :inserted_at],
          limit: 1,
          select: r.inserted_at
      )

    avg_wait_seconds =
      Repo.one(
        from r in Report,
          where: r.status in ["open", "assigned"],
          select:
            fragment(
              "EXTRACT(EPOCH FROM AVG(? - ?))",
              ^now,
              r.inserted_at
            )
      )

    pending_appeals =
      Repo.one(
        from a in Appeal,
          where: a.status in ["pending", "under_review"],
          select: count(a.id)
      )

    %{
      open_count: open_count,
      oldest_report_at: oldest,
      avg_wait_seconds: if(avg_wait_seconds, do: round(avg_wait_seconds), else: 0),
      pending_appeals: pending_appeals
    }
  end

  def suggest_assignment do
    # Find the staff member with fewest assigned open reports
    result =
      Repo.one(
        from m in UserGroupMembership,
          join: g in assoc(m, :group),
          where: g.is_staff == true,
          left_join: r in Report,
          on: r.assigned_to_id == m.user_id and r.status in ["open", "assigned"],
          group_by: m.user_id,
          order_by: [asc: count(r.id)],
          limit: 1,
          select: {m.user_id, count(r.id)}
      )

    case result do
      {user_id, count} -> %{user_id: user_id, assigned_count: count}
      nil -> nil
    end
  end

  # =====================
  # Ban Evasion Detection
  # =====================

  def detect_suspicious_accounts(user_id) do
    user = ForgeNexus.Accounts.get_user!(user_id)

    # Find accounts sharing the same registration IP
    ip_matches =
      if user.registered_ip do
        Repo.all(
          from u in User,
            where: u.id != ^user_id and u.registered_ip == ^user.registered_ip,
            select: u
        )
        |> Enum.map(fn linked ->
          %{linked_user_id: linked.id, match_type: "ip_exact", confidence: 0.9}
        end)
      else
        []
      end

    # Find accounts sharing IPs from post history
    post_ips =
      Repo.all(
        from p in Post,
          where: p.user_id == ^user_id and not is_nil(p.ip_address),
          distinct: true,
          select: p.ip_address
      )

    post_ip_matches =
      if post_ips != [] do
        Repo.all(
          from p in Post,
            where: p.user_id != ^user_id and p.ip_address in ^post_ips,
            distinct: true,
            select: {p.user_id, p.ip_address}
        )
        |> Enum.map(fn {linked_user_id, _ip} ->
          %{linked_user_id: linked_user_id, match_type: "ip_range", confidence: 0.7}
        end)
        |> Enum.uniq_by(& &1.linked_user_id)
      else
        []
      end

    # Find email pattern matches (same email prefix with different domains, or +alias)
    base_email = user.email |> String.split("@") |> List.first() |> String.split("+") |> List.first()

    email_matches =
      Repo.all(
        from u in User,
          where: u.id != ^user_id and ilike(u.email, ^"#{base_email}%@%"),
          select: u
      )
      |> Enum.map(fn linked ->
        %{linked_user_id: linked.id, match_type: "email_pattern", confidence: 0.6}
      end)

    # Deduplicate and save
    all_matches =
      (ip_matches ++ post_ip_matches ++ email_matches)
      |> Enum.uniq_by(&{&1.linked_user_id, &1.match_type})

    saved =
      Enum.map(all_matches, fn match ->
        attrs = Map.merge(match, %{user_id: user_id})

        case %SuspiciousAccount{}
             |> SuspiciousAccount.changeset(attrs)
             |> Repo.insert(on_conflict: :nothing) do
          {:ok, sa} -> sa
          {:error, _} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, saved}
  end

  def list_suspicious_accounts(opts \\ []) do
    reviewed = Keyword.get(opts, :reviewed)
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from sa in SuspiciousAccount,
        order_by: [desc: :confidence, desc: :inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:user, :linked_user, :reviewed_by]

    query =
      case reviewed do
        nil -> query
        val -> where(query, [sa], sa.reviewed == ^val)
      end

    Repo.all(query)
  end

  def mark_suspicious_reviewed(id, %User{} = reviewer) do
    sa = Repo.get!(SuspiciousAccount, id)

    sa
    |> SuspiciousAccount.review_changeset(%{
      reviewed: true,
      reviewed_by_id: reviewer.id,
      reviewed_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  # =====================
  # Impersonation (Login-As-User)
  # =====================

  def is_admin?(user_id) do
    Repo.exists?(
      from m in UserGroupMembership,
        join: g in assoc(m, :group),
        where: m.user_id == ^user_id and g.name == "Administrators"
    )
  end

  def start_impersonation(admin_id, target_user_id, reason) do
    # Check no active impersonation session
    active =
      Repo.one(
        from il in ImpersonationLog,
          where: il.admin_id == ^admin_id and is_nil(il.ended_at),
          limit: 1
      )

    if active do
      {:error, :already_impersonating}
    else
      result =
        %ImpersonationLog{}
        |> ImpersonationLog.changeset(%{
          admin_id: admin_id,
          target_user_id: target_user_id,
          reason: reason,
          started_at: DateTime.utc_now()
        })
        |> Repo.insert()

      case result do
        {:ok, log} ->
          log_action(%User{id: admin_id}, "start_impersonation", "user", target_user_id, %{
            reason: reason,
            impersonation_log_id: log.id
          })

          {:ok, Repo.preload(log, [:admin, :target_user])}

        error ->
          error
      end
    end
  end

  def end_impersonation(admin_id) do
    case Repo.one(
           from il in ImpersonationLog,
             where: il.admin_id == ^admin_id and is_nil(il.ended_at),
             limit: 1
         ) do
      nil ->
        {:error, :no_active_session}

      log ->
        result =
          log
          |> ImpersonationLog.end_changeset(%{ended_at: DateTime.utc_now()})
          |> Repo.update()

        case result do
          {:ok, log} ->
            log_action(%User{id: admin_id}, "end_impersonation", "user", log.target_user_id, %{
              impersonation_log_id: log.id
            })

            {:ok, Repo.preload(log, [:admin, :target_user])}

          error ->
            error
        end
    end
  end

  def get_active_impersonation(admin_id) do
    Repo.one(
      from il in ImpersonationLog,
        where: il.admin_id == ^admin_id and is_nil(il.ended_at),
        limit: 1,
        preload: [:target_user]
    )
  end

  def list_impersonation_logs(opts \\ []) do
    admin_id = Keyword.get(opts, :admin_id)
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from il in ImpersonationLog,
        order_by: [desc: :started_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:admin, :target_user]

    query = if admin_id, do: where(query, [il], il.admin_id == ^admin_id), else: query

    Repo.all(query)
  end

  # =====================
  # Double Post Merge
  # =====================

  def maybe_merge_double_post(thread_id, user_id, new_body, minutes_threshold \\ 5) do
    cutoff = DateTime.add(DateTime.utc_now(), -minutes_threshold * 60, :second)

    recent_post =
      Repo.one(
        from p in Post,
          where:
            p.thread_id == ^thread_id and p.user_id == ^user_id and
              p.inserted_at >= ^cutoff and p.is_hidden == false,
          order_by: [desc: :inserted_at],
          limit: 1
      )

    case recent_post do
      nil ->
        {:ok, :no_merge}

      post ->
        merged_body = post.body <> "\n\n---\n\n" <> new_body

        post
        |> Ecto.Changeset.change(body: merged_body, is_edited: true, edited_at: DateTime.utc_now() |> DateTime.truncate(:second))
        |> Repo.update()
        |> case do
          {:ok, updated_post} -> {:ok, :merged, updated_post}
          error -> error
        end
    end
  end

  # =====================
  # Content Policies
  # =====================

  def create_content_policy(attrs) do
    %ContentPolicy{}
    |> ContentPolicy.changeset(attrs)
    |> Repo.insert()
  end

  def update_content_policy(id, attrs) do
    Repo.get!(ContentPolicy, id)
    |> ContentPolicy.changeset(attrs)
    |> Repo.update()
  end

  def delete_content_policy(id) do
    Repo.get!(ContentPolicy, id)
    |> Repo.delete()
  end

  def get_content_policy!(id) do
    Repo.get!(ContentPolicy, id)
  end

  def list_content_policies(opts \\ []) do
    forum_id = Keyword.get(opts, :forum_id)
    active_only = Keyword.get(opts, :active_only, false)

    query =
      from cp in ContentPolicy,
        order_by: [desc: :inserted_at]

    query = if forum_id, do: where(query, [cp], cp.forum_id == ^forum_id), else: query
    query = if active_only, do: where(query, [cp], cp.is_active == true), else: query

    Repo.all(query)
  end

  def get_policy_for_forum(forum_id) do
    Repo.one(
      from cp in ContentPolicy,
        where: cp.forum_id == ^forum_id and cp.is_active == true,
        limit: 1
    )
  end

  def get_escalation_thresholds(forum_id) do
    case get_policy_for_forum(forum_id) do
      nil ->
        @escalation_thresholds

      policy ->
        overrides = policy.escalation_overrides || %{}

        [
          {Map.get(overrides, "cooldown_threshold", 3), "cooldown", 24},
          {Map.get(overrides, "read_only_threshold", 6), "read_only", 72},
          {Map.get(overrides, "temp_ban_threshold", 10), "temp_ban", 168},
          {Map.get(overrides, "permanent_ban_threshold", 15), "permanent_ban", nil}
        ]
    end
  end

  # =====================
  # AI Moderation (Stub)
  # =====================

  @doc """
  AI content flagging stub. Only runs when AI moderation is enabled for the
  content's forum. Never auto-punishes — only creates a report for human review.

  Returns {:ok, %{flagged: false}} when disabled or when content passes.
  Returns {:ok, %{flagged: true, reason: "..."}} when content is flagged,
  and auto-creates a report for the mod queue.

  This is a stub — replace the inner logic with an actual AI provider call
  when ready. The contract (flag-only, human-reviews) stays the same.
  """
  def ai_flag_content(content, opts \\ []) do
    forum_id = Keyword.get(opts, :forum_id)
    post_id = Keyword.get(opts, :post_id)
    user_id = Keyword.get(opts, :user_id)

    policy = if forum_id, do: get_policy_for_forum(forum_id), else: nil

    # If no policy or AI moderation disabled, skip entirely
    if is_nil(policy) or not policy.ai_moderation_enabled do
      {:ok, %{flagged: false, reason: nil, ai_enabled: false}}
    else
      # --- Stub: rule-based checks using policy.rules ---
      rules = policy.rules || %{}
      blocked_words = Map.get(rules, "blocked_words", [])

      content_lower = String.downcase(content)

      flagged_word =
        Enum.find(blocked_words, fn word ->
          String.contains?(content_lower, String.downcase(word))
        end)

      if flagged_word do
        reason = "AI flag: content contains blocked word '#{flagged_word}'"

        # Auto-create a report for human review (never auto-punish)
        if post_id && user_id do
          create_report(
            %{
              reason: "ai_flag",
              description: reason,
              reportable_type: "post",
              reportable_id: post_id,
              reporter_id: nil
            },
            %User{id: user_id}
          )
        end

        {:ok, %{flagged: true, reason: reason, ai_enabled: true}}
      else
        {:ok, %{flagged: false, reason: nil, ai_enabled: true}}
      end
    end
  end

  # =====================
  # Scheduled Tasks (Oban-ready)
  # =====================

  @doc """
  Expire bans and warnings. Call periodically (e.g., hourly via Oban job or GenServer).
  """
  def run_expiration_tasks do
    {bans_expired, _} = expire_bans()
    {warnings_expired, _} = expire_warnings()
    {:ok, %{bans_expired: bans_expired, warnings_expired: warnings_expired}}
  end

  # =====================
  # Plugin-friendly helpers (no actor needed)
  # =====================

  @doc "System actor used for automated moderation actions from plugins."
  def system_actor do
    case Repo.one(from u in User, where: u.username == "system", limit: 1) do
      nil ->
        case Repo.one(from u in User, order_by: [asc: :inserted_at], limit: 1) do
          nil -> %User{id: nil, username: "system"}
          first -> first
        end

      sys ->
        sys
    end
  end

  @doc "Timeout (cooldown) a user for N seconds. Used by no-code plugins."
  def timeout_user_seconds(user_id, duration_seconds, reason \\ "") do
    expires_at =
      DateTime.utc_now()
      |> DateTime.add(duration_seconds, :second)
      |> DateTime.truncate(:second)

    attrs = %{
      type: "temporary",
      reason: reason,
      expires_at: expires_at,
      is_active: true
    }

    ban_user(user_id, attrs, system_actor())
  end

  @doc "Remove the active ban for a user, if any."
  def unban_user_by_id(user_id) do
    case get_active_ban(user_id) do
      nil -> {:ok, :not_banned}
      ban -> unban_user(ban.id, system_actor())
    end
  end

  @doc "Ban an IP address."
  def ban_ip(ip_address, reason, duration_hours) when is_binary(ip_address) do
    expires_at =
      if duration_hours > 0 do
        DateTime.utc_now()
        |> DateTime.add(duration_hours * 3600, :second)
        |> DateTime.truncate(:second)
      else
        nil
      end

    sys = system_actor()

    attrs = %{
      type: if(duration_hours > 0, do: "temporary", else: "permanent"),
      reason: reason,
      ip_address: ip_address,
      expires_at: expires_at,
      is_active: true,
      banned_by_id: sys.id
    }

    %Ban{} |> Ban.changeset(attrs) |> Repo.insert()
  end

  @doc "Add infraction points to a user via a warning record."
  def add_infraction_points(user_id, points, reason) when is_integer(points) do
    attrs = %{points: points, reason: reason, type: "warning", is_active: true}
    issue_warning(user_id, attrs, system_actor())
  end

  @doc "Total active warning points for a user."
  def get_infraction_points(user_id) do
    Repo.one(
      from w in Warning,
        where: w.user_id == ^user_id and w.is_active == true,
        select: coalesce(sum(w.points), 0)
    ) || 0
  end

  @doc "Bulk delete posts by ID. Returns count deleted."
  def bulk_delete_posts(ids) when is_list(ids) do
    {n, _} = from(p in Post, where: p.id in ^ids) |> Repo.delete_all()
    n
  end

  @doc """
  Quarantine a user. Sets status to "quarantined" and creates a
  QuarantineRecord capturing the current group memberships so release
  can restore them. No-op if the user is already quarantined (active
  record exists).
  """
  def quarantine_user(user_id, reason, actor_id \\ nil) do
    case Repo.get(User, user_id) do
      nil ->
        {:error, :not_found}

      user ->
        if active_quarantine_for(user_id) do
          {:error, :already_quarantined}
        else
          original_group_ids =
            from(m in ForgeNexus.Accounts.UserGroupMembership,
              where: m.user_id == ^user_id,
              select: m.group_id
            )
            |> Repo.all()

          actor = resolve_actor(actor_id)
          log_action(actor, "quarantine", "user", user_id, %{reason: reason})

          Repo.transaction(fn ->
            {:ok, updated} =
              user |> Ecto.Changeset.change(status: "quarantined") |> Repo.update()

            {:ok, _record} =
              %ForgeNexus.Moderation.QuarantineRecord{}
              |> ForgeNexus.Moderation.QuarantineRecord.changeset(%{
                user_id: user_id,
                quarantined_by_id: actor_id,
                original_group_ids: original_group_ids,
                reason: reason,
                quarantined_at: DateTime.utc_now()
              })
              |> Repo.insert()

            updated
          end)
        end
    end
  end

  @doc "Release a user from quarantine. Marks record released_at and sets status back to 'active'."
  def release_quarantine(user_id, actor_id \\ nil) do
    case active_quarantine_for(user_id) do
      nil ->
        {:error, :not_quarantined}

      record ->
        case Repo.get(User, user_id) do
          nil ->
            {:error, :not_found}

          user ->
            Repo.transaction(fn ->
              {:ok, _} =
                record
                |> Ecto.Changeset.change(released_at: DateTime.utc_now())
                |> Repo.update()

              {:ok, updated} =
                user |> Ecto.Changeset.change(status: "active") |> Repo.update()

              actor = resolve_actor(actor_id)
              log_action(actor, "release_quarantine", "user", user_id, %{})
              updated
            end)
        end
    end
  end

  defp resolve_actor(nil), do: system_actor()

  defp resolve_actor(%User{} = user), do: user

  defp resolve_actor(actor_id) when is_binary(actor_id) do
    case Repo.get(User, actor_id) do
      nil -> system_actor()
      user -> user
    end
  end

  defp resolve_actor(_), do: system_actor()

  @doc "Get the currently active (not released) quarantine record for a user, if any."
  def active_quarantine_for(user_id) do
    from(q in ForgeNexus.Moderation.QuarantineRecord,
      where: q.user_id == ^user_id and is_nil(q.released_at),
      limit: 1
    )
    |> Repo.one()
  end

  @doc "List quarantine records. Pass active: true to filter to active ones only."
  def list_quarantine_records(opts \\ []) do
    active_only = Keyword.get(opts, :active, false)
    limit = Keyword.get(opts, :limit, 100)

    query =
      ForgeNexus.Moderation.QuarantineRecord
      |> order_by(desc: :quarantined_at)
      |> limit(^limit)
      |> preload([:user, :quarantined_by])

    query =
      if active_only do
        where(query, [q], is_nil(q.released_at))
      else
        query
      end

    Repo.all(query)
  end

  @doc "Toggle post approval requirement for a forum or user."
  def set_post_approval(target_type, target_id, require?) do
    case target_type do
      "forum" ->
        case Repo.get(ForgeNexus.Forums.Forum, target_id) do
          nil ->
            {:error, :not_found}

          forum ->
            forum
            |> Ecto.Changeset.change(require_post_approval: require?)
            |> Repo.update()
        end

      "user" ->
        case Repo.get(User, target_id) do
          nil ->
            {:error, :not_found}

          user ->
            user
            |> Ecto.Changeset.change(status: if(require?, do: "moderated", else: "active"))
            |> Repo.update()
        end

      _ ->
        {:error, :invalid_target_type}
    end
  end

  @doc "Broadcast a moderator alert via PubSub."
  def send_mod_alert(title, description, severity, metadata \\ %{}) do
    payload = %{
      title: title,
      description: description,
      severity: severity,
      metadata: metadata,
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(ForgeNexus.PubSub, "mod:alerts", {:mod_alert, payload})
    {:ok, payload}
  end
end
