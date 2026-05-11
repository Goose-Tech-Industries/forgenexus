alias ForgeNexus.Voice.Transcription
alias ForgeNexus.Settings

IO.puts("=== whisper.cpp local provider smoke test ===\n")

# Enable transcription, set provider to local
Settings.set("voice_transcription_enabled", "true")
Settings.set("voice_transcription_provider", "local")
Settings.set("voice_transcription_whisper_cpp_bin", "/opt/whisper.cpp/main")
Settings.set("voice_transcription_whisper_cpp_model", "/opt/whisper.cpp/models/ggml-small.en.bin")

# Case 1: whisper.cpp not installed -> graceful error
tmp_file = Path.join(System.tmp_dir!(), "fake_audio.webm")
File.write!(tmp_file, <<0x1A, 0x45, 0xDF, 0xA3>> <> :binary.copy(<<0>>, 1024))

IO.puts("## Case 1: whisper.cpp NOT installed (expected graceful error)")

case Transcription.transcribe(tmp_file) do
  {:error, :whisper_cpp_not_installed} ->
    IO.puts("  ✓ returns :whisper_cpp_not_installed when binary missing")

  {:error, :whisper_cpp_model_missing} ->
    IO.puts("  ✓ returns :whisper_cpp_model_missing when model missing")

  {:error, :ffmpeg_missing} ->
    IO.puts("  ✓ returns :ffmpeg_missing (expected on minimal dev envs)")

  {:ok, result} ->
    IO.puts("  ✓ whisper.cpp is installed and transcribed: #{inspect(result)}")

  other ->
    IO.puts("  ? returned #{inspect(other)}")
end

# Case 2: file does not exist
IO.puts("\n## Case 2: file not found")

case Transcription.transcribe("/nonexistent/path.webm") do
  {:error, :file_not_found} -> IO.puts("  ✓ returns :file_not_found")
  other -> IO.puts("  ✗ expected :file_not_found, got #{inspect(other)}"); System.halt(1)
end

# Case 3: feature flag off
Settings.set("voice_transcription_enabled", "false")
IO.puts("\n## Case 3: feature flag off")

case Transcription.transcribe(tmp_file) do
  {:error, :disabled} -> IO.puts("  ✓ returns :disabled when flag is off")
  other -> IO.puts("  ✗ expected :disabled, got #{inspect(other)}"); System.halt(1)
end

# Case 4: unknown provider
Settings.set("voice_transcription_enabled", "true")
Settings.set("voice_transcription_provider", "nonsense")
IO.puts("\n## Case 4: unknown provider")

case Transcription.transcribe(tmp_file) do
  {:error, {:unknown_provider, "nonsense"}} -> IO.puts("  ✓ returns {:unknown_provider, \"nonsense\"}")
  other -> IO.puts("  ✗ expected unknown_provider, got #{inspect(other)}"); System.halt(1)
end

# Reset to safe defaults
Settings.set("voice_transcription_enabled", "false")
Settings.set("voice_transcription_provider", "disabled")
File.rm(tmp_file)

IO.puts("\n=== All whisper local provider checks passed ===")
