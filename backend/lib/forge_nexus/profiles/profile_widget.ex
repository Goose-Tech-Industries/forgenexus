defmodule ForgeNexus.Profiles.ProfileWidget do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @widget_types ~w(
    about top_friends guestbook activity achievements clips
    stats heatmap recent_posts trophy_case now_playing
    custom_html embed mood_board favorites
  )

  schema "profile_widgets" do
    field :type, :string
    field :title, :string
    field :config, :map, default: %{}
    field :position, :integer, default: 0
    field :is_visible, :boolean, default: true

    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(widget, attrs) do
    widget
    |> cast(attrs, [:user_id, :type, :title, :config, :position, :is_visible])
    |> validate_required([:user_id, :type])
    |> validate_inclusion(:type, @widget_types)
  end

  def widget_types, do: @widget_types

  def default_widgets do
    [
      %{type: "about", title: "About Me", position: 0},
      %{type: "top_friends", title: "Top 8", position: 1},
      %{type: "guestbook", title: "Comments", position: 2},
      %{type: "activity", title: "Recent Activity", position: 3},
      %{type: "achievements", title: "Trophy Case", position: 4},
      %{type: "clips", title: "My Clips", position: 5}
    ]
  end
end
