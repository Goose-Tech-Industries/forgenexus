defmodule ForgeNexusWeb.ForumsChannel do
  @moduledoc """
  Read-only channel for the forum index. Subscribers receive `forum_updated`
  events whenever a thread/post is created in any forum, so the homepage and
  the `/forums` index can refresh counters without a hard reload.

  Topic: `forums:index`
  """
  use ForgeNexusWeb, :channel

  @impl true
  def join("forums:index", _params, socket) do
    {:ok, socket}
  end

  def join(_topic, _params, _socket), do: {:error, %{reason: "unknown topic"}}
end
