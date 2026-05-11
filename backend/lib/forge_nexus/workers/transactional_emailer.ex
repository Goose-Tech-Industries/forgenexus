defmodule ForgeNexus.Workers.TransactionalEmailer do
  @moduledoc """
  Sends transactional emails (verify, password reset, email change, security notices).

  For token-bearing emails (verify / password_reset / email_change), the worker
  generates the plaintext token itself and hands it to the template. This way the
  plaintext never lives in Oban args (which persist in DB for up to 7 days).
  """
  use Oban.Worker, queue: :mailers, max_attempts: 5

  alias ForgeNexus.{Accounts, Emails, Mailer}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"template" => "verify_email", "user_id" => user_id}}) do
    with_user(user_id, fn user ->
      with {:ok, plaintext, _token} <- Accounts.create_email_verify_token(user) do
        user |> Emails.verification_email(plaintext) |> Mailer.deliver() |> normalize()
      end
    end)
  end

  def perform(%Oban.Job{args: %{"template" => "password_reset", "user_id" => user_id}}) do
    with_user(user_id, fn user ->
      with {:ok, plaintext, _token} <- Accounts.create_password_reset_token(user) do
        user |> Emails.password_reset_email(plaintext) |> Mailer.deliver() |> normalize()
      end
    end)
  end

  def perform(%Oban.Job{args: %{"template" => "email_change", "user_id" => user_id, "new_email" => new_email}}) do
    with_user(user_id, fn user ->
      with {:ok, plaintext, token} <- Accounts.create_email_change_token(user, new_email) do
        user |> Emails.email_change_email(token.email, plaintext) |> Mailer.deliver() |> normalize()
      end
    end)
  end

  # Tripwire notices sent to the OLD address when a sensitive op happens.
  # Contain no tokens — purely informational "this was you?" with a support contact.
  def perform(%Oban.Job{args: %{"template" => "password_changed_notice", "user_id" => user_id}}) do
    with_user(user_id, fn user ->
      user |> Emails.password_changed_notice(user.email) |> Mailer.deliver() |> normalize()
    end)
  end

  def perform(%Oban.Job{args: %{"template" => "email_changed_notice", "user_id" => user_id, "old_email" => old_email}}) do
    with_user(user_id, fn user ->
      user |> Emails.email_changed_notice(old_email, user.email) |> Mailer.deliver() |> normalize()
    end)
  end

  def perform(%Oban.Job{args: %{"template" => "ban_notice", "user_id" => user_id} = args}) do
    with_user(user_id, fn user ->
      ban_type = Map.get(args, "type", "temporary")
      reason = Map.get(args, "reason", "Violation of community guidelines")
      expires_at = Map.get(args, "expires_at")

      user |> Emails.ban_notice_email(ban_type, reason, expires_at) |> Mailer.deliver() |> normalize()
    end)
  end

  def perform(%Oban.Job{args: %{"template" => "warning_notice", "user_id" => user_id} = args}) do
    with_user(user_id, fn user ->
      reason = Map.get(args, "reason", "Violation of community guidelines")
      points = Map.get(args, "points", 1)

      user |> Emails.warning_notice_email(reason, points) |> Mailer.deliver() |> normalize()
    end)
  end

  def perform(%Oban.Job{args: %{"template" => "ban_lifted_notice", "user_id" => user_id}}) do
    with_user(user_id, fn user ->
      user |> Emails.ban_lifted_notice_email() |> Mailer.deliver() |> normalize()
    end)
  end

  def perform(%Oban.Job{args: %{"template" => "warning_revoked_notice", "user_id" => user_id} = args}) do
    with_user(user_id, fn user ->
      reason = Map.get(args, "reason", "")
      user |> Emails.warning_revoked_notice_email(reason) |> Mailer.deliver() |> normalize()
    end)
  end

  defp with_user(user_id, fun) do
    case Accounts.get_user(user_id) do
      nil -> {:cancel, :user_not_found}
      user -> fun.(user)
    end
  end

  defp normalize({:ok, _resp}), do: :ok
  defp normalize({:error, reason}), do: {:error, reason}
  defp normalize(:ok), do: :ok
end
