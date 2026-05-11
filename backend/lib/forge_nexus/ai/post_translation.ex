defmodule ForgeNexus.AI.PostTranslation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "post_translations" do
    field :source_language, :string
    field :target_language, :string
    field :translated_body, :string

    belongs_to :post, ForgeNexus.Forums.Post
    belongs_to :provider, ForgeNexus.AI.Provider

    timestamps()
  end

  def changeset(post_translation, attrs) do
    post_translation
    |> cast(attrs, [:source_language, :target_language, :translated_body, :post_id, :provider_id])
    |> validate_required([:source_language, :target_language, :translated_body, :post_id])
    |> foreign_key_constraint(:post_id)
    |> foreign_key_constraint(:provider_id)
  end
end
