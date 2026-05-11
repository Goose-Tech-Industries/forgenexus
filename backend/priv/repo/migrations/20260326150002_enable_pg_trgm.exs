defmodule ForgeNexus.Repo.Migrations.EnablePgTrgm do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
    execute "CREATE INDEX IF NOT EXISTS threads_title_trgm_idx ON threads USING gin (title gin_trgm_ops)"
  end

  def down do
    execute "DROP INDEX IF EXISTS threads_title_trgm_idx"
  end
end
