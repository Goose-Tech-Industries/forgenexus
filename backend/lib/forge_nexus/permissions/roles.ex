defmodule ForgeNexus.Permissions.Roles do
  @moduledoc """
  Role hierarchy for permissions. Each role inherits everything from the role
  below it and adds its own grants on top. This keeps the default permission
  matrix declarative — adding a new permission to `ForgeNexus.Permissions.Registry`
  only requires deciding which role should first gain it.

  Roles (ordered lowest to highest privilege):

    :guest → :member → :trusted → :moderator → :admin
  """

  alias ForgeNexus.Permissions.Registry

  @roles ~w(guest member trusted moderator admin)a

  @doc "Ordered list of all role atoms (lowest to highest)."
  def roles, do: @roles

  @doc """
  Compute the full permission map for a role.

  Starts from an all-`false` map, then for every role up to and including the
  requested role, applies that role's grant set.
  """
  def compute(role) when role in @roles do
    base = for key <- Registry.all_permissions(), into: %{}, do: {key, false}

    @roles
    |> Enum.take_while(fn r -> true_unless_past(r, role) end)
    |> Enum.reduce(base, fn r, acc -> Map.merge(acc, grants_for(r)) end)
  end

  def compute(_), do: compute(:member)

  defp true_unless_past(current, target) do
    Enum.find_index(@roles, &(&1 == current)) <= Enum.find_index(@roles, &(&1 == target))
  end

  # --- Per-role grant sets (additive over previous roles) ---

  defp grants_for(:guest) do
    %{}
  end

  defp grants_for(:member) do
    # Members get the Registry-declared defaults.
    Registry.default_permissions()
  end

  defp grants_for(:trusted) do
    %{
      delete_own_post: true,
      view_private_threads: true,
      change_username: true
    }
  end

  defp grants_for(:moderator) do
    %{
      edit_any_post: true,
      delete_any_post: true,
      lock_thread: true,
      pin_thread: true,
      move_thread: true,
      merge_thread: true,
      warn_user: true,
      ban_user: true,
      view_reports: true,
      view_ip: true,
      view_private_threads: true
    }
  end

  defp grants_for(:admin) do
    # Admins get every permission turned on, regardless of Registry defaults.
    for key <- Registry.all_permissions(), into: %{}, do: {key, true}
  end
end
