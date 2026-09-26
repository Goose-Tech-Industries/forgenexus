defmodule ForgeNexus.Workers.ModerationAndNotificationWorkersTest do
  use ForgeNexus.DataCase, async: false
  use Oban.Testing, repo: ForgeNexus.Repo

  alias ForgeNexus.{Accounts, Forums, Governance, Moderation, Repo}
  alias ForgeNexus.Governance.Proposal
  alias ForgeNexus.Moderation.Report
  alias ForgeNexus.Moderation.SoftBlockFlow

  alias ForgeNexus.Workers.{
    GovernanceWorker,
    LiveNotificationWorker,
    SoftBlockExpiryWorker,
    TriageReportWorker
  }

  defp create_user(attrs \\ %{}) do
    unique_suffix = System.unique_integer([:positive])

    defaults = %{
      username: "worker_user_#{unique_suffix}",
      email: "worker_user_#{unique_suffix}@example.com",
      password: "SecurePass!987654#Alpha",
      password_confirmation: "SecurePass!987654#Alpha"
    }

    {:ok, user} =
      defaults
      |> Map.merge(Enum.into(attrs, %{}))
      |> Accounts.register_user()

    user
  end

  defp create_forum_and_thread(user) do
    unique_suffix = System.unique_integer([:positive])

    {:ok, category} =
      Forums.create_category(%{
        name: "Cat #{unique_suffix}"
      })

    {:ok, forum} =
      Forums.create_forum(%{
        name: "Worker Forum #{unique_suffix}",
        description: "Forum for worker tests",
        category_id: category.id,
        position: 0
      })

    {:ok, thread} =
      Forums.create_thread(%{
        title: "Worker Thread #{unique_suffix}",
        body: "Thread body content",
        user_id: user.id,
        forum_id: forum.id
      })

    [post | _] = Forums.list_posts(thread.id)
    {forum, thread, post}
  end

  describe "SoftBlockExpiryWorker" do
    test "expires pending soft block and deletes unedited post" do
      user = create_user()
      {_forum, _thread, post} = create_forum_and_thread(user)

      {:ok, sb} =
        SoftBlockFlow.create(%{
          post_id: post.id,
          moderator_id: user.id,
          reason: "Inappropriate language",
          rule_violated: "Spam",
          window_hours: 1
        })

      assert sb.status == "pending"

      assert :ok = perform_job(SoftBlockExpiryWorker, %{"soft_block_id" => sb.id})

      assert is_nil(Repo.get(Forums.Post, post.id))
      assert is_nil(Repo.get(ForgeNexus.Moderation.SoftBlock, sb.id))
    end

    test "handles missing args with {:error, :missing_args}" do
      assert {:error, :missing_args} = perform_job(SoftBlockExpiryWorker, %{})
    end
  end

  describe "TriageReportWorker" do
    test "auto-triages report and persists severity and category to database" do
      user = create_user()
      reporter = create_user()
      {_forum, _thread, post} = create_forum_and_thread(user)

      {:ok, report} =
        Moderation.create_report(
          %{
            reason: "spam",
            description: "This is automated bot spam",
            reportable_type: "post",
            reportable_id: post.id
          },
          reporter
        )

      assert :ok =
               perform_job(TriageReportWorker, %{
                 "report_id" => report.id,
                 "content" => post.body,
                 "reason" => "spam"
               })

      updated = Repo.get!(Report, report.id)
      assert updated.ai_severity != nil
      assert updated.ai_category != nil
    end

    test "handles missing args with {:error, :missing_args}" do
      assert {:error, :missing_args} = perform_job(TriageReportWorker, %{"report_id" => "123"})
    end
  end

  describe "LiveNotificationWorker" do
    test "notifies all followers when user goes live in a voice room" do
      broadcaster = create_user()
      follower = create_user()

      {:ok, _follow} = Accounts.toggle_follow(follower.id, broadcaster.id)

      assert :ok =
               perform_job(LiveNotificationWorker, %{
                 "user_id" => broadcaster.id,
                 "room_id" => Ecto.UUID.generate(),
                 "room_name" => "Gaming Room"
               })

      notifications = ForgeNexus.Notifications.list_notifications(follower.id)
      assert length(notifications) == 1
      notif = hd(notifications)
      assert notif.actor_id == broadcaster.id
      assert notif.type == "went_live"
      assert String.contains?(notif.title, "Gaming Room")
    end

    test "handles missing args with {:error, :missing_args}" do
      assert {:error, :missing_args} = perform_job(LiveNotificationWorker, %{})
    end
  end

  describe "GovernanceWorker" do
    test "transitions proposals from discussion to voting and voting to passed/failed" do
      user = create_user()
      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)
      future = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      # 1. Proposal in discussion whose voting_starts_at has passed
      {:ok, p_start} =
        Governance.create_proposal(%{
          title: "Discussion Proposal",
          description: "Let's vote on this",
          body: "Full body explanation",
          type: "policy",
          author_id: user.id,
          status: "discussion",
          voting_starts_at: past,
          voting_ends_at: future,
          yes_count: 0,
          no_count: 0,
          abstain_count: 0,
          min_participation: 1
        })

      # 2. Proposal in voting that passed (yes > no and meets min_participation)
      {:ok, p_pass} =
        Governance.create_proposal(%{
          title: "Passed Proposal",
          description: "Passed",
          body: "Passed proposal body",
          type: "policy",
          author_id: user.id,
          status: "voting",
          voting_starts_at: DateTime.add(past, -3600, :second),
          voting_ends_at: past,
          threshold_type: "simple_majority",
          yes_count: 10,
          no_count: 2,
          abstain_count: 1,
          min_participation: 5
        })

      # 3. Proposal in voting that failed quorum (min_participation not met)
      {:ok, p_fail_quorum} =
        Governance.create_proposal(%{
          title: "Quorum Failed Proposal",
          description: "Not enough voters",
          body: "Quorum failed body",
          type: "policy",
          author_id: user.id,
          status: "voting",
          voting_starts_at: DateTime.add(past, -3600, :second),
          voting_ends_at: past,
          threshold_type: "two_thirds",
          yes_count: 1,
          no_count: 0,
          abstain_count: 0,
          min_participation: 10
        })

      assert :ok = perform_job(GovernanceWorker, %{})

      assert Repo.get!(Proposal, p_start.id).status == "voting"

      updated_pass = Repo.get!(Proposal, p_pass.id)
      assert updated_pass.status == "passed"
      assert String.contains?(updated_pass.result_summary, "Quorum met.")

      updated_fail = Repo.get!(Proposal, p_fail_quorum.id)
      assert updated_fail.status == "failed"
      assert String.contains?(updated_fail.result_summary, "Quorum not met.")
    end
  end
end
