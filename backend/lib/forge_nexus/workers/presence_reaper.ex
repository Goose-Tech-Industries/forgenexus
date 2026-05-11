defmodule ForgeNexus.Workers.PresenceReaper do
  @moduledoc """
  Marks users offline whose `last_seen_at` is older than the idle threshold.

  Without this, `is_online` is sticky — it gets set to `true` on login or
  socket connect but is never cleared on logout/disconnect, so the column
  drifts further from reality over time.
  """
  use Oban.Worker, queue: :default, max_attempts: 1

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Accounts.User

  # Users idle longer than this are considered offline.
  @idle_minutes 5

  @impl Oban.Worker
  def perform(_job) do
    threshold =
      DateTime.utc_now()
      |> DateTime.add(-@idle_minutes * 60, :second)
      |> DateTime.truncate(:second)

    {count, _} =
      from(u in User,
        where: u.is_online == true and (is_nil(u.last_seen_at) or u.last_seen_at < ^threshold)
      )
      |> Repo.update_all(set: [is_online: false])

    {:ok, %{marked_offline: count}}
  end
end
