defmodule ForgeNexus.Federation.ActivityPub.Object do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ap_objects" do
    field :uri, :string
    field :type, :string
    field :data, :map
    field :is_local, :boolean, default: false

    belongs_to :local_post, ForgeNexus.Forums.Post
    belongs_to :local_thread, ForgeNexus.Forums.Thread
    belongs_to :actor, ForgeNexus.Federation.ActivityPub.Actor

    timestamps()
  end

  def changeset(object, attrs) do
    object
    |> cast(attrs, [:uri, :type, :data, :is_local, :local_post_id, :local_thread_id, :actor_id])
    |> validate_required([:uri, :type, :actor_id])
    |> unique_constraint(:uri)
    |> foreign_key_constraint(:local_post_id)
    |> foreign_key_constraint(:local_thread_id)
    |> foreign_key_constraint(:actor_id)
  end
end
