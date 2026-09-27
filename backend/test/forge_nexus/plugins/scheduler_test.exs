defmodule ForgeNexus.Plugins.SchedulerTest do
  use ForgeNexus.DataCase

  import ExUnit.CaptureLog

  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Plugins.{Flow, FlowExecution, FlowNode, FlowRateLimit, Scheduler}
  alias ForgeNexus.Repo

  defp create_user do
    uid = System.unique_integer([:positive])

    %User{}
    |> User.registration_changeset(%{
      email: "user_#{uid}@example.com",
      username: "user_#{uid}",
      password: "Password1234!",
      password_confirmation: "Password1234!"
    })
    |> Repo.insert!()
  end

  defp create_flow(user, attrs) do
    uid = System.unique_integer([:positive])

    defaults = %{
      name: "Scheduled Flow #{uid}",
      slug: "scheduled-flow-#{uid}",
      trigger_type: "scheduled",
      trigger_config: %{"cron_expression" => "* * * * *"},
      status: "active",
      tier: "nocode",
      created_by_id: user.id
    }

    %Flow{}
    |> Flow.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp wait_for_plugin_tasks do
    for pid <- Task.Supervisor.children(ForgeNexus.PluginTaskSupervisor) do
      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _} -> :ok
      after
        1000 -> :ok
      end
    end
  end

  describe "cron_matches?/2" do
    test "matches wildcard * for all fields" do
      now = ~U[2026-05-01 14:30:00Z]
      assert Scheduler.cron_matches?("* * * * *", now)
    end

    test "matches exact numbers for all fields" do
      # 2026-05-01 is a Friday (day_of_week = 5, rem(7) = 5)
      now = ~U[2026-05-01 14:30:00Z]
      assert Scheduler.cron_matches?("30 14 1 5 5", now)
    end

    test "returns false when minute does not match" do
      now = ~U[2026-05-01 14:30:00Z]
      refute Scheduler.cron_matches?("15 * * * *", now)
    end

    test "returns false when hour does not match" do
      now = ~U[2026-05-01 14:30:00Z]
      refute Scheduler.cron_matches?("* 10 * * *", now)
    end

    test "returns false when day of month does not match" do
      now = ~U[2026-05-01 14:30:00Z]
      refute Scheduler.cron_matches?("* * 2 * *", now)
    end

    test "returns false when month does not match" do
      now = ~U[2026-05-01 14:30:00Z]
      refute Scheduler.cron_matches?("* * * 6 *", now)
    end

    test "returns false when weekday does not match" do
      # 2026-05-01 Friday has weekday 5
      now = ~U[2026-05-01 14:30:00Z]
      refute Scheduler.cron_matches?("* * * * 1", now)
    end

    test "returns false for invalid cron expressions" do
      now = ~U[2026-05-01 14:30:00Z]

      # Not 5 parts
      refute Scheduler.cron_matches?("*", now)
      refute Scheduler.cron_matches?("* * *", now)
      refute Scheduler.cron_matches?("* * * * * *", now)
      refute Scheduler.cron_matches?("", now)

      # Non-numeric, non-wildcard field
      refute Scheduler.cron_matches?("invalid * * * *", now)
      refute Scheduler.cron_matches?("30abc * * * *", now)
    end
  end

  describe "perform/1" do
    test "returns :ok when there are no scheduled flows" do
      assert Scheduler.perform(%Oban.Job{}) == :ok
    end

    test "skips flow when cron expression does not match" do
      user = create_user()
      # Non-matching cron (e.g. month 13 will never match)
      flow =
        create_flow(user, %{
          trigger_config: %{"cron_expression" => "* * * 13 *"}
        })

      assert Scheduler.perform(%Oban.Job{}) == :ok
      wait_for_plugin_tasks()

      refute Repo.exists?(from fe in FlowExecution, where: fe.flow_id == ^flow.id)
    end

    test "triggers flow and executes under task supervisor when cron matches" do
      user = create_user()

      flow =
        create_flow(user, %{
          trigger_config: %{"cron_expression" => "* * * * *"}
        })

      # Add a trigger node so executor runs
      %FlowNode{
        id: Ecto.UUID.generate(),
        flow_id: flow.id,
        type: "trigger/scheduled",
        category: "trigger",
        config: %{}
      }
      |> Repo.insert!()

      assert Scheduler.perform(%Oban.Job{}) == :ok
      wait_for_plugin_tasks()

      assert Repo.exists?(from fe in FlowExecution, where: fe.flow_id == ^flow.id)
    end

    test "catches and logs errors when flow execution fails" do
      user = create_user()

      flow =
        create_flow(user, %{
          trigger_config: %{"cron_expression" => "* * * * *"}
        })

      # Pre-seed a rate limit at or above maximum to force Executor to raise SandboxError
      now = DateTime.utc_now()

      window_start =
        now |> DateTime.truncate(:second) |> Map.put(:minute, 0) |> Map.put(:second, 0)

      %FlowRateLimit{
        flow_id: flow.id,
        window_start: window_start,
        execution_count: 100
      }
      |> Repo.insert!()

      log =
        capture_log(fn ->
          assert Scheduler.perform(%Oban.Job{}) == :ok
          wait_for_plugin_tasks()
        end)

      assert log =~ "[Plugins.Scheduler] Flow #{flow.id} failed:"
      assert log =~ "Rate limit exceeded"
    end
  end
end
