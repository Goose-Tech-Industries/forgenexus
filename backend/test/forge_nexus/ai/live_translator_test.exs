defmodule ForgeNexus.AI.LiveTranslatorTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.AI.LiveTranslator
  alias ForgeNexus.{Accounts, Settings, Voice}

  defp create_user do
    uid = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "trans_u_#{uid}",
        email: "trans_u_#{uid}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp create_voice_room(user) do
    uid = System.unique_integer([:positive])
    {:ok, room} = Voice.create_room(%{name: "Voice Room #{uid}", created_by_id: user.id})
    room
  end

  describe "supported_languages/0" do
    test "returns expected list of supported language codes" do
      langs = LiveTranslator.supported_languages()
      assert is_list(langs)
      assert "en" in langs
      assert "es" in langs
      assert "ja" in langs
      assert length(langs) == 16
    end
  end

  describe "translate/4" do
    test "returns {:error, :disabled} when voice translation is disabled" do
      Settings.set("voice_translation_enabled", "false")

      assert {:error, :disabled} =
               LiveTranslator.translate(Ecto.UUID.generate(), Ecto.UUID.generate(), "hello", "es")
    end

    test "returns {:error, :no_api_key} when enabled but ANTHROPIC_API_KEY is missing" do
      Settings.set("voice_translation_enabled", "true")
      prev_key = System.get_env("ANTHROPIC_API_KEY")
      System.delete_env("ANTHROPIC_API_KEY")

      on_exit(fn ->
        if prev_key,
          do: System.put_env("ANTHROPIC_API_KEY", prev_key),
          else: System.delete_env("ANTHROPIC_API_KEY")
      end)

      assert {:error, :no_api_key} =
               LiveTranslator.translate(Ecto.UUID.generate(), Ecto.UUID.generate(), "hello", "es")
    end

    test "translates text, broadcasts subtitle, and saves record on 200 response" do
      Settings.set("voice_translation_enabled", "true")
      Settings.set("voice_translation_model", "claude-haiku-4-5-20251001")
      prev_key = System.get_env("ANTHROPIC_API_KEY")
      System.put_env("ANTHROPIC_API_KEY", "test_anthropic_key")

      user = create_user()
      room = create_voice_room(user)

      Req.default_options(plug: {Req.Test, ForgeNexus.AI.LiveTranslator}, retry: false)

      on_exit(fn ->
        Req.default_options([])

        if prev_key,
          do: System.put_env("ANTHROPIC_API_KEY", prev_key),
          else: System.delete_env("ANTHROPIC_API_KEY")
      end)

      # Subscribe to voice room broadcast
      ForgeNexusWeb.Endpoint.subscribe("voice:#{room.id}")

      # Test across all supported languages to cover every branch in language_name/1
      for lang <- LiveTranslator.supported_languages() ++ ["custom_lang"] do
        Req.Test.stub(ForgeNexus.AI.LiveTranslator, fn conn ->
          assert conn.request_path == "/v1/messages"
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          parsed = Jason.decode!(body)
          assert parsed["model"] == "claude-haiku-4-5-20251001"

          resp = %{"content" => [%{"text" => "Translated [#{lang}]: Hello World\n"}]}

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(resp))
        end)

        assert {:ok, translated} = LiveTranslator.translate(room.id, user.id, "Hello World", lang)
        assert translated == "Translated [#{lang}]: Hello World"

        assert_receive %Phoenix.Socket.Broadcast{
          topic: topic,
          event: "subtitle",
          payload: payload
        }

        assert topic == "voice:#{room.id}"
        assert payload.translated == translated
        assert payload.language == lang
      end

      # Also test with user_id = nil
      assert {:ok, _} = LiveTranslator.translate(room.id, nil, "Hello World", "en")
      assert_receive %Phoenix.Socket.Broadcast{topic: _, event: "subtitle", payload: _}
    end

    test "handles HTTP error status codes, request failures, and exceptions" do
      Settings.set("voice_translation_enabled", "true")
      prev_key = System.get_env("ANTHROPIC_API_KEY")
      System.put_env("ANTHROPIC_API_KEY", "test_anthropic_key")

      user = create_user()
      room = create_voice_room(user)

      Req.default_options(plug: {Req.Test, ForgeNexus.AI.LiveTranslator}, retry: false)

      on_exit(fn ->
        Req.default_options([])

        if prev_key,
          do: System.put_env("ANTHROPIC_API_KEY", prev_key),
          else: System.delete_env("ANTHROPIC_API_KEY")
      end)

      # 1. HTTP 500 error
      Req.Test.stub(ForgeNexus.AI.LiveTranslator, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "server error"}))
      end)

      assert {:error, {:http, 500}} = LiveTranslator.translate(room.id, user.id, "Hello", "es")

      # 2. Request failure
      Req.Test.stub(ForgeNexus.AI.LiveTranslator, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, {:request_failed, _}} =
               LiveTranslator.translate(room.id, user.id, "Hello", "es")

      # 3. Exception
      Req.Test.stub(ForgeNexus.AI.LiveTranslator, fn _conn ->
        raise RuntimeError, "Network crash"
      end)

      assert {:error, {:exception, "Network crash"}} =
               LiveTranslator.translate(room.id, user.id, "Hello", "es")
    end
  end
end
