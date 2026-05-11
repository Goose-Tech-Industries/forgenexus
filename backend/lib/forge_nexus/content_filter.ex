defmodule ForgeNexus.ContentFilter do
  @moduledoc """
  Content-level spam filtering for posts and threads.
  Checks for excessive links, banned words, and repetitive content.
  """

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Forums.Post

  @max_links 5

  @banned_words ~w(
    viagra cialis levitra tramadol phentermine
    casino poker slots jackpot
    buy-now limited-offer act-now click-here
  )

  @url_regex ~r/https?:\/\/[^\s\]\[<>"]+/i

  @doc """
  Checks content for spam indicators.
  Returns `{:ok, :clean}` or `{:error, reason_string}`.
  """
  def check(body, user_id, _opts \\ []) do
    with :ok <- check_excessive_links(body),
         :ok <- check_banned_words(body),
         :ok <- check_repetitive_content(body, user_id) do
      {:ok, :clean}
    end
  end

  defp check_excessive_links(body) do
    link_count = body |> String.downcase() |> then(&Regex.scan(@url_regex, &1)) |> length()

    if link_count > @max_links do
      {:error, "Too many links in your post (maximum #{@max_links} allowed)"}
    else
      :ok
    end
  end

  defp check_banned_words(body) do
    lower_body = String.downcase(body)

    found = Enum.find(@banned_words, fn word ->
      String.contains?(lower_body, word)
    end)

    if found do
      {:error, "Your post contains prohibited content"}
    else
      :ok
    end
  end

  defp check_repetitive_content(body, user_id) when is_binary(body) and not is_nil(user_id) do
    cutoff = DateTime.utc_now() |> DateTime.add(-24 * 3600, :second)
    body_trimmed = String.trim(body)

    duplicate_exists =
      from(p in Post,
        where:
          p.user_id == ^user_id and
          p.body == ^body_trimmed and
          p.inserted_at >= ^cutoff,
        select: count(p.id)
      )
      |> Repo.one()
      |> then(&(&1 > 0))

    if duplicate_exists do
      {:error, "You have already posted this exact content recently"}
    else
      :ok
    end
  end

  defp check_repetitive_content(_body, _user_id), do: :ok
end
