defmodule ForgeNexusWeb.AdminPromotionController do
  use ForgeNexusWeb, :controller
  alias ForgeNexus.Accounts

  def index(conn, _params) do
    rules = Accounts.list_all_promotion_rules()
    conn |> json(%{rules: Enum.map(rules, &rule_json/1)})
  end

  def create(conn, params) do
    case Accounts.create_promotion_rule(params) do
      {:ok, rule} -> conn |> put_status(:created) |> json(%{rule: rule_json(ForgeNexus.Repo.preload(rule, [:from_group, :to_group]))})
      {:error, cs} -> conn |> put_status(:unprocessable_entity) |> json(%{error: format_errors(cs)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Accounts.update_promotion_rule(id, params) do
      {:ok, rule} -> conn |> json(%{rule: rule_json(rule)})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Accounts.delete_promotion_rule(id) do
      {:ok, _} -> conn |> json(%{ok: true})
      _ -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
    end
  end

  def evaluate_all(conn, _params) do
    summary = Accounts.evaluate_promotion_rules()
    conn |> json(%{ok: true, summary: summary})
  end

  defp rule_json(r) do
    %{id: r.id, name: r.name, criteria: r.criteria, is_active: r.is_active, position: r.position,
      from_group: r.from_group && %{id: r.from_group.id, name: r.from_group.name},
      to_group: r.to_group && %{id: r.to_group.id, name: r.to_group.name}}
  end

  defp format_errors(cs), do: Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)
end
