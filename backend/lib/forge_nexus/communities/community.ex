defmodule ForgeNexus.Communities.Community do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # v3 revenue ladder. `free` is unsubbed; `forum`/`community`/`creator`/`platform`/`enterprise` are paid.
  # `houses` is the multi-creator collective tier ($149 base + $25/additional creator).
  # Old names (`starter`, `social`) kept here for migration compatibility — old communities still
  # validate. Map them via the migration when you cut over.
  @plans ~w(free forum community creator platform enterprise houses starter social)
  @plan_statuses ~w(inactive active trialing past_due canceled unpaid)
  @default_features %{
    "forums" => true,
    "profiles" => true,
    "chat" => false,
    "voice" => false,
    "streaming" => false,
    "economy" => false,
    "social_feed" => false,
    "automation" => false,
    "marketplace" => false,
    "white_label" => false
  }

  schema "communities" do
    field :name, :string
    field :slug, :string
    field :subdomain, :string
    field :custom_domain, :string
    field :description, :string
    field :logo_url, :string
    field :banner_url, :string
    field :plan, :string, default: "free"
    field :plan_status, :string, default: "inactive"
    field :feature_flags, :map, default: @default_features
    field :settings, :map, default: %{}
    field :is_active, :boolean, default: true
    field :member_count, :integer, default: 0
    field :monthly_fee_cents, :integer, default: 0
    field :is_discoverable, :boolean, default: true
    field :tags, {:array, :string}, default: []
    field :category, :string
    field :activity_score, :float, default: 0.0
    # Stripe billing
    field :stripe_customer_id, :string
    field :current_period_end, :utc_datetime
    field :cancel_at, :utc_datetime

    belongs_to :owner, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(community, attrs) do
    community
    |> cast(attrs, [:name, :slug, :subdomain, :custom_domain, :description,
                     :logo_url, :banner_url, :plan, :plan_status, :feature_flags, :settings,
                     :is_active, :owner_id, :member_count, :monthly_fee_cents,
                     :stripe_customer_id, :current_period_end, :cancel_at])
    |> validate_required([:name, :slug])
    |> validate_inclusion(:plan, @plans)
    |> validate_inclusion(:plan_status, @plan_statuses)
    |> validate_format(:slug, ~r/^[a-z0-9\-]+$/)
    |> validate_length(:slug, min: 3, max: 63)
    |> validate_format(:subdomain, ~r/^[a-z0-9\-]+$/)
    |> unique_constraint(:slug)
    |> unique_constraint(:subdomain)
    |> unique_constraint(:custom_domain)
  end

  def plans, do: @plans
  def default_features, do: @default_features

  def has_feature?(%__MODULE__{feature_flags: flags}, feature) when is_binary(feature) do
    Map.get(flags || @default_features, feature, false)
  end

  def plan_features do
    %{
      "free" => %{"forums" => true, "profiles" => true},
      "starter" => %{"forums" => true, "profiles" => true, "chat" => true, "social_feed" => true},
      "social" => %{"forums" => true, "profiles" => true, "chat" => true, "voice" => true, "social_feed" => true},
      "creator" => %{"forums" => true, "profiles" => true, "chat" => true, "voice" => true, "streaming" => true, "economy" => true, "social_feed" => true},
      "platform" => %{"forums" => true, "profiles" => true, "chat" => true, "voice" => true, "streaming" => true, "economy" => true, "social_feed" => true, "automation" => true, "marketplace" => true},
      "enterprise" => %{"forums" => true, "profiles" => true, "chat" => true, "voice" => true, "streaming" => true, "economy" => true, "social_feed" => true, "automation" => true, "marketplace" => true, "white_label" => true}
    }
  end
end
