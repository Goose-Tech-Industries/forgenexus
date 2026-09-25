defmodule ForgeNexus.Accounts.UserTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Accounts.User

  @valid_registration %{
    username: "coder_01",
    email: "coder01@example.com",
    password: "Password1234!",
    display_name: "Coder 01",
    registered_ip: "127.0.0.1"
  }

  describe "registration_changeset/2" do
    test "valid attributes produce a valid changeset with slug and password_hash" do
      changeset = User.registration_changeset(%User{}, @valid_registration)

      assert changeset.valid?
      assert get_change(changeset, :slug) == "coder-01"
      assert get_change(changeset, :password_hash) != nil
      assert get_change(changeset, :password) == "Password1234!"
    end

    test "requires username, email, and password" do
      changeset = User.registration_changeset(%User{}, %{})

      refute changeset.valid?

      assert %{
               username: ["can't be blank"],
               email: ["can't be blank"],
               password: ["can't be blank"]
             } =
               errors_on(changeset)
    end

    test "validates username length (3-25)" do
      too_short =
        User.registration_changeset(%User{}, Map.put(@valid_registration, :username, "ab"))

      refute too_short.valid?
      assert "should be at least 3 character(s)" in errors_on(too_short).username

      too_long =
        User.registration_changeset(
          %User{},
          Map.put(@valid_registration, :username, String.duplicate("a", 26))
        )

      refute too_long.valid?
      assert "should be at most 25 character(s)" in errors_on(too_long).username
    end

    test "validates username format allows letters, numbers, underscores, and hyphens" do
      invalid =
        User.registration_changeset(%User{}, Map.put(@valid_registration, :username, "bad name!"))

      refute invalid.valid?
      assert "only letters, numbers, underscores, and hyphens" in errors_on(invalid).username

      valid_hyphen =
        User.registration_changeset(
          %User{},
          Map.put(@valid_registration, :username, "valid-user_99")
        )

      assert valid_hyphen.valid?
    end

    test "validates email format" do
      invalid =
        User.registration_changeset(%User{}, Map.put(@valid_registration, :email, "not-an-email"))

      refute invalid.valid?
      assert "must be a valid email" in errors_on(invalid).email
    end

    test "validates password length (8-128)" do
      short =
        User.registration_changeset(%User{}, Map.put(@valid_registration, :password, "short"))

      refute short.valid?
      assert "should be at least 8 character(s)" in errors_on(short).password
    end
  end

  describe "oauth_changeset/2" do
    test "valid attributes without password" do
      attrs = %{
        username: "oauth_user",
        email: "oauth@example.com",
        display_name: "OAuth User",
        avatar_url: "https://example.com/pic.png",
        registered_ip: "10.0.0.1"
      }

      changeset = User.oauth_changeset(%User{}, attrs)
      assert changeset.valid?
      assert get_change(changeset, :slug) == "oauth-user"
    end

    test "allows nil email when email_unverified is true" do
      attrs = %{
        username: "no_email_user",
        email_unverified: true
      }

      changeset = User.oauth_changeset(%User{}, attrs)
      assert changeset.valid?
    end

    test "validates email format if email is provided" do
      attrs = %{
        username: "bad_email_user",
        email: "bademail"
      }

      changeset = User.oauth_changeset(%User{}, attrs)
      refute changeset.valid?
      assert "must be a valid email" in errors_on(changeset).email
    end
  end

  describe "password_changeset/2" do
    test "validates required password and hashes it" do
      changeset = User.password_changeset(%User{}, %{password: "NewSecret123!"})
      assert changeset.valid?
      assert get_change(changeset, :password_hash) != nil

      empty = User.password_changeset(%User{}, %{})
      refute empty.valid?
      assert "can't be blank" in errors_on(empty).password
    end
  end

  describe "email_changeset/2" do
    test "validates required email and format" do
      valid = User.email_changeset(%User{}, %{email: "valid@domain.com"})
      assert valid.valid?

      invalid = User.email_changeset(%User{}, %{email: "plainaddress"})
      refute invalid.valid?
      assert "must be a valid email" in errors_on(invalid).email
    end
  end

  describe "admin_changeset/2" do
    test "accepts valid administrative fields" do
      attrs = %{
        username: "admin_updated",
        email: "admin_updated@example.com",
        status: "suspended",
        trust_level: 3,
        creator_tier: "top",
        is_premium: true,
        infraction_points: 5
      }

      changeset = User.admin_changeset(%User{}, attrs)
      assert changeset.valid?
    end

    test "validates status inclusion" do
      invalid = User.admin_changeset(%User{}, %{status: "rogue"})
      refute invalid.valid?
      assert "is invalid" in errors_on(invalid).status
    end

    test "validates trust_level boundaries (0 to 4)" do
      low = User.admin_changeset(%User{}, %{trust_level: -1})
      refute low.valid?
      assert "must be greater than or equal to 0" in errors_on(low).trust_level

      high = User.admin_changeset(%User{}, %{trust_level: 5})
      refute high.valid?
      assert "must be less than or equal to 4" in errors_on(high).trust_level
    end

    test "validates creator_tier inclusion" do
      invalid = User.admin_changeset(%User{}, %{creator_tier: "legendary"})
      refute invalid.valid?
      assert "is invalid" in errors_on(invalid).creator_tier
    end
  end

  describe "profile_changeset/2" do
    test "accepts valid profile customizations" do
      attrs = %{
        display_name: "Cool Dev",
        bio: "Just a builder building things.",
        signature: "Stay sharp.",
        theme: "light",
        content_density: "compact",
        profile_vibe: "cyber",
        birthday_visibility: "friends",
        location_visibility: "public",
        email_visibility: "private",
        activity_visibility: "members",
        profile_accent_color: "#ff5500",
        profile_background_color: "#121212",
        social_links: %{
          "github" => "https://github.com/cooldev",
          "twitter" => "https://twitter.com/cooldev"
        }
      }

      changeset = User.profile_changeset(%User{}, attrs)
      assert changeset.valid?
    end

    test "validates theme and content_density inclusion" do
      invalid = User.profile_changeset(%User{}, %{theme: "neon", content_density: "wide"})
      refute invalid.valid?
      assert "is invalid" in errors_on(invalid).theme
      assert "is invalid" in errors_on(invalid).content_density
    end

    test "validates profile_vibe inclusion" do
      valid = User.profile_changeset(%User{}, %{profile_vibe: "retro"})
      assert valid.valid?

      invalid = User.profile_changeset(%User{}, %{profile_vibe: "galactic"})
      refute invalid.valid?
      assert "is invalid" in errors_on(invalid).profile_vibe
    end

    test "validates visibility levels for privacy fields" do
      invalid =
        User.profile_changeset(%User{}, %{
          birthday_visibility: "secret",
          location_visibility: "all",
          email_visibility: "none",
          activity_visibility: "followers"
        })

      refute invalid.valid?
      errors = errors_on(invalid)
      assert "is invalid" in errors.birthday_visibility
      assert "is invalid" in errors.location_visibility
      assert "is invalid" in errors.email_visibility
      assert "is invalid" in errors.activity_visibility
    end

    test "validates hex colors" do
      valid = User.profile_changeset(%User{}, %{profile_accent_color: "#33aaff"})
      assert valid.valid?

      empty =
        %User{}
        |> Ecto.Changeset.change(%{profile_accent_color: ""})
        |> User.profile_changeset(%{})

      assert empty.valid?

      invalid = User.profile_changeset(%User{}, %{profile_accent_color: "blue"})
      refute invalid.valid?
      assert "must be a valid hex color like #ff8800" in errors_on(invalid).profile_accent_color
    end

    test "validates social links structure and platforms" do
      non_map = User.profile_changeset(%User{}, %{social_links: "not-a-map"})
      refute non_map.valid?
      assert "is invalid" in errors_on(non_map).social_links

      direct_non_map =
        %User{}
        |> Ecto.Changeset.change(%{social_links: "not-a-map"})
        |> User.profile_changeset(%{})

      refute direct_non_map.valid?
      assert "must be an object of platform→url" in errors_on(direct_non_map).social_links

      non_binary_val =
        User.profile_changeset(%User{}, %{
          social_links: %{"github" => 12345}
        })

      refute non_binary_val.valid?

      assert Enum.any?(
               errors_on(non_binary_val).social_links,
               &String.contains?(&1, "only supports https://")
             )

      unsupported_platform =
        User.profile_changeset(%User{}, %{
          social_links: %{"myspace_unsupported" => "https://myspace.com/me"}
        })

      refute unsupported_platform.valid?

      assert Enum.any?(
               errors_on(unsupported_platform).social_links,
               &String.contains?(&1, "only supports https://")
             )

      non_https =
        User.profile_changeset(%User{}, %{
          social_links: %{"github" => "ftp://github.com/me"}
        })

      refute non_https.valid?
    end

    test "validates field length limits" do
      too_long =
        User.profile_changeset(%User{}, %{
          signature: String.duplicate("x", 501),
          pronouns: String.duplicate("y", 41)
        })

      refute too_long.valid?
      assert "should be at most 500 character(s)" in errors_on(too_long).signature
      assert "should be at most 40 character(s)" in errors_on(too_long).pronouns
    end
  end

  describe "constants / metadata" do
    test "exposes allowed_social_platforms, vibe_tags, and visibility_levels" do
      assert is_list(User.allowed_social_platforms())
      assert "github" in User.allowed_social_platforms()
      assert "discord" in User.allowed_social_platforms()

      assert is_list(User.vibe_tags())
      assert "cyber" in User.vibe_tags()
      assert "retro" in User.vibe_tags()

      assert User.visibility_levels() == ~w(public members friends private)
    end
  end
end
