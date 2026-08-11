defmodule ForgeNexus.Reputation do
  @moduledoc """
  Reputation system. Users earn/lose reputation from votes, trades, milestones, etc.
  Backed by `users.reputation` (rolling total) and `reputation_events` (audit log).
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo
  alias ForgeNexus.Reputation.Event

  @doc """
  Awards (or deducts) reputation to a user and logs an event atomically.

  ## Params
    * `user_id` — UUID of the target user
    * `amount`  — positive or negative integer
    * `opts`    — `:event_type`, `:source_type`, `:source_id`
  """
  def award(user_id, amount, opts \\ []) when is_integer(amount) do
    event_type = Keyword.get(opts, :event_type, "adjustment")
    source_type = Keyword.get(opts, :source_type)
    source_id = Keyword.get(opts, :source_id)

    Multi.new()
    |> Multi.run(:user, fn repo, _ ->
      case repo.get(User, user_id) do
        nil -> {:error, :user_not_found}
        user -> {:ok, user}
      end
    end)
    |> Multi.update(:updated_user, fn %{user: user} ->
      Ecto.Changeset.change(user, reputation: (user.reputation || 0) + amount)
    end)
    |> Multi.insert(:event, fn _ ->
      Event.changeset(%Event{}, %{
        user_id: user_id,
        event_type: event_type,
        points: amount,
        source_type: source_type,
        source_id: source_id
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{updated_user: user, event: event}} ->
        {:ok, %{user: user, event: event, new_total: user.reputation}}

      {:error, _step, reason, _} ->
        {:error, reason}
    end
  end

  @doc """
  Give reputation from one user to another. Emits one "given" event and one
  "received" event; only the recipient's total moves.

  Used by the no-code `reputation/give_reputation` node.
  """
  def give_reputation(%{from_user_id: _from, to_user_id: to, amount: amount} = params) do
    amount = to_integer(amount)
    type = Map.get(params, :type, "positive")

    delta =
      case type do
        "negative" -> -abs(amount)
        _ -> abs(amount)
      end

    case award(to, delta,
           event_type: "vote_#{type}",
           source_type: "user",
           source_id: params.from_user_id
         ) do
      {:ok, %{new_total: total}} -> {:ok, total}
      other -> other
    end
  end

  @doc """
  Returns a reputation summary for a user.

  Shape: `{:ok, %{total: int, positive_count: int, negative_count: int}}`
  """
  def get_reputation(nil), do: {:error, :missing_user_id}

  def get_reputation(user_id) do
    case Repo.get(User, user_id) do
      nil ->
        {:error, :user_not_found}

      user ->
        {pos, neg} =
          from(e in Event,
            where: e.user_id == ^user_id,
            select: {
              sum(fragment("CASE WHEN ? > 0 THEN 1 ELSE 0 END", e.points)),
              sum(fragment("CASE WHEN ? < 0 THEN 1 ELSE 0 END", e.points))
            }
          )
          |> Repo.one() || {0, 0}

        {:ok,
         %{
           total: user.reputation || 0,
           positive_count: pos || 0,
           negative_count: neg || 0
         }}
    end
  end

  @doc "Alias for `get_reputation/1` returning just the integer score."
  def current_score(user_id) do
    case get_reputation(user_id) do
      {:ok, %{total: total}} -> total
      _ -> 0
    end
  end

  @doc "Returns trade-specific reputation derived from `source_type = 'trade'` events."
  def get_trade_reputation(nil), do: {:error, :missing_user_id}

  def get_trade_reputation(user_id) do
    rows =
      from(e in Event,
        where: e.user_id == ^user_id and e.source_type == "trade",
        select: {
          sum(e.points),
          sum(fragment("CASE WHEN ? > 0 THEN 1 ELSE 0 END", e.points)),
          count(e.id)
        }
      )
      |> Repo.one()

    {score, successful, total} = rows || {0, 0, 0}

    {:ok,
     %{
       score: score || 0,
       successful_trades: successful || 0,
       total_trades: total || 0
     }}
  end

  @doc """
  Applies reputation decay to inactive users.

  Reduces reputation of users with no events in the last `inactive_days`
  by `decay_percent` percent. Returns `{:ok, %{users_affected:, total_decayed:}}`.
  """
  def apply_decay(%{decay_percent: pct, inactive_days: days} = _params) do
    cutoff = NaiveDateTime.utc_now() |> NaiveDateTime.add(-days * 86_400, :second)
    pct = to_float(pct)

    inactive_user_ids =
      from(u in User,
        left_join: e in Event,
        on: e.user_id == u.id and e.inserted_at > ^cutoff,
        where: is_nil(e.id) and u.reputation > 0,
        select: u.id
      )
      |> Repo.all()

    {count, total} =
      Enum.reduce(inactive_user_ids, {0, 0}, fn uid, {count, total} ->
        case Repo.get(User, uid) do
          nil ->
            {count, total}

          user ->
            current = user.reputation || 0
            decayed = round(current * pct / 100.0)

            if decayed > 0 do
              case award(uid, -decayed, event_type: "decay", source_type: "system") do
                {:ok, _} -> {count + 1, total + decayed}
                _ -> {count, total}
              end
            else
              {count, total}
            end
        end
      end)

    {:ok, %{users_affected: count, total_decayed: total}}
  end

  @doc "Recent reputation events for a user."
  def recent_events(user_id, limit \\ 20) do
    from(e in Event,
      where: e.user_id == ^user_id,
      order_by: [desc: e.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc "Top users by reputation."
  def top_users(limit \\ 10) do
    from(u in User,
      order_by: [desc: u.reputation],
      limit: ^limit,
      select: %{id: u.id, username: u.username, reputation: u.reputation}
    )
    |> Repo.all()
  end

  defp to_integer(n) when is_integer(n), do: n
  defp to_integer(n) when is_float(n), do: round(n)
  defp to_integer(n) when is_binary(n), do: String.to_integer(n)
  defp to_integer(_), do: 0

  defp to_float(n) when is_number(n), do: n * 1.0

  defp to_float(n) when is_binary(n) do
    case Float.parse(n) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  defp to_float(_), do: 0.0
end
