defmodule ForgeNexus.Profiles.ForgeCodes do
  @moduledoc """
  Encode, apply, and browse Forge Codes — shareable profile themes.

  ## Safety

  A Forge Code is JSON that goes through `ForgeCodeSchema.validate/1` on BOTH
  encode (so we never store garbage) and apply (defense in depth against DB
  tampering). The renderer emits CSS custom properties from the resulting map;
  user content never reaches the DOM as raw HTML or CSS strings.

  ## Code format

  Short, human-pasteable identifiers: 8 lowercase base36 chars, grouped as
  `forge-XXXX-XXXX` for readability when typed. We retry on collision.
  """

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Profiles.{ForgeCode, ForgeCodeApplication, ForgeCodeSchema}

  @code_alphabet ~c"abcdefghijkmnpqrstuvwxyz23456789"
  @code_len 8
  @max_per_owner 50

  # ---- Code generation ------------------------------------------------------

  def generate_code do
    random = for _ <- 1..@code_len, into: "", do: <<Enum.random(@code_alphabet)>>
    {a, b} = String.split_at(random, 4)
    "#{a}-#{b}"
  end

  # ---- Build config from a user --------------------------------------------

  @doc """
  Derive a valid Forge Code config from a user's current profile state.
  This is what "Save my profile as a Forge Code" clicks produce.
  """
  def build_config_from_user(%User{} = user) do
    background =
      cond do
        user.profile_background_url ->
          %{"type" => "image", "url" => user.profile_background_url}

        user.profile_gradient_start && user.profile_gradient_end ->
          %{
            "type" => "gradient",
            "start" => user.profile_gradient_start,
            "end" => user.profile_gradient_end,
            "direction" => user.profile_gradient_direction || "to bottom"
          }

        user.profile_background_color ->
          %{"type" => "color", "color" => user.profile_background_color}

        true ->
          nil
      end

    overrides =
      %{
        "accent" => user.color_override_accent,
        "bg_primary" => user.color_override_bg_primary,
        "bg_secondary" => user.color_override_bg_secondary,
        "text_primary" => user.color_override_text_primary
      }
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Enum.into(%{})

    nameplate =
      drop_nils(%{
        "color" => user.nameplate_color,
        "image_url" => user.nameplate_image_url
      })

    avatar_frame =
      drop_nils(%{
        "frame" => user.avatar_frame,
        "color" => user.avatar_frame_color
      })

    mood =
      drop_nils(%{
        "text" => user.profile_mood,
        "emoji" => user.profile_mood_emoji
      })

    music =
      drop_nils(%{
        "url" => user.profile_song_url,
        "title" => user.profile_song_title,
        "autoplay" => user.profile_song_autoplay
      })

    blurbs =
      drop_nils(%{
        "interests" => user.interests,
        "favorite_music" => user.favorite_music,
        "favorite_movies" => user.favorite_movies,
        "favorite_tv" => user.favorite_tv,
        "favorite_games" => user.favorite_games,
        "favorite_books" => user.favorite_books,
        "heroes" => user.heroes,
        "who_id_like_to_meet" => user.who_id_like_to_meet,
        "about" => user.about_me_bbcode
      })

    %{
      "background" => background,
      "accent" => user.profile_accent_color,
      "font" => user.profile_font,
      "widgets" => user.profile_widget_order,
      "color_overrides" => overrides,
      "nameplate" => if(map_size(nameplate) > 0, do: nameplate, else: nil),
      "avatar_frame" => if(map_size(avatar_frame) > 0, do: avatar_frame, else: nil),
      "mood" => if(map_size(mood) > 0, do: mood, else: nil),
      "music" => if(map_size(music) > 0, do: music, else: nil),
      "blurbs" => if(map_size(blurbs) > 0, do: blurbs, else: nil),
      "vibe" => user.profile_vibe,
      "layout" => user.profile_layout
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) or v == %{} or v == [] end)
    |> Enum.into(%{})
  end

  # ---- Apply a config to a user --------------------------------------------

  @doc """
  Apply a validated Forge Code config onto a user. Every field is either set
  from the config or left untouched (partial apply = non-destructive).
  Returns `{:ok, updated_user}` or `{:error, changeset}`.
  """
  def apply_config_to_user(%User{} = user, %{} = config) do
    with {:ok, safe} <- ForgeCodeSchema.validate(config) do
      attrs = config_to_user_attrs(safe)

      user
      |> User.profile_changeset(attrs)
      |> Repo.update()
    end
  end

  defp config_to_user_attrs(safe) do
    bg = Map.get(safe, "background") || %{}

    bg_attrs =
      case Map.get(bg, "type") do
        "color" ->
          %{
            profile_background_color: Map.get(bg, "color"),
            profile_background_url: nil,
            profile_gradient_start: nil,
            profile_gradient_end: nil
          }

        "gradient" ->
          %{
            profile_gradient_start: Map.get(bg, "start"),
            profile_gradient_end: Map.get(bg, "end"),
            profile_gradient_direction: Map.get(bg, "direction"),
            profile_background_url: nil,
            profile_background_color: nil
          }

        "image" ->
          %{
            profile_background_url: Map.get(bg, "url"),
            profile_background_color: nil,
            profile_gradient_start: nil,
            profile_gradient_end: nil
          }

        _ ->
          %{}
      end

    overrides = Map.get(safe, "color_overrides") || %{}
    nameplate = Map.get(safe, "nameplate") || %{}
    avatar_frame = Map.get(safe, "avatar_frame") || %{}
    mood = Map.get(safe, "mood") || %{}
    music = Map.get(safe, "music") || %{}
    blurbs = Map.get(safe, "blurbs") || %{}

    %{
      profile_accent_color: Map.get(safe, "accent"),
      profile_font: Map.get(safe, "font"),
      profile_widget_order: Map.get(safe, "widgets"),
      profile_vibe: Map.get(safe, "vibe"),
      profile_layout: Map.get(safe, "layout"),
      color_override_accent: Map.get(overrides, "accent"),
      color_override_bg_primary: Map.get(overrides, "bg_primary"),
      color_override_bg_secondary: Map.get(overrides, "bg_secondary"),
      color_override_text_primary: Map.get(overrides, "text_primary"),
      nameplate_color: Map.get(nameplate, "color"),
      nameplate_image_url: Map.get(nameplate, "image_url"),
      avatar_frame: Map.get(avatar_frame, "frame"),
      avatar_frame_color: Map.get(avatar_frame, "color"),
      profile_mood: Map.get(mood, "text"),
      profile_mood_emoji: Map.get(mood, "emoji"),
      profile_song_url: Map.get(music, "url"),
      profile_song_title: Map.get(music, "title"),
      profile_song_autoplay: Map.get(music, "autoplay") || false,
      interests: Map.get(blurbs, "interests"),
      favorite_music: Map.get(blurbs, "favorite_music"),
      favorite_movies: Map.get(blurbs, "favorite_movies"),
      favorite_tv: Map.get(blurbs, "favorite_tv"),
      favorite_games: Map.get(blurbs, "favorite_games"),
      favorite_books: Map.get(blurbs, "favorite_books"),
      heroes: Map.get(blurbs, "heroes"),
      who_id_like_to_meet: Map.get(blurbs, "who_id_like_to_meet"),
      about_me_bbcode: Map.get(blurbs, "about")
    }
    |> Map.merge(bg_attrs)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  # ---- CRUD -----------------------------------------------------------------

  @doc "Save a user's current profile as a new Forge Code."
  def save_from_user(%User{} = user, attrs) do
    count = Repo.aggregate(from(f in ForgeCode, where: f.owner_id == ^user.id), :count)

    if count >= @max_per_owner do
      {:error, :limit_reached}
    else
      config = build_config_from_user(user)

      with {:ok, safe_config} <- ForgeCodeSchema.validate(config) do
        code = unique_code()

        %ForgeCode{}
        |> ForgeCode.changeset(
          Map.merge(attrs, %{
            "code" => code,
            "config" => safe_config,
            "owner_id" => user.id
          })
        )
        |> Repo.insert()
      end
    end
  end

  def get_by_code(code) when is_binary(code) do
    from(f in ForgeCode, where: f.code == ^code, preload: [:owner])
    |> Repo.one()
  end

  def get!(id), do: Repo.get!(ForgeCode, id) |> Repo.preload(:owner)

  def apply_by_code(code, %User{} = user) when is_binary(code) do
    case get_by_code(code) do
      nil ->
        {:error, :not_found}

      %ForgeCode{is_public: false, owner_id: owner_id} when owner_id != user.id ->
        {:error, :private}

      %ForgeCode{} = fc ->
        Repo.transaction(fn ->
          case apply_config_to_user(user, fc.config) do
            {:ok, updated} ->
              from(f in ForgeCode, where: f.id == ^fc.id)
              |> Repo.update_all(inc: [applies_count: 1])

              updated
              |> Ecto.Changeset.change(active_forge_code: fc.code)
              |> Repo.update!()

              %ForgeCodeApplication{}
              |> ForgeCodeApplication.changeset(%{
                forge_code_id: fc.id,
                user_id: user.id,
                inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
              })
              |> Repo.insert!()

              %{user: Repo.get!(User, user.id), forge_code: fc}

            {:error, cs} ->
              Repo.rollback(cs)
          end
        end)
    end
  end

  # ---- Gallery --------------------------------------------------------------

  def list_gallery(opts \\ []) do
    tab = Keyword.get(opts, :tab, "featured")
    vibe = Keyword.get(opts, :vibe)
    limit = Keyword.get(opts, :limit, 24)
    offset = Keyword.get(opts, :offset, 0)

    base =
      from(f in ForgeCode,
        where: f.is_public == true,
        preload: [:owner]
      )

    base =
      case vibe do
        nil -> base
        v -> from(f in base, where: f.vibe_tag == ^v)
      end

    query =
      case tab do
        "featured" ->
          from(f in base, where: f.is_official == true, order_by: [desc: f.inserted_at])

        "trending" ->
          from(f in base, order_by: [desc: f.applies_count, desc: f.inserted_at])

        "new" ->
          from(f in base, order_by: [desc: f.inserted_at])

        "mine" ->
          raise ArgumentError, "pass user to list_mine/2 instead"

        _ ->
          base
      end

    query
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  def list_mine(%User{} = user, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    from(f in ForgeCode,
      where: f.owner_id == ^user.id,
      order_by: [desc: f.inserted_at],
      limit: ^limit,
      preload: [:owner]
    )
    |> Repo.all()
  end

  def update_visibility(%ForgeCode{} = fc, attrs) do
    fc
    |> ForgeCode.changeset(attrs)
    |> Repo.update()
  end

  def delete(%ForgeCode{} = fc), do: Repo.delete(fc)

  def set_official(%ForgeCode{} = fc, value) when is_boolean(value) do
    fc
    |> Ecto.Changeset.change(is_official: value)
    |> Repo.update()
  end

  # ---- internals ------------------------------------------------------------

  defp unique_code(retries \\ 8) do
    code = generate_code()

    case Repo.get_by(ForgeCode, code: code) do
      nil -> code
      _ when retries > 0 -> unique_code(retries - 1)
      _ -> raise "could not generate unique Forge Code after retries"
    end
  end

  defp drop_nils(map) do
    map
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end
end
