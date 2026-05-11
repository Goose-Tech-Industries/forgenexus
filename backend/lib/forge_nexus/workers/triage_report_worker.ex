defmodule ForgeNexus.Workers.TriageReportWorker do
  @moduledoc """
  Oban worker that auto-triages new reports via AI. Runs after a report
  is created, categorizes by severity/type, and tags the report for
  moderator prioritization.
  """
  use Oban.Worker, queue: :default, max_attempts: 2

  import Ecto.Query
  alias ForgeNexus.{Repo}
  alias ForgeNexus.AI.ModQueueTriage

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"report_id" => report_id, "content" => content, "reason" => reason}}) do
    case ModQueueTriage.triage(content, %{reporter_reason: reason}) do
      {:ok, result} ->
        from(r in "reports", where: r.id == type(^report_id, :binary_id))
        |> Repo.update_all(set: [
          ai_severity: result.severity,
          ai_category: result.category,
          ai_confidence: result.confidence,
          ai_reason: result.reason
        ])

        :ok

      _ ->
        :ok
    end
  end

  def perform(%Oban.Job{args: args}) do
    require Logger
    Logger.warning("[TriageReport] missing required args, got: #{inspect(args)}")
    {:error, :missing_args}
  end
end
