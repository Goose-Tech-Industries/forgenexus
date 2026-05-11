defmodule ForgeNexus.Repo.Migrations.AttachableIdNullableForInline do
  use Ecto.Migration

  def up do
    # Inline uploads (e.g. images dropped into a post body) don't yet know
    # which entity they'll be attached to. The original migration required
    # attachable_id to be set, which crashed every inline POST /api/uploads.
    alter table(:attachments) do
      modify :attachable_id, :uuid, null: true
    end
  end

  def down do
    alter table(:attachments) do
      modify :attachable_id, :uuid, null: false
    end
  end
end
