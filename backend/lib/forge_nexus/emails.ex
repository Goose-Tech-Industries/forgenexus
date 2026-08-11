defmodule ForgeNexus.Emails do
  @moduledoc """
  Email templates for transactional emails.
  """
  import Swoosh.Email

  @from {"ForgeNexus", "noreply@forum.tcgaming.quest"}

  def verification_email(user, token) do
    verify_url = "#{base_url()}/auth/verify-email?token=#{token}"

    new()
    |> to({user.username, user.email})
    |> from(@from)
    |> subject("Verify your ForgeNexus email")
    |> html_body("""
    <h2>Welcome to ForgeNexus, #{user.username}!</h2>
    <p>Please verify your email address by clicking the link below:</p>
    <p><a href="#{verify_url}" style="display:inline-block;padding:12px 24px;background:#00d4aa;color:#000;text-decoration:none;border-radius:4px;font-weight:bold;">Verify Email</a></p>
    <p>Or copy this link: #{verify_url}</p>
    <p>This link expires in 24 hours.</p>
    <p>If you didn't create this account, ignore this email.</p>
    """)
    |> text_body("Welcome to ForgeNexus! Verify your email: #{verify_url}")
  end

  def password_reset_email(user, token) do
    reset_url = "#{base_url()}/auth/reset-password?token=#{token}"

    new()
    |> to({user.username, user.email})
    |> from(@from)
    |> subject("Reset your ForgeNexus password")
    |> html_body("""
    <h2>Password Reset</h2>
    <p>Hi #{user.username}, someone requested a password reset for your account.</p>
    <p><a href="#{reset_url}" style="display:inline-block;padding:12px 24px;background:#00d4aa;color:#000;text-decoration:none;border-radius:4px;font-weight:bold;">Reset Password</a></p>
    <p>Or copy this link: #{reset_url}</p>
    <p>This link expires in 1 hour. If you didn't request this, ignore this email.</p>
    """)
    |> text_body("Reset your password: #{reset_url}")
  end

  def email_change_email(user, new_email, token) do
    confirm_url = "#{base_url()}/auth/confirm-email-change?token=#{token}"

    new()
    |> to({user.username, new_email})
    |> from(@from)
    |> subject("Confirm your new email for ForgeNexus")
    |> html_body("""
    <h2>Email Change Confirmation</h2>
    <p>Hi #{user.username}, you requested to change your email to #{new_email}.</p>
    <p><a href="#{confirm_url}" style="display:inline-block;padding:12px 24px;background:#00d4aa;color:#000;text-decoration:none;border-radius:4px;font-weight:bold;">Confirm Email Change</a></p>
    <p>Or copy this link: #{confirm_url}</p>
    <p>This link expires in 24 hours. If you didn't request this, ignore this email.</p>
    """)
    |> text_body("Confirm email change: #{confirm_url}")
  end

  def contact_form_email(name, sender_email, subject, message) do
    new()
    |> to({"ForgeNexus Admin", System.get_env("ADMIN_EMAIL", "admin@forgenexus.com")})
    |> from(@from)
    |> reply_to({name, sender_email})
    |> subject("[Contact Form] #{subject}")
    |> html_body("""
    <h2>New Contact Form Submission</h2>
    <p><strong>From:</strong> #{name} (#{sender_email})</p>
    <p><strong>Subject:</strong> #{subject}</p>
    <hr />
    <p>#{String.replace(message, "\n", "<br />")}</p>
    """)
    |> text_body("From: #{name} (#{sender_email})\nSubject: #{subject}\n\n#{message}")
  end

  @doc "Tripwire sent to the current email when the user's password is changed."
  def password_changed_notice(user, to_email) do
    new()
    |> to({user.username, to_email})
    |> from(@from)
    |> subject("Your ForgeNexus password was changed")
    |> html_body("""
    <h2>Password changed</h2>
    <p>Hi #{user.username}, your ForgeNexus password was just changed.</p>
    <p>If this was you, no action is needed.</p>
    <p><strong>If this wasn't you</strong>, your account may be compromised. Reset your password immediately at #{base_url()}/auth/forgot-password and contact support.</p>
    <p>All active sessions have been signed out as a precaution.</p>
    """)
    |> text_body(
      "Your ForgeNexus password was changed. If this wasn't you, reset at #{base_url()}/auth/forgot-password. All sessions have been signed out."
    )
  end

  @doc "Tripwire sent to the OLD email when the user's email is changed."
  def email_changed_notice(user, old_email, new_email) do
    new()
    |> to({user.username, old_email})
    |> from(@from)
    |> subject("Your ForgeNexus email was changed")
    |> html_body("""
    <h2>Email changed</h2>
    <p>Hi #{user.username}, the email on your ForgeNexus account was just changed from #{old_email} to #{new_email}.</p>
    <p><strong>If this wasn't you</strong>, your account may be compromised. Contact support immediately — this address will no longer receive account emails.</p>
    <p>All active sessions have been signed out as a precaution.</p>
    """)
    |> text_body(
      "Your ForgeNexus email was changed from #{old_email} to #{new_email}. If this wasn't you, contact support."
    )
  end

  @doc "Sent when a user is banned. Explains the reason and appeal path."
  def ban_notice_email(user, ban_type, reason, expires_at_iso) do
    duration_line =
      cond do
        ban_type == "permanent" ->
          "This is a <strong>permanent</strong> ban."

        is_binary(expires_at_iso) ->
          "This ban expires on <strong>#{expires_at_iso}</strong> (UTC)."

        true ->
          "Duration not specified."
      end

    new()
    |> to({user.username, user.email})
    |> from(@from)
    |> subject("Your ForgeNexus account has been banned")
    |> html_body("""
    <h2>Account banned</h2>
    <p>Hi #{user.username},</p>
    <p>Your ForgeNexus account has been banned by a staff member. Here are the details:</p>
    <p><strong>Reason:</strong> #{safe_text(reason)}</p>
    <p>#{duration_line}</p>
    <p>You have been signed out on all devices. You cannot post, comment, or send messages while banned.</p>
    <h3>Appeal this decision</h3>
    <p>If you believe this was issued in error, you can file an appeal:</p>
    <p><a href="#{base_url()}/account/infractions" style="display:inline-block;padding:12px 24px;background:#00d4aa;color:#000;text-decoration:none;border-radius:4px;font-weight:bold;">Open Appeal Form</a></p>
    <p>Appeals are reviewed by senior staff, typically within 72 hours.</p>
    """)
    |> text_body("""
    Your ForgeNexus account has been banned.
    Reason: #{reason}
    #{duration_line |> String.replace(~r/<[^>]+>/, "")}
    Appeal at: #{base_url()}/account/infractions
    """)
  end

  @doc "Sent when a staff member lifts an active ban."
  def ban_lifted_notice_email(user) do
    new()
    |> to({user.username, user.email})
    |> from(@from)
    |> subject("Your ForgeNexus ban has been lifted")
    |> html_body("""
    <h2>Welcome back</h2>
    <p>Hi #{user.username},</p>
    <p>A staff member has lifted your ban. You can now sign in and use ForgeNexus normally.</p>
    <p><a href="#{base_url()}/auth/login" style="display:inline-block;padding:12px 24px;background:#00d4aa;color:#000;text-decoration:none;border-radius:4px;font-weight:bold;">Sign In</a></p>
    <p>Please review the community guidelines before returning. Another violation can result in a permanent ban.</p>
    """)
    |> text_body("Your ForgeNexus ban has been lifted. Sign in at #{base_url()}/auth/login")
  end

  @doc "Sent when a staff member revokes an active warning."
  def warning_revoked_notice_email(user, reason) do
    new()
    |> to({user.username, user.email})
    |> from(@from)
    |> subject("A warning on your ForgeNexus account was revoked")
    |> html_body("""
    <h2>Warning revoked</h2>
    <p>Hi #{user.username},</p>
    <p>A staff member has revoked a warning issued to your account. The original reason was:</p>
    <p><em>#{safe_text(reason)}</em></p>
    <p>This warning no longer counts toward your infraction points.</p>
    """)
    |> text_body("A warning on your ForgeNexus account was revoked. Original reason: #{reason}")
  end

  @doc "Sent when a user is issued a warning."
  def warning_notice_email(user, reason, points) do
    new()
    |> to({user.username, user.email})
    |> from(@from)
    |> subject("You received a warning on ForgeNexus")
    |> html_body("""
    <h2>Warning received</h2>
    <p>Hi #{user.username},</p>
    <p>A staff member has issued you a warning. Please review the reason below:</p>
    <p><strong>Reason:</strong> #{safe_text(reason)}</p>
    <p><strong>Infraction points:</strong> #{points}</p>
    <p>Warnings accumulate over time and may lead to automatic temporary restrictions if thresholds are exceeded. You can view and appeal warnings at:</p>
    <p><a href="#{base_url()}/account/infractions" style="display:inline-block;padding:10px 20px;background:#00d4aa;color:#000;text-decoration:none;border-radius:4px;font-weight:bold;">View Infractions</a></p>
    """)
    |> text_body("""
    You received a warning on ForgeNexus.
    Reason: #{reason}
    Points: #{points}
    View / appeal: #{base_url()}/account/infractions
    """)
  end

  defp safe_text(nil), do: ""

  defp safe_text(s) when is_binary(s),
    do: Phoenix.HTML.html_escape(s) |> Phoenix.HTML.safe_to_string()

  defp safe_text(other), do: to_string(other)

  defp base_url do
    Application.get_env(:forge_nexus, :frontend_url, "http://localhost:5173")
  end
end
