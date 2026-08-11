defmodule ForgeNexus.Profiles.ForgeCodeSchema do
  @moduledoc """
  Whitelist validator for Forge Code configs.

  A Forge Code decodes to a JSON object. We refuse anything not matching this
  schema, so it's impossible to smuggle HTML / CSS / script into the profile
  render path. CSS properties are emitted as CSS custom properties from these
  typed values — the user's JSON never hits the DOM as text.
  """

  alias ForgeNexus.Accounts.User

  @font_allowlist [
    "Inter",
    "JetBrains Mono",
    "Source Code Pro",
    "Fira Code",
    "Playfair Display",
    "Cinzel",
    "MedievalSharp",
    "Press Start 2P",
    "VT323",
    "Share Tech Mono",
    "Cormorant Garamond",
    "EB Garamond",
    "Lora",
    "Montserrat",
    "Poppins",
    "Quicksand",
    "Righteous",
    "Orbitron",
    "Audiowide",
    "Russo One",
    "Creepster",
    "Nosifer",
    "Butcherman",
    "Permanent Marker",
    "Pacifico",
    "Lobster",
    "Dancing Script"
  ]

  @gradient_directions [
    "to top",
    "to bottom",
    "to left",
    "to right",
    "to top left",
    "to top right",
    "to bottom left",
    "to bottom right",
    "135deg",
    "45deg",
    "90deg",
    "180deg",
    "270deg"
  ]

  @widget_slots ~w(about top_friends guestbook activity achievements clips blurbs music mood heatmap pinned_thread endorsements social_links)

  @max_blurb 2000
  @max_name_field 80

  def font_allowlist, do: @font_allowlist
  def gradient_directions, do: @gradient_directions
  def widget_slots, do: @widget_slots

  @doc """
  Validate a raw config map. Returns `{:ok, cleaned_map}` or `{:error, reason}`.

  The returned map is SAFE — all values are either primitives that match
  strict types, or scrubbed to defaults. Callers can confidently apply
  these to user fields.
  """
  def validate(config) when is_map(config) do
    with {:ok, bg} <- validate_background(Map.get(config, "background")),
         {:ok, accent} <- validate_hex(Map.get(config, "accent")),
         {:ok, font} <- validate_font(Map.get(config, "font")),
         {:ok, widgets} <- validate_widgets(Map.get(config, "widgets")),
         {:ok, overrides} <- validate_color_overrides(Map.get(config, "color_overrides")),
         {:ok, nameplate} <- validate_nameplate(Map.get(config, "nameplate")),
         {:ok, avatar_frame} <- validate_avatar_frame(Map.get(config, "avatar_frame")),
         {:ok, mood} <- validate_mood(Map.get(config, "mood")),
         {:ok, music} <- validate_music(Map.get(config, "music")),
         {:ok, blurbs} <- validate_blurbs(Map.get(config, "blurbs")),
         {:ok, vibe} <- validate_vibe(Map.get(config, "vibe")),
         {:ok, layout} <- validate_layout(Map.get(config, "layout")) do
      cleaned =
        %{
          "background" => bg,
          "accent" => accent,
          "font" => font,
          "widgets" => widgets,
          "color_overrides" => overrides,
          "nameplate" => nameplate,
          "avatar_frame" => avatar_frame,
          "mood" => mood,
          "music" => music,
          "blurbs" => blurbs,
          "vibe" => vibe,
          "layout" => layout
        }
        |> strip_nils()

      {:ok, cleaned}
    end
  end

  def validate(_), do: {:error, :not_a_map}

  # ---- field validators -----------------------------------------------------

  defp validate_background(nil), do: {:ok, nil}

  defp validate_background(%{"type" => "color", "color" => color}) do
    with {:ok, hex} <- validate_hex(color), do: {:ok, %{"type" => "color", "color" => hex}}
  end

  defp validate_background(%{"type" => "gradient"} = bg) do
    with {:ok, start_hex} <- validate_hex(Map.get(bg, "start")),
         {:ok, end_hex} <- validate_hex(Map.get(bg, "end")),
         {:ok, dir} <- validate_gradient_dir(Map.get(bg, "direction")) do
      {:ok, %{"type" => "gradient", "start" => start_hex, "end" => end_hex, "direction" => dir}}
    end
  end

  defp validate_background(%{"type" => "image", "url" => url}) do
    with {:ok, safe_url} <- validate_image_url(url) do
      {:ok, %{"type" => "image", "url" => safe_url}}
    end
  end

  defp validate_background(_), do: {:error, :invalid_background}

  defp validate_hex(nil), do: {:ok, nil}
  defp validate_hex(""), do: {:ok, nil}

  defp validate_hex(value) when is_binary(value) do
    if Regex.match?(~r/^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/, value),
      do: {:ok, String.downcase(value)},
      else: {:error, {:invalid_hex, value}}
  end

  defp validate_hex(_), do: {:error, :invalid_hex}

  defp validate_font(nil), do: {:ok, nil}
  defp validate_font(""), do: {:ok, nil}

  defp validate_font(name) when is_binary(name) do
    if name in @font_allowlist,
      do: {:ok, name},
      else: {:error, {:font_not_allowlisted, name}}
  end

  defp validate_font(_), do: {:error, :invalid_font}

  defp validate_gradient_dir(nil), do: {:ok, "to bottom"}

  defp validate_gradient_dir(dir) when is_binary(dir) do
    if dir in @gradient_directions,
      do: {:ok, dir},
      else: {:error, {:invalid_gradient_direction, dir}}
  end

  defp validate_gradient_dir(_), do: {:error, :invalid_gradient_direction}

  defp validate_widgets(nil), do: {:ok, nil}

  defp validate_widgets(list) when is_list(list) do
    cleaned =
      list
      |> Enum.filter(&is_binary/1)
      |> Enum.filter(&(&1 in @widget_slots))
      |> Enum.uniq()

    if Enum.empty?(cleaned), do: {:ok, nil}, else: {:ok, cleaned}
  end

  defp validate_widgets(_), do: {:error, :invalid_widgets}

  defp validate_color_overrides(nil), do: {:ok, nil}

  defp validate_color_overrides(%{} = map) do
    allowed = ~w(accent bg_primary bg_secondary text_primary)

    Enum.reduce_while(allowed, {:ok, %{}}, fn key, {:ok, acc} ->
      case validate_hex(Map.get(map, key)) do
        {:ok, nil} -> {:cont, {:ok, acc}}
        {:ok, hex} -> {:cont, {:ok, Map.put(acc, key, hex)}}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, map} when map_size(map) == 0 -> {:ok, nil}
      other -> other
    end
  end

  defp validate_color_overrides(_), do: {:error, :invalid_color_overrides}

  defp validate_nameplate(nil), do: {:ok, nil}

  defp validate_nameplate(%{} = np) do
    with {:ok, color} <- validate_hex(Map.get(np, "color")),
         {:ok, image} <- validate_image_url(Map.get(np, "image_url")) do
      {:ok, drop_nils(%{"color" => color, "image_url" => image})}
    end
  end

  defp validate_nameplate(_), do: {:error, :invalid_nameplate}

  defp validate_avatar_frame(nil), do: {:ok, nil}

  defp validate_avatar_frame(%{} = af) do
    frame =
      case Map.get(af, "frame") do
        s when is_binary(s) and byte_size(s) <= 40 -> s
        _ -> nil
      end

    with {:ok, color} <- validate_hex(Map.get(af, "color")) do
      {:ok, drop_nils(%{"frame" => frame, "color" => color})}
    end
  end

  defp validate_avatar_frame(_), do: {:error, :invalid_avatar_frame}

  defp validate_mood(nil), do: {:ok, nil}

  defp validate_mood(%{} = mood) do
    text =
      case Map.get(mood, "text") do
        s when is_binary(s) -> s |> String.slice(0, 80) |> strip_controls()
        _ -> nil
      end

    emoji =
      case Map.get(mood, "emoji") do
        s when is_binary(s) and byte_size(s) <= 16 -> s
        _ -> nil
      end

    {:ok, drop_nils(%{"text" => text, "emoji" => emoji})}
  end

  defp validate_mood(_), do: {:error, :invalid_mood}

  defp validate_music(nil), do: {:ok, nil}

  defp validate_music(%{} = music) do
    with {:ok, url} <- validate_media_url(Map.get(music, "url")) do
      title =
        case Map.get(music, "title") do
          s when is_binary(s) -> s |> String.slice(0, @max_name_field) |> strip_controls()
          _ -> nil
        end

      autoplay = !!Map.get(music, "autoplay")

      {:ok, drop_nils(%{"url" => url, "title" => title, "autoplay" => autoplay})}
    end
  end

  defp validate_music(_), do: {:error, :invalid_music}

  defp validate_blurbs(nil), do: {:ok, nil}

  defp validate_blurbs(%{} = blurbs) do
    allowed =
      ~w(interests favorite_music favorite_movies favorite_tv favorite_games favorite_books heroes who_id_like_to_meet about)

    cleaned =
      Enum.reduce(allowed, %{}, fn key, acc ->
        case Map.get(blurbs, key) do
          s when is_binary(s) ->
            Map.put(acc, key, s |> String.slice(0, @max_blurb) |> strip_controls())

          _ ->
            acc
        end
      end)

    if map_size(cleaned) == 0, do: {:ok, nil}, else: {:ok, cleaned}
  end

  defp validate_blurbs(_), do: {:error, :invalid_blurbs}

  defp validate_vibe(nil), do: {:ok, nil}

  defp validate_vibe(vibe) when is_binary(vibe) do
    if vibe in User.vibe_tags(),
      do: {:ok, vibe},
      else: {:error, {:invalid_vibe, vibe}}
  end

  defp validate_vibe(_), do: {:error, :invalid_vibe}

  defp validate_layout(nil), do: {:ok, nil}

  defp validate_layout(layout) when is_binary(layout) do
    if layout in ~w(classic modern minimal cards magazine),
      do: {:ok, layout},
      else: {:error, {:invalid_layout, layout}}
  end

  defp validate_layout(_), do: {:error, :invalid_layout}

  # ---- URL validators -------------------------------------------------------

  @doc """
  Image URL must be https, ≤400 chars, and match a curated allowlist of image
  hosts. Same-origin uploads are always accepted.
  """
  def validate_image_url(nil), do: {:ok, nil}
  def validate_image_url(""), do: {:ok, nil}

  def validate_image_url(url) when is_binary(url) do
    cond do
      byte_size(url) > 400 ->
        {:error, :url_too_long}

      String.starts_with?(url, "/uploads/") ->
        {:ok, url}

      String.starts_with?(url, "/static/") ->
        {:ok, url}

      String.starts_with?(url, "https://") and host_allowlisted?(url, image_host_allowlist()) ->
        {:ok, url}

      true ->
        {:error, {:url_not_allowlisted, url}}
    end
  end

  def validate_image_url(_), do: {:error, :invalid_url}

  @doc "Audio URL — same-origin uploads only (music player is user-uploaded content)."
  def validate_media_url(nil), do: {:ok, nil}
  def validate_media_url(""), do: {:ok, nil}

  def validate_media_url(url) when is_binary(url) do
    cond do
      byte_size(url) > 400 ->
        {:error, :url_too_long}

      String.starts_with?(url, "/uploads/") ->
        {:ok, url}

      String.starts_with?(url, "https://") and host_allowlisted?(url, media_host_allowlist()) ->
        {:ok, url}

      true ->
        {:error, {:media_url_not_allowlisted, url}}
    end
  end

  def validate_media_url(_), do: {:error, :invalid_url}

  defp image_host_allowlist do
    [
      "i.imgur.com",
      "imgur.com",
      "cdn.discordapp.com",
      "media.discordapp.net",
      "pbs.twimg.com",
      "abs.twimg.com",
      "cdn.bsky.app",
      "i.redd.it",
      "preview.redd.it",
      "raw.githubusercontent.com",
      "github.com",
      # ForgeNexus own CDN (future R2 domain)
      "cdn.tcgaming.quest",
      "forum.tcgaming.quest"
    ]
  end

  defp media_host_allowlist do
    [
      "cdn.tcgaming.quest",
      "forum.tcgaming.quest"
      # Intentionally conservative — no Spotify/SoundCloud embeds here;
      # we auto-upload the MP3 ourselves for the player.
    ]
  end

  defp host_allowlisted?(url, allowlist) do
    case URI.parse(url) do
      %URI{host: h, scheme: "https"} when is_binary(h) -> h in allowlist
      _ -> false
    end
  end

  # ---- helpers --------------------------------------------------------------

  defp strip_nils(map) when is_map(map) do
    map
    |> Enum.reject(fn {_, v} -> is_nil(v) or v == %{} or v == [] end)
    |> Enum.into(%{})
  end

  defp drop_nils(map) do
    map
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  defp strip_controls(s) do
    s
    |> String.replace(~r/[\x00-\x08\x0B-\x1F\x7F]/u, "")
    |> String.trim()
  end
end
