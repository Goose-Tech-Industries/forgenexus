defmodule ForgeNexus.Accounts.OAuthAccount do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "oauth_accounts" do
    field :provider, :string
    field :provider_uid, :string
    field :provider_email, :string
    field :provider_name, :string
    field :provider_avatar, :string
    field :access_token, :string
    field :refresh_token, :string

    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(oauth_account, attrs) do
    oauth_account
    |> cast(attrs, [
      :user_id,
      :provider,
      :provider_uid,
      :provider_email,
      :provider_name,
      :provider_avatar,
      :access_token,
      :refresh_token
    ])
    |> validate_required([:user_id, :provider, :provider_uid])
    |> unique_constraint([:provider, :provider_uid],
      name: :oauth_accounts_provider_provider_uid_index
    )
    |> unique_constraint([:provider, :user_id], name: :oauth_accounts_provider_user_id_index)
    |> foreign_key_constraint(:user_id)
  end
end
