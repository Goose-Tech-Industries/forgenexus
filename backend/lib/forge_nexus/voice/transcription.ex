defmodule ForgeNexus.Voice.Transcription do
  @moduledoc """
  Audio transcription dispatch. Reads the configured provider from site
  settings and dispatches to the matching implementation. Returns
  `{:ok, %{text: String.t(), language: String.t() | nil}}` on success, or
  `{:error, reason}` on failure.

  Supported providers:
    * `"openai"`  — OpenAI Whisper API (requires `OPENAI_API_KEY` env var)
    * `"local"`   — Self-hosted whisper.cpp on the server (no external calls)
    * `"disabled"` — explicit no-op (default)

  Feature flag: `voice_transcription_enabled` must be "true" in site settings.

  ## Local provider setup

  Install whisper.cpp and download a model on the server:

      git clone https://github.com/ggerganov/whisper.cpp /opt/whisper.cpp
      cd /opt/whisper.cpp && make -j
      bash ./models/download-ggml-model.sh small.en

  Then set `voice_transcription_provider` to `"local"` in admin settings.
  Optionally override the binary/model paths via:

    * `voice_transcription_whisper_cpp_bin`   (default `/opt/whisper.cpp/main`)
    * `voice_transcription_whisper_cpp_model` (default `/opt/whisper.cpp/models/ggml-small.en.bin`)

  `ffmpeg` must be available in `PATH` — whisper.cpp requires 16 kHz mono
  PCM WAV input, so we transcode the uploaded Opus/WebM file first.
  """

  require Logger
  alias ForgeNexus.Settings

  @doc "Transcribe an audio file at the given path. Returns {:ok, result} or {:error, reason}."
  def transcribe(file_path) when is_binary(file_path) do
    cond do
      not Settings.get_bool("voice_transcription_enabled") ->
        {:error, :disabled}

      not File.exists?(file_path) ->
        {:error, :file_not_found}

      true ->
        provider = Settings.get("voice_transcription_provider") || "disabled"
        dispatch(provider, file_path)
    end
  end

  defp dispatch("openai", file_path), do: transcribe_openai(file_path)
  defp dispatch("local", file_path), do: transcribe_local(file_path)
  defp dispatch("disabled", _file_path), do: {:error, :disabled}
  defp dispatch(other, _file_path), do: {:error, {:unknown_provider, other}}

  defp transcribe_openai(file_path) do
    api_key = System.get_env("OPENAI_API_KEY")

    if is_nil(api_key) or api_key == "" do
      Logger.warning("[Voice.Transcription] OPENAI_API_KEY not set; skipping transcription")
      {:error, :no_api_key}
    else
      do_openai_request(api_key, file_path)
    end
  end

  defp do_openai_request(api_key, file_path) do
    url = "https://api.openai.com/v1/audio/transcriptions"

    body = {
      :multipart,
      [
        {"model", "whisper-1"},
        {"response_format", "verbose_json"},
        {:file, file_path,
         {"form-data", [name: "file", filename: Path.basename(file_path)]}, []}
      ]
    }

    try do
      case Req.post(url,
             headers: [{"authorization", "Bearer #{api_key}"}],
             body: body,
             receive_timeout: 120_000
           ) do
        {:ok, %{status: 200, body: resp}} when is_map(resp) ->
          {:ok,
           %{
             text: Map.get(resp, "text", ""),
             language: Map.get(resp, "language")
           }}

        {:ok, %{status: status, body: body}} ->
          Logger.warning("[Voice.Transcription] OpenAI returned #{status}: #{inspect(body)}")
          {:error, {:http, status}}

        {:error, reason} ->
          Logger.warning("[Voice.Transcription] OpenAI request failed: #{inspect(reason)}")
          {:error, {:request_failed, reason}}
      end
    rescue
      e ->
        Logger.warning("[Voice.Transcription] Exception: #{Exception.message(e)}")
        {:error, {:exception, Exception.message(e)}}
    end
  end

  # --- Local provider (whisper.cpp) ---

  defp transcribe_local(file_path) do
    bin = Settings.get("voice_transcription_whisper_cpp_bin") || "/opt/whisper.cpp/main"
    model = Settings.get("voice_transcription_whisper_cpp_model") || "/opt/whisper.cpp/models/ggml-small.en.bin"

    cond do
      not executable?(bin) ->
        Logger.warning("[Voice.Transcription] whisper.cpp binary not found at #{bin}")
        {:error, :whisper_cpp_not_installed}

      not File.exists?(model) ->
        Logger.warning("[Voice.Transcription] whisper.cpp model not found at #{model}")
        {:error, :whisper_cpp_model_missing}

      not ffmpeg_available?() ->
        Logger.warning("[Voice.Transcription] ffmpeg not found in PATH")
        {:error, :ffmpeg_missing}

      true ->
        run_whisper_cpp(bin, model, file_path)
    end
  end

  defp run_whisper_cpp(bin, model, source_path) do
    tmp_wav = Path.join(System.tmp_dir!(), "whisper_#{:erlang.unique_integer([:positive])}.wav")
    tmp_txt_base = Path.rootname(tmp_wav)

    try do
      with :ok <- convert_to_pcm16_mono_wav(source_path, tmp_wav),
           :ok <- call_whisper_cpp(bin, model, tmp_wav, tmp_txt_base),
           {:ok, text} <- read_whisper_output(tmp_txt_base <> ".txt") do
        {:ok, %{text: text, language: nil}}
      else
        {:error, reason} = err ->
          Logger.warning("[Voice.Transcription] local whisper failed: #{inspect(reason)}")
          err
      end
    after
      File.rm(tmp_wav)
      File.rm(tmp_txt_base <> ".txt")
    end
  end

  defp convert_to_pcm16_mono_wav(source_path, dest_path) do
    # whisper.cpp needs 16 kHz mono 16-bit PCM
    case System.cmd(
           "ffmpeg",
           ["-y", "-i", source_path, "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le", dest_path],
           stderr_to_stdout: true
         ) do
      {_output, 0} -> :ok
      {output, status} -> {:error, {:ffmpeg_failed, status, String.slice(output, 0, 500)}}
    end
  rescue
    ErlangError -> {:error, :ffmpeg_missing}
  end

  defp call_whisper_cpp(bin, model, wav_path, output_base) do
    args = [
      "-m", model,
      "-f", wav_path,
      "-otxt",
      "-nt",
      "-of", output_base
    ]

    case System.cmd(bin, args, stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {output, status} -> {:error, {:whisper_cpp_failed, status, String.slice(output, 0, 500)}}
    end
  rescue
    ErlangError -> {:error, :whisper_cpp_not_installed}
  end

  defp read_whisper_output(txt_path) do
    case File.read(txt_path) do
      {:ok, contents} -> {:ok, contents |> String.trim() |> collapse_whitespace()}
      {:error, reason} -> {:error, {:read_failed, reason}}
    end
  end

  defp collapse_whitespace(s) do
    s
    |> String.split(~r/\s+/, trim: true)
    |> Enum.join(" ")
  end

  defp executable?(bin) do
    cond do
      File.exists?(bin) and File.stat!(bin).type == :regular -> true
      true -> false
    end
  end

  defp ffmpeg_available? do
    case System.find_executable("ffmpeg") do
      nil -> false
      _ -> true
    end
  end
end
