defmodule ForgeNexus.Accounts.AccountsRemainingSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Accounts.{
    AuthToken,
    AvatarFrame,
    LoginEvent,
    LoginSession,
    OAuthAccount,
    PromotionRule,
    Rank,
    Theme,
    UserBlock,
    UserPreference
  }

  describe "AuthToken" do
    @uid Ecto.UUID.generate()

    test "valid changeset, hash/1, expired?/1, and used?/1" do
      plaintext = "super_secret_token_123"
      hash = AuthToken.hash(plaintext)
      assert is_binary(hash)

      future = DateTime.utc_now() |> DateTime.add(3600, :second)
      past = DateTime.utc_now() |> DateTime.add(-3600, :second)

      for type <- ~w(email_verify password_reset email_change) do
        cs =
          AuthToken.changeset(%AuthToken{}, %{
            token_hash: hash,
            type: type,
            expires_at: future,
            user_id: @uid,
            email: "user@example.com"
          })

        assert cs.valid?
        assert get_field(cs, :type) == type
      end

      # Expired? check
      token_future = %AuthToken{expires_at: future}
      refute AuthToken.expired?(token_future)
      token_past = %AuthToken{expires_at: past}
      assert AuthToken.expired?(token_past)

      # Used? check
      token_unused = %AuthToken{used_at: nil}
      refute AuthToken.used?(token_unused)
      token_used = %AuthToken{used_at: DateTime.utc_now()}
      assert AuthToken.used?(token_used)

      # Required fields and invalid type
      req_cs = AuthToken.changeset(%AuthToken{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).token_hash
      assert "can't be blank" in errors_on(req_cs).type
      assert "can't be blank" in errors_on(req_cs).expires_at
      assert "can't be blank" in errors_on(req_cs).user_id

      bad_type_cs =
        AuthToken.changeset(%AuthToken{}, %{
          token_hash: hash,
          type: "session",
          expires_at: future,
          user_id: @uid
        })

      refute bad_type_cs.valid?
      assert "is invalid" in errors_on(bad_type_cs).type
    end
  end

  describe "AvatarFrame" do
    test "valid changeset and validations" do
      cs =
        AvatarFrame.changeset(%AvatarFrame{}, %{
          name: "Golden Ring",
          slug: "golden-ring",
          css_class: "frame-gold",
          description: "A shiny gold ring avatar frame",
          min_posts: 100
        })

      assert cs.valid?
      assert get_field(cs, :slug) == "golden-ring"

      req_cs = AvatarFrame.changeset(%AvatarFrame{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).slug
      assert "can't be blank" in errors_on(req_cs).css_class
    end
  end

  describe "LoginEvent" do
    test "valid changeset" do
      cs =
        LoginEvent.changeset(%LoginEvent{}, %{
          email: "user@example.com",
          ip_address: "1.2.3.4",
          user_agent: "Mozilla/5.0",
          success: true
        })

      assert cs.valid?
      assert get_field(cs, :success) == true

      req_cs = LoginEvent.changeset(%LoginEvent{}, %{success: nil})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).success
    end
  end

  describe "LoginSession" do
    @uid Ecto.UUID.generate()

    test "valid changeset, active?/1, and parse_device_name/1" do
      cs =
        LoginSession.changeset(%LoginSession{}, %{
          token_jti: "jti_123456",
          user_id: @uid,
          ip_address: "192.168.1.1"
        })

      assert cs.valid?

      req_cs = LoginSession.changeset(%LoginSession{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).token_jti
      assert "can't be blank" in errors_on(req_cs).user_id

      # active?
      assert LoginSession.active?(%LoginSession{revoked_at: nil})
      refute LoginSession.active?(%LoginSession{revoked_at: DateTime.utc_now()})

      # parse_device_name
      assert LoginSession.parse_device_name(
               "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) Mobile/15E148"
             ) == "Mobile Browser"

      assert LoginSession.parse_device_name(
               "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0"
             ) == "Chrome"

      assert LoginSession.parse_device_name(
               "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/119.0"
             ) == "Firefox"

      assert LoginSession.parse_device_name(
               "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15"
             ) == "Safari"

      assert LoginSession.parse_device_name(
               "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Edge/120.0.0.0"
             ) == "Edge"

      assert LoginSession.parse_device_name("curl/7.68.0") == "Unknown Device"
      assert LoginSession.parse_device_name(nil) == "Unknown Device"
    end
  end

  describe "OAuthAccount" do
    @uid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        OAuthAccount.changeset(%OAuthAccount{}, %{
          user_id: @uid,
          provider: "github",
          provider_uid: "12345678",
          provider_email: "alice@github.com"
        })

      assert cs.valid?

      req_cs = OAuthAccount.changeset(%OAuthAccount{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).provider
      assert "can't be blank" in errors_on(req_cs).provider_uid
    end
  end

  describe "PromotionRule" do
    @gid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        PromotionRule.changeset(%PromotionRule{}, %{
          name: "Senior Member Promotion",
          to_group_id: @gid,
          criteria: %{"min_posts" => 100, "min_days" => 30}
        })

      assert cs.valid?
      assert get_field(cs, :name) == "Senior Member Promotion"

      req_cs = PromotionRule.changeset(%PromotionRule{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).to_group_id
      assert "can't be blank" in errors_on(req_cs).criteria
    end
  end

  describe "Rank" do
    test "valid changeset" do
      cs =
        Rank.changeset(%Rank{}, %{
          title: "Grand Master",
          min_posts: 1000,
          image_url: "https://example.com/master.png"
        })

      assert cs.valid?
      assert get_field(cs, :title) == "Grand Master"

      req_cs = Rank.changeset(%Rank{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).title
    end
  end

  describe "Theme" do
    test "valid changeset, allowed_variable_keys/0, and CSS validation" do
      keys = Theme.allowed_variable_keys()
      assert "bg_primary" in keys
      assert "accent" in keys

      cs =
        Theme.changeset(%Theme{}, %{
          name: "Cyberpunk",
          slug: "cyberpunk",
          variables: %{
            "bg_primary" => "#0d0221",
            "accent" => "rgba(255, 0, 128, 0.8)",
            "text_primary" => "white"
          }
        })

      assert cs.valid?
      assert get_field(cs, :slug) == "cyberpunk"

      req_cs = Theme.changeset(%Theme{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).slug

      # Invalid variable key and invalid CSS value
      bad_vars_cs =
        Theme.changeset(%Theme{}, %{
          name: "Bad Theme",
          slug: "bad-theme",
          variables: %{
            "invalid_color_key" => "#123456",
            "accent" => "javascript:alert(1)"
          }
        })

      refute bad_vars_cs.valid?
      assert any_error?(errors_on(bad_vars_cs).variables, "contains invalid keys")
      assert any_error?(errors_on(bad_vars_cs).variables, "contains invalid values")

      # Non-map variables change
      non_map_cs =
        Ecto.Changeset.change(%Theme{name: "Test", slug: "test"}, %{variables: "not_a_map"})

      validated_cs = Theme.changeset(non_map_cs, %{})
      refute validated_cs.valid?
      assert "must be a map" in errors_on(validated_cs).variables
    end
  end

  describe "UserBlock" do
    @uid1 Ecto.UUID.generate()
    @uid2 Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        UserBlock.changeset(%UserBlock{}, %{
          user_id: @uid1,
          blocked_user_id: @uid2
        })

      assert cs.valid?

      req_cs = UserBlock.changeset(%UserBlock{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).blocked_user_id
    end
  end

  describe "UserPreference" do
    @uid Ecto.UUID.generate()

    test "changeset and create_changeset with inclusions and time format validations" do
      # create_changeset requires user_id
      create_cs =
        UserPreference.create_changeset(%UserPreference{}, %{
          user_id: @uid,
          pagination_mode: "infinite_scroll",
          thread_display_mode: "threaded",
          content_density: "compact",
          colorblind_mode: "protanopia",
          email_digest: "daily",
          profile_visibility: "friends",
          default_thread_notification: "tracking",
          posts_per_page: 50,
          dnd_start: "23:00",
          dnd_end: "07:30"
        })

      assert create_cs.valid?
      assert get_field(create_cs, :pagination_mode) == "infinite_scroll"

      # create_changeset requires user_id
      req_create_cs = UserPreference.create_changeset(%UserPreference{}, %{})
      refute req_create_cs.valid?
      assert "can't be blank" in errors_on(req_create_cs).user_id

      # Invalid inclusions
      bad_inc_cs =
        UserPreference.changeset(%UserPreference{}, %{
          pagination_mode: "swipe",
          thread_display_mode: "tree_view",
          content_density: "micro",
          colorblind_mode: "monochrome",
          email_digest: "hourly",
          profile_visibility: "classified",
          default_thread_notification: "loud",
          posts_per_page: 999
        })

      refute bad_inc_cs.valid?
      assert "is invalid" in errors_on(bad_inc_cs).pagination_mode
      assert "is invalid" in errors_on(bad_inc_cs).thread_display_mode
      assert "is invalid" in errors_on(bad_inc_cs).content_density
      assert "is invalid" in errors_on(bad_inc_cs).colorblind_mode
      assert "is invalid" in errors_on(bad_inc_cs).email_digest
      assert "is invalid" in errors_on(bad_inc_cs).profile_visibility
      assert "is invalid" in errors_on(bad_inc_cs).default_thread_notification
      assert "is invalid" in errors_on(bad_inc_cs).posts_per_page

      # Invalid time format for dnd_start / dnd_end
      bad_time_cs =
        UserPreference.changeset(%UserPreference{}, %{
          dnd_start: "11pm",
          dnd_end: "25:00"
        })

      refute bad_time_cs.valid?
      assert "must be in HH:MM format (e.g. 22:00)" in errors_on(bad_time_cs).dnd_start
      assert "must be in HH:MM format (e.g. 22:00)" in errors_on(bad_time_cs).dnd_end
    end
  end

  defp any_error?(error_list, pattern) when is_list(error_list) do
    Enum.any?(error_list, &String.contains?(&1, pattern))
  end

  defp any_error?(_, _), do: false
end
