defmodule ForgeNexus.Social.UserPremium do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @plans ~w(basic plus pro)
  @default_features %{
    "animated_avatar" => false,
    "profile_song" => false,
    "profile_css" => false,
    "verified_badge" => false,
    "extra_storage_mb" => 0,
    "custom_emote_slots" => 0,
    "colored_username" => false,
    "gif_profile_banner" => false,
    "priority_support" => false,
    "early_access" => false
  }

  @plan_features %{
    "basic" => %{
      "animated_avatar" => true,
      "profile_song" => true,
      "colored_username" => true,
      "custom_emote_slots" => 5,
      "extra_storage_mb" => 500
    },
    "plus" => %{
      "animated_avatar" => true,
      "profile_song" => true,
      "profile_css" => true,
      "colored_username" => true,
      "verified_badge" => true,
      "custom_emote_slots" => 25,
      "extra_storage_mb" => 2000,
      "gif_profile_banner" => true
    },
    "pro" => %{
      "animated_avatar" => true,
      "profile_song" => true,
      "profile_css" => true,
      "colored_username" => true,
      "verified_badge" => true,
      "custom_emote_slots" => 100,
      "extra_storage_mb" => 10000,
      "gif_profile_banner" => true,
      "priority_support" => true,
      "early_access" => true
    }
  }

  schema "user_premiums" do
    field :plan, :string, default: "basic"
    field :status, :string, default: "active"
    field :started_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :stripe_subscription_id, :string
    field :features, :map, default: @default_features

    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(premium, attrs) do
    premium
    |> cast(attrs, [
      :user_id,
      :plan,
      :status,
      :started_at,
      :expires_at,
      :stripe_subscription_id,
      :features
    ])
    |> validate_required([:user_id, :plan])
    |> validate_inclusion(:plan, @plans)
    |> validate_inclusion(:status, ~w(active cancelled expired))
    |> unique_constraint(:user_id)
  end

  def plans, do: @plans
  def plan_features, do: @plan_features
  def features_for_plan(plan), do: Map.get(@plan_features, plan, @default_features)
end
