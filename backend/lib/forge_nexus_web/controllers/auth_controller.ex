defmodule ForgeNexusWeb.AuthController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Accounts
  alias ForgeNexus.Guardian
  alias ForgeNexus.Workers.TransactionalEmailer

  def register(conn, %{"user" => user_params}) do
    user_params = Map.put(user_params, "registered_ip", to_string(:inet.ntoa(conn.remote_ip)))

    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Add to default group
        if group = Accounts.get_default_group() do
          Accounts.add_user_to_group(user.id, group.id)
        end

        # Queue email verification. Worker generates the token itself so plaintext
        # never enters Oban args.
        %{template: "verify_email", user_id: user.id}
        |> TransactionalEmailer.new()
        |> Oban.insert()

        # Fire webhook event for new user registration
        Task.start(fn ->
          ForgeNexus.Forums.fire_webhook_event("forum.user.joined", %{
            user_id: user.id,
            username: user.username
          })
        end)

        {:ok, token, _claims} = Guardian.encode_and_sign(user)

        conn
        |> put_status(:created)
        |> put_resp_cookie("fn_token", token,
          http_only: true,
          secure: false,
          same_site: "Lax",
          max_age: 7 * 24 * 60 * 60,
          path: "/"
        )
        |> json(%{
          token: token,
          user: user_json(user)
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    ip = to_string(:inet.ntoa(conn.remote_ip))
    ua = List.first(get_req_header(conn, "user-agent")) |> truncate_ua()

    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(user)
        Accounts.update_last_seen(user)

        Accounts.record_login_event(%{
          user_id: user.id,
          email: email,
          ip_address: ip,
          user_agent: ua,
          success: true
        })

        conn
        |> put_resp_cookie("fn_token", token,
          http_only: true,
          secure: false,
          same_site: "Lax",
          max_age: 7 * 24 * 60 * 60,
          path: "/"
        )
        |> json(%{
          token: token,
          user: user_json(user)
        })

      {:error, :invalid_credentials} ->
        Accounts.record_login_event(%{
          email: email,
          ip_address: ip,
          user_agent: ua,
          success: false,
          failure_reason: "invalid_credentials"
        })

        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})
    end
  end

  defp truncate_ua(nil), do: nil
  defp truncate_ua(ua) when is_binary(ua), do: String.slice(ua, 0, 500)

  def refresh(conn, _params) do
    case conn.cookies["fn_token"] do
      nil ->
        conn |> put_status(:unauthorized) |> json(%{error: "No refresh token"})

      token ->
        case ForgeNexus.Guardian.resource_from_token(token) do
          {:ok, user, _claims} ->
            {:ok, new_token, _claims} = ForgeNexus.Guardian.encode_and_sign(user)

            conn
            |> put_resp_cookie("fn_token", new_token,
              http_only: true,
              secure: false,
              same_site: "Lax",
              max_age: 7 * 24 * 60 * 60,
              path: "/"
            )
            |> json(%{token: new_token, user: user_json(user)})

          _ ->
            conn |> put_status(:unauthorized) |> json(%{error: "Invalid token"})
        end
    end
  end

  def logout(conn, _params) do
    conn
    |> delete_resp_cookie("fn_token", path: "/")
    |> json(%{ok: true})
  end

  def me(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    case user do
      nil ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})

      user ->
        conn |> json(%{user: user_json(user)})
    end
  end

  def verify_email(conn, %{"token" => token}) when is_binary(token) and byte_size(token) > 0 do
    case Accounts.consume_email_verify_token(token) do
      {:ok, user} ->
        conn |> json(%{ok: true, user: user_json(user)})

      {:error, :invalid_token} ->
        conn |> put_status(:not_found) |> json(%{error: "Invalid verification token"})

      {:error, :already_used} ->
        conn |> put_status(:gone) |> json(%{error: "This verification link has already been used"})

      {:error, :expired} ->
        conn |> put_status(:gone) |> json(%{error: "This verification link has expired"})
    end
  end

  def verify_email(conn, _), do: conn |> put_status(:bad_request) |> json(%{error: "Missing token"})

  def forgot_password(conn, %{"email" => email}) when is_binary(email) and byte_size(email) > 0 do
    # Always respond 200 regardless — never leak whether an email exists.
    if user = Accounts.get_user_by_email(email) do
      %{template: "password_reset", user_id: user.id}
      |> TransactionalEmailer.new()
      |> Oban.insert()
    end

    conn |> json(%{ok: true})
  end

  def forgot_password(conn, _), do: conn |> put_status(:bad_request) |> json(%{error: "Missing email"})

  def reset_password(conn, %{"token" => token, "password" => new_password})
      when is_binary(token) and byte_size(token) > 0 and is_binary(new_password) do
    case Accounts.consume_password_reset_token(token, new_password) do
      {:ok, _user} ->
        conn |> json(%{ok: true})

      {:error, :invalid_token} ->
        conn |> put_status(:not_found) |> json(%{error: "Invalid reset token"})

      {:error, :already_used} ->
        conn |> put_status(:gone) |> json(%{error: "This reset link has already been used"})

      {:error, :expired} ->
        conn |> put_status(:gone) |> json(%{error: "This reset link has expired"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
    end
  end

  def reset_password(conn, _), do: conn |> put_status(:bad_request) |> json(%{error: "Missing token or password"})

  def request_email_change(conn, %{"new_email" => new_email, "password" => password})
      when is_binary(new_email) and is_binary(password) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})

      user ->
        cond do
          not Bcrypt.verify_pass(password, user.password_hash) ->
            Bcrypt.no_user_verify()
            conn |> put_status(:unauthorized) |> json(%{error: "Password incorrect"})

          String.downcase(new_email) == String.downcase(user.email) ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: "New email must differ from current email"})

          Accounts.get_user_by_email(new_email) != nil ->
            # Don't leak whether that email is already taken — pretend we queued it.
            conn |> json(%{ok: true})

          true ->
            %{template: "email_change", user_id: user.id, new_email: String.downcase(new_email)}
            |> TransactionalEmailer.new()
            |> Oban.insert()

            conn |> json(%{ok: true})
        end
    end
  end

  def request_email_change(conn, _), do: conn |> put_status(:bad_request) |> json(%{error: "Missing new_email or password"})

  def confirm_email_change(conn, %{"token" => token}) when is_binary(token) and byte_size(token) > 0 do
    case Accounts.consume_email_change_token(token) do
      {:ok, user} ->
        conn |> json(%{ok: true, user: user_json(user)})

      {:error, :invalid_token} ->
        conn |> put_status(:not_found) |> json(%{error: "Invalid confirmation token"})

      {:error, :already_used} ->
        conn |> put_status(:gone) |> json(%{error: "This confirmation link has already been used"})

      {:error, :expired} ->
        conn |> put_status(:gone) |> json(%{error: "This confirmation link has expired"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
    end
  end

  def confirm_email_change(conn, _), do: conn |> put_status(:bad_request) |> json(%{error: "Missing token"})

  def resend_verification(conn, _params) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})

      %{email_verified_at: %DateTime{}} ->
        conn |> put_status(:conflict) |> json(%{error: "Email already verified"})

      user ->
        %{template: "verify_email", user_id: user.id}
        |> TransactionalEmailer.new()
        |> Oban.insert()

        conn |> json(%{ok: true})
    end
  end

  defp user_json(user) do
    # Preload primary_group to check staff status
    user = ForgeNexus.Repo.preload(user, [:primary_group, :groups])
    is_staff = user.trust_level >= 3 or Enum.any?(user.groups, & &1.is_staff)

    %{
      id: user.id,
      username: user.username,
      email: user.email,
      display_name: user.display_name,
      slug: user.slug,
      avatar_url: user.avatar_url,
      post_count: user.post_count,
      thread_count: user.thread_count,
      reputation: user.reputation,
      trust_level: user.trust_level,
      status: user.status,
      theme: user.theme,
      inserted_at: user.inserted_at,
      is_staff: is_staff,
      email_verified: user.email_verified_at != nil,
      totp_enabled: user.totp_enabled || false,
      custom_title: user.custom_title,
      username_color: user.username_color,
      username_effect: user.username_effect,
      nameplate_color: user.nameplate_color,
      avatar_frame: user.avatar_frame,
      avatar_frame_color: user.avatar_frame_color,
      presence_status: user.presence_status,
      custom_status_text: user.custom_status_text,
      custom_status_emoji: user.custom_status_emoji,
      theme_id: nil,
      subscription_tier: nil
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
