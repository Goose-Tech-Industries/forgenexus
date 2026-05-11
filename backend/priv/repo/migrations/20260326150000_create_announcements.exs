defmodule ForgeNexus.Repo.Migrations.CreateAnnouncements do
  use Ecto.Migration

  def change do
    create table(:announcements, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :body, :text, null: false
      add :body_html, :text
      add :priority, :integer, default: 0
      add :display_location, :string, default: "banner"
      add :forum_id, references(:forums, type: :binary_id, on_delete: :delete_all)
      add :target_group_ids, {:array, :binary_id}, default: []
      add :is_dismissible, :boolean, default: true
      add :is_active, :boolean, default: true
      add :starts_at, :utc_datetime
      add :ends_at, :utc_datetime
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:announcements, [:is_active])
    create index(:announcements, [:starts_at, :ends_at])
    create index(:announcements, [:display_location])
  end
end
