defmodule ForgeNexus.AI.Provider do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ai_providers" do
    field :name, :string
    field :display_name, :string
    field :api_key_encrypted, :binary
    field :base_url, :string
    field :default_model, :string
    field :is_active, :boolean, default: false
    field :priority, :integer, default: 0
    field :max_tokens_per_request, :integer, default: 4096
    field :config, :map, default: %{}

    timestamps()
  end

  def changeset(provider, attrs) do
    provider
    |> cast(attrs, [
      :name,
      :display_name,
      :api_key_encrypted,
      :base_url,
      :default_model,
      :is_active,
      :priority,
      :max_tokens_per_request,
      :config
    ])
    |> validate_required([:name])
    |> validate_inclusion(:name, ["openai", "anthropic", "ollama", "custom"])
    |> unique_constraint(:name)
  end
end
