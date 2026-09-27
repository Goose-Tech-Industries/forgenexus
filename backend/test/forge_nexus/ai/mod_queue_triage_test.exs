defmodule ForgeNexus.AI.ModQueueTriageTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.AI.ModQueueTriage
  alias ForgeNexus.Settings

  describe "triage/2" do
    test "returns disabled reason when ai_mod_triage_enabled is false" do
      Settings.set("ai_mod_triage_enabled", "false")

      assert {:ok, result} = ModQueueTriage.triage("Offensive post content")
      assert result.severity == "medium"
      assert result.category == "other"
      assert result.confidence == 0.0
      assert result.reason == "AI triage disabled"
    end

    test "returns no API key reason when ANTHROPIC_API_KEY is not set or empty" do
      Settings.set("ai_mod_triage_enabled", "true")
      prev_key = System.get_env("ANTHROPIC_API_KEY")
      System.delete_env("ANTHROPIC_API_KEY")

      on_exit(fn ->
        if prev_key,
          do: System.put_env("ANTHROPIC_API_KEY", prev_key),
          else: System.delete_env("ANTHROPIC_API_KEY")
      end)

      assert {:ok, result} = ModQueueTriage.triage("Offensive post content")
      assert result.reason == "No API key"

      System.put_env("ANTHROPIC_API_KEY", "")
      assert {:ok, result2} = ModQueueTriage.triage("Offensive post content")
      assert result2.reason == "No API key"
    end

    test "successfully triages report with reporter_reason in context" do
      Settings.set("ai_mod_triage_enabled", "true")
      Settings.set("ai_mod_triage_model", "claude-haiku-4-5-20251001")
      prev_key = System.get_env("ANTHROPIC_API_KEY")
      System.put_env("ANTHROPIC_API_KEY", "test_key")

      Req.default_options(plug: {Req.Test, ForgeNexus.AI.ModQueueTriage}, retry: false)

      on_exit(fn ->
        Req.default_options([])

        if prev_key,
          do: System.put_env("ANTHROPIC_API_KEY", prev_key),
          else: System.delete_env("ANTHROPIC_API_KEY")
      end)

      Req.Test.stub(ForgeNexus.AI.ModQueueTriage, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)
        user_prompt = hd(parsed["messages"])["content"]
        assert user_prompt =~ "Reporter's reason: spam links"

        resp = %{
          "content" => [
            %{
              "text" =>
                Jason.encode!(%{
                  "severity" => "high",
                  "category" => "spam",
                  "confidence" => 0.95,
                  "reason" => "Repeated promotional links."
                })
            }
          ]
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(resp))
      end)

      assert {:ok, result} =
               ModQueueTriage.triage("Check out this site: spam.com", %{
                 reporter_reason: "spam links"
               })

      assert result.severity == "high"
      assert result.category == "spam"
      assert result.confidence == 0.95
      assert result.reason == "Repeated promotional links."
    end

    test "handles missing confidence and reason in Claude response using defaults" do
      Settings.set("ai_mod_triage_enabled", "true")
      prev_key = System.get_env("ANTHROPIC_API_KEY")
      System.put_env("ANTHROPIC_API_KEY", "test_key")

      Req.default_options(plug: {Req.Test, ForgeNexus.AI.ModQueueTriage}, retry: false)

      on_exit(fn ->
        Req.default_options([])

        if prev_key,
          do: System.put_env("ANTHROPIC_API_KEY", prev_key),
          else: System.delete_env("ANTHROPIC_API_KEY")
      end)

      Req.Test.stub(ForgeNexus.AI.ModQueueTriage, fn conn ->
        resp = %{
          "content" => [
            %{
              "text" =>
                Jason.encode!(%{
                  "severity" => "low",
                  "category" => "off_topic"
                })
            }
          ]
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(resp))
      end)

      assert {:ok, result} = ModQueueTriage.triage("Just off topic talk")
      assert result.severity == "low"
      assert result.category == "off_topic"
      assert result.confidence == 0.5
      assert result.reason == ""
    end

    test "handles JSON parse error or invalid severity/category" do
      Settings.set("ai_mod_triage_enabled", "true")
      prev_key = System.get_env("ANTHROPIC_API_KEY")
      System.put_env("ANTHROPIC_API_KEY", "test_key")

      Req.default_options(plug: {Req.Test, ForgeNexus.AI.ModQueueTriage}, retry: false)

      on_exit(fn ->
        Req.default_options([])

        if prev_key,
          do: System.put_env("ANTHROPIC_API_KEY", prev_key),
          else: System.delete_env("ANTHROPIC_API_KEY")
      end)

      # 1. Non-JSON response
      Req.Test.stub(ForgeNexus.AI.ModQueueTriage, fn conn ->
        resp = %{"content" => [%{"text" => "Sorry, I cannot classify this."}]}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(resp))
      end)

      assert {:ok, result} = ModQueueTriage.triage("Some text")
      assert result.reason == "Parse error"

      # 2. Invalid category
      Req.Test.stub(ForgeNexus.AI.ModQueueTriage, fn conn ->
        resp = %{
          "content" => [
            %{
              "text" =>
                Jason.encode!(%{
                  "severity" => "critical",
                  "category" => "non_existent_category"
                })
            }
          ]
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(resp))
      end)

      assert {:ok, result2} = ModQueueTriage.triage("Some text")
      assert result2.reason == "Parse error"
    end

    test "handles API errors and exceptions" do
      Settings.set("ai_mod_triage_enabled", "true")
      prev_key = System.get_env("ANTHROPIC_API_KEY")
      System.put_env("ANTHROPIC_API_KEY", "test_key")

      Req.default_options(plug: {Req.Test, ForgeNexus.AI.ModQueueTriage}, retry: false)

      on_exit(fn ->
        Req.default_options([])

        if prev_key,
          do: System.put_env("ANTHROPIC_API_KEY", prev_key),
          else: System.delete_env("ANTHROPIC_API_KEY")
      end)

      # 1. HTTP 500 error
      Req.Test.stub(ForgeNexus.AI.ModQueueTriage, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "server_error"}))
      end)

      assert {:ok, result} = ModQueueTriage.triage("Some text")
      assert result.reason == "API error"

      # 2. Exception
      Req.Test.stub(ForgeNexus.AI.ModQueueTriage, fn _conn ->
        raise RuntimeError, "Connection lost"
      end)

      assert {:ok, result2} = ModQueueTriage.triage("Some text")
      assert result2.reason == "Exception"
    end
  end
end
