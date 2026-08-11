defmodule ForgeNexus.Workers.NotificationEmailer do
  @moduledoc """
  Oban worker that sends email notifications for replies, mentions, and DMs.
  Respects user preferences (DND, email toggles).
  """
  use Oban.Worker, queue: :mailers, max_attempts: 3

  alias ForgeNexus.{Mailer, Accounts}
  import Swoosh.Email

  @from {"ForgeNexus", "noreply@forum.tcgaming.quest"}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => type} = args}) do
    user = Accounts.get_user!(args["user_id"])
    pref = Accounts.get_preferences(user.id)

    if should_send_email?(type, pref) do
      email = build_email(type, user, args)
      if email, do: Mailer.deliver(email)
    end

    :ok
  end

  defp should_send_email?(type, pref) do
    # Check DND
    if pref.dnd_enabled and in_dnd_window?(pref.dnd_start, pref.dnd_end) do
      false
    else
      case type do
        "reply" -> pref.email_replies
        "mention" -> pref.email_mentions
        "dm" -> pref.email_dms
        _ -> false
      end
    end
  end

  defp in_dnd_window?(start_str, end_str) do
    now = DateTime.utc_now()
    {h, m} = parse_time(start_str)
    {eh, em} = parse_time(end_str)
    current = now.hour * 60 + now.minute
    start_min = h * 60 + m
    end_min = eh * 60 + em

    if start_min < end_min do
      current >= start_min and current < end_min
    else
      # Wraps midnight (e.g. 22:00 to 08:00)
      current >= start_min or current < end_min
    end
  end

  defp parse_time(time_str) do
    case String.split(time_str || "00:00", ":") do
      [h, m] ->
        hour =
          case Integer.parse(h) do
            {n, _} -> n
            :error -> 0
          end

        minute =
          case Integer.parse(m) do
            {n, _} -> n
            :error -> 0
          end

        {hour, minute}

      _ ->
        {0, 0}
    end
  end

  defp build_email("reply", user, args) do
    thread_title = args["thread_title"] || "a thread"
    replier = args["actor_name"] || "Someone"
    thread_url = "#{base_url()}/threads/#{args["thread_slug"]}"

    new()
    |> to({user.username, user.email})
    |> from(@from)
    |> subject("#{replier} replied to \"#{thread_title}\"")
    |> html_body("""
    <p><strong>#{replier}</strong> replied to <strong>#{thread_title}</strong></p>
    <p><a href="#{thread_url}">View thread</a></p>
    """)
    |> text_body("#{replier} replied to #{thread_title}: #{thread_url}")
  end

  defp build_email("mention", user, args) do
    actor = args["actor_name"] || "Someone"
    url = args["url"] || base_url()

    new()
    |> to({user.username, user.email})
    |> from(@from)
    |> subject("#{actor} mentioned you on ForgeNexus")
    |> html_body("""
    <p><strong>#{actor}</strong> mentioned you.</p>
    <p><a href="#{url}">View post</a></p>
    """)
    |> text_body("#{actor} mentioned you: #{url}")
  end

  defp build_email("dm", user, args) do
    sender = args["actor_name"] || "Someone"

    new()
    |> to({user.username, user.email})
    |> from(@from)
    |> subject("New message from #{sender}")
    |> html_body("""
    <p><strong>#{sender}</strong> sent you a private message.</p>
    <p><a href="#{base_url()}/messages">View messages</a></p>
    """)
    |> text_body("New message from #{sender}: #{base_url()}/messages")
  end

  defp build_email(_, _, _), do: nil

  defp base_url do
    Application.get_env(:forge_nexus, :frontend_url, "http://localhost:5173")
  end

  # Helper to enqueue from anywhere in the app
  def enqueue_reply_notification(user_id, actor_name, thread_title, thread_slug) do
    %{
      type: "reply",
      user_id: user_id,
      actor_name: actor_name,
      thread_title: thread_title,
      thread_slug: thread_slug
    }
    |> __MODULE__.new()
    |> Oban.insert()
  end

  def enqueue_mention_notification(user_id, actor_name, url) do
    %{type: "mention", user_id: user_id, actor_name: actor_name, url: url}
    |> __MODULE__.new()
    |> Oban.insert()
  end

  def enqueue_dm_notification(user_id, actor_name) do
    %{type: "dm", user_id: user_id, actor_name: actor_name}
    |> __MODULE__.new()
    |> Oban.insert()
  end
end
