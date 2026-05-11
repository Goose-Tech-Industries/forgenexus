defmodule ForgeNexus.Accounts.Theme do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @allowed_variable_keys ~w(
    bg_primary bg_secondary bg_tertiary bg_hover bg_card bg_input
    accent accent_glow accent_hover accent_dim
    text_primary text_secondary text_muted text_link text_link_hover
    border_color border_accent
  )

  schema "themes" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :is_default, :boolean, default: false
    field :is_active, :boolean, default: true
    field :position, :integer, default: 0
    field :variables, :map, default: %{}

    belongs_to :created_by, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(theme, attrs) do
    theme
    |> cast(attrs, [:name, :slug, :description, :is_default, :is_active, :position, :variables, :created_by_id])
    |> validate_required([:name, :slug])
    |> unique_constraint(:slug)
    |> validate_variables()
  end

  defp validate_variables(changeset) do
    case get_change(changeset, :variables) do
      nil ->
        changeset

      variables when is_map(variables) ->
        invalid_keys = Map.keys(variables) -- @allowed_variable_keys
        invalid_values = Enum.filter(variables, fn {_k, v} -> not valid_css_value?(v) end)

        changeset
        |> then(fn cs ->
          if invalid_keys != [],
            do: add_error(cs, :variables, "contains invalid keys: #{Enum.join(invalid_keys, ", ")}"),
            else: cs
        end)
        |> then(fn cs ->
          if invalid_values != [],
            do: add_error(cs, :variables, "contains invalid values"),
            else: cs
        end)

      _ ->
        add_error(changeset, :variables, "must be a map")
    end
  end

  defp valid_css_value?(value) when is_binary(value) do
    # Allow hex colors, rgba, CSS functions
    String.match?(value, ~r/^(#[0-9a-fA-F]{3,8}|rgba?\(.+\)|[a-zA-Z\-]+)$/)
  end

  defp valid_css_value?(_), do: false

  def allowed_variable_keys, do: @allowed_variable_keys
end
