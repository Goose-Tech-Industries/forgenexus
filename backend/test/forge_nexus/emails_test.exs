defmodule ForgeNexus.EmailsTest do
  use ExUnit.Case, async: true
  import Swoosh.TestAssertions

  alias ForgeNexus.{Emails, Mailer}

  @mock_user %{
    id: "usr_123",
    username: "testuser",
    email: "testuser@example.com"
  }

  describe "verification_email/2" do
    test "builds email with token link and delivers via Mailer" do
      email = Emails.verification_email(@mock_user, "tok_verify_abc")

      assert email.to == [{"testuser", "testuser@example.com"}]
      assert email.subject == "Verify your ForgeNexus email"
      assert email.html_body =~ "Welcome to ForgeNexus, testuser!"
      assert email.html_body =~ "/auth/verify-email?token=tok_verify_abc"
      assert email.text_body =~ "token=tok_verify_abc"

      assert {:ok, _} = Mailer.deliver(email)
      assert_email_sent(email)
    end
  end

  describe "password_reset_email/2" do
    test "builds reset email and contains 1 hour expiry text" do
      email = Emails.password_reset_email(@mock_user, "tok_reset_123")

      assert email.to == [{"testuser", "testuser@example.com"}]
      assert email.subject == "Reset your ForgeNexus password"
      assert email.html_body =~ "/auth/reset-password?token=tok_reset_123"
      assert email.html_body =~ "expires in 1 hour"
      assert email.text_body =~ "/auth/reset-password?token=tok_reset_123"

      assert {:ok, _} = Mailer.deliver(email)
      assert_email_sent(email)
    end
  end

  describe "email_change_email/3" do
    test "sends confirmation link to the new email address" do
      email = Emails.email_change_email(@mock_user, "newemail@example.com", "tok_change_789")

      assert email.to == [{"testuser", "newemail@example.com"}]
      assert email.subject == "Confirm your new email for ForgeNexus"
      assert email.html_body =~ "/auth/confirm-email-change?token=tok_change_789"
      assert email.html_body =~ "requested to change your email to newemail@example.com"
      assert email.text_body =~ "token=tok_change_789"

      assert {:ok, _} = Mailer.deliver(email)
      assert_email_sent(email)
    end
  end

  describe "contact_form_email/4" do
    test "builds contact submission with reply_to and replaces newlines in html" do
      email =
        Emails.contact_form_email(
          "Alice Smith",
          "alice@example.com",
          "Question about billing",
          "Line 1\nLine 2"
        )

      assert email.reply_to == {"Alice Smith", "alice@example.com"}
      assert email.subject == "[Contact Form] Question about billing"
      assert email.html_body =~ "Line 1<br />Line 2"
      assert email.text_body =~ "From: Alice Smith (alice@example.com)"
      assert email.text_body =~ "Line 1\nLine 2"

      assert {:ok, _} = Mailer.deliver(email)
      assert_email_sent(email)
    end
  end

  describe "password_changed_notice/2" do
    test "notifies old/current email that password was changed" do
      email = Emails.password_changed_notice(@mock_user, "alert@example.com")

      assert email.to == [{"testuser", "alert@example.com"}]
      assert email.subject == "Your ForgeNexus password was changed"
      assert email.html_body =~ "All active sessions have been signed out"
      assert email.text_body =~ "/auth/forgot-password"

      assert {:ok, _} = Mailer.deliver(email)
      assert_email_sent(email)
    end
  end

  describe "email_changed_notice/3" do
    test "alerts old email of the change" do
      email =
        Emails.email_changed_notice(@mock_user, "old@example.com", "updated@example.com")

      assert email.to == [{"testuser", "old@example.com"}]
      assert email.subject == "Your ForgeNexus email was changed"
      assert email.html_body =~ "changed from old@example.com to updated@example.com"
      assert email.text_body =~ "from old@example.com to updated@example.com"

      assert {:ok, _} = Mailer.deliver(email)
      assert_email_sent(email)
    end
  end

  describe "ban_notice_email/4" do
    test "formats permanent ban notice and escapes html in reason" do
      email =
        Emails.ban_notice_email(
          @mock_user,
          "permanent",
          "<script>alert('spam')</script>",
          nil
        )

      assert email.subject == "Your ForgeNexus account has been banned"
      assert email.html_body =~ "This is a <strong>permanent</strong> ban."
      assert email.html_body =~ "&lt;script&gt;alert(&#39;spam&#39;)&lt;/script&gt;"
      refute email.html_body =~ "<script>"
      assert email.text_body =~ "This is a permanent ban."
    end

    test "formats temporary ban with ISO expiration date" do
      iso_date = "2026-10-01T12:00:00Z"
      email = Emails.ban_notice_email(@mock_user, "temporary", "Rule violation", iso_date)

      assert email.html_body =~ "This ban expires on <strong>2026-10-01T12:00:00Z</strong>"
      assert email.text_body =~ "expires on 2026-10-01T12:00:00Z"
    end

    test "formats ban with unspecified duration when expires_at is not binary" do
      email = Emails.ban_notice_email(@mock_user, "warning_only", "Minor warning", nil)

      assert email.html_body =~ "Duration not specified."
      assert email.text_body =~ "Duration not specified."
    end
  end

  describe "ban_lifted_notice_email/1" do
    test "builds ban lifted notification" do
      email = Emails.ban_lifted_notice_email(@mock_user)

      assert email.subject == "Your ForgeNexus ban has been lifted"
      assert email.html_body =~ "Welcome back"
      assert email.html_body =~ "/auth/login"
      assert email.text_body =~ "/auth/login"

      assert {:ok, _} = Mailer.deliver(email)
      assert_email_sent(email)
    end
  end

  describe "warning_revoked_notice_email/2" do
    test "escapes reason and builds revoked warning email" do
      email =
        Emails.warning_revoked_notice_email(@mock_user, "<b>Spam report withdrawn</b>")

      assert email.subject == "A warning on your ForgeNexus account was revoked"
      assert email.html_body =~ "&lt;b&gt;Spam report withdrawn&lt;/b&gt;"
      refute email.html_body =~ "<b>"
      assert email.text_body =~ "Spam report withdrawn"

      assert {:ok, _} = Mailer.deliver(email)
      assert_email_sent(email)
    end
  end

  describe "warning_notice_email/3" do
    test "escapes reason, displays points and link to infractions" do
      email = Emails.warning_notice_email(@mock_user, "Inappropriate image & language", 3)

      assert email.subject == "You received a warning on ForgeNexus"
      assert email.html_body =~ "Inappropriate image &amp; language"
      assert email.html_body =~ "Infraction points:</strong> 3"
      assert email.text_body =~ "Points: 3"
      assert email.text_body =~ "/account/infractions"

      assert {:ok, _} = Mailer.deliver(email)
      assert_email_sent(email)
    end

    test "handles nil and integer reason safely" do
      email_nil = Emails.warning_notice_email(@mock_user, nil, 1)
      assert email_nil.html_body =~ "<strong>Reason:</strong> </p>"

      email_int = Emails.warning_notice_email(@mock_user, 404, 1)
      assert email_int.html_body =~ "<strong>Reason:</strong> 404</p>"
    end
  end
end
