defmodule ForgeNexus.Workers.LiveNotificationWorker do
  @moduledoc """
  Notifies followers when a user starts a voice room session.
  Triggered by RoomServer when the first person joins (room spins up).
  """
  use Oban.Worker, queue: :notifications, max_attempts: 2

  import Ecto.Query
  alias ForgeNexus.{Repo, Notifications}
  alias ForgeNexus.Accounts.UserFollow

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "room_id" => room_id, "room_name" => room_name}}) do
    follower_ids =
      UserFollow
      |> where([f], f.followed_id == ^user_id)
      |> select([f], f.follower_id)
      |> Repo.all()

    Enum.each(follower_ids, fn follower_id ->
      # Schema only knows type/title/body/url/metadata/user_id/actor_id —
      # room reference goes in metadata so it survives the cast.
      case Notifications.create_notification(%{
        user_id: follower_id,
        actor_id: user_id,
        type: "went_live",
        title: "is now live in #{room_name}",
        url: "/voice/#{room_id}",
        metadata: %{room_id: room_id, room_name: room_name, kind: "voice_room"}
      }) do
        {:ok, notif} ->
          # Use the standard broadcast so the user channel + toaster pick it up.
          actor = ForgeNexus.Repo.get(ForgeNexus.Accounts.User, user_id)
          Notifications.broadcast_notification(notif, actor)

        _ ->
          :ok
      end
    end)

    :ok
  end

  def perform(%Oban.Job{args: args}) do
    require Logger
    Logger.warning("[LiveNotification] missing required args, got: #{inspect(args)}")
    {:error, :missing_args}
  end
end
