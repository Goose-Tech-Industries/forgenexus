defmodule ForgeNexus.AI.TagSuggestion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ai_tag_suggestions" do
    field :suggested_tags, :map, default: %{}
    field :suggested_prefix, :string
    field :content_type, :string
    field :confidence, :float
    field :was_applied, :boolean, default: false

    belongs_to :thread, ForgeNexus.Forums.Thread
    belongs_to :suggested_forum, ForgeNexus.Forums.Forum
    belongs_to :reviewed_by, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(tag_suggestion, attrs) do
    tag_suggestion
    |> cast(attrs, [
      :suggested_tags,
      :suggested_prefix,
      :content_type,
      :confidence,
      :was_applied,
      :thread_id,
      :suggested_forum_id,
      :reviewed_by_id
    ])
    |> validate_required([:thread_id])
    |> foreign_key_constraint(:thread_id)
    |> foreign_key_constraint(:suggested_forum_id)
    |> foreign_key_constraint(:reviewed_by_id)
  end
end
