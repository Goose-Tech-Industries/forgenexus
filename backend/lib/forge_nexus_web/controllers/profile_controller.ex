defmodule ForgeNexusWeb.ProfileController do
  use ForgeNexusWeb, :controller
  import Ecto.Query

  alias ForgeNexus.{Accounts, Profiles, BBCode}

  # GET /profiles/:slug — public profile
  def show(conn, %{"slug" => slug}) do
    case Profiles.get_profile_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Profile not found"})

      profile_user ->
        viewer = Guardian.Plug.current_resource(conn)
        pref = Accounts.get_preferences(profile_user.id)

        # Check profile visibility
        can_view =
          cond do
            viewer && viewer.id == profile_user.id -> true
            pref.profile_visibility == "public" -> true
            pref.profile_visibility == "members" -> !is_nil(viewer)
            pref.profile_visibility == "private" -> false
            true -> true
          end

        if can_view do
          # Record visit if authenticated
          if viewer, do: Profiles.record_visit(profile_user.id, viewer.id)

          top_friends = Profiles.list_top_friends(profile_user.id)
          guestbook = Profiles.list_guestbook_entries(profile_user.id, limit: 10)
          recent_visitors = Profiles.recent_visitors(profile_user.id, 10)

          is_following =
            if viewer, do: Accounts.is_following?(viewer.id, profile_user.id), else: false

          follower_count = Accounts.follower_count(profile_user.id)
          following_count = Accounts.following_count(profile_user.id)

          endorsement_counts = Profiles.endorsement_counts(profile_user.id)

          my_endorsements =
            if viewer, do: Profiles.my_endorsements(profile_user.id, viewer.id), else: []

          pinned_thread =
            if profile_user.pinned_thread_id,
              do: ForgeNexus.Repo.get(ForgeNexus.Forums.Thread, profile_user.pinned_thread_id)

          conn
          |> json(%{
            profile:
              Map.merge(profile_json(profile_user), %{
                follower_count: follower_count,
                following_count: following_count
              }),
            is_following: is_following,
            top_friends: Enum.map(top_friends, &top_friend_json/1),
            guestbook: Enum.map(guestbook, &guestbook_json/1),
            recent_visitors: Enum.map(recent_visitors, &visitor_json/1),
            endorsements: %{counts: endorsement_counts, mine: my_endorsements},
            pinned_thread:
              pinned_thread &&
                %{
                  id: pinned_thread.id,
                  title: pinned_thread.title,
                  slug: pinned_thread.slug,
                  reply_count: pinned_thread.reply_count,
                  view_count: pinned_thread.view_count,
                  inserted_at: pinned_thread.inserted_at
                },
            privacy: %{
              profile_visibility: pref.profile_visibility,
              show_activity: pref.show_activity
            }
          })
        else
          conn
          |> put_status(:forbidden)
          |> json(%{error: "This profile is private"})
        end
    end
  end

  # GET /profiles/:slug/reputation - reputation breakdown
  def give_reputation(conn, %{"user_id" => target_user_id, "amount" => amount} = params) do
    user = Guardian.Plug.current_resource(conn)
    _reason = Map.get(params, "reason", "Manual reputation")
    amount = if is_binary(amount), do: String.to_integer(amount), else: amount

    cond do
      user.id == target_user_id ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "You cannot give reputation to yourself"})

      amount == 0 ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Amount cannot be zero"})

      abs(amount) > 10 ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Amount must be between -10 and 10"})

      true ->
        event_type = if amount > 0, do: "user_given", else: "user_taken"

        case ForgeNexus.Forums.log_reputation_event(
               target_user_id,
               event_type,
               amount,
               "user",
               user.id
             ) do
          {:ok, event} ->
            # Update user's total reputation
            import Ecto.Query

            ForgeNexus.Repo.update_all(
              from(u in ForgeNexus.Accounts.User, where: u.id == ^target_user_id),
              inc: [reputation: amount]
            )

            conn
            |> json(%{
              success: true,
              event: %{id: event.id, points: event.points, event_type: event.event_type},
              message: if(amount > 0, do: "Reputation given!", else: "Reputation taken.")
            })

          {:error, _changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to give reputation"})
        end
    end
  end

  def reputation(conn, %{"slug" => slug}) do
    case Profiles.get_profile_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Profile not found"})

      profile_user ->
        breakdown = ForgeNexus.Forums.get_reputation_breakdown(profile_user.id)
        history = ForgeNexus.Forums.get_reputation_history(profile_user.id, limit: 20)

        conn
        |> json(%{
          breakdown:
            Enum.map(breakdown, fn b ->
              %{event_type: b.event_type, total_points: b.total_points, count: b.count}
            end),
          history:
            Enum.map(history, fn e ->
              %{
                id: e.id,
                event_type: e.event_type,
                points: e.points,
                source_type: e.source_type,
                source_id: e.source_id,
                inserted_at: e.inserted_at
              }
            end),
          total: profile_user.reputation
        })
    end
  end

  # PUT /profile — update own profile page
  def update(conn, %{"profile" => profile_params}) do
    user = Guardian.Plug.current_resource(conn)

    case Accounts.update_profile_page(user, profile_params) do
      {:ok, updated_user} ->
        conn |> json(%{profile: profile_json(updated_user)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  @blurb_fields ~w(interests favorite_music favorite_movies favorite_tv favorite_games favorite_books heroes who_id_like_to_meet about_me_bbcode about_me_html)
  @mood_fields ~w(profile_mood profile_mood_emoji profile_song_url profile_song_title profile_song_autoplay walk_on_sound_url walk_on_sound_name)
  @layout_fields ~w(profile_layout profile_widget_order)
  @css_fields ~w(color_override_accent color_override_bg_primary color_override_bg_secondary color_override_text_primary profile_accent_color profile_background_color profile_background_url profile_gradient_start profile_gradient_end profile_gradient_direction profile_banner_url profile_font)

  # PUT /profile/blurbs — MySpace-style About Me blurbs
  def update_blurbs(conn, params), do: do_partial_update(conn, params, @blurb_fields)

  # PUT /profile/mood — current mood + profile song + walk-on sound
  def update_mood(conn, params), do: do_partial_update(conn, params, @mood_fields)

  # PUT /profile/layout — layout style + widget order
  def update_layout(conn, params), do: do_partial_update(conn, params, @layout_fields)

  # PUT /profile/css — color overrides + profile chrome
  def update_css(conn, params), do: do_partial_update(conn, params, @css_fields)

  defp do_partial_update(conn, params, allowed_fields) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn |> put_status(:unauthorized) |> json(%{error: "unauthorized"})

      user ->
        attrs =
          (params["profile"] || params)
          |> Map.take(allowed_fields)

        case Accounts.update_profile_page(user, attrs) do
          {:ok, updated_user} ->
            conn |> json(%{profile: profile_json(updated_user)})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_errors(changeset)})
        end
    end
  end

  # GET /profiles/:slug/guestbook — paginated guestbook
  def guestbook(conn, %{"slug" => slug} = params) do
    case Profiles.get_profile_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Profile not found"})

      profile_user ->
        page = Map.get(params, "page", "1") |> safe_to_integer(1)
        limit = 25
        offset = (page - 1) * limit

        entries = Profiles.list_guestbook_entries(profile_user.id, limit: limit, offset: offset)

        conn
        |> json(%{
          guestbook: Enum.map(entries, &guestbook_json/1),
          page: page
        })
    end
  end

  # POST /profiles/:slug/guestbook — sign guestbook
  def sign_guestbook(conn, %{"slug" => slug, "body" => body_bbcode}) do
    author = Guardian.Plug.current_resource(conn)

    case Profiles.get_profile_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Profile not found"})

      profile_user ->
        body_html = BBCode.to_html(body_bbcode)

        case Profiles.create_guestbook_entry(%{
               profile_user_id: profile_user.id,
               author_id: author.id,
               body_bbcode: body_bbcode,
               body_html: body_html
             }) do
          {:ok, entry} ->
            entry = ForgeNexus.Repo.preload(entry, :author)
            conn |> put_status(:created) |> json(%{entry: guestbook_json(entry)})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_errors(changeset)})
        end
    end
  end

  # DELETE /guestbook/:id
  def delete_guestbook_entry(conn, %{"id" => entry_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Profiles.delete_guestbook_entry(entry_id, user.id) do
      {:ok, _} ->
        conn |> json(%{ok: true})

      {:error, :unauthorized} ->
        conn |> put_status(:forbidden) |> json(%{error: "Not authorized to delete this entry"})
    end
  end

  # PUT /profile/top-friends
  def top_friends(conn, %{"friend_ids" => friend_ids}) do
    user = Guardian.Plug.current_resource(conn)

    case Profiles.set_top_friends(user.id, friend_ids) do
      {:ok, friends} ->
        conn |> json(%{top_friends: Enum.map(friends, &top_friend_json/1)})

      {:error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to update top friends"})
    end
  end

  # GET /profile/analytics — owner's view-count sparkline (last 30 days)
  def analytics(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    case user do
      nil ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})

      user ->
        daily = Profiles.daily_visit_counts(user.id, 30)
        total = Enum.reduce(daily, 0, fn %{count: c}, acc -> acc + c end)
        conn |> json(%{daily: daily, total_last_30d: total, all_time: user.profile_views || 0})
    end
  end

  # POST /profiles/:slug/ai-summary  — generate an on-demand AI summary
  def ai_summary(conn, %{"slug" => slug}) do
    case Accounts.get_user_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Profile not found"})

      user ->
        case ForgeNexus.AI.ProfileSummarizer.generate(user) do
          {:ok, summary} ->
            conn |> json(%{summary: summary})

          {:error, :feature_disabled} ->
            conn
            |> put_status(:service_unavailable)
            |> json(%{error: "AI profile summaries are disabled on this server"})

          {:error, reason} ->
            conn
            |> put_status(:bad_gateway)
            |> json(%{error: "AI summary failed", detail: inspect(reason)})
        end
    end
  end

  # PUT /profile/pin-thread  {"thread_id": "..."} — pin a thread the user owns
  def pin_thread(conn, %{"thread_id" => thread_id}) do
    user = Guardian.Plug.current_resource(conn)

    case ForgeNexus.Repo.get(ForgeNexus.Forums.Thread, thread_id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Thread not found"})

      %{user_id: owner_id} when owner_id != user.id ->
        conn |> put_status(:forbidden) |> json(%{error: "You can only pin your own threads"})

      thread ->
        user
        |> Ecto.Changeset.change(pinned_thread_id: thread.id)
        |> ForgeNexus.Repo.update()

        conn |> json(%{ok: true, pinned_thread_id: thread.id})
    end
  end

  def pin_thread(conn, _),
    do: conn |> put_status(:bad_request) |> json(%{error: "Missing thread_id"})

  # DELETE /profile/pin-thread
  def unpin_thread(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    user
    |> Ecto.Changeset.change(pinned_thread_id: nil)
    |> ForgeNexus.Repo.update()

    conn |> json(%{ok: true})
  end

  # GET /profile/widgets — list current user's profile widgets
  def list_widgets(conn, _params) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn |> put_status(:unauthorized) |> json(%{error: "unauthorized"})

      user ->
        widgets =
          ForgeNexus.Repo.all(
            from w in ForgeNexus.Profiles.ProfileWidget,
              where: w.user_id == ^user.id,
              order_by: [asc: w.position]
          )

        conn |> json(%{widgets: Enum.map(widgets, &widget_json/1)})
    end
  end

  # POST /profile/widgets
  def create_widget(conn, params) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn |> put_status(:unauthorized) |> json(%{error: "unauthorized"})

      user ->
        attrs =
          (params["widget"] || params)
          |> Map.take(["type", "title", "config", "position", "is_visible"])
          |> Map.put("user_id", user.id)

        case %ForgeNexus.Profiles.ProfileWidget{}
             |> ForgeNexus.Profiles.ProfileWidget.changeset(attrs)
             |> ForgeNexus.Repo.insert() do
          {:ok, w} ->
            conn |> put_status(:created) |> json(%{widget: widget_json(w)})

          {:error, cs} ->
            conn |> put_status(:unprocessable_entity) |> json(%{errors: changeset_errors(cs)})
        end
    end
  end

  # PUT /profile/widgets/:id
  def update_widget(conn, %{"id" => id} = params) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn |> put_status(:unauthorized) |> json(%{error: "unauthorized"})

      user ->
        case ForgeNexus.Repo.get(ForgeNexus.Profiles.ProfileWidget, id) do
          %ForgeNexus.Profiles.ProfileWidget{user_id: uid} = w when uid == user.id ->
            attrs =
              (params["widget"] || params)
              |> Map.take(["title", "config", "position", "is_visible", "type"])

            case w
                 |> ForgeNexus.Profiles.ProfileWidget.changeset(attrs)
                 |> ForgeNexus.Repo.update() do
              {:ok, w2} ->
                conn |> json(%{widget: widget_json(w2)})

              {:error, cs} ->
                conn |> put_status(:unprocessable_entity) |> json(%{errors: changeset_errors(cs)})
            end

          %ForgeNexus.Profiles.ProfileWidget{} ->
            conn |> put_status(:forbidden) |> json(%{error: "not your widget"})

          nil ->
            conn |> put_status(:not_found) |> json(%{error: "not found"})
        end
    end
  end

  # DELETE /profile/widgets/:id
  def delete_widget(conn, %{"id" => id}) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn |> put_status(:unauthorized) |> json(%{error: "unauthorized"})

      user ->
        case ForgeNexus.Repo.get(ForgeNexus.Profiles.ProfileWidget, id) do
          %ForgeNexus.Profiles.ProfileWidget{user_id: uid} = w when uid == user.id ->
            ForgeNexus.Repo.delete!(w)
            conn |> json(%{ok: true})

          %ForgeNexus.Profiles.ProfileWidget{} ->
            conn |> put_status(:forbidden) |> json(%{error: "not your widget"})

          nil ->
            conn |> put_status(:not_found) |> json(%{error: "not found"})
        end
    end
  end

  defp widget_json(w) do
    %{
      id: w.id,
      type: w.type,
      title: w.title,
      config: w.config,
      position: w.position,
      is_visible: w.is_visible,
      inserted_at: w.inserted_at
    }
  end

  defp changeset_errors(cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", to_string(v)) end)
    end)
  end

  # GET /avatar-frames
  def avatar_frames(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    frames =
      if user do
        Accounts.get_available_frames_for_user(user)
      else
        Accounts.list_avatar_frames()
      end

    conn |> json(%{frames: Enum.map(frames, &frame_json/1)})
  end

  # --- JSON serializers ---

  defp profile_json(user) do
    group = if Ecto.assoc_loaded?(user.primary_group), do: user.primary_group, else: nil
    theme = if Ecto.assoc_loaded?(user.selected_theme), do: user.selected_theme, else: nil

    %{
      id: user.id,
      username: user.username,
      display_name: user.display_name,
      slug: user.slug,
      avatar_url: user.avatar_url,
      bio: user.bio,
      location: user.location,
      website: user.website,
      post_count: user.post_count,
      thread_count: user.thread_count,
      reputation: user.reputation,
      is_online: user.is_online,
      last_seen_at: user.last_seen_at,
      inserted_at: user.inserted_at,
      profile_views: user.profile_views,
      # Customization
      username_color:
        user.username_color || (group && group.username_color) || (group && group.color),
      username_effect: user.username_effect || (group && group.username_effect) || "none",
      custom_title: user.custom_title,
      display_title: ForgeNexus.Accounts.display_title(user),
      group_name: group && group.name,
      # Profile page
      profile_background_url: user.profile_background_url,
      profile_background_color: user.profile_background_color,
      profile_gradient_start: user.profile_gradient_start,
      profile_gradient_end: user.profile_gradient_end,
      profile_gradient_direction: user.profile_gradient_direction,
      profile_banner_url: user.profile_banner_url,
      profile_accent_color: user.profile_accent_color,
      profile_font: user.profile_font,
      about_me_html: user.about_me_html,
      about_me_bbcode: user.about_me_bbcode,
      nameplate_color: user.nameplate_color,
      nameplate_image_url: user.nameplate_image_url,
      avatar_frame: user.avatar_frame,
      avatar_frame_color: user.avatar_frame_color,
      signature: user.signature,
      signature_html: user.signature_html,
      # Theme
      theme_id: user.theme_id,
      theme:
        theme && %{id: theme.id, name: theme.name, slug: theme.slug, variables: theme.variables},
      color_override_accent: user.color_override_accent,
      color_override_bg_primary: user.color_override_bg_primary,
      color_override_bg_secondary: user.color_override_bg_secondary,
      color_override_text_primary: user.color_override_text_primary,
      # SOTA additions
      pronouns: user.pronouns,
      social_links: user.social_links || %{},
      profile_vibe: user.profile_vibe,
      avatar_3d_url: user.avatar_3d_url,
      verified_creator_at: user.verified_creator_at,
      pinned_thread_id: user.pinned_thread_id,
      active_forge_code: user.active_forge_code,
      timezone: user.timezone,
      birthday_visibility: user.birthday_visibility,
      location_visibility: user.location_visibility,
      email_visibility: user.email_visibility,
      activity_visibility: user.activity_visibility,
      # MySpace-style About Me blurbs
      interests: user.interests,
      favorite_music: user.favorite_music,
      favorite_movies: user.favorite_movies,
      favorite_tv: user.favorite_tv,
      favorite_games: user.favorite_games,
      favorite_books: user.favorite_books,
      heroes: user.heroes,
      who_id_like_to_meet: user.who_id_like_to_meet,
      # Mood / music / walk-on
      profile_mood: user.profile_mood,
      profile_mood_emoji: user.profile_mood_emoji,
      profile_song_url: user.profile_song_url,
      profile_song_title: user.profile_song_title,
      profile_song_autoplay: user.profile_song_autoplay,
      walk_on_sound_url: user.walk_on_sound_url,
      walk_on_sound_name: user.walk_on_sound_name,
      profile_layout: user.profile_layout,
      profile_widget_order: user.profile_widget_order || []
    }
  end

  defp top_friend_json(tf) do
    %{
      id: tf.friend.id,
      username: tf.friend.username,
      slug: tf.friend.slug,
      avatar_url: tf.friend.avatar_url,
      is_online: tf.friend.is_online,
      position: tf.position
    }
  end

  defp guestbook_json(entry) do
    %{
      id: entry.id,
      body_html: entry.body_html,
      body_bbcode: entry.body_bbcode,
      inserted_at: entry.inserted_at,
      author: %{
        id: entry.author.id,
        username: entry.author.username,
        slug: entry.author.slug,
        avatar_url: entry.author.avatar_url
      }
    }
  end

  defp visitor_json(visit) do
    %{
      user_id: visit.visitor.id,
      username: visit.visitor.username,
      slug: visit.visitor.slug,
      avatar_url: visit.visitor.avatar_url,
      visited_at: visit.visited_at
    }
  end

  defp frame_json(frame) do
    %{
      id: frame.id,
      name: frame.name,
      slug: frame.slug,
      css_class: frame.css_class,
      description: frame.description,
      min_posts: frame.min_posts
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp safe_to_integer(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> default
    end
  end

  defp safe_to_integer(val, _default) when is_integer(val), do: val
  defp safe_to_integer(_, default), do: default
end
