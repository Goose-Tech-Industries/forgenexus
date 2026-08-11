defmodule ForgeNexus.Moderation.SoftBlockFlow do
  @moduledoc """
  Soft-block moderation flow — middle ground between delete-and-ban and do-nothing.
  Hides a post from public, notifies the author with a reason and edit deadline,
  auto-deletes if not edited within the window.
  """

  import Ecto.Query
  alias ForgeNexus.{Repo, Notifications}
  alias ForgeNexus.Moderation.SoftBlock
  alias ForgeNexus.Forums.Post

  @default_window_hours 24

  def create(attrs) do
    post = Repo.get!(Post, attrs[:post_id] || attrs["post_id"])
    window = attrs[:window_hours] || attrs["window_hours"] || @default_window_hours

    expires =
      DateTime.utc_now() |> DateTime.add(window * 3600, :second) |> DateTime.truncate(:second)

    sb_attrs = %{
      community_id: post.community_id,
      post_id: post.id,
      thread_id: post.thread_id,
      moderator_id: attrs[:moderator_id] || attrs["moderator_id"],
      author_id: post.user_id,
      reason: attrs[:reason] || attrs["reason"],
      rule_violated: attrs[:rule_violated] || attrs["rule_violated"],
      expires_at: expires,
      original_body: post.body,
      status: "pending"
    }

    case %SoftBlock{} |> SoftBlock.changeset(sb_attrs) |> Repo.insert() do
      {:ok, soft_block} ->
        post |> Ecto.Changeset.change(%{is_hidden: true}) |> Repo.update()

        Notifications.create_notification(%{
          user_id: post.user_id,
          actor_id: soft_block.moderator_id,
          type: "soft_block",
          title: "Your post has been flagged — edit within #{window} hours to keep it",
          url: "/threads/#{post.thread_id}#post-#{post.id}",
          reference_type: "soft_block",
          reference_id: soft_block.id
        })

        %{soft_block_id: soft_block.id, expires_at: expires}
        |> ForgeNexus.Workers.SoftBlockExpiryWorker.new(scheduled_at: expires)
        |> Oban.insert()

        {:ok, soft_block}

      error ->
        error
    end
  end

  def author_edit(soft_block_id, new_body) do
    case Repo.get(SoftBlock, soft_block_id) do
      nil ->
        {:error, :not_found}

      %SoftBlock{status: "pending"} = sb ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        if DateTime.compare(now, sb.expires_at) == :gt do
          {:error, :expired}
        else
          post = Repo.get!(Post, sb.post_id)
          post |> Ecto.Changeset.change(%{body: new_body, is_hidden: false}) |> Repo.update()
          sb |> SoftBlock.changeset(%{status: "edited", edited_at: now}) |> Repo.update()
          {:ok, :edited}
        end

      _ ->
        {:error, :already_resolved}
    end
  end

  def expire_unedited(soft_block_id) do
    case Repo.get(SoftBlock, soft_block_id) do
      %SoftBlock{status: "pending"} = sb ->
        post = Repo.get(Post, sb.post_id)
        if post, do: Repo.delete(post)
        sb |> SoftBlock.changeset(%{status: "expired"}) |> Repo.update()
        {:ok, :deleted}

      _ ->
        :ok
    end
  end

  def list_pending(community_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    SoftBlock
    |> where([s], s.community_id == ^community_id and s.status == "pending")
    |> order_by(asc: :expires_at)
    |> limit(^limit)
    |> preload([:moderator, :author])
    |> Repo.all()
  end
end
