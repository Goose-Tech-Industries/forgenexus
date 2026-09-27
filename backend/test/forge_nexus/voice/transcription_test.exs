defmodule ForgeNexus.Voice.TranscriptionTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Settings
  alias ForgeNexus.Voice.Transcription


  describe "transcribe/1 basic gates" do
    test "returns {:error, :disabled} when feature flag is off" do
      Settings.set("voice_transcription_enabled", "false")
      assert {:error, :disabled} = Transcription.transcribe("some_file.wav")
    end

    test "returns {:error, :file_not_found} when file does not exist" do
      Settings.set("voice_transcription_enabled", "true")
      assert {:error, :file_not_found} = Transcription.transcribe("nonexistent_audio_file.wav")
    end

    test "returns {:error, :disabled} when provider is 'disabled'" do
      Settings.set("voice_transcription_enabled", "true")
      Settings.set("voice_transcription_provider", "disabled")

      tmp_file = Path.join(System.tmp_dir!(), "audio_gate_test.wav")
      File.write!(tmp_file, "dummy audio bytes")
      on_exit(fn -> File.rm(tmp_file) end)

      assert {:error, :disabled} = Transcription.transcribe(tmp_file)
    end

    test "returns {:error, {:unknown_provider, other}} when provider is unsupported" do
      Settings.set("voice_transcription_enabled", "true")
      Settings.set("voice_transcription_provider", "bogus_provider")

      tmp_file = Path.join(System.tmp_dir!(), "audio_unknown_test.wav")
      File.write!(tmp_file, "dummy audio bytes")
      on_exit(fn -> File.rm(tmp_file) end)

      assert {:error, {:unknown_provider, "bogus_provider"}} = Transcription.transcribe(tmp_file)
    end
  end

  describe "transcribe/1 with 'openai' provider" do
    setup do
      Settings.set("voice_transcription_enabled", "true")
      Settings.set("voice_transcription_provider", "openai")

      tmp_file = Path.join(System.tmp_dir!(), "audio_openai_test.wav")
      File.write!(tmp_file, "dummy audio bytes")

      old_req_opts = Application.get_env(:req, :default_options, [])
      Req.default_options(plug: {Req.Test, ForgeNexus.Voice.Transcription}, retry: false)

      on_exit(fn ->
        File.rm(tmp_file)
        System.delete_env("OPENAI_API_KEY")
        Application.put_env(:req, :default_options, old_req_opts)
      end)

      {:ok, file_path: tmp_file}
    end

    test "returns {:error, :no_api_key} when OPENAI_API_KEY is not set or empty", %{
      file_path: file_path
    } do
      System.delete_env("OPENAI_API_KEY")
      assert {:error, :no_api_key} = Transcription.transcribe(file_path)

      System.put_env("OPENAI_API_KEY", "")
      assert {:error, :no_api_key} = Transcription.transcribe(file_path)
    end

    test "returns {:ok, result} on successful 200 response from OpenAI", %{file_path: file_path} do
      System.put_env("OPENAI_API_KEY", "sk-test-key-12345")

      Req.Test.stub(ForgeNexus.Voice.Transcription, fn conn ->
        Req.Test.json(conn, %{
          "text" => "Welcome to ForgeNexus voice transcription",
          "language" => "english"
        })
      end)

      assert {:ok, result} = Transcription.transcribe(file_path)
      assert result.text == "Welcome to ForgeNexus voice transcription"
      assert result.language == "english"
    end

    test "returns {:error, {:http, status}} on non-200 response", %{file_path: file_path} do
      System.put_env("OPENAI_API_KEY", "sk-test-key-12345")

      Req.Test.stub(ForgeNexus.Voice.Transcription, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => "Invalid API key"})
      end)

      assert {:error, {:http, 401}} = Transcription.transcribe(file_path)
    end

    test "returns {:error, {:request_failed, reason}} on transport failure", %{
      file_path: file_path
    } do
      System.put_env("OPENAI_API_KEY", "sk-test-key-12345")

      Req.Test.stub(ForgeNexus.Voice.Transcription, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, {:request_failed, %Req.TransportError{reason: :econnrefused}}} =
               Transcription.transcribe(file_path)
    end

    test "returns {:error, {:exception, message}} on unexpected runtime exception", %{
      file_path: file_path
    } do
      System.put_env("OPENAI_API_KEY", "sk-test-key-12345")

      Req.Test.stub(ForgeNexus.Voice.Transcription, fn _conn ->
        raise RuntimeError, "Network stack crashed"
      end)

      assert {:error, {:exception, "Network stack crashed"}} = Transcription.transcribe(file_path)
    end
  end

  describe "transcribe/1 with 'local' provider (whisper.cpp)" do
    setup do
      Settings.set("voice_transcription_enabled", "true")
      Settings.set("voice_transcription_provider", "local")

      tmp_file = Path.join(System.tmp_dir!(), "audio_local_test.wav")
      File.write!(tmp_file, "dummy content")

      on_exit(fn ->
        File.rm(tmp_file)
        Application.delete_env(:forge_nexus, :transcription_ffmpeg_available)
        Application.delete_env(:forge_nexus, :transcription_ffmpeg_cmd)
      end)

      {:ok, file_path: tmp_file}
    end

    test "returns {:error, :whisper_cpp_not_installed} when binary does not exist", %{
      file_path: file_path
    } do
      Settings.set("voice_transcription_whisper_cpp_bin", "/nonexistent/path/whisper")
      assert {:error, :whisper_cpp_not_installed} = Transcription.transcribe(file_path)
    end

    test "returns {:error, :whisper_cpp_model_missing} when model does not exist", %{
      file_path: file_path
    } do
      tmp_bin =
        Path.join(
          System.tmp_dir!(),
          "dummy_whisper_bin_#{System.unique_integer([:positive])}.bat"
        )

      File.write!(tmp_bin, "@echo off\nexit /b 0\n")
      on_exit(fn -> File.rm(tmp_bin) end)

      Settings.set("voice_transcription_whisper_cpp_bin", tmp_bin)
      Settings.set("voice_transcription_whisper_cpp_model", "/nonexistent/model.bin")

      assert {:error, :whisper_cpp_model_missing} = Transcription.transcribe(file_path)
    end

    test "returns {:error, :ffmpeg_missing} when ffmpeg is not available in PATH", %{
      file_path: file_path
    } do
      tmp_bin =
        Path.join(
          System.tmp_dir!(),
          "dummy_whisper_bin_#{System.unique_integer([:positive])}.bat"
        )

      File.write!(tmp_bin, "@echo off\nexit /b 0\n")
      on_exit(fn -> File.rm(tmp_bin) end)

      tmp_model =
        Path.join(System.tmp_dir!(), "dummy_model_#{System.unique_integer([:positive])}.bin")

      File.write!(tmp_model, "dummy model")
      on_exit(fn -> File.rm(tmp_model) end)

      Settings.set("voice_transcription_whisper_cpp_bin", tmp_bin)
      Settings.set("voice_transcription_whisper_cpp_model", tmp_model)
      Application.put_env(:forge_nexus, :transcription_ffmpeg_available, false)

      assert {:error, :ffmpeg_missing} = Transcription.transcribe(file_path)
    end

    test "executes local whisper workflow and returns text on success" do
      valid_wav = Path.join(System.tmp_dir!(), "source_#{System.unique_integer([:positive])}.wav")

      System.cmd("ffmpeg", [
        "-y",
        "-f",
        "lavfi",
        "-i",
        "anullsrc=r=16000:cl=mono",
        "-t",
        "0.5",
        valid_wav
      ])

      on_exit(fn -> File.rm(valid_wav) end)

      tmp_model =
        Path.join(System.tmp_dir!(), "mock_model_#{System.unique_integer([:positive])}.bin")

      File.write!(tmp_model, "mock model bytes")
      on_exit(fn -> File.rm(tmp_model) end)

      tmp_bin =
        Path.join(System.tmp_dir!(), "mock_whisper_#{System.unique_integer([:positive])}.bat")

      bat_content =
        "@echo off\necho Local   transcribed    text  output> \"%~8.txt\"\nexit /b 0\n"

      File.write!(tmp_bin, bat_content)
      on_exit(fn -> File.rm(tmp_bin) end)

      Settings.set("voice_transcription_whisper_cpp_bin", tmp_bin)
      Settings.set("voice_transcription_whisper_cpp_model", tmp_model)

      assert {:ok, result} = Transcription.transcribe(valid_wav)
      assert result.text == "Local transcribed text output"
      assert result.language == nil
    end

    test "handles whisper.cpp script failure" do
      valid_wav =
        Path.join(System.tmp_dir!(), "source_fail_#{System.unique_integer([:positive])}.wav")

      System.cmd("ffmpeg", [
        "-y",
        "-f",
        "lavfi",
        "-i",
        "anullsrc=r=16000:cl=mono",
        "-t",
        "0.5",
        valid_wav
      ])

      on_exit(fn -> File.rm(valid_wav) end)

      tmp_model =
        Path.join(System.tmp_dir!(), "mock_model_fail_#{System.unique_integer([:positive])}.bin")

      File.write!(tmp_model, "mock model")
      on_exit(fn -> File.rm(tmp_model) end)

      tmp_bin =
        Path.join(
          System.tmp_dir!(),
          "mock_whisper_fail_#{System.unique_integer([:positive])}.bat"
        )

      File.write!(tmp_bin, "@echo off\necho error occurred\nexit /b 2\n")
      on_exit(fn -> File.rm(tmp_bin) end)

      Settings.set("voice_transcription_whisper_cpp_bin", tmp_bin)
      Settings.set("voice_transcription_whisper_cpp_model", tmp_model)

      assert {:error, {:whisper_cpp_failed, 2, _}} = Transcription.transcribe(valid_wav)
    end

    test "handles whisper.cpp script success but output file missing" do
      valid_wav =
        Path.join(System.tmp_dir!(), "source_nofile_#{System.unique_integer([:positive])}.wav")

      System.cmd("ffmpeg", [
        "-y",
        "-f",
        "lavfi",
        "-i",
        "anullsrc=r=16000:cl=mono",
        "-t",
        "0.5",
        valid_wav
      ])

      on_exit(fn -> File.rm(valid_wav) end)

      tmp_model =
        Path.join(
          System.tmp_dir!(),
          "mock_model_nofile_#{System.unique_integer([:positive])}.bin"
        )

      File.write!(tmp_model, "mock model")
      on_exit(fn -> File.rm(tmp_model) end)

      tmp_bin =
        Path.join(
          System.tmp_dir!(),
          "mock_whisper_nofile_#{System.unique_integer([:positive])}.bat"
        )

      # Exits with 0 without creating the .txt output file
      File.write!(tmp_bin, "@echo off\nexit /b 0\n")
      on_exit(fn -> File.rm(tmp_bin) end)

      Settings.set("voice_transcription_whisper_cpp_bin", tmp_bin)
      Settings.set("voice_transcription_whisper_cpp_model", tmp_model)

      assert {:error, {:read_failed, :enoent}} = Transcription.transcribe(valid_wav)
    end

    test "handles ffmpeg audio conversion failure" do
      invalid_audio =
        Path.join(System.tmp_dir!(), "invalid_#{System.unique_integer([:positive])}.wav")

      File.write!(invalid_audio, "definitely not a valid audio file")
      on_exit(fn -> File.rm(invalid_audio) end)

      tmp_model =
        Path.join(System.tmp_dir!(), "mock_model_ff_#{System.unique_integer([:positive])}.bin")

      File.write!(tmp_model, "mock model")
      on_exit(fn -> File.rm(tmp_model) end)

      tmp_bin =
        Path.join(System.tmp_dir!(), "mock_whisper_ff_#{System.unique_integer([:positive])}.bat")

      File.write!(tmp_bin, "@echo off\nexit /b 0\n")
      on_exit(fn -> File.rm(tmp_bin) end)

      Settings.set("voice_transcription_whisper_cpp_bin", tmp_bin)
      Settings.set("voice_transcription_whisper_cpp_model", tmp_model)

      assert {:error, {:ffmpeg_failed, _, _}} = Transcription.transcribe(invalid_audio)
    end

    test "handles ffmpeg executable missing during conversion" do
      valid_wav =
        Path.join(
          System.tmp_dir!(),
          "source_ff_missing_#{System.unique_integer([:positive])}.wav"
        )

      System.cmd("ffmpeg", [
        "-y",
        "-f",
        "lavfi",
        "-i",
        "anullsrc=r=16000:cl=mono",
        "-t",
        "0.5",
        valid_wav
      ])

      on_exit(fn -> File.rm(valid_wav) end)

      tmp_model =
        Path.join(System.tmp_dir!(), "mock_model_ff_m_#{System.unique_integer([:positive])}.bin")

      File.write!(tmp_model, "mock model")
      on_exit(fn -> File.rm(tmp_model) end)

      tmp_bin =
        Path.join(
          System.tmp_dir!(),
          "mock_whisper_ff_m_#{System.unique_integer([:positive])}.bat"
        )

      File.write!(tmp_bin, "@echo off\nexit /b 0\n")
      on_exit(fn -> File.rm(tmp_bin) end)

      Settings.set("voice_transcription_whisper_cpp_bin", tmp_bin)
      Settings.set("voice_transcription_whisper_cpp_model", tmp_model)

      Application.put_env(:forge_nexus, :transcription_ffmpeg_available, true)

      Application.put_env(
        :forge_nexus,
        :transcription_ffmpeg_cmd,
        "nonexistent_ffmpeg_executable_xyz"
      )

      assert {:error, :ffmpeg_missing} = Transcription.transcribe(valid_wav)
    end

    test "handles whisper.cpp executable missing during whisper execution" do
      valid_wav =
        Path.join(System.tmp_dir!(), "source_whisper_m_#{System.unique_integer([:positive])}.wav")

      System.cmd("ffmpeg", [
        "-y",
        "-f",
        "lavfi",
        "-i",
        "anullsrc=r=16000:cl=mono",
        "-t",
        "0.5",
        valid_wav
      ])

      on_exit(fn -> File.rm(valid_wav) end)

      tmp_model =
        Path.join(System.tmp_dir!(), "mock_model_w_m_#{System.unique_integer([:positive])}.bin")

      File.write!(tmp_model, "mock model")
      on_exit(fn -> File.rm(tmp_model) end)

      tmp_bin =
        Path.join(System.tmp_dir!(), "mock_whisper_w_m_#{System.unique_integer([:positive])}.bat")

      File.write!(tmp_bin, "@echo off\nexit /b 0\n")

      on_exit(fn ->
        File.rm(tmp_bin)
        Application.delete_env(:forge_nexus, :transcription_whisper_cmd)
      end)

      Settings.set("voice_transcription_whisper_cpp_bin", tmp_bin)
      Settings.set("voice_transcription_whisper_cpp_model", tmp_model)

      Application.put_env(
        :forge_nexus,
        :transcription_whisper_cmd,
        "nonexistent_whisper_executable_xyz"
      )

      assert {:error, :whisper_cpp_not_installed} = Transcription.transcribe(valid_wav)
    end
  end
end
