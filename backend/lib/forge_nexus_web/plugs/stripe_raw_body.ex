defmodule ForgeNexusWeb.Plugs.StripeRawBody do
  @moduledoc """
  Captures the raw request body for Stripe webhook signature verification.
  Mount BEFORE Plug.Parsers — once Plug.Parsers reads the body it's gone.

  Used as a JSON body reader passed via `body_reader` in Plug.Parsers; we
  stash the raw chars in conn.assigns[:raw_body] for the controller to use.
  """
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts), do: conn

  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        {:ok, body, Plug.Conn.assign(conn, :raw_body, body)}

      {:more, body, conn} ->
        {:more, body, Plug.Conn.assign(conn, :raw_body, (conn.assigns[:raw_body] || "") <> body)}

      other ->
        other
    end
  end
end
