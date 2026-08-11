defmodule ForgeNexus.Moderation.ContentPolicy do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "content_policies" do
    field :name, :string
    field :description, :string
    field :is_active, :boolean, default: false
    field :ai_moderation_enabled, :boolean, default: false
    field :rules, :map, default: %{}
    field :escalation_overrides, :map, default: %{}

    belongs_to :forum, ForgeNexus.Forums.Forum
    belongs_to :category, ForgeNexus.Forums.Category

    timestamps()
  end

  @doc """
  Rules map structure:
  %{
    "blocked_words" => ["word1", "word2"],
    "blocked_patterns" => ["regex1", "regex2"],
    "max_links" => 5,
    "min_post_length" => 10,
    "require_approval_for_new_users" => false
  }

  Escalation overrides map structure (nil values inherit global defaults):
  %{
    "cooldown_threshold" => 3,
    "read_only_threshold" => 6,
    "temp_ban_threshold" => 10,
    "permanent_ban_threshold" => 15
  }
  """
  def changeset(policy, attrs) do
    policy
    |> cast(attrs, [
      :name,
      :description,
      :is_active,
      :ai_moderation_enabled,
      :rules,
      :escalation_overrides,
      :forum_id,
      :category_id
    ])
    |> validate_required([:name])
    |> foreign_key_constraint(:forum_id)
    |> foreign_key_constraint(:category_id)
  end
end
