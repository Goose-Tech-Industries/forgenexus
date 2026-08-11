defmodule ForgeNexusWeb.EconomyController do
  use ForgeNexusWeb, :controller
  alias ForgeNexus.Economy

  def balance(conn, _params) do
    case Guardian.Plug.current_resource(conn) do
      nil -> conn |> put_status(:unauthorized) |> json(%{error: "unauthorized"})
      user -> conn |> json(%{points: Economy.get_points(user.id)})
    end
  end

  def history(conn, _params) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn |> put_status(:unauthorized) |> json(%{error: "unauthorized"})

      user ->
        do_history(conn, user)
    end
  end

  defp do_history(conn, user) do
    txs = Economy.transaction_history(user.id)

    conn
    |> json(%{
      transactions:
        Enum.map(txs, fn t ->
          %{
            id: t.id,
            amount: t.amount,
            balance_after: t.balance_after,
            reason: t.reason,
            description: t.description,
            inserted_at: t.inserted_at
          }
        end)
    })
  end

  def leaderboard(conn, _params) do
    users = Economy.leaderboard()
    conn |> json(%{leaderboard: users})
  end

  # Admin
  def config(conn, _params) do
    conn |> json(%{config: Economy.list_config()})
  end

  def update_config(conn, %{"action" => action, "points" => points} = params) do
    is_active = Map.get(params, "is_active", true)
    Economy.update_config(action, points, is_active)
    conn |> json(%{ok: true})
  end

  def admin_grant(conn, %{"user_id" => user_id, "amount" => amount} = params) do
    amount = if is_binary(amount), do: safe_to_integer(amount, 0), else: amount

    if is_integer(amount) and amount > 0 do
      Economy.award_points(user_id, "admin_grant",
        amount: amount,
        description: params["description"] || "Admin grant"
      )

      conn |> json(%{ok: true})
    else
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{error: "Amount must be a positive integer"})
    end
  end

  def tip(conn, %{"to_user_id" => to_id, "amount" => amount} = params) do
    user = Guardian.Plug.current_resource(conn)
    amount = safe_to_integer(amount, 0)
    message = Map.get(params, "message")

    cond do
      amount <= 0 ->
        conn |> put_status(:bad_request) |> json(%{error: "Amount must be positive"})

      user.id == to_id ->
        conn |> put_status(:bad_request) |> json(%{error: "Cannot tip yourself"})

      Economy.get_points(user.id) < amount ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Insufficient points"})

      true ->
        Economy.deduct_points(user.id, amount, "tip_sent",
          description: "Tip to user #{to_id}" <> if(message, do: ": #{message}", else: "")
        )

        Economy.award_points(to_id, "tip_received",
          amount: amount,
          description: "Tip from #{user.username}" <> if(message, do: ": #{message}", else: "")
        )

        ForgeNexusWeb.Endpoint.broadcast("user:#{to_id}", "tip_received", %{
          from_id: user.id,
          from_username: user.username,
          amount: amount,
          message: message
        })

        conn |> json(%{ok: true, new_balance: Economy.get_points(user.id)})
    end
  end

  defp safe_to_integer(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> default
    end
  end

  defp safe_to_integer(val, _default) when is_integer(val), do: val
  defp safe_to_integer(_, default), do: default
end
