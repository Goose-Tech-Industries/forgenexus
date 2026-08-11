defmodule ForgeNexus.Plugins.Nodes.Poll.CreatePoll do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    question = Map.get(inputs, :question) || Map.get(inputs, "question")
    thread_id = Map.get(inputs, :thread_id) || Map.get(inputs, "thread_id")
    forum_id = Map.get(inputs, :forum_id) || Map.get(inputs, "forum_id")
    title = Map.get(inputs, :title) || Map.get(inputs, "title") || question
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id") || ctx[:user_id]
    options_raw = Map.get(config, "options", "")
    duration_hours = Map.get(config, "duration_hours", 24) |> to_number()
    allow_multiple = Map.get(config, "allow_multiple", false)

    options =
      options_raw
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    cond do
      length(options) < 2 ->
        {:error, "Poll must have at least 2 options", ctx}

      is_nil(thread_id) and (is_nil(forum_id) or is_nil(user_id)) ->
        {:error, "Either thread_id, or both forum_id and user_id are required to create a poll",
         ctx}

      true ->
        with {:ok, resolved_thread_id, ctx} <-
               resolve_thread(thread_id, forum_id, user_id, title, question, ctx) do
          closes_at =
            DateTime.utc_now()
            |> DateTime.add(trunc(duration_hours * 3600), :second)
            |> DateTime.truncate(:second)

          attrs = %{
            question: question,
            thread_id: resolved_thread_id,
            is_multiple_choice: allow_multiple,
            max_choices: if(allow_multiple, do: length(options), else: 1),
            closes_at: closes_at
          }

          case ForgeNexus.Forums.Polls.create_poll(attrs, options) do
            {:ok, poll} ->
              ctx = Sandbox.increment_db_ops(ctx)
              {:ok, %{poll_id: poll.id, thread_id: resolved_thread_id, success: true}, ctx}

            {:error, err} ->
              ctx = Sandbox.increment_db_ops(ctx)
              {:error, "Failed to create poll: #{inspect(err)}", ctx}
          end
        end
    end
  end

  # Auto-creates a host thread when no thread_id is provided.
  defp resolve_thread(thread_id, _forum_id, _user_id, _title, _question, ctx)
       when not is_nil(thread_id) do
    {:ok, thread_id, ctx}
  end

  defp resolve_thread(nil, forum_id, user_id, title, question, ctx) do
    body = "This thread hosts a poll: #{question}"

    attrs = %{
      "forum_id" => forum_id,
      "user_id" => user_id,
      "title" => title || "Poll",
      "body" => body,
      "body_html" => body
    }

    case ForgeNexus.Forums.create_thread(attrs) do
      {:ok, thread} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, thread.id, ctx}

      {:error, reason} ->
        {:error, "Failed to auto-create poll thread: #{inspect(reason)}", ctx}

      {:error, :spam_detected, reason} ->
        {:error, "Poll thread rejected: #{inspect(reason)}", ctx}
    end
  end

  defp to_number(v) when is_number(v), do: v

  defp to_number(v) when is_binary(v) do
    case Float.parse(v) do
      {n, _} -> n
      _ -> 0
    end
  end

  defp to_number(_), do: 0

  @impl true
  def validate_config(config) do
    case Map.get(config, "options") do
      nil ->
        {:error, ["options is required"]}

      "" ->
        {:error, ["options cannot be empty"]}

      opts when is_binary(opts) ->
        parsed = opts |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
        if length(parsed) < 2, do: {:error, ["at least 2 options are required"]}, else: :ok

      _ ->
        {:error, ["options must be a comma-separated string"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "poll/create_poll",
      category: "poll",
      label: "Create Poll",
      description: "Creates a new poll attached to a thread with multiple choice options.",
      inputs: [
        %{name: "question", type: "string", required: true},
        %{
          name: "thread_id",
          type: "string",
          required: false,
          description:
            "Existing thread to host the poll. If omitted, a new thread is auto-created."
        },
        %{
          name: "forum_id",
          type: "string",
          required: false,
          description: "Forum for auto-created host thread (required if thread_id is omitted)."
        },
        %{
          name: "user_id",
          type: "string",
          required: false,
          description: "Author for auto-created host thread (required if thread_id is omitted)."
        },
        %{
          name: "title",
          type: "string",
          required: false,
          description: "Title for auto-created host thread. Defaults to the question."
        }
      ],
      outputs: [
        %{name: "poll_id", type: "string"},
        %{name: "thread_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "options",
          type: "string",
          default: "",
          description: "Comma-separated poll options"
        },
        %{
          name: "duration_hours",
          type: "number",
          default: 24,
          description: "How long the poll stays open (hours)"
        },
        %{
          name: "allow_multiple",
          type: "boolean",
          default: false,
          description: "Allow users to vote for multiple options"
        }
      ]
    }
  end
end
