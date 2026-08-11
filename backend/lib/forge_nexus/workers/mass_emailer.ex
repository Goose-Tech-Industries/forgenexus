defmodule ForgeNexus.Workers.MassEmailer do
  @moduledoc """
  Oban worker that sends mass email announcements to forum members.
  Supports segmenting by: all users, active in last 30 days, or verified email only.
  Sends in batches of 50 to avoid overwhelming the mailer.
  """
  use Oban.Worker, queue: :mailers, max_attempts: 3, unique: [period: 60]

  import Ecto.Query, except: [from: 2]
  alias ForgeNexus.{Repo, Mailer}
  alias ForgeNexus.Accounts.User

  @from {"ForgeNexus", "noreply@forum.tcgaming.quest"}
  @batch_size 50

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"subject" => subject, "body_html" => body_html, "segment" => segment}
      }) do
    users = query_users(segment)

    users
    |> Enum.chunk_every(@batch_size)
    |> Enum.each(fn batch ->
      Enum.each(batch, fn user ->
        email =
          %Swoosh.Email{}
          |> Swoosh.Email.to({user.username, user.email})
          |> Swoosh.Email.subject(subject)
          |> Swoosh.Email.html_body(body_html)
          |> Swoosh.Email.text_body(strip_html(body_html))
          |> Map.put(:from, @from)

        Mailer.deliver(email)
      end)

      # Brief pause between batches to avoid overwhelming the mailer
      Process.sleep(1_000)
    end)

    :ok
  end

  @doc """
  Returns the count of users that would receive the email for a given segment.
  """
  def recipient_count(segment) do
    segment
    |> base_query()
    |> Repo.aggregate(:count, :id)
  end

  defp query_users(segment) do
    segment
    |> base_query()
    |> select([u], %{username: u.username, email: u.email})
    |> Repo.all()
  end

  defp base_query("active_30d") do
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    Ecto.Query.from(u in User,
      where: u.status == "active",
      where: not is_nil(u.email),
      where: u.last_seen_at >= ^thirty_days_ago
    )
  end

  defp base_query("verified") do
    Ecto.Query.from(u in User,
      where: u.status == "active",
      where: not is_nil(u.email),
      where: not is_nil(u.email_verified_at)
    )
  end

  defp base_query(_all) do
    Ecto.Query.from(u in User,
      where: u.status == "active",
      where: not is_nil(u.email)
    )
  end

  defp strip_html(html) do
    html
    |> String.replace(~r/<br\s*\/?>/, "\n")
    |> String.replace(~r/<\/p>/, "\n\n")
    |> String.replace(~r/<[^>]+>/, "")
    |> String.trim()
  end
end
