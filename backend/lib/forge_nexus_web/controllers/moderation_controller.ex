defmodule ForgeNexusWeb.ModerationController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Moderation
  alias ForgeNexus.Forums

  # =====================
  # Reports
  # =====================

  def list_reports(conn, params) do
    opts = [
      status: Map.get(params, "status"),
      assigned_to_id: Map.get(params, "assigned_to_id"),
      limit: parse_int(params, "limit", 25),
      offset: parse_int(params, "offset", 0)
    ]

    reports = Moderation.list_reports(opts)
    counts = Moderation.report_counts_by_status()

    conn |> json(%{reports: Enum.map(reports, &report_json/1), counts: counts})
  end

  def show_report(conn, %{"id" => id}) do
    report = Moderation.get_report!(id)
    conn |> json(%{report: report_json(report)})
  end

  def show_report_with_context(conn, %{"id" => id}) do
    data = Moderation.get_report_with_context!(id)

    conn
    |> json(%{
      report: report_json(data.report),
      context: data.context,
      reported_user_infractions: data.reported_user_infractions
    })
  end

  def assign_report(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)
    moderator_id = Map.get(params, "moderator_id", user.id)

    case Moderation.assign_report(id, moderator_id, user) do
      {:ok, report} ->
        conn |> json(%{report: report_json(report)})

      {:error, _changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Operation failed"})
    end
  end

  def resolve_report(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)

    case Moderation.resolve_report(id, %{resolution_note: Map.get(params, "resolution_note")}, user) do
      {:ok, report} ->
        conn |> json(%{report: report_json(report)})

      {:error, _changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Operation failed"})
    end
  end

  def dismiss_report(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)

    case Moderation.dismiss_report(id, %{resolution_note: Map.get(params, "resolution_note")}, user) do
      {:ok, report} ->
        conn |> json(%{report: report_json(report)})

      {:error, _changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Operation failed"})
    end
  end

  # =====================
  # Bans
  # =====================

  def list_bans(conn, params) do
    opts = [
      user_id: Map.get(params, "user_id"),
      active_only: Map.get(params, "active_only") == "true",
      limit: parse_int(params, "limit", 25),
      offset: parse_int(params, "offset", 0)
    ]

    bans = Moderation.list_bans(opts)
    conn |> json(%{bans: Enum.map(bans, &ban_json/1)})
  end

  def create_ban(conn, %{"ban" => ban_params}) do
    user = Guardian.Plug.current_resource(conn)
    user_id = Map.fetch!(ban_params, "user_id")

    attrs = %{
      type: Map.get(ban_params, "type", "temporary"),
      reason: Map.fetch!(ban_params, "reason"),
      expires_at: parse_datetime(Map.get(ban_params, "expires_at")),
      ip_address: Map.get(ban_params, "ip_address")
    }

    case Moderation.ban_user(user_id, attrs, user) do
      {:ok, ban} ->
        conn |> put_status(:created) |> json(%{ban: ban_json(ban)})

      {:error, _changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Operation failed"})
    end
  end

  def revoke_ban(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Moderation.unban_user(id, user) do
      {:ok, ban} ->
        conn |> json(%{ban: ban_json(ban)})

      {:error, _changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Operation failed"})
    end
  end

  # =====================
  # Warnings
  # =====================

  def list_warnings(conn, params) do
    user_id = Map.get(params, "user_id")

    if user_id do
      warnings = Moderation.list_warnings(user_id, active_only: Map.get(params, "active_only") == "true")
      conn |> json(%{warnings: Enum.map(warnings, &warning_json/1)})
    else
      conn |> put_status(:bad_request) |> json(%{error: "user_id is required"})
    end
  end

  def create_warning(conn, %{"warning" => warning_params}) do
    user = Guardian.Plug.current_resource(conn)
    user_id = Map.fetch!(warning_params, "user_id")

    attrs = %{
      type: Map.get(warning_params, "type", "warning"),
      reason: Map.fetch!(warning_params, "reason"),
      points: parse_int(warning_params, "points", 1),
      expires_at: parse_datetime(Map.get(warning_params, "expires_at"))
    }

    case Moderation.issue_warning(user_id, attrs, user) do
      {:ok, warning} ->
        conn |> put_status(:created) |> json(%{warning: warning_json(warning)})

      {:error, _changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Operation failed"})
    end
  end

  def revoke_warning(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Moderation.revoke_warning(id, user) do
      {:ok, warning} ->
        conn |> json(%{warning: warning_json(warning)})

      {:error, _changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Operation failed"})
    end
  end

  def user_infractions(conn, %{"user_id" => user_id}) do
    infractions = Moderation.user_infractions(user_id)

    conn
    |> json(%{
      bans: Enum.map(infractions.bans, &ban_json/1),
      warnings: Enum.map(infractions.warnings, &warning_json/1),
      active_points: infractions.active_points,
      restriction: infractions.restriction,
      reports_against: Enum.map(infractions.reports_against, &report_json/1)
    })
  end

  # =====================
  # Mod Notes
  # =====================

  def list_notes(conn, %{"user_id" => user_id}) do
    notes = Moderation.list_mod_notes(user_id)
    conn |> json(%{notes: Enum.map(notes, &note_json/1)})
  end

  def create_note(conn, %{"user_id" => user_id, "body" => body}) do
    user = Guardian.Plug.current_resource(conn)

    case Moderation.create_mod_note(user_id, body, user) do
      {:ok, note} ->
        note = ForgeNexus.Repo.preload(note, [:author])
        conn |> put_status(:created) |> json(%{note: note_json(note)})

      {:error, _changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Operation failed"})
    end
  end

  def delete_note(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Moderation.delete_mod_note(id, user) do
      {:ok, _} ->
        conn |> json(%{ok: true})

      {:error, :unauthorized} ->
        conn |> put_status(:forbidden) |> json(%{error: "You can only delete your own notes"})
    end
  end

  # =====================
  # Mod Log
  # =====================

  def list_logs(conn, params) do
    opts = [
      moderator_id: Map.get(params, "moderator_id"),
      action: Map.get(params, "action"),
      target_type: Map.get(params, "target_type"),
      limit: parse_int(params, "limit", 25),
      offset: parse_int(params, "offset", 0)
    ]

    logs = Moderation.list_mod_logs(opts)
    conn |> json(%{logs: Enum.map(logs, &log_json/1)})
  end

  # =====================
  # Thread Management
  # =====================

  def lock_thread(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)
    thread = Forums.get_thread!(id)

    case Forums.update_thread(thread, %{is_locked: true}) do
      {:ok, thread} ->
        Moderation.log_action(user, "lock_thread", "thread", id)
        ForgeNexus.Forums.fire_webhook_event("forum.thread.locked", %{thread_id: id, locked_by: user.id})
        conn |> json(%{ok: true, thread: %{id: thread.id, is_locked: true}})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to lock thread"})
    end
  end

  def unlock_thread(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)
    thread = Forums.get_thread!(id)

    case Forums.update_thread(thread, %{is_locked: false}) do
      {:ok, thread} ->
        Moderation.log_action(user, "unlock_thread", "thread", id)
        ForgeNexus.Forums.fire_webhook_event("forum.thread.unlocked", %{thread_id: id, unlocked_by: user.id})
        conn |> json(%{ok: true, thread: %{id: thread.id, is_locked: false}})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to unlock thread"})
    end
  end

  def pin_thread(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)
    thread = Forums.get_thread!(id)

    case Forums.update_thread(thread, %{is_pinned: true}) do
      {:ok, thread} ->
        Moderation.log_action(user, "pin_thread", "thread", id)
        ForgeNexus.Forums.fire_webhook_event("forum.thread.pinned", %{thread_id: id, pinned_by: user.id})
        conn |> json(%{ok: true, thread: %{id: thread.id, is_pinned: true}})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to pin thread"})
    end
  end

  def unpin_thread(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)
    thread = Forums.get_thread!(id)

    case Forums.update_thread(thread, %{is_pinned: false}) do
      {:ok, thread} ->
        Moderation.log_action(user, "unpin_thread", "thread", id)
        ForgeNexus.Forums.fire_webhook_event("forum.thread.unpinned", %{thread_id: id, unpinned_by: user.id})
        conn |> json(%{ok: true, thread: %{id: thread.id, is_pinned: false}})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to unpin thread"})
    end
  end

  def hide_thread(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)
    thread = Forums.get_thread!(id)

    case Forums.update_thread(thread, %{is_hidden: true}) do
      {:ok, _} ->
        Moderation.log_action(user, "hide_thread", "thread", id, %{
          reason: Map.get(params, "reason")
        })

        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to hide thread"})
    end
  end

  def unhide_thread(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)
    thread = Forums.get_thread!(id)

    case Forums.update_thread(thread, %{is_hidden: false}) do
      {:ok, _} ->
        Moderation.log_action(user, "unhide_thread", "thread", id)
        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to unhide thread"})
    end
  end

  def move_thread(conn, %{"id" => id, "forum_id" => forum_id}) do
    user = Guardian.Plug.current_resource(conn)
    thread = Forums.get_thread!(id)

    case Forums.update_thread(thread, %{forum_id: forum_id}) do
      {:ok, _} ->
        Moderation.log_action(user, "move_thread", "thread", id, %{
          from_forum_id: thread.forum_id,
          to_forum_id: forum_id
        })

        # Notify thread author
        new_forum = Forums.get_forum!(forum_id)
        if thread.user_id != user.id do
          ForgeNexus.Notifications.notify_thread_moved(
            thread.user_id,
            thread.title,
            thread.slug,
            new_forum.name,
            user.id
          )
        end

        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to move thread"})
    end
  end

  def merge_threads(conn, %{"id" => source_id, "target_thread_id" => target_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Forums.merge_threads(source_id, target_id) do
      {:ok, target} ->
        Moderation.log_action(user, "merge_threads", "thread", source_id, %{
          target_thread_id: target_id
        })

        conn |> json(%{ok: true, target_thread: %{id: target.id, slug: target.slug}})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to merge: #{inspect(reason)}"})
    end
  end

  # =====================
  # Bulk Thread Management
  # =====================

  def bulk_thread_action(conn, %{"action" => action, "thread_ids" => thread_ids}) when is_list(thread_ids) do
    user = Guardian.Plug.current_resource(conn)

    result = case action do
      "lock" ->
        Forums.bulk_update_threads(thread_ids, %{is_locked: true})
      "unlock" ->
        Forums.bulk_update_threads(thread_ids, %{is_locked: false})
      "hide" ->
        Forums.bulk_hide_threads(thread_ids)
      "move" ->
        target_forum_id = conn.params["target_forum_id"]
        if target_forum_id do
          # Fetch threads before move to get author info
          threads_to_move = Enum.map(thread_ids, &Forums.get_thread!/1)
          result = Forums.bulk_move_threads(thread_ids, target_forum_id)

          # Notify all thread authors about the move
          if result == :ok do
            new_forum = Forums.get_forum!(target_forum_id)
            for thread <- threads_to_move, thread.user_id != user.id do
              ForgeNexus.Notifications.notify_thread_moved(
                thread.user_id,
                thread.title,
                thread.slug,
                new_forum.name,
                user.id
              )
            end
          end

          result
        else
          {:error, "target_forum_id required for move action"}
        end
      _ ->
        {:error, "Unknown action: #{action}"}
    end

    case result do
      :ok ->
        Moderation.log_action(user, "bulk_#{action}_threads", "thread", nil, %{
          thread_ids: thread_ids,
          count: length(thread_ids)
        })
        conn |> json(%{ok: true, action: action, count: length(thread_ids)})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: reason})
    end
  end

  # =====================
  # Post Management
  # =====================

  def hide_post(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)
    post = Forums.get_post!(id)

    case Forums.mod_update_post(post, %{is_hidden: true}) do
      {:ok, _} ->
        Moderation.log_action(user, "hide_post", "post", id, %{
          reason: Map.get(params, "reason")
        })

        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to hide post"})
    end
  end

  def unhide_post(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)
    post = Forums.get_post!(id)

    case Forums.mod_update_post(post, %{is_hidden: false}) do
      {:ok, _} ->
        Moderation.log_action(user, "unhide_post", "post", id)
        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to unhide post"})
    end
  end

  # =====================
  # Appeals (Staff)
  # =====================

  def list_appeals(conn, params) do
    opts = [
      status: Map.get(params, "status"),
      limit: parse_int(params, "limit", 25),
      offset: parse_int(params, "offset", 0)
    ]

    appeals = Moderation.list_appeals(opts)
    conn |> json(%{appeals: Enum.map(appeals, &appeal_json/1)})
  end

  def show_appeal(conn, %{"id" => id}) do
    appeal = Moderation.get_appeal!(id)
    conn |> json(%{appeal: appeal_json(appeal)})
  end

  def review_appeal(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)

    case Map.get(params, "decision") do
      nil ->
        conn |> put_status(:bad_request) |> json(%{error: "decision is required"})

      decision ->
        decision_note = Map.get(params, "decision_note")

        case Moderation.review_appeal(id, decision, decision_note, user) do
          {:ok, appeal} ->
            conn |> json(%{appeal: appeal_json(appeal)})

          {:error, :cannot_review_own_sanction} ->
            conn
            |> put_status(:forbidden)
            |> json(%{error: "You cannot review an appeal for a sanction you issued"})

          {:error, _changeset} ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: "Operation failed"})
        end
    end
  end

  # =====================
  # Dashboard / Workload
  # =====================

  def workload(conn, params) do
    moderator_id = Map.get(params, "moderator_id")

    if moderator_id do
      stats = Moderation.mod_workload_stats(moderator_id)
      conn |> json(%{workload: stats})
    else
      # Return workload for current user
      user = Guardian.Plug.current_resource(conn)
      stats = Moderation.mod_workload_stats(user.id)
      conn |> json(%{workload: stats})
    end
  end

  def queue_stats(conn, _params) do
    stats = Moderation.report_queue_stats()
    conn |> json(%{queue: stats})
  end

  def suggest_assignment(conn, _params) do
    case Moderation.suggest_assignment() do
      nil ->
        conn |> json(%{suggestion: nil})

      suggestion ->
        conn |> json(%{suggestion: suggestion})
    end
  end

  # =====================
  # Suspicious Accounts
  # =====================

  def list_suspicious_accounts(conn, params) do
    opts = [
      reviewed: case Map.get(params, "reviewed") do
        "true" -> true
        "false" -> false
        _ -> nil
      end,
      limit: parse_int(params, "limit", 25),
      offset: parse_int(params, "offset", 0)
    ]

    accounts = Moderation.list_suspicious_accounts(opts)
    conn |> json(%{suspicious_accounts: Enum.map(accounts, &suspicious_account_json/1)})
  end

  def scan_suspicious(conn, %{"user_id" => user_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Moderation.detect_suspicious_accounts(user_id) do
      {:ok, results} ->
        Moderation.log_action(user, "scan_suspicious", "user", user_id, %{
          matches_found: length(results)
        })

        conn |> json(%{matches: length(results), suspicious_accounts: Enum.map(results, &suspicious_account_json/1)})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
    end
  end

  def review_suspicious(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Moderation.mark_suspicious_reviewed(id, user) do
      {:ok, sa} ->
        sa = ForgeNexus.Repo.preload(sa, [:user, :linked_user, :reviewed_by])
        conn |> json(%{suspicious_account: suspicious_account_json(sa)})

      {:error, _changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Operation failed"})
    end
  end

  # =====================
  # Impersonation (Admin only)
  # =====================

  def start_impersonation(conn, %{"target_user_id" => target_user_id, "reason" => reason}) do
    user = Guardian.Plug.current_resource(conn)

    case Moderation.start_impersonation(user.id, target_user_id, reason) do
      {:ok, log} ->
        conn |> json(%{impersonation: impersonation_json(log)})

      {:error, :already_impersonating} ->
        conn |> put_status(:conflict) |> json(%{error: "You already have an active impersonation session"})

      {:error, _changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Operation failed"})
    end
  end

  def end_impersonation(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    case Moderation.end_impersonation(user.id) do
      {:ok, log} ->
        conn |> json(%{impersonation: impersonation_json(log)})

      {:error, :no_active_session} ->
        conn |> put_status(:not_found) |> json(%{error: "No active impersonation session"})
    end
  end

  def active_impersonation(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    case Moderation.get_active_impersonation(user.id) do
      nil ->
        conn |> json(%{impersonation: nil})

      log ->
        conn |> json(%{impersonation: impersonation_json(log)})
    end
  end

  def impersonation_logs(conn, params) do
    opts = [
      admin_id: Map.get(params, "admin_id"),
      limit: parse_int(params, "limit", 25),
      offset: parse_int(params, "offset", 0)
    ]

    logs = Moderation.list_impersonation_logs(opts)
    conn |> json(%{logs: Enum.map(logs, &impersonation_json/1)})
  end

  # =====================
  # Double Post Merge
  # =====================

  def check_double_post(conn, %{"thread_id" => thread_id, "body" => body}) do
    user = Guardian.Plug.current_resource(conn)

    case Moderation.maybe_merge_double_post(thread_id, user.id, body) do
      {:ok, :no_merge} ->
        conn |> json(%{merged: false})

      {:ok, :merged, post} ->
        conn |> json(%{merged: true, post: %{id: post.id, body: post.body}})

      {:error, _changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Operation failed"})
    end
  end

  # =====================
  # Content Policies
  # =====================

  def list_policies(conn, params) do
    opts = [
      forum_id: Map.get(params, "forum_id"),
      active_only: Map.get(params, "active_only") == "true"
    ]

    policies = Moderation.list_content_policies(opts)
    conn |> json(%{policies: Enum.map(policies, &policy_json/1)})
  end

  def show_policy(conn, %{"id" => id}) do
    policy = Moderation.get_content_policy!(id)
    conn |> json(%{policy: policy_json(policy)})
  end

  def create_policy(conn, %{"policy" => policy_params}) do
    user = Guardian.Plug.current_resource(conn)

    attrs = %{
      name: Map.fetch!(policy_params, "name"),
      description: Map.get(policy_params, "description"),
      is_active: Map.get(policy_params, "is_active", false),
      ai_moderation_enabled: Map.get(policy_params, "ai_moderation_enabled", false),
      rules: Map.get(policy_params, "rules", %{}),
      escalation_overrides: Map.get(policy_params, "escalation_overrides", %{}),
      forum_id: Map.get(policy_params, "forum_id"),
      category_id: Map.get(policy_params, "category_id")
    }

    case Moderation.create_content_policy(attrs) do
      {:ok, policy} ->
        Moderation.log_action(user, "create_policy", "content_policy", policy.id, %{
          name: policy.name,
          ai_moderation_enabled: policy.ai_moderation_enabled
        })

        conn |> put_status(:created) |> json(%{policy: policy_json(policy)})

      {:error, _changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Operation failed"})
    end
  end

  def update_policy(conn, %{"id" => id, "policy" => policy_params}) do
    user = Guardian.Plug.current_resource(conn)

    attrs =
      policy_params
      |> Map.take(["name", "description", "is_active", "ai_moderation_enabled", "rules", "escalation_overrides", "forum_id", "category_id"])
      |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)
      |> Map.new()

    case Moderation.update_content_policy(id, attrs) do
      {:ok, policy} ->
        Moderation.log_action(user, "update_policy", "content_policy", policy.id, %{
          name: policy.name,
          ai_moderation_enabled: policy.ai_moderation_enabled
        })

        conn |> json(%{policy: policy_json(policy)})

      {:error, _changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Operation failed"})
    end
  end

  def delete_policy(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Moderation.delete_content_policy(id) do
      {:ok, policy} ->
        Moderation.log_action(user, "delete_policy", "content_policy", id, %{name: policy.name})
        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete policy"})
    end
  end

  # =====================
  # Soft-Block
  # =====================

  def soft_block(conn, %{"post_id" => post_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    case ForgeNexus.Moderation.SoftBlockFlow.create(%{
      post_id: post_id,
      moderator_id: user.id,
      reason: params["reason"] || "Content flagged for review",
      rule_violated: params["rule"],
      window_hours: params["window_hours"]
    }) do
      {:ok, sb} ->
        conn |> json(%{soft_block: %{id: sb.id, expires_at: sb.expires_at, status: sb.status}})

      {:error, _changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to create soft-block"})
    end
  end

  def soft_block_edit(conn, %{"id" => sb_id, "body" => body}) do
    case ForgeNexus.Moderation.SoftBlockFlow.author_edit(sb_id, body) do
      {:ok, :edited} -> conn |> json(%{ok: true, status: "edited"})
      {:error, :expired} -> conn |> put_status(:gone) |> json(%{error: "Edit window expired"})
      {:error, reason} -> conn |> put_status(:bad_request) |> json(%{error: to_string(reason)})
    end
  end

  def list_soft_blocks(conn, _params) do
    community_id = conn.assigns.community_id
    blocks = ForgeNexus.Moderation.SoftBlockFlow.list_pending(community_id)

    conn |> json(%{soft_blocks: Enum.map(blocks, fn sb ->
      %{id: sb.id, post_id: sb.post_id, reason: sb.reason, rule: sb.rule_violated,
        expires_at: sb.expires_at, status: sb.status,
        author: sb.author && %{id: sb.author.id, username: sb.author.username},
        moderator: sb.moderator && %{id: sb.moderator.id, username: sb.moderator.username}}
    end)})
  end

  # =====================
  # JSON Helpers
  # =====================

  defp policy_json(policy) do
    %{
      id: policy.id,
      name: policy.name,
      description: policy.description,
      is_active: policy.is_active,
      ai_moderation_enabled: policy.ai_moderation_enabled,
      rules: policy.rules,
      escalation_overrides: policy.escalation_overrides,
      forum_id: policy.forum_id,
      category_id: policy.category_id,
      inserted_at: policy.inserted_at,
      updated_at: policy.updated_at
    }
  end

  defp report_json(report) do
    %{
      id: report.id,
      reason: report.reason,
      description: report.description,
      status: report.status,
      priority: report.priority,
      reportable_type: report.reportable_type,
      reportable_id: report.reportable_id,
      resolution_note: report.resolution_note,
      resolved_at: report.resolved_at,
      inserted_at: report.inserted_at,
      reporter: user_mini_json(report.reporter),
      resolver: if(report.resolver, do: user_mini_json(report.resolver)),
      assigned_to: if(report.assigned_to, do: user_mini_json(report.assigned_to))
    }
  end

  defp ban_json(ban) do
    %{
      id: ban.id,
      type: ban.type,
      reason: ban.reason,
      expires_at: ban.expires_at,
      is_active: ban.is_active,
      ip_address: ban.ip_address,
      inserted_at: ban.inserted_at,
      user: if(Ecto.assoc_loaded?(ban.user), do: user_mini_json(ban.user)),
      banned_by: if(Ecto.assoc_loaded?(ban.banned_by), do: user_mini_json(ban.banned_by))
    }
  end

  defp warning_json(warning) do
    %{
      id: warning.id,
      type: warning.type,
      reason: warning.reason,
      points: warning.points,
      expires_at: warning.expires_at,
      is_active: warning.is_active,
      inserted_at: warning.inserted_at,
      issued_by: if(Ecto.assoc_loaded?(warning.issued_by), do: user_mini_json(warning.issued_by))
    }
  end

  defp note_json(note) do
    %{
      id: note.id,
      body: note.body,
      inserted_at: note.inserted_at,
      author: user_mini_json(note.author)
    }
  end

  defp log_json(log) do
    %{
      id: log.id,
      action: log.action,
      reason: log.reason,
      metadata: log.metadata,
      target_type: log.target_type,
      target_id: log.target_id,
      inserted_at: log.inserted_at,
      moderator: user_mini_json(log.moderator)
    }
  end

  defp appeal_json(appeal) do
    %{
      id: appeal.id,
      type: appeal.type,
      target_id: appeal.target_id,
      reason: appeal.reason,
      status: appeal.status,
      decision_note: appeal.decision_note,
      decided_at: appeal.decided_at,
      inserted_at: appeal.inserted_at,
      user: if(Ecto.assoc_loaded?(appeal.user), do: user_mini_json(appeal.user)),
      reviewer: if(appeal.reviewer && Ecto.assoc_loaded?(appeal.reviewer), do: user_mini_json(appeal.reviewer))
    }
  end

  defp suspicious_account_json(sa) do
    %{
      id: sa.id,
      match_type: sa.match_type,
      confidence: sa.confidence,
      reviewed: sa.reviewed,
      reviewed_at: sa.reviewed_at,
      inserted_at: sa.inserted_at,
      user: if(Ecto.assoc_loaded?(sa.user), do: user_mini_json(sa.user)),
      linked_user: if(Ecto.assoc_loaded?(sa.linked_user), do: user_mini_json(sa.linked_user)),
      reviewed_by: if(sa.reviewed_by && Ecto.assoc_loaded?(sa.reviewed_by), do: user_mini_json(sa.reviewed_by))
    }
  end

  defp impersonation_json(log) do
    %{
      id: log.id,
      reason: log.reason,
      started_at: log.started_at,
      ended_at: log.ended_at,
      inserted_at: log.inserted_at,
      admin: if(Ecto.assoc_loaded?(log.admin), do: user_mini_json(log.admin)),
      target_user: if(Ecto.assoc_loaded?(log.target_user), do: user_mini_json(log.target_user))
    }
  end

  defp user_mini_json(nil), do: nil

  defp user_mini_json(user) do
    %{
      id: user.id,
      username: user.username,
      slug: user.slug,
      avatar_url: user.avatar_url
    }
  end

  defp parse_int(params, key, default) do
    case Map.get(params, key) do
      nil -> default
      val when is_binary(val) -> safe_to_integer(val, default)
      val when is_integer(val) -> val
    end
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end


  defp safe_to_integer(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> default
    end
  end
  defp safe_to_integer(val, _default) when is_integer(val), do: val
  defp safe_to_integer(_, default), do: default

end
