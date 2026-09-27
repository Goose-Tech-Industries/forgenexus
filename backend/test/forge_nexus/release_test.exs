defmodule ForgeNexus.ReleaseTest do
  use ExUnit.Case, async: false

  alias ForgeNexus.Release

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(ForgeNexus.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(ForgeNexus.Repo, {:shared, self()})
    :ok
  end

  test "migrate/0 runs successfully" do
    assert [{:ok, [], _}] = Release.migrate()
  end

  test "rollback/2 runs successfully with future target" do
    assert {:ok, [], _} = Release.rollback(ForgeNexus.Repo, 99_999_999_999_999)
  end

  test "seed/0 runs successfully" do
    assert [{:ok, _, _}] = Release.seed()
  end
end
