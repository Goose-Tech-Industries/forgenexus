defmodule ForgeNexusWeb.ForgeCodeController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Profiles.{ForgeCodes, ForgeCodeSchema}

  # GET /api/forge-codes/gallery?tab=featured|trending|new&vibe=neon&limit=24&offset=0
  def gallery(conn, params) do
    tab = Map.get(params, "tab", "featured")
    vibe = Map.get(params, "vibe")
    limit = parse_int(Map.get(params, "limit"), 24) |> min(50)
    offset = parse_int(Map.get(params, "offset"), 0)

    codes = ForgeCodes.list_gallery(tab: tab, vibe: vibe, limit: limit, offset: offset)

    conn |> json(%{codes: Enum.map(codes, &code_json/1), tab: tab, vibe: vibe})
  end

  # GET /api/forge-codes/mine
  def mine(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    case user do
      nil ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})

      user ->
        codes = ForgeCodes.list_mine(user)
        conn |> json(%{codes: Enum.map(codes, &code_json/1)})
    end
  end

  # GET /api/forge-codes/:code
  def show(conn, %{"code" => code}) do
    case ForgeCodes.get_by_code(code) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Forge Code not found"})
      fc -> conn |> json(%{code: code_json(fc)})
    end
  end

  # GET /api/forge-codes/vocabulary  (fonts, vibes, widgets, emojis, platforms)
  def vocabulary(conn, _params) do
    conn
    |> json(%{
      fonts: ForgeCodeSchema.font_allowlist(),
      vibes: ForgeNexus.Accounts.User.vibe_tags(),
      gradient_directions: ForgeCodeSchema.gradient_directions(),
      widget_slots: ForgeCodeSchema.widget_slots(),
      social_platforms: ForgeNexus.Accounts.User.allowed_social_platforms(),
      visibility_levels: ForgeNexus.Accounts.User.visibility_levels(),
      endorsement_emojis: ForgeNexus.Profiles.ProfileEndorsement.allowed_emoji()
    })
  end

  # POST /api/forge-codes  — save current profile as a code
  def create(conn, %{"name" => name} = params) do
    user = Guardian.Plug.current_resource(conn)

    attrs = %{
      "name" => name,
      "description" => Map.get(params, "description"),
      "vibe_tag" => Map.get(params, "vibe_tag"),
      "is_public" => Map.get(params, "is_public", true),
      "is_remixable" => Map.get(params, "is_remixable", true),
      "preview_image_url" => Map.get(params, "preview_image_url")
    }

    case ForgeCodes.save_from_user(user, attrs) do
      {:ok, fc} ->
        conn |> put_status(:created) |> json(%{code: code_json(fc)})

      {:error, :limit_reached} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "You've reached the max of 50 Forge Codes"})

      {:error, {:invalid_hex, value}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid color in profile: #{value}"})

      {:error, reason} when is_atom(reason) or is_tuple(reason) ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})

      {:error, %Ecto.Changeset{} = cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(cs)})
    end
  end

  def create(conn, _), do: conn |> put_status(:bad_request) |> json(%{error: "Missing name"})

  # POST /api/forge-codes/:code/apply
  def apply(conn, %{"code" => code}) do
    user = Guardian.Plug.current_resource(conn)

    case ForgeCodes.apply_by_code(code, user) do
      {:ok, %{user: updated, forge_code: fc}} ->
        conn |> json(%{ok: true, active_forge_code: fc.code, user_id: updated.id})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Forge Code not found"})

      {:error, :private} ->
        conn |> put_status(:forbidden) |> json(%{error: "This Forge Code is private"})

      {:error, %Ecto.Changeset{} = cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(cs)})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
    end
  end

  # PUT /api/forge-codes/:code
  def update(conn, %{"code" => code} = params) do
    user = Guardian.Plug.current_resource(conn)

    case ForgeCodes.get_by_code(code) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Forge Code not found"})

      %{owner_id: owner_id} = fc when owner_id == user.id ->
        attrs =
          params
          |> Map.take([
            "name",
            "description",
            "vibe_tag",
            "is_public",
            "is_remixable",
            "preview_image_url"
          ])

        case ForgeCodes.update_visibility(fc, attrs) do
          {:ok, updated} ->
            conn |> json(%{code: code_json(updated)})

          {:error, cs} ->
            conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(cs)})
        end

      _ ->
        conn |> put_status(:forbidden) |> json(%{error: "You don't own this Forge Code"})
    end
  end

  # DELETE /api/forge-codes/:code
  def delete(conn, %{"code" => code}) do
    user = Guardian.Plug.current_resource(conn)

    case ForgeCodes.get_by_code(code) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Forge Code not found"})

      %{owner_id: owner_id} = fc when owner_id == user.id ->
        ForgeCodes.delete(fc)
        conn |> json(%{ok: true})

      _ ->
        conn |> put_status(:forbidden) |> json(%{error: "You don't own this Forge Code"})
    end
  end

  defp code_json(fc) do
    %{
      code: fc.code,
      name: fc.name,
      description: fc.description,
      vibe_tag: fc.vibe_tag,
      config: fc.config,
      is_official: fc.is_official,
      is_public: fc.is_public,
      is_remixable: fc.is_remixable,
      applies_count: fc.applies_count,
      endorsement_count: fc.endorsement_count,
      preview_image_url: fc.preview_image_url,
      schema_version: fc.schema_version,
      inserted_at: fc.inserted_at,
      owner:
        case fc.owner do
          %Ecto.Association.NotLoaded{} -> nil
          nil -> nil
          o -> %{id: o.id, username: o.username, slug: o.slug, avatar_url: o.avatar_url}
        end
    }
  end

  defp parse_int(nil, default), do: default

  defp parse_int(v, default) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_int(v, _) when is_integer(v), do: v
  defp parse_int(_, default), do: default

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", to_string(v)) end)
    end)
  end
end
