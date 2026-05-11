defmodule ForgeNexus.AntiSpam do
  @moduledoc """
  Anti-spam integration. Checks IPs and emails against StopForumSpam database.
  Falls back gracefully if service is unavailable.
  """

  @stopforumspam_url "https://api.stopforumspam.org/api"

  def check_registration(ip, email, username) do
    results = %{ip: :clean, email: :clean, username: :clean, score: 0}

    case check_stopforumspam(ip, email, username) do
      {:ok, data} -> data
      {:error, _} -> results # Fail open — don't block registration if service is down
    end
  end

  def suspicious?(results) do
    results.score > 50
  end

  defp check_stopforumspam(ip, email, username) do
    params = URI.encode_query(%{
      ip: ip,
      email: email,
      username: username,
      json: "1"
    })

    case Req.get("#{@stopforumspam_url}?#{params}", receive_timeout: 5_000) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        score = calculate_score(body)
        {:ok, %{
          ip: if(get_in(body, ["ip", "appears"]) == 1, do: :spam, else: :clean),
          email: if(get_in(body, ["email", "appears"]) == 1, do: :spam, else: :clean),
          username: if(get_in(body, ["username", "appears"]) == 1, do: :spam, else: :clean),
          score: score
        }}
      _ -> {:error, :service_unavailable}
    end
  rescue
    _ -> {:error, :service_unavailable}
  end

  defp calculate_score(body) do
    ip_freq = get_in(body, ["ip", "frequency"]) || 0
    email_freq = get_in(body, ["email", "frequency"]) || 0
    ip_conf = get_in(body, ["ip", "confidence"]) || 0
    email_conf = get_in(body, ["email", "confidence"]) || 0

    # Weighted confidence score
    round(ip_conf * 0.4 + email_conf * 0.5 + min(ip_freq + email_freq, 100) * 0.1)
  end
end
