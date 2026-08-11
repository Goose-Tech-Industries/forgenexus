defmodule ForgeNexus.Forums.CustomBBCode do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "custom_bbcodes" do
    field :tag_name, :string
    field :replacement_html, :string
    field :description, :string, default: ""
    field :is_active, :boolean, default: true

    timestamps()
  end

  def changeset(bbcode, attrs) do
    bbcode
    |> cast(attrs, [:tag_name, :replacement_html, :description, :is_active])
    |> validate_required([:tag_name, :replacement_html])
    |> validate_length(:tag_name, min: 1, max: 50)
    |> validate_format(:tag_name, ~r/^[a-zA-Z][a-zA-Z0-9_-]*$/,
      message: "must start with a letter and contain only letters, numbers, hyphens, underscores"
    )
    |> unique_constraint(:tag_name)
    |> validate_no_script_tags()
  end

  defp validate_no_script_tags(changeset) do
    case get_change(changeset, :replacement_html) do
      nil ->
        changeset

      html ->
        if String.match?(html, ~r/<script/i) do
          add_error(changeset, :replacement_html, "must not contain script tags")
        else
          changeset
        end
    end
  end
end
