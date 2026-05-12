defmodule ForgeNexus.Repo.Migrations.AddSubscriptionsEnabledAt do
  use Ecto.Migration

  def change do
    # When set, the creator has passed the affiliate gate and may receive
    # paid subscriptions. Nullable timestamp keeps an audit trail of when
    # the gate was crossed; boolean is derived by `not is_nil(...)`.
    alter table(:users) do
      add :subscriptions_enabled_at, :utc_datetime
    end
  end
end
