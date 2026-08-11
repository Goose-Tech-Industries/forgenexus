defmodule ForgeNexus.Workers.AutoHighlightWorker do
  @moduledoc """
  Generates auto-highlight clips when a recording transcription completes.
  Enqueued by the TranscribeRecordingWorker after a successful transcription.
  """
  use Oban.Worker, queue: :default, max_attempts: 2

  alias ForgeNexus.AI.ClipAutoHighlight

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"recording_id" => recording_id}}) do
    case ClipAutoHighlight.generate_highlights(recording_id, max_clips: 3) do
      {:ok, clips} ->
        require Logger

        Logger.info(
          "[AutoHighlight] Generated #{length(clips)} clips for recording #{recording_id}"
        )

        :ok

      {:error, :no_transcript} ->
        :ok

      {:error, _reason} ->
        :ok
    end
  end

  def perform(%Oban.Job{args: args}) do
    require Logger
    Logger.warning("[AutoHighlight] missing required args, got: #{inspect(args)}")
    {:error, :missing_args}
  end
end
