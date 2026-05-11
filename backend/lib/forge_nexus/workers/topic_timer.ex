defmodule ForgeNexus.Workers.TopicTimer do
  @moduledoc "Oban worker that auto-closes and auto-deletes threads based on timers."
  use Oban.Worker, queue: :default, max_attempts: 3

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Forums.Thread

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    now = DateTime.utc_now()

    # Auto-close threads
    from(t in Thread,
      where: not is_nil(t.auto_close_at) and t.auto_close_at <= ^now and t.is_locked == false
    )
    |> Repo.update_all(set: [is_locked: true, auto_close_at: nil])

    # Auto-delete (hide) threads
    from(t in Thread,
      where: not is_nil(t.auto_delete_at) and t.auto_delete_at <= ^now and t.is_hidden == false
    )
    |> Repo.update_all(set: [is_hidden: true, auto_delete_at: nil])

    :ok
  end
end
