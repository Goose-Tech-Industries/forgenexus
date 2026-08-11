defmodule ForgeNexus.Workers.TranscribeRecordingWorker do
  @moduledoc """
  Oban worker that transcribes a voice recording via the configured provider
  and writes the result back to the recording row.
  """
  use Oban.Worker, queue: :transcription, max_attempts: 3

  require Logger
  alias ForgeNexus.Repo
  alias ForgeNexus.Voice
  alias ForgeNexus.Voice.{Recording, Transcription}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"recording_id" => recording_id}}) do
    case Repo.get(Recording, recording_id) do
      nil ->
        :ok

      %Recording{audio_url: url} = recording ->
        Voice.mark_transcript_processing(recording)

        file_path = local_path_from_url(url)

        case Transcription.transcribe(file_path) do
          {:ok, %{text: text, language: lang}} ->
            Voice.attach_transcript(recording, text, lang)
            :ok

          {:error, :disabled} ->
            Voice.mark_transcript_status(recording, "disabled")
            :ok

          {:error, reason} ->
            Logger.warning(
              "[TranscribeRecordingWorker] #{recording_id} failed: #{inspect(reason)}"
            )

            Voice.mark_transcript_status(recording, "failed")
            {:error, reason}
        end
    end
  end

  defp local_path_from_url("/uploads/" <> rest),
    do: Path.join(["priv/static/uploads", rest])

  defp local_path_from_url(url), do: url
end
