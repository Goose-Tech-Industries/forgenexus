defmodule ForgeNexus.TestMockHttpServer do
  @moduledoc "Ephemeral Bandit HTTP server for testing Webhooks and Ollama AI clients."
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case {conn.method, conn.request_path} do
      {"POST", "/webhook/success"} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{status: "delivered", ok: true}))

      {"POST", "/webhook/error"} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(500, Jason.encode!(%{error: "internal server error"}))

      {"POST", "/api/chat"} ->
        {:ok, body, conn} = read_body(conn)
        parsed = Jason.decode!(body)
        messages = parsed["messages"] || []

        system_msg =
          Enum.find_value(messages, "", fn m ->
            if m["role"] == "system", do: m["content"]
          end)

        content =
          cond do
            String.contains?(system_msg, "forum moderation assistant") ->
              Jason.encode!(%{
                "action" => "warn",
                "confidence" => 0.95,
                "reasoning" => "Content violates spam policy.",
                "context_summary" => "First warning for spam."
              })

            String.contains?(system_msg, "suggest categorization") ->
              Jason.encode!(%{
                "tags" => ["gaming", "strategy"],
                "content_type" => "discussion",
                "suggested_prefix" => "Guide",
                "confidence" => 0.9
              })

            String.contains?(system_msg, "Analyze the sentiment") ->
              Jason.encode!(%{
                "sentiment" => 0.85,
                "emotions" => ["happy", "grateful"]
              })

            String.contains?(system_msg, "Translate the following forum post") ->
              "Ceci est une traduction automatique."

            String.contains?(system_msg, "Summarize this forum thread discussion") ->
              Jason.encode!(%{
                "summary" => "This is a detailed summary of the conversation.",
                "key_points" => ["Important point 1", "Important point 2"],
                "participant_count" => 3
              })

            true ->
              "Default mock AI response"
          end

        resp_body =
          Jason.encode!(%{
            "message" => %{"content" => content},
            "prompt_eval_count" => 40,
            "eval_count" => 25
          })

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, resp_body)

      _ ->
        conn |> send_resp(404, "not found")
    end
  end

  def start do
    {:ok, pid} = Bandit.start_link(plug: __MODULE__, port: 0, ip: {127, 0, 0, 1})
    {:ok, {_, port}} = ThousandIsland.listener_info(pid)
    {pid, port}
  end
end
