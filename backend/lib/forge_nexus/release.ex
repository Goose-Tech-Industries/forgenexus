defmodule ForgeNexus.Release do
  @moduledoc """
  Release tasks for running migrations and seeds in production.

  Usage (from deploy script or Docker exec):
    bin/forge_nexus eval "ForgeNexus.Release.migrate()"
    bin/forge_nexus eval "ForgeNexus.Release.seed()"
    bin/forge_nexus eval "ForgeNexus.Release.rollback(ForgeNexus.Repo, 20260407010000)"
  """

  @app :forge_nexus

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          seed_file = Application.app_dir(@app, "priv/repo/seeds.exs")

          if File.exists?(seed_file) do
            Code.eval_file(seed_file)
          end
        end)
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
