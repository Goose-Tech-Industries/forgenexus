defmodule ForgeNexus.Workers.SoftBlockExpiryWorker do
  use Oban.Worker, queue: :default, max_attempts: 2

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"soft_block_id" => id}}) do
    ForgeNexus.Moderation.SoftBlockFlow.expire_unedited(id)
    :ok
  end

  def perform(%Oban.Job{args: args}) do
    require Logger
    Logger.warning("[SoftBlockExpiry] missing required args, got: #{inspect(args)}")
    {:error, :missing_args}
  end
end
