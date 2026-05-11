defmodule ForgeNexus.OAuth do
  @moduledoc """
  Lightweight OAuth2 client for Google, Discord, and GitHub.
  Uses Req for HTTP — no ueberauth dependency needed.
  """

  @providers %{
    "google" => %{
      authorize_url: "https://accounts.google.com/o/oauth2/v2/auth",
      token_url: "https://oauth2.googleapis.com/token",
      userinfo_url: "https://www.googleapis.com/oauth2/v2/userinfo",
      scope: "openid email profile"
    },
    "discord" => %{
      authorize_url: "https://discord.com/api/oauth2/authorize",
      token_url: "https://discord.com/api/oauth2/token",
      userinfo_url: "https://discord.com/api/users/@me",
      scope: "identify email"
    },
    "github" => %{
      authorize_url: "https://github.com/login/oauth/authorize",
      token_url: "https://github.com/login/oauth/access_token",
      userinfo_url: "https://api.github.com/user",
      scope: "user:email"
    }
  }

  @doc "List of supported provider names."
  def supported_providers, do: Map.keys(@providers)

  @doc "Check if a provider string is valid."
  def valid_provider?(provider), do: Map.has_key?(@providers, provider)

  @doc "Generate a random state token for CSRF protection."
  def generate_state do
    :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)
  end

  @doc "Build the authorization redirect URL for a given provider."
  def authorize_url(provider, state) do
    with {:ok, provider_config} <- provider_config(provider),
         {:ok, app_config} <- app_config(provider) do
      params =
        URI.encode_query(%{
          client_id: app_config[:client_id],
          redirect_uri: app_config[:redirect_uri],
          response_type: "code",
          scope: provider_config.scope,
          state: state
        })

      {:ok, "#{provider_config.authorize_url}?#{params}"}
    end
  end

  @doc "Exchange an authorization code for an access token."
  def exchange_code(provider, code) do
    with {:ok, provider_config} <- provider_config(provider),
         {:ok, app_config} <- app_config(provider) do
      body = %{
        client_id: app_config[:client_id],
        client_secret: app_config[:client_secret],
        code: code,
        redirect_uri: app_config[:redirect_uri],
        grant_type: "authorization_code"
      }

      headers = [{"accept", "application/json"}]

      case Req.post(provider_config.token_url, form: body, headers: headers) do
        {:ok, %{status: 200, body: %{"access_token" => token} = resp}} ->
          {:ok, %{access_token: token, refresh_token: resp["refresh_token"]}}

        {:ok, %{body: body}} ->
          {:error, body["error_description"] || body["error"] || "Token exchange failed"}

        {:error, reason} ->
          {:error, "HTTP error: #{inspect(reason)}"}
      end
    end
  end

  @doc "Fetch user info from the provider using the access token."
  def get_user_info(provider, access_token) do
    with {:ok, provider_config} <- provider_config(provider) do
      headers = [{"authorization", "Bearer #{access_token}"}]

      # GitHub needs a special User-Agent header
      headers =
        if provider == "github",
          do: [{"user-agent", "ForgeNexus"} | headers],
          else: headers

      case Req.get(provider_config.userinfo_url, headers: headers) do
        {:ok, %{status: 200, body: body}} ->
          {:ok, normalize_user_info(provider, body)}

        {:ok, %{status: status, body: body}} ->
          {:error, "Provider returned #{status}: #{inspect(body)}"}

        {:error, reason} ->
          {:error, "HTTP error: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  For GitHub, the primary email may not be in the user endpoint.
  We need to fetch /user/emails separately.
  """
  def get_github_email(access_token) do
    headers = [
      {"authorization", "Bearer #{access_token}"},
      {"user-agent", "ForgeNexus"}
    ]

    case Req.get("https://api.github.com/user/emails", headers: headers) do
      {:ok, %{status: 200, body: emails}} when is_list(emails) ->
        primary =
          Enum.find(emails, fn e -> e["primary"] && e["verified"] end) ||
            Enum.find(emails, fn e -> e["verified"] end) ||
            List.first(emails)

        {:ok, primary["email"]}

      _ ->
        {:ok, nil}
    end
  end

  # --- Private ---

  defp provider_config(provider) do
    case Map.get(@providers, provider) do
      nil -> {:error, :invalid_provider}
      config -> {:ok, config}
    end
  end

  @supported_providers ~w(google github discord twitter)a

  defp app_config(provider) do
    oauth_config = Application.get_env(:forge_nexus, :oauth, [])
    provider_atom = String.to_atom(provider)

    if provider_atom not in @supported_providers do
      {:error, :unsupported_provider}
    else
      case Keyword.get(oauth_config, provider_atom) do
        nil -> {:error, :provider_not_configured}
        config -> {:ok, config}
      end
    end
  end

  defp normalize_user_info("google", data) do
    %{
      email: data["email"],
      name: data["name"],
      avatar_url: data["picture"],
      provider_uid: to_string(data["id"])
    }
  end

  defp normalize_user_info("discord", data) do
    avatar_url =
      if data["avatar"] do
        "https://cdn.discordapp.com/avatars/#{data["id"]}/#{data["avatar"]}.png?size=256"
      else
        nil
      end

    %{
      email: data["email"],
      name: data["global_name"] || data["username"],
      avatar_url: avatar_url,
      provider_uid: to_string(data["id"])
    }
  end

  defp normalize_user_info("github", data) do
    %{
      email: data["email"],
      name: data["name"] || data["login"],
      avatar_url: data["avatar_url"],
      provider_uid: to_string(data["id"])
    }
  end
end
