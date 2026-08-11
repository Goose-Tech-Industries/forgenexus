defmodule ForgeNexusWeb.AdminAchievementController do
  @moduledoc "Admin CRUD for achievements + manual grant/revoke to users."
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Achievements

  def index(conn, _params) do
    achievements = Achievements.list_all_achievements()

    result =
      Enum.map(achievements, fn a ->
        a |> achievement_json() |> Map.put(:unlock_count, Achievements.unlock_count(a.id))
      end)

    conn |> json(%{achievements: result})
  end

  def show(conn, %{"id" => id}) do
    case Achievements.get_achievement(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Achievement not found"})

      a ->
        conn
        |> json(%{
          achievement:
            a |> achievement_json() |> Map.put(:unlock_count, Achievements.unlock_count(a.id))
        })
    end
  end

  def create(conn, %{"achievement" => attrs}) do
    attrs = normalize_attrs(attrs)

    case Achievements.create_achievement(attrs) do
      {:ok, a} ->
        conn |> put_status(:created) |> json(%{achievement: achievement_json(a)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: format_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    attrs = params |> Map.get("achievement", params) |> normalize_attrs()

    case Achievements.update_achievement(id, attrs) do
      {:ok, a} ->
        conn |> json(%{achievement: achievement_json(a)})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Achievement not found"})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: format_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Achievements.delete_achievement(id) do
      {:ok, _} ->
        conn |> json(%{ok: true})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Achievement not found"})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete"})
    end
  end

  def grant(conn, %{"id" => achievement_id, "user_id" => user_id}) do
    case Achievements.unlock_achievement(user_id, achievement_id) do
      {:ok, _} ->
        conn |> json(%{ok: true})

      {:error, :already_unlocked} ->
        conn |> put_status(:conflict) |> json(%{error: "User already has this achievement"})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
    end
  end

  def revoke(conn, %{"id" => achievement_id, "user_id" => user_id}) do
    case Achievements.revoke_user_achievement(user_id, achievement_id) do
      {:ok, _} ->
        conn |> json(%{ok: true})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "User does not have this achievement"})
    end
  end

  @doc "Bulk grant or revoke an achievement for many users. Resolves usernames or UUIDs."
  def bulk(conn, %{"id" => achievement_id, "action" => action, "targets" => targets})
      when action in ["grant", "revoke"] and is_list(targets) do
    results =
      Enum.map(targets, fn target ->
        target = String.trim(to_string(target))

        case resolve_user_id(target) do
          nil ->
            %{target: target, status: "not_found"}

          user_id ->
            case do_bulk_action(action, user_id, achievement_id) do
              {:ok, _} ->
                %{target: target, user_id: user_id, status: "ok"}

              {:error, :already_unlocked} ->
                %{target: target, user_id: user_id, status: "skipped", reason: "already_unlocked"}

              {:error, :not_found} ->
                %{target: target, user_id: user_id, status: "skipped", reason: "not_unlocked"}

              {:error, reason} ->
                %{target: target, user_id: user_id, status: "error", reason: inspect(reason)}
            end
        end
      end)

    summary = %{
      total: length(results),
      ok: Enum.count(results, &(&1.status == "ok")),
      skipped: Enum.count(results, &(&1.status == "skipped")),
      not_found: Enum.count(results, &(&1.status == "not_found")),
      errors: Enum.count(results, &(&1.status == "error"))
    }

    conn |> json(%{results: results, summary: summary})
  end

  def bulk(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Invalid bulk request. Expected action (grant/revoke) and targets array."})
  end

  defp do_bulk_action("grant", user_id, achievement_id),
    do: Achievements.unlock_achievement(user_id, achievement_id)

  defp do_bulk_action("revoke", user_id, achievement_id),
    do: Achievements.revoke_user_achievement(user_id, achievement_id)

  defp resolve_user_id(target) when is_binary(target) do
    cond do
      uuid?(target) ->
        case ForgeNexus.Accounts.get_user(target) do
          nil -> nil
          user -> user.id
        end

      true ->
        case ForgeNexus.Accounts.get_user_by_username(target) do
          nil -> nil
          user -> user.id
        end
    end
  end

  defp uuid?(str) when is_binary(str) do
    Regex.match?(~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i, str)
  end

  defp achievement_json(a) do
    %{
      id: a.id,
      name: a.name,
      slug: a.slug,
      description: a.description,
      icon: a.icon,
      category: a.category,
      points: a.points,
      criteria: a.criteria,
      is_hidden: a.is_hidden,
      is_active: a.is_active,
      sort_order: a.sort_order,
      inserted_at: a.inserted_at,
      updated_at: a.updated_at
    }
  end

  defp normalize_attrs(attrs) when is_map(attrs) do
    attrs
    |> Map.new(fn {k, v} -> {to_string(k), v} end)
    |> maybe_slugify()
  end

  defp maybe_slugify(%{"slug" => slug} = attrs) when is_binary(slug) and slug != "", do: attrs

  defp maybe_slugify(%{"name" => name} = attrs) when is_binary(name) and name != "" do
    slug =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")

    Map.put(attrs, "slug", slug)
  end

  defp maybe_slugify(attrs), do: attrs

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
