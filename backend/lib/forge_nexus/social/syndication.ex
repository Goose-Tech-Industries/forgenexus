defmodule ForgeNexus.Social.Syndication do
  @moduledoc """
  Cross-community post syndication. Allows sharing a thread excerpt
  from one community to another, driving cross-community discovery.
  """

  import Ecto.Query
  alias ForgeNexus.{Repo, Forums}

  def syndicate_thread(source_thread_id, target_community_id, syndicated_by_id) do
    source = Forums.get_thread!(source_thread_id)

    excerpt = case Forums.list_posts(source.id, limit: 1) do
      [first_post | _] -> String.slice(first_post.body || "", 0, 500)
      [] -> ""
    end

    target_attrs = %{
      "title" => "[Shared] #{source.title}",
      "body" => "#{excerpt}\n\n---\n*Originally posted in another community. [View original →]*",
      "user_id" => syndicated_by_id,
      "forum_id" => get_default_forum(target_community_id)
    }

    case Forums.create_thread(target_attrs) do
      {:ok, target_thread} ->
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        Repo.insert_all("syndicated_posts", [
          %{
            id: Ecto.UUID.generate(),
            source_thread_id: source.id,
            source_community_id: source.community_id,
            target_community_id: target_community_id,
            target_thread_id: target_thread.id,
            syndicated_by_id: syndicated_by_id,
            status: "active",
            inserted_at: now,
            updated_at: now
          }
        ])

        {:ok, target_thread}

      error ->
        error
    end
  end

  defp get_default_forum(community_id) do
    from(f in "forums",
      where: f.community_id == ^community_id,
      order_by: [asc: :position],
      limit: 1,
      select: f.id
    )
    |> Repo.one()
  end
end
