defmodule ForgeNexus.Accounts do
  @moduledoc """
  The Accounts context — user registration, authentication, profiles, groups.
  """
  import Ecto.Query
  alias ForgeNexus.Repo

  alias ForgeNexus.Accounts.{
    User,
    UserGroup,
    UserGroupMembership,
    Rank,
    UserFollow,
    UserBlock,
    OAuthAccount,
    PromotionRule,
    UserPreference,
    LoginSession,
    AvatarFrame,
    LoginEvent,
    AuthToken
  }

  # --- Users ---

  def get_user!(id), do: Repo.get!(User, id)

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_email(email) do
    Repo.get_by(User, email: String.downcase(email))
  end

  def get_user_by_username(username) do
    Repo.get_by(User, username: username)
  end

  def get_user_by_slug(slug) do
    Repo.get_by(User, slug: slug)
  end

  def list_users(opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    User
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  def register_user(attrs) do
    case %User{} |> User.registration_changeset(attrs) |> apply_password_security_check() do
      %Ecto.Changeset{valid?: true} = cs -> Repo.insert(cs)
      %Ecto.Changeset{} = cs -> {:error, %{cs | action: :insert}}
    end
  end

  # SOTA: reject passwords that appear in known breach corpora.
  # HIBP k-anonymity — only the first 5 chars of SHA-1 hash leave this server.
  defp apply_password_security_check(%Ecto.Changeset{valid?: true} = changeset) do
    case Ecto.Changeset.get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        case ForgeNexus.PasswordSecurity.check(password) do
          {:pwned, count} ->
            Ecto.Changeset.add_error(
              changeset,
              :password,
              "has appeared in #{count} known data breaches — choose a different password"
            )

          :ok ->
            changeset
        end
    end
  end

  defp apply_password_security_check(changeset), do: changeset

  # --- Auth tokens (email verify / password reset / email change) ---

  @token_ttls %{
    "email_verify" => 24 * 3600,
    "password_reset" => 1 * 3600,
    "email_change" => 24 * 3600
  }

  # SOTA: plaintext token only exists in the email. DB stores SHA-256(plaintext).
  # If the DB leaks, tokens can't be replayed. Caller gets the plaintext back for
  # queueing into the outbound email job.
  defp create_auth_token(%User{} = user, type, email) when is_map_key(@token_ttls, type) do
    plaintext = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    expires_at =
      DateTime.utc_now() |> DateTime.add(@token_ttls[type], :second) |> DateTime.truncate(:second)

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    result =
      Repo.transaction(fn ->
        # Invalidate any prior unused token of the same type for this user —
        # new request supersedes old. Prevents token hoarding / race conditions.
        from(t in AuthToken,
          where: t.user_id == ^user.id and t.type == ^type and is_nil(t.used_at)
        )
        |> Repo.update_all(set: [used_at: now])

        case %AuthToken{}
             |> AuthToken.changeset(%{
               token_hash: AuthToken.hash(plaintext),
               type: type,
               email: email,
               user_id: user.id,
               expires_at: expires_at
             })
             |> Repo.insert() do
          {:ok, token_row} -> token_row
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)

    case result do
      {:ok, token_row} -> {:ok, plaintext, token_row}
      {:error, reason} -> {:error, reason}
    end
  end

  defp consume_auth_token(plaintext, type, on_valid)
       when is_binary(plaintext) and is_function(on_valid, 2) do
    hash = AuthToken.hash(plaintext)

    Repo.transaction(fn ->
      case Repo.get_by(AuthToken, token_hash: hash, type: type) do
        nil ->
          Repo.rollback(:invalid_token)

        %AuthToken{} = at ->
          cond do
            AuthToken.used?(at) ->
              Repo.rollback(:already_used)

            AuthToken.expired?(at) ->
              Repo.rollback(:expired)

            true ->
              user = Repo.get!(User, at.user_id)
              now = DateTime.utc_now() |> DateTime.truncate(:second)

              {:ok, _} =
                at
                |> Ecto.Changeset.change(used_at: now)
                |> Repo.update()

              case on_valid.(user, at) do
                {:ok, result} -> result
                {:error, err} -> Repo.rollback(err)
              end
          end
      end
    end)
  end

  # Email verification

  def create_email_verify_token(%User{} = user),
    do: create_auth_token(user, "email_verify", user.email)

  def consume_email_verify_token(token) do
    consume_auth_token(token, "email_verify", fn user, _at ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      user |> Ecto.Changeset.change(email_verified_at: now) |> Repo.update()
    end)
  end

  # Password reset

  def create_password_reset_token(%User{} = user),
    do: create_auth_token(user, "password_reset", user.email)

  def consume_password_reset_token(token, new_password) when is_binary(new_password) do
    consume_auth_token(token, "password_reset", fn user, _at ->
      with %Ecto.Changeset{valid?: true} = cs <-
             user
             |> User.password_changeset(%{password: new_password})
             |> apply_password_security_check(),
           {:ok, updated} <- Repo.update(cs) do
        revoke_all_sessions(updated.id)

        %{template: "password_changed_notice", user_id: updated.id}
        |> ForgeNexus.Workers.TransactionalEmailer.new()
        |> Oban.insert()

        {:ok, updated}
      else
        %Ecto.Changeset{} = cs -> {:error, %{cs | action: :update}}
        other -> other
      end
    end)
  end

  # Email change

  def create_email_change_token(%User{} = user, new_email) when is_binary(new_email) do
    create_auth_token(user, "email_change", String.downcase(new_email))
  end

  def consume_email_change_token(token) do
    consume_auth_token(token, "email_change", fn user, at ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      old_email = user.email

      case user
           |> User.email_changeset(%{email: at.email})
           |> Ecto.Changeset.put_change(:email_verified_at, now)
           |> Repo.update() do
        {:ok, updated} ->
          revoke_all_sessions(updated.id)

          %{template: "email_changed_notice", user_id: updated.id, old_email: old_email}
          |> ForgeNexus.Workers.TransactionalEmailer.new()
          |> Oban.insert()

          {:ok, updated}

        {:error, cs} ->
          {:error, cs}
      end
    end)
  end

  # --- Session revocation ---

  @doc """
  Revoke every outstanding JWT for a user by bumping their session_generation.
  Any token minted before this point will fail the `gen` claim check in
  `ForgeNexus.Guardian.resource_from_claims/1` and be rejected as revoked.
  Also stamps revoked_at on any LoginSession rows for device-list accuracy.
  """
  def revoke_all_sessions(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(u in User, where: u.id == ^user_id)
    |> Repo.update_all(inc: [session_generation: 1])

    from(s in LoginSession, where: s.user_id == ^user_id and is_nil(s.revoked_at))
    |> Repo.update_all(set: [revoked_at: now])

    :ok
  end

  def update_profile(user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  def admin_update_user(user, attrs) do
    user
    |> User.admin_changeset(attrs)
    |> Repo.update()
  end

  def admin_set_verified_creator(user_id, verified) when is_boolean(verified) do
    user = Repo.get!(User, user_id)
    value = if verified, do: DateTime.utc_now() |> DateTime.truncate(:second), else: nil

    user
    |> Ecto.Changeset.change(verified_creator_at: value)
    |> Repo.update()
  end

  def update_user_fields(user_id, fields) when is_map(fields) do
    case Repo.get(User, user_id) do
      nil -> {:error, :not_found}
      user -> user |> Ecto.Changeset.change(fields) |> Repo.update()
    end
  end

  def authenticate_user(email, password) do
    user = get_user_by_email(email)

    cond do
      user && Bcrypt.verify_pass(password, user.password_hash) ->
        {:ok, user}

      user ->
        {:error, :invalid_credentials}

      true ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  @doc """
  Records a login attempt (success or failure) into `login_attempts`.

  Accepts a map with keys: `:user_id`, `:email`, `:ip_address`, `:user_agent`,
  `:success`, `:failure_reason`. Fire-and-forget — logs and swallows errors.
  """
  def record_login_event(attrs) when is_map(attrs) do
    attrs =
      attrs
      |> Map.put_new(:occurred_at, DateTime.utc_now())
      |> Map.put_new(:success, false)

    %LoginEvent{}
    |> LoginEvent.changeset(attrs)
    |> Repo.insert()
  rescue
    e ->
      require Logger
      Logger.warning("[Accounts.record_login_event] #{Exception.message(e)}")
      {:error, :record_failed}
  end

  @doc """
  Lists login events for admin review. Supports filters:
  `:user_id`, `:email`, `:ip_address`, `:success` (boolean),
  `:since` (DateTime), `:limit` (default 100, max 500).
  """
  def list_login_events(opts \\ []) do
    limit =
      case Keyword.get(opts, :limit, 100) do
        n when is_integer(n) and n > 0 and n <= 500 -> n
        _ -> 100
      end

    query =
      LoginEvent
      |> order_by(desc: :inserted_at)
      |> limit(^limit)
      |> preload(:user)

    query
    |> maybe_filter_user_id(Keyword.get(opts, :user_id))
    |> maybe_filter_email(Keyword.get(opts, :email))
    |> maybe_filter_ip(Keyword.get(opts, :ip_address))
    |> maybe_filter_success(Keyword.get(opts, :success))
    |> maybe_filter_since(Keyword.get(opts, :since))
    |> Repo.all()
  end

  defp maybe_filter_user_id(q, nil), do: q
  defp maybe_filter_user_id(q, ""), do: q
  defp maybe_filter_user_id(q, user_id), do: where(q, [e], e.user_id == ^user_id)

  defp maybe_filter_email(q, nil), do: q
  defp maybe_filter_email(q, ""), do: q
  defp maybe_filter_email(q, email), do: where(q, [e], ilike(e.email, ^"%#{email}%"))

  defp maybe_filter_ip(q, nil), do: q
  defp maybe_filter_ip(q, ""), do: q
  defp maybe_filter_ip(q, ip), do: where(q, [e], e.ip_address == ^ip)

  defp maybe_filter_success(q, nil), do: q

  defp maybe_filter_success(q, success) when is_boolean(success),
    do: where(q, [e], e.success == ^success)

  defp maybe_filter_success(q, _), do: q

  defp maybe_filter_since(q, nil), do: q
  defp maybe_filter_since(q, %DateTime{} = since), do: where(q, [e], e.inserted_at >= ^since)
  defp maybe_filter_since(q, _), do: q

  @doc """
  Counts successful logins for a user over the last `period_days` days.
  """
  def count_logins(user_id, period_days) when is_integer(period_days) do
    since = DateTime.utc_now() |> DateTime.add(-period_days * 86_400, :second)

    from(e in LoginEvent,
      where: e.user_id == ^user_id and e.success == true and e.inserted_at >= ^since,
      select: count(e.id)
    )
    |> Repo.one()
    |> Kernel.||(0)
  end

  def update_last_seen(user) do
    user
    |> Ecto.Changeset.change(
      last_seen_at: DateTime.utc_now() |> DateTime.truncate(:second),
      is_online: true
    )
    |> Repo.update()
  end

  def set_offline(user) do
    user
    |> Ecto.Changeset.change(is_online: false)
    |> Repo.update()
  end

  def online_users do
    User
    |> where([u], u.is_online == true)
    |> select([u], %{id: u.id, username: u.username, slug: u.slug, avatar_url: u.avatar_url})
    |> Repo.all()
  end

  # --- User Groups ---

  def list_groups do
    UserGroup |> order_by(:position) |> Repo.all()
  end

  def get_group!(id), do: Repo.get!(UserGroup, id)

  def create_group(attrs) do
    %UserGroup{}
    |> UserGroup.changeset(attrs)
    |> Repo.insert()
  end

  def get_default_group do
    Repo.get_by(UserGroup, is_default: true)
  end

  def add_user_to_group(user_id, group_id) do
    %UserGroupMembership{}
    |> UserGroupMembership.changeset(%{user_id: user_id, group_id: group_id})
    |> Repo.insert()
  end

  # --- Ranks ---

  def list_ranks do
    Rank |> order_by(:position) |> Repo.all()
  end

  def get_rank_for_posts(post_count) do
    Rank
    |> where([r], r.min_posts <= ^post_count)
    |> order_by(desc: :min_posts)
    |> limit(1)
    |> Repo.one()
  end

  # --- Permissions ---

  def user_has_permission?(_user, _permission), do: true

  # --- Stats ---

  def count_users do
    Repo.one(from u in User, select: count(u.id)) || 0
  end

  def newest_member do
    User
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def new_members_this_week do
    one_week_ago = DateTime.utc_now() |> DateTime.add(-7 * 24 * 3600, :second)

    User
    |> where([u], u.inserted_at >= ^one_week_ago)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  def online_count do
    Repo.one(from u in User, where: u.is_online == true, select: count(u.id)) || 0
  end

  def online_stats do
    members = Repo.one(from u in User, where: u.is_online == true, select: count(u.id)) || 0
    %{total: members, members: members, guests: 0}
  end

  def online_users_detailed do
    User
    |> where([u], u.is_online == true)
    |> preload([:primary_group, :groups])
    |> Repo.all()
  end

  def new_members_this_month do
    start_of_month =
      Date.utc_today() |> Date.beginning_of_month() |> DateTime.new!(~T[00:00:00], "Etc/UTC")

    Repo.one(from u in User, where: u.inserted_at >= ^start_of_month, select: count(u.id)) || 0
  end

  def most_active_users(limit \\ 10) do
    User
    |> where([u], u.post_count > 0)
    |> order_by(desc: :post_count)
    |> limit(^limit)
    |> preload([:primary_group])
    |> Repo.all()
  end

  # --- Follows ---

  def is_following?(follower_id, followed_id) do
    Repo.exists?(
      from f in UserFollow, where: f.follower_id == ^follower_id and f.followed_id == ^followed_id
    )
  end

  def toggle_follow(follower_id, followed_id) do
    case Repo.get_by(UserFollow, follower_id: follower_id, followed_id: followed_id) do
      nil ->
        case %UserFollow{}
             |> UserFollow.changeset(%{follower_id: follower_id, followed_id: followed_id})
             |> Repo.insert() do
          {:ok, _} -> {:ok, :followed}
          {:error, cs} -> {:error, cs}
        end

      existing ->
        Repo.delete(existing)
        {:ok, :unfollowed}
    end
  end

  def follower_count(user_id) do
    Repo.one(from f in UserFollow, where: f.followed_id == ^user_id, select: count(f.id)) || 0
  end

  def following_count(user_id) do
    Repo.one(from f in UserFollow, where: f.follower_id == ^user_id, select: count(f.id)) || 0
  end

  def list_followers(user_id) do
    from(f in UserFollow,
      where: f.followed_id == ^user_id,
      join: u in User,
      on: u.id == f.follower_id,
      order_by: [desc: f.inserted_at],
      select: u
    )
    |> Repo.all()
  end

  def list_following(user_id) do
    from(f in UserFollow,
      where: f.follower_id == ^user_id,
      join: u in User,
      on: u.id == f.followed_id,
      order_by: [desc: f.inserted_at],
      select: u
    )
    |> Repo.all()
  end

  def following_feed(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    following_ids =
      from(f in UserFollow, where: f.follower_id == ^user_id, select: f.followed_id)
      |> Repo.all()

    if following_ids == [] do
      []
    else
      from(p in ForgeNexus.Forums.Post,
        where: p.user_id in ^following_ids and p.is_hidden == false,
        order_by: [desc: p.inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:user, thread: :forum]
      )
      |> Repo.all()
    end
  end

  # --- Blocks ---

  def block_user(user_id, blocked_user_id) do
    %UserBlock{}
    |> UserBlock.changeset(%{user_id: user_id, blocked_user_id: blocked_user_id})
    |> Repo.insert(on_conflict: :nothing)
  end

  def unblock_user(user_id, blocked_user_id) do
    case Repo.get_by(UserBlock, user_id: user_id, blocked_user_id: blocked_user_id) do
      nil -> {:error, :not_found}
      block -> Repo.delete(block)
    end
  end

  def list_blocked_users(user_id) do
    from(b in UserBlock,
      where: b.user_id == ^user_id,
      join: u in User,
      on: u.id == b.blocked_user_id,
      select: %{
        id: u.id,
        username: u.username,
        slug: u.slug,
        avatar_url: u.avatar_url,
        blocked_at: b.inserted_at
      }
    )
    |> Repo.all()
  end

  # --- OAuth Accounts ---

  def list_oauth_accounts(user_id) do
    OAuthAccount
    |> where([o], o.user_id == ^user_id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  def link_oauth_account(user_id, provider, user_info) do
    attrs = %{
      user_id: user_id,
      provider: provider,
      provider_uid:
        to_string(user_info[:id] || user_info["id"] || user_info[:uid] || user_info["uid"]),
      provider_email: user_info[:email] || user_info["email"],
      provider_name: user_info[:name] || user_info["name"],
      provider_avatar:
        user_info[:avatar_url] || user_info["avatar_url"] || user_info[:avatar] ||
          user_info["avatar"],
      access_token: user_info[:access_token] || user_info["access_token"],
      refresh_token: user_info[:refresh_token] || user_info["refresh_token"]
    }

    %OAuthAccount{}
    |> OAuthAccount.changeset(attrs)
    |> Repo.insert()
  end

  def unlink_oauth_account(user_id, provider) do
    case Repo.get_by(OAuthAccount, user_id: user_id, provider: provider) do
      nil ->
        {:error, :not_found}

      account ->
        user = Repo.get(User, user_id)

        oauth_count =
          Repo.one(from o in OAuthAccount, where: o.user_id == ^user_id, select: count(o.id)) || 0

        if is_nil(user.password_hash) and oauth_count <= 1 do
          {:error, :last_auth_method}
        else
          Repo.delete(account)
        end
    end
  end

  @doc """
  Find or create a user for an OAuth sign-in.

  Resolution order:

    1. If an `oauth_accounts` row already exists for `{provider, provider_uid}`,
       return the attached user (returning-user path).
    2. Otherwise, if the provider returned an email and a user with that email
       already exists, link the OAuth account to that user and return it
       (account-linking path — prevents duplicate accounts when the same person
       signs in via multiple providers).
    3. Otherwise, create a new user:
         * Username is derived from `name`/`username`/`email`, collision-suffixed
           to uniqueness via `unique_username/1`.
         * Email is set if the provider returned one, else `nil` with
           `email_unverified: true` so the UI can prompt the user later.
         * Password hash stays `nil` — OAuth users authenticate via provider.

  Always returns `{:ok, user}` on success, `{:error, reason}` on failure.
  The whole create/link flow runs inside a Repo transaction so partial
  failures roll back cleanly.
  """
  def find_or_create_oauth_user(provider, user_info) do
    provider_uid =
      to_string(user_info[:id] || user_info["id"] || user_info[:uid] || user_info["uid"] || "")

    email = normalize_email(user_info[:email] || user_info["email"])
    name = user_info[:name] || user_info["name"]
    username_hint = user_info[:username] || user_info["username"] || name || email

    avatar =
      user_info[:avatar] || user_info["avatar"] || user_info[:picture] || user_info["picture"]

    Repo.transaction(fn ->
      if provider_uid == "" do
        Repo.rollback(:missing_provider_uid)
      else
        existing_link = Repo.get_by(OAuthAccount, provider: provider, provider_uid: provider_uid)
        existing_user_by_email = if email, do: Repo.get_by(User, email: email), else: nil

        cond do
          existing_link != nil ->
            case Repo.get(User, existing_link.user_id) do
              nil -> Repo.rollback(:user_deleted)
              user -> user
            end

          existing_user_by_email != nil ->
            case link_oauth_account(existing_user_by_email.id, provider, user_info) do
              {:ok, _} -> existing_user_by_email
              {:error, reason} -> Repo.rollback(reason)
            end

          true ->
            username = unique_username(username_hint || "#{provider}_#{provider_uid}")

            user_attrs = %{
              username: username,
              email: email,
              email_unverified: is_nil(email),
              display_name: name || username,
              avatar_url: avatar
            }

            with {:ok, user} <- %User{} |> User.oauth_changeset(user_attrs) |> Repo.insert(),
                 {:ok, _} <- link_oauth_account(user.id, provider, user_info) do
              user
            else
              {:error, reason} -> Repo.rollback(reason)
            end
        end
      end
    end)
  end

  defp normalize_email(nil), do: nil
  defp normalize_email(""), do: nil
  defp normalize_email(email) when is_binary(email), do: String.downcase(String.trim(email))
  defp normalize_email(_), do: nil

  @doc """
  Return a unique username derived from `hint`. Strips invalid characters,
  enforces a 3-char minimum, then appends an integer suffix (2, 3, 4, ...)
  until no collision exists in the users table.
  """
  def unique_username(hint) do
    base =
      hint
      |> to_string()
      |> String.replace(~r/[^a-zA-Z0-9_-]/, "_")
      |> String.replace(~r/_+/, "_")
      |> String.trim("_")
      |> String.slice(0, 20)

    base = if String.length(base) < 3, do: "user_#{base}" |> String.slice(0, 20), else: base
    base = if base == "", do: "user", else: base

    find_unused_username(base, 1)
  end

  defp find_unused_username(candidate, attempt) do
    name = if attempt == 1, do: candidate, else: "#{candidate}#{attempt}"

    if Repo.get_by(User, username: name) do
      find_unused_username(candidate, attempt + 1)
    else
      name
    end
  end

  def create_login_session(user, jti, conn) do
    ip =
      case conn do
        %{remote_ip: ip} when not is_nil(ip) -> ip |> :inet.ntoa() |> to_string()
        _ -> nil
      end

    user_agent =
      case conn do
        %Plug.Conn{} = c ->
          case Plug.Conn.get_req_header(c, "user-agent") do
            [ua | _] -> ua
            _ -> nil
          end

        _ ->
          nil
      end

    device_name = LoginSession.parse_device_name(user_agent)

    %LoginSession{}
    |> LoginSession.changeset(%{
      user_id: user.id,
      token_jti: jti,
      ip_address: ip,
      user_agent: user_agent,
      device_name: device_name,
      last_active_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert()
  end

  # --- Preferences ---

  def get_preferences(user_id) do
    case Repo.get_by(UserPreference, user_id: user_id) do
      nil ->
        {:ok, pref} =
          %UserPreference{}
          |> UserPreference.create_changeset(%{user_id: user_id})
          |> Repo.insert()

        pref

      pref ->
        pref
    end
  end

  def update_preferences(user_id, attrs) do
    pref = get_preferences(user_id)

    pref
    |> UserPreference.changeset(attrs)
    |> Repo.update()
  end

  # --- Achievements (delegated to ForgeNexus.Achievements context) ---

  defdelegate list_achievements(), to: ForgeNexus.Achievements
  defdelegate list_user_achievements(user_id), to: ForgeNexus.Achievements

  # --- Promotion Rules ---

  def list_all_promotion_rules do
    PromotionRule
    |> order_by(:position)
    |> preload([:from_group, :to_group])
    |> Repo.all()
  end

  def create_promotion_rule(attrs) do
    %PromotionRule{} |> PromotionRule.changeset(attrs) |> Repo.insert()
  end

  def update_promotion_rule(id, attrs) do
    case Repo.get(PromotionRule, id) do
      nil -> {:error, :not_found}
      rule -> rule |> PromotionRule.changeset(attrs) |> Repo.update()
    end
  end

  def delete_promotion_rule(id) do
    case Repo.get(PromotionRule, id) do
      nil -> {:error, :not_found}
      rule -> Repo.delete(rule)
    end
  end

  @doc """
  Evaluates every active promotion rule against every user and promotes
  anyone who qualifies. Returns a summary map.

  Supported criteria shapes (merged with AND):
    %{"post_count" => n}        — user.post_count >= n
    %{"thread_count" => n}      — user.thread_count >= n
    %{"reputation" => n}        — user.reputation >= n
    %{"trust_level" => n}       — user.trust_level >= n
    %{"days_since_join" => n}   — account age >= n days
    %{"from_group_id" => uuid}  — user must currently be in that group (moves them out)

  If `from_group_id` is set on the rule itself, users must currently belong
  to it to qualify.
  """
  def evaluate_promotion_rules do
    rules =
      PromotionRule
      |> where([r], r.is_active == true)
      |> order_by(asc: :position)
      |> preload([:from_group, :to_group])
      |> Repo.all()

    Enum.reduce(rules, %{evaluated: 0, promoted: 0, per_rule: []}, fn rule, acc ->
      candidates = candidates_for_rule(rule)
      qualifying = Enum.filter(candidates, &user_matches_criteria?(&1, rule.criteria || %{}))

      promoted =
        Enum.reduce(qualifying, 0, fn user, n ->
          case promote_user(user, rule) do
            :ok -> n + 1
            :skip -> n
          end
        end)

      Map.merge(acc, %{
        evaluated: acc.evaluated + length(candidates),
        promoted: acc.promoted + promoted,
        per_rule:
          acc.per_rule ++
            [
              %{
                rule_id: rule.id,
                rule_name: rule.name,
                candidates: length(candidates),
                promoted: promoted
              }
            ]
      })
    end)
  end

  defp candidates_for_rule(%PromotionRule{from_group_id: nil}) do
    Repo.all(User)
  end

  defp candidates_for_rule(%PromotionRule{from_group_id: from_id}) do
    from(u in User,
      join: m in UserGroupMembership,
      on: m.user_id == u.id,
      where: m.group_id == ^from_id
    )
    |> Repo.all()
  end

  defp user_matches_criteria?(user, criteria) when is_map(criteria) do
    Enum.all?(criteria, fn {key, value} ->
      case to_string(key) do
        "post_count" ->
          is_integer(value) and user.post_count >= value

        "thread_count" ->
          is_integer(value) and user.thread_count >= value

        "reputation" ->
          is_integer(value) and user.reputation >= value

        "trust_level" ->
          is_integer(value) and user.trust_level >= value

        "days_since_join" ->
          is_integer(value) and
            NaiveDateTime.diff(NaiveDateTime.utc_now(), user.inserted_at, :second) >=
              value * 86_400

        _ ->
          true
      end
    end)
  end

  defp user_matches_criteria?(_user, _), do: false

  defp promote_user(user, rule) do
    already =
      Repo.exists?(
        from m in UserGroupMembership,
          where: m.user_id == ^user.id and m.group_id == ^rule.to_group_id
      )

    if already do
      :skip
    else
      %UserGroupMembership{}
      |> UserGroupMembership.changeset(%{user_id: user.id, group_id: rule.to_group_id})
      |> Repo.insert()

      if rule.from_group_id do
        from(m in UserGroupMembership,
          where: m.user_id == ^user.id and m.group_id == ^rule.from_group_id
        )
        |> Repo.delete_all()
      end

      :ok
    end
  end

  # --- Permissions ---

  @doc """
  Default permission map applied to brand-new user groups / the baseline
  member role. Delegates to the canonical `ForgeNexus.Permissions.Registry`
  so there is a single source of truth.
  """
  def default_permissions do
    ForgeNexus.Permissions.Registry.default_permissions()
  end

  @doc """
  Idempotently create the five default user groups (guest, member, trusted,
  moderator, admin) with their role-computed permissions from
  `ForgeNexus.Permissions.Roles`. Existing groups (matched by slug) are left
  untouched.

  Returns `%{created: [UserGroup.t()], skipped: [String.t()]}`.
  """
  def seed_default_groups do
    alias ForgeNexus.Permissions.Roles

    defaults = [
      %{
        slug: "guest",
        name: "Guest",
        description: "Unauthenticated visitors",
        position: 0,
        is_default: false,
        is_staff: false
      },
      %{
        slug: "member",
        name: "Member",
        description: "Default role for registered users",
        position: 10,
        is_default: true,
        is_staff: false
      },
      %{
        slug: "trusted",
        name: "Trusted Member",
        description: "Established members with extended privileges",
        position: 20,
        is_default: false,
        is_staff: false
      },
      %{
        slug: "moderator",
        name: "Moderator",
        description: "Community moderators",
        position: 30,
        is_default: false,
        is_staff: true
      },
      %{
        slug: "admin",
        name: "Administrator",
        description: "Full administrative access",
        position: 40,
        is_default: false,
        is_staff: true
      }
    ]

    Enum.reduce(defaults, %{created: [], skipped: []}, fn attrs, acc ->
      case Repo.get_by(UserGroup, slug: attrs.slug) do
        nil ->
          role = String.to_existing_atom(attrs.slug)

          full_attrs =
            attrs
            |> Map.put(:permissions, Roles.compute(role))

          case %UserGroup{} |> UserGroup.admin_changeset(full_attrs) |> Repo.insert() do
            {:ok, group} -> %{acc | created: [group | acc.created]}
            {:error, _} -> %{acc | skipped: [attrs.slug | acc.skipped]}
          end

        _existing ->
          %{acc | skipped: [attrs.slug | acc.skipped]}
      end
    end)
  end

  # --- Status ---

  def update_status(user, status) when is_binary(status) do
    if status in ~w(online away busy invisible offline) do
      user
      |> Ecto.Changeset.change(presence_status: status)
      |> Repo.update()
    else
      {:error, :invalid_status}
    end
  end

  def set_custom_status(user, text, emoji) do
    user
    |> Ecto.Changeset.change(%{custom_status_text: text, custom_status_emoji: emoji})
    |> Repo.update()
  end

  def clear_custom_status(user) do
    user
    |> Ecto.Changeset.change(%{custom_status_text: nil, custom_status_emoji: nil})
    |> Repo.update()
  end

  def get_visible_status(%User{} = user) do
    case user.presence_status do
      "invisible" -> "offline"
      nil -> if user.is_online, do: "online", else: "offline"
      status -> status
    end
  end

  # --- Avatar Frames ---

  def list_avatar_frames do
    AvatarFrame
    |> where([f], f.is_active == true)
    |> order_by(:position)
    |> Repo.all()
  end

  def get_available_frames_for_user(%User{} = user) do
    AvatarFrame
    |> where(
      [f],
      f.is_active == true and (is_nil(f.min_posts) or f.min_posts <= ^user.post_count)
    )
    |> order_by(:position)
    |> Repo.all()
  end

  # --- Profile helpers ---

  def display_title(%User{} = user) do
    cond do
      is_binary(user.custom_title) and user.custom_title != "" -> user.custom_title
      true -> nil
    end
  end

  def update_profile_page(user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  def recent_registrations(limit \\ 5) do
    User
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def search_users_by_ip(ip) when is_binary(ip) do
    User
    |> where([u], u.registered_ip == ^ip)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  def monthly_member_growth(months \\ 12) do
    cutoff = DateTime.utc_now() |> DateTime.add(-months * 30 * 24 * 3600, :second)

    from(u in User,
      where: u.inserted_at >= ^cutoff,
      group_by: fragment("to_char(?, 'YYYY-MM')", u.inserted_at),
      select: %{
        month: fragment("to_char(?, 'YYYY-MM')", u.inserted_at),
        count: count(u.id)
      },
      order_by: fragment("to_char(?, 'YYYY-MM')", u.inserted_at)
    )
    |> Repo.all()
  end
end
