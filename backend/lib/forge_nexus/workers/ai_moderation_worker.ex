defmodule ForgeNexus.Workers.AIModerationWorker do
  use Oban.Worker, queue: :ai, max_attempts: 3

  alias ForgeNexus.{AI, Accounts, Forums, Moderation, Repo}
  alias ForgeNexus.AI.Client

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"report_id" => report_id}}) do
    unless AI.feature_enabled?(:moderation), do: throw(:disabled)

    report = Moderation.get_report!(report_id)

    {post, thread, reported_user} =
      cond do
        report.reportable_type == "post" ->
          p = Repo.get(Forums.Post, report.reportable_id)
          t = if p, do: Repo.get(Forums.Thread, p.thread_id)
          u = if p, do: Repo.get(Accounts.User, p.user_id)
          {p, t, u}

        report.reportable_type == "thread" ->
          t = Repo.get(Forums.Thread, report.reportable_id)
          u = if t, do: Repo.get(Accounts.User, t.user_id)
          {nil, t, u}

        report.reportable_type == "user" ->
          u = Repo.get(Accounts.User, report.reportable_id)
          {nil, nil, u}

        true ->
          p = if report.post_id, do: Repo.get(Forums.Post, report.post_id)
          t = if report.thread_id, do: Repo.get(Forums.Thread, report.thread_id)
          u = if report.reported_user_id, do: Repo.get(Accounts.User, report.reported_user_id)
          {p, t, u}
      end

    # Get user's history for context
    history =
      if reported_user do
        infractions = Moderation.user_infractions(reported_user.id)
        count = length(infractions.warnings) + length(infractions.bans)
        "User has #{count} prior infractions."
      else
        "No user history available."
      end

    # Check historical mod decisions for similar cases
    accuracy = AI.moderation_accuracy(days: 90)

    accuracy_context =
      if accuracy && accuracy.total > 0 do
        rate = round(accuracy.accepted / accuracy.total * 100)
        "Historical AI accuracy: #{rate}% (#{accuracy.total} reviews)"
      else
        ""
      end

    messages = [
      %{
        role: "system",
        content: """
        You are a forum moderation assistant for ForgeNexus. Analyze reported content and suggest an action.

        Available actions: dismiss (not a violation), warn (minor violation), temp_ban (serious violation), delete (remove content), cooling_off (lock thread temporarily).

        Respond in JSON format:
        {"action": "...", "confidence": 0.0-1.0, "reasoning": "...", "context_summary": "..."}

        Consider: severity, user intent, community impact, prior history. Be fair and measured.
        #{accuracy_context}
        """
      },
      %{
        role: "user",
        content: """
        Report reason: #{report.reason}
        #{if post, do: "Post content: #{post.body}", else: ""}
        #{if thread, do: "Thread title: #{thread.title}", else: ""}
        #{history}
        """
      }
    ]

    case Client.complete(:moderation, messages, metadata: %{report_id: report_id}) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, parsed} ->
            AI.create_moderation_analysis(%{
              report_id: report_id,
              post_id: if(post, do: post.id),
              thread_id: if(thread, do: thread.id),
              suggested_action: parsed["action"],
              confidence: parsed["confidence"],
              reasoning: parsed["reasoning"],
              context_summary: parsed["context_summary"]
            })

          # Failed to parse, skip silently
          _ ->
            :ok
        end

      {:error, _} ->
        :ok
    end

    :ok
  catch
    :disabled -> :ok
  end
end
