defmodule ForgeNexus.Themes do
  @moduledoc """
  The Themes context — manage site-wide theme packs.
  """
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Accounts.Theme

  def list_active_themes do
    Theme
    |> where([t], t.is_active == true)
    |> order_by(:position)
    |> Repo.all()
  end

  def get_theme!(id), do: Repo.get!(Theme, id)

  def get_default_theme do
    Theme
    |> where([t], t.is_default == true and t.is_active == true)
    |> limit(1)
    |> Repo.one()
  end

  def create_theme(attrs) do
    %Theme{}
    |> Theme.changeset(attrs)
    |> Repo.insert()
  end

  def update_theme(%Theme{} = theme, attrs) do
    theme
    |> Theme.changeset(attrs)
    |> Repo.update()
  end

  def delete_theme(%Theme{} = theme) do
    Repo.delete(theme)
  end
end
