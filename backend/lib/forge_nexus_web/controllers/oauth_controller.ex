defmodule ForgeNexusWeb.OAuthController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.{OAuth, Accounts, Guardian}
  alias ForgeNexusWeb.Plugs.AuthCookie

  @frontend_url "http://localhost:5173"
  @state_cookie "oauth_state"
  # 10 minutes
  @state_max_age 600

  # GET /auth/oauth/:provider — redirect to provider's authorize page
  def redirect_to_provider(conn, %{"provider" => provider}) do
    if OAuth.valid_provider?(provider) do
      state = OAuth.generate_state()

      case OAuth.authorize_url(provider, state) do
        {:ok, url} ->
          conn
          |> put_resp_cookie(@state_cookie, state,
            http_only: true,
            secure: Mix.env() == :prod,
            same_site: "Lax",
            max_age: @state_max_age,
            path: "/"
          )
          |> redirect(external: url)

        {:error, reason} ->
          redirect_with_error(conn, "OAuth configuration error: #{inspect(reason)}")
      end
    else
      redirect_with_error(conn, "Unsupported provider")
    end
  end

  # GET /auth/oauth/:provider/callback — handle the OAuth callback
  def callback(conn, %{"provider" => provider, "code" => code, "state" => state}) do
    stored_state = conn.cookies[@state_cookie]

    cond do
      !OAuth.valid_provider?(provider) ->
        redirect_with_error(conn, "Unsupported provider")

      is_nil(stored_state) || state != stored_state ->
        redirect_with_error(conn, "Invalid state parameter. Please try again.")

      true ->
        conn = delete_resp_cookie(conn, @state_cookie, path: "/")
        handle_oauth_flow(conn, provider, code)
    end
  end

  def callback(conn, %{"error" => error, "error_description" => desc}) do
    redirect_with_error(conn, desc || error)
  end

  def callback(conn, %{"error" => error}) do
    redirect_with_error(conn, error)
  end

  def callback(conn, _params) do
    redirect_with_error(conn, "Missing authorization code")
  end

  # POST /auth/oauth/:provider/link — link provider to logged-in user
  def link(conn, %{"provider" => provider}) do
    user = Guardian.Plug.current_resource(conn)

    if !OAuth.valid_provider?(provider) do
      conn |> put_status(:bad_request) |> json(%{error: "Unsupported provider"})
    else
      state = OAuth.generate_state()

      case OAuth.authorize_url(provider, state) do
        {:ok, url} ->
          conn
          |> put_resp_cookie(@state_cookie, state,
            http_only: true,
            secure: Mix.env() == :prod,
            same_site: "Lax",
            max_age: @state_max_age,
            path: "/"
          )
          |> put_resp_cookie("oauth_link_user", user.id,
            http_only: true,
            secure: Mix.env() == :prod,
            same_site: "Lax",
            max_age: @state_max_age,
            path: "/"
          )
          |> json(%{redirect_url: url})

        {:error, reason} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "Config error: #{inspect(reason)}"})
      end
    end
  end

  # DELETE /auth/oauth/:provider/unlink — remove linked provider
  def unlink(conn, %{"provider" => provider}) do
    user = Guardian.Plug.current_resource(conn)

    case Accounts.unlink_oauth_account(user.id, provider) do
      {:ok, _} ->
        json(conn, %{message: "#{String.capitalize(provider)} account unlinked"})

      {:error, :last_auth_method} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Cannot unlink your only login method. Set a password first."})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "No linked #{provider} account found"})
    end
  end

  # GET /auth/oauth/accounts — list linked providers
  def linked_accounts(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    accounts = Accounts.list_oauth_accounts(user.id)

    json(conn, %{
      accounts:
        Enum.map(accounts, fn a ->
          %{
            provider: a.provider,
            provider_email: a.provider_email,
            provider_name: a.provider_name,
            provider_avatar: a.provider_avatar,
            linked_at: a.inserted_at
          }
        end)
    })
  end

  # --- Private ---

  defp handle_oauth_flow(conn, provider, code) do
    with {:ok, tokens} <- OAuth.exchange_code(provider, code),
         {:ok, user_info} <- OAuth.get_user_info(provider, tokens.access_token) do
      # For GitHub, email may not be in the main endpoint
      user_info =
        if provider == "github" && is_nil(user_info[:email]) do
          case OAuth.get_github_email(tokens.access_token) do
            {:ok, email} when not is_nil(email) -> Map.put(user_info, :email, email)
            _ -> user_info
          end
        else
          user_info
        end

      # Merge tokens into user_info for storage
      user_info =
        user_info
        |> Map.put(:access_token, tokens.access_token)
        |> Map.put(:refresh_token, tokens[:refresh_token])

      # Check if this is a "link" flow (user was already logged in)
      link_user_id = conn.cookies["oauth_link_user"]

      result =
        if link_user_id do
          _conn = delete_resp_cookie(conn, "oauth_link_user", path: "/")

          case Accounts.link_oauth_account(link_user_id, provider, user_info) do
            {:ok, _} -> {:linked, link_user_id}
            {:error, %Ecto.Changeset{} = cs} -> {:error, format_changeset_error(cs)}
            {:error, reason} -> {:error, inspect(reason)}
          end
        else
          Accounts.find_or_create_oauth_user(provider, user_info)
        end

      case result do
        {:linked, _user_id} ->
          redirect(conn,
            external: "#{frontend_url()}/settings/account?oauth=linked&provider=#{provider}"
          )

        {:ok, user} ->
          {:ok, token, claims} = Guardian.encode_and_sign(user)
          Accounts.create_login_session(user, claims["jti"], conn)
          Accounts.update_last_seen(user)

          conn
          |> AuthCookie.set_cookie(token)
          |> redirect(external: "#{frontend_url()}/auth/oauth/callback?token=#{token}")

        {:error, reason} ->
          redirect_with_error(conn, to_string(reason))
      end
    else
      {:error, reason} ->
        redirect_with_error(conn, to_string(reason))
    end
  end

  defp redirect_with_error(conn, message) do
    encoded = URI.encode_www_form(message)
    redirect(conn, external: "#{frontend_url()}/auth/oauth/callback?error=#{encoded}")
  end

  defp frontend_url do
    Application.get_env(:forge_nexus, :frontend_url, @frontend_url)
  end

  defp format_changeset_error(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
    |> Enum.join("; ")
  end
end
