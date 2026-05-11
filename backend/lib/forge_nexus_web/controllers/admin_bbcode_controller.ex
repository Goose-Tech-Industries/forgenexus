defmodule ForgeNexusWeb.AdminBBCodeController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Forums

  def index(conn, _params) do
    bbcodes = Forums.list_custom_bbcodes()
    conn |> json(%{bbcodes: Enum.map(bbcodes, &bbcode_json/1)})
  end

  def create(conn, %{"bbcode" => attrs}) do
    case Forums.create_custom_bbcode(attrs) do
      {:ok, bbcode} ->
        conn |> put_status(:created) |> json(%{bbcode: bbcode_json(bbcode)})
      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: format_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    attrs = Map.get(params, "bbcode", params)
    case Forums.update_custom_bbcode(id, attrs) do
      {:ok, bbcode} ->
        conn |> json(%{bbcode: bbcode_json(bbcode)})
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "BBCode not found"})
      {:error, %Ecto.Changeset{} = changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: format_errors(changeset)})
      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Forums.delete_custom_bbcode(id) do
      {:ok, _} -> conn |> json(%{ok: true})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "BBCode not found"})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete"})
    end
  end

  defp bbcode_json(bbcode) do
    %{
      id: bbcode.id,
      tag_name: bbcode.tag_name,
      replacement_html: bbcode.replacement_html,
      description: bbcode.description,
      is_active: bbcode.is_active,
      inserted_at: bbcode.inserted_at,
      updated_at: bbcode.updated_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
