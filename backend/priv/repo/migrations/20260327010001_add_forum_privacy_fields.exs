defmodule ForgeNexus.Repo.Migrations.AddForumPrivacyFields do
  use Ecto.Migration

  def change do
    alter table(:forums) do
      add :is_private, :boolean, default: false
      add :require_post_approval, :boolean, default: false
      add :allow_thread_ratings, :boolean, default: false
      add :min_post_length, :integer, default: 1
    end
  end
end
