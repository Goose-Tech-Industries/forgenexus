defmodule ForgeNexusWeb.AffiliateController do
  @moduledoc """
  Creator-facing affiliate gate. GET returns progress + targets; POST
  flips the subscription_enabled flag if all thresholds are met.
  """
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Affiliate

  # GET /api/creator/affiliate-progress
  def progress(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    json(conn, %{progress: Affiliate.progress(user)})
  end

  # POST /api/creator/enable-subscriptions
  def enable(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    case Affiliate.enable_subscriptions(user) do
      {:ok, updated} ->
        json(conn, %{
          ok: true,
          subscriptions_enabled_at: updated.subscriptions_enabled_at,
          progress: Affiliate.progress(updated)
        })

      {:error, :gate_not_met} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Affiliate gate not yet met", progress: Affiliate.progress(user)})

      {:error, cs} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Could not enable", details: inspect(cs)})
    end
  end
end
