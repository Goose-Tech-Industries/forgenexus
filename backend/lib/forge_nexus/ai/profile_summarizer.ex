defmodule ForgeNexus.AI.ProfileSummarizer do
  @moduledoc """
  Generates a short "What does this user post about?" summary for a profile
  from their recent posts + profile blurbs. On-demand, not auto-computed.
  """

  import Ecto.Query
  alias ForgeNexus.{Repo, AI}
  alias ForgeNexus.Forums.Post

  @feature "profile_summary"
  @post_sample 30
  @max_chars_per_post 500

  def generate(user) do
    case AI.feature_enabled?(@feature) do
      false ->
        {:error, :feature_disabled}

      true ->
        posts_text = recent_posts_sample(user.id)
        blurbs = assemble_blurbs(user)

        messages = [
          %{
            role: "system",
            content: """
            You write concise, third-person summaries of a forum user's interests and
            posting style based on their recent posts and profile blurbs. Be warm but
            factual. 2-3 sentences, under 280 characters. No bullet points. No emojis
            unless the user uses them a lot themselves.
            """
          },
          %{
            role: "user",
            content: """
            Username: #{user.username}
            Display name: #{user.display_name || user.username}
            Pronouns: #{user.pronouns || "not listed"}

            Profile blurbs:
            #{blurbs}

            Recent posts sample (most recent first):
            #{posts_text}

            Write the summary.
            """
          }
        ]

        AI.Client.complete(@feature, messages, max_tokens: 180, temperature: 0.4)
    end
  end

  defp recent_posts_sample(user_id) do
    from(p in Post,
      where: p.user_id == ^user_id and p.is_hidden == false,
      order_by: [desc: p.inserted_at],
      limit: @post_sample,
      select: p.body
    )
    |> Repo.all()
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn text ->
      "- " <> String.slice(text, 0, @max_chars_per_post)
    end)
    |> Enum.join("\n")
  end

  defp assemble_blurbs(user) do
    [
      {"About", user.about_me_bbcode},
      {"Interests", user.interests},
      {"Favorite music", user.favorite_music},
      {"Favorite movies", user.favorite_movies},
      {"Favorite games", user.favorite_games},
      {"Favorite TV", user.favorite_tv},
      {"Favorite books", user.favorite_books},
      {"Heroes", user.heroes},
      {"Who they'd like to meet", user.who_id_like_to_meet}
    ]
    |> Enum.reject(fn {_, v} -> is_nil(v) or v == "" end)
    |> Enum.map(fn {label, v} -> "#{label}: #{String.slice(v, 0, 400)}" end)
    |> Enum.join("\n")
  end
end
