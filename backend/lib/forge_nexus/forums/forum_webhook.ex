defmodule ForgeNexus.Forums.ForumWebhook do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "forum_webhooks" do
    field :name, :string
    field :url, :string
    field :secret, :string
    field :events, {:array, :string}, default: []
    field :is_active, :boolean, default: true
    field :last_triggered_at, :utc_datetime
    field :failure_count, :integer, default: 0

    belongs_to :created_by, ForgeNexus.Accounts.User

    timestamps()
  end

  @valid_events ~w(
    forum.thread.created
    forum.post.created
    forum.user.joined
    forum.thread.locked
    forum.thread.unlocked
    forum.thread.pinned
    forum.thread.unpinned
  )

  def valid_events, do: @valid_events

  def changeset(webhook, attrs) do
    webhook
    |> cast(attrs, [
      :name,
      :url,
      :secret,
      :events,
      :is_active,
      :created_by_id,
      :last_triggered_at,
      :failure_count
    ])
    |> validate_required([:name, :url, :events])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_url()
    |> validate_events()
    |> put_secret()
  end

  defp validate_url(changeset) do
    case get_field(changeset, :url) do
      nil ->
        changeset

      url ->
        if String.starts_with?(url, "https://") or String.starts_with?(url, "http://") do
          changeset
        else
          add_error(changeset, :url, "must start with http:// or https://")
        end
    end
  end

  defp validate_events(changeset) do
    case get_field(changeset, :events) do
      nil ->
        changeset

      events ->
        invalid = Enum.reject(events, &(&1 in @valid_events))

        if invalid == [] do
          changeset
        else
          add_error(changeset, :events, "contains invalid events: #{Enum.join(invalid, ", ")}")
        end
    end
  end

  defp put_secret(changeset) do
    if get_field(changeset, :secret) do
      changeset
    else
      put_change(changeset, :secret, generate_secret())
    end
  end

  defp generate_secret do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
