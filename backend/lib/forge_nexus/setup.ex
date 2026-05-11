defmodule ForgeNexus.Setup do
  @moduledoc """
  First-run setup system for ForgeNexus.
  Handles pre-flight checks and the full installation wizard.
  """

  import Ecto.Query
  require Logger

  alias ForgeNexus.Repo
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Accounts.UserGroup
  alias ForgeNexus.Accounts.UserGroupMembership
  alias ForgeNexus.Forums.Category
  alias ForgeNexus.Forums.Forum
  alias ForgeNexus.Accounts.Theme
  alias ForgeNexus.Settings.SiteSetting
  alias ForgeNexus.Economy.Currency
  alias Ecto.Multi

  # -------------------------------------------------------------------
  # Pre-flight checks
  # -------------------------------------------------------------------

  def preflight_checks do
    [
      check_database(),
      check_meilisearch(),
      check_elixir_version(),
      check_otp_version()
    ]
  end

  defp check_database do
    try do
      Repo.query!("SELECT 1")
      %{name: "PostgreSQL", status: "ok", detail: "Connected", optional: false}
    rescue
      e ->
        %{name: "PostgreSQL", status: "error", detail: Exception.message(e), optional: false}
    end
  end

  defp check_meilisearch do
    url = Application.get_env(:forge_nexus, :meilisearch_url, "http://localhost:7700")

    case Req.get("#{url}/health", receive_timeout: 3_000) do
      {:ok, %{status: 200}} ->
        %{name: "Meilisearch", status: "ok", detail: "Connected — fast search enabled", optional: true}

      _ ->
        %{name: "Meilisearch", status: "warn", detail: "Not reachable — search will use PostgreSQL fallback", optional: true}
    end
  rescue
    _ ->
      %{name: "Meilisearch", status: "warn", detail: "Not reachable — search will use PostgreSQL fallback", optional: true}
  end

  defp check_elixir_version do
    version = System.version()
    %{name: "Elixir", status: "ok", detail: "v#{version}", optional: false}
  end

  defp check_otp_version do
    version = :erlang.system_info(:otp_release) |> List.to_string()
    %{name: "Erlang/OTP", status: "ok", detail: "OTP #{version}", optional: false}
  end

  # -------------------------------------------------------------------
  # Installation detection
  # -------------------------------------------------------------------

  def installed? do
    admin_by_trust =
      from(u in User, where: u.trust_level >= 4, limit: 1)
      |> Repo.exists?()

    if admin_by_trust do
      true
    else
      from(u in User,
        join: m in UserGroupMembership, on: m.user_id == u.id,
        join: g in UserGroup, on: g.id == m.group_id,
        where: g.is_staff == true,
        limit: 1
      )
      |> Repo.exists?()
    end
  end

  # -------------------------------------------------------------------
  # Validation
  # -------------------------------------------------------------------

  def validate_setup_params(params) do
    required = ~w(admin_username admin_email admin_password site_name)
    missing =
      Enum.filter(required, fn key ->
        value = Map.get(params, key) || Map.get(params, String.to_atom(key))
        is_nil(value) or (is_binary(value) and String.trim(value) == "")
      end)

    case missing do
      [] -> :ok
      fields -> {:error, Enum.map(fields, &"#{&1} is required")}
    end
  end

  # -------------------------------------------------------------------
  # Main setup
  # -------------------------------------------------------------------

  def run_setup(params) do
    params = normalize_params(params)

    with :ok <- validate_setup_params(params) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Multi.new()
      |> Multi.run(:check_not_installed, fn _repo, _changes ->
        if installed?(), do: {:error, :already_installed}, else: {:ok, :not_installed}
      end)
      |> Multi.insert(:admin, fn _changes ->
        %User{}
        |> User.registration_changeset(%{
          username: params["admin_username"],
          email: params["admin_email"],
          password: params["admin_password"],
          display_name: params["admin_display_name"] || params["admin_username"]
        })
        |> Ecto.Changeset.put_change(:trust_level, 4)
        |> Ecto.Changeset.put_change(:email_verified_at, now)
      end)
      |> Multi.insert(:admin_group, fn _changes ->
        %UserGroup{}
        |> UserGroup.changeset(%{
          name: "Administrators",
          slug: "administrators",
          description: "Site administrators with full access",
          color: "#ef4444",
          is_staff: true,
          is_default: false,
          position: 0
        })
      end)
      |> Multi.insert(:members_group, fn _changes ->
        %UserGroup{}
        |> UserGroup.changeset(%{
          name: "Members",
          slug: "members",
          description: "Default group for all registered members",
          color: "#3b82f6",
          is_staff: false,
          is_default: true,
          position: 1
        })
      end)
      |> Multi.insert(:admin_membership, fn %{admin: admin, admin_group: group} ->
        %UserGroupMembership{}
        |> UserGroupMembership.changeset(%{user_id: admin.id, group_id: group.id})
      end)
      |> Multi.run(:site_settings, fn _repo, _changes ->
        save_site_settings(params)
      end)
      |> Multi.run(:email_settings, fn _repo, _changes ->
        save_email_settings(params)
      end)
      |> Multi.run(:feature_settings, fn _repo, _changes ->
        save_feature_settings(params)
      end)
      |> Multi.run(:default_forums, fn _repo, _changes ->
        forums = Map.get(params, "forums")
        create_forums(forums)
      end)
      |> Multi.run(:default_theme, fn _repo, %{admin: admin} ->
        create_default_theme(admin.id)
      end)
      |> Multi.run(:slash_commands, fn _repo, _changes ->
        seed_slash_commands()
      end)
      |> Multi.insert(:default_currency, fn _changes ->
        %Currency{}
        |> Currency.changeset(%{
          name: "Points",
          slug: "points",
          icon: "star",
          is_default: true
        })
      end)
      |> Multi.run(:setup_search, fn _repo, _changes ->
        setup_search_indexes()
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{admin: admin, site_settings: site_name}} ->
          {:ok, %{admin: admin, site_name: site_name}}

        {:error, :check_not_installed, :already_installed, _changes} ->
          {:error, :already_installed}

        {:error, step, changeset_or_reason, _changes} ->
          {:error, {step, changeset_or_reason}}
      end
    end
  end

  # -------------------------------------------------------------------
  # Settings helpers
  # -------------------------------------------------------------------

  defp save_site_settings(params) do
    settings = [
      {"site_name", params["site_name"]},
      {"site_description", params["site_description"] || "A modern forum community"},
      {"site_tagline", params["site_tagline"] || ""},
      {"site_url", params["site_url"] || ""},
      {"site_logo_url", params["site_logo_url"] || ""}
    ]

    upsert_settings(settings)
    {:ok, params["site_name"]}
  end

  defp save_email_settings(params) do
    email = Map.get(params, "email", %{})

    if email != %{} and Map.get(email, "smtp_host", "") != "" do
      settings = [
        {"smtp_host", Map.get(email, "smtp_host", "")},
        {"smtp_port", Map.get(email, "smtp_port", "587")},
        {"smtp_username", Map.get(email, "smtp_username", "")},
        {"smtp_password", Map.get(email, "smtp_password", "")},
        {"smtp_from_address", Map.get(email, "from_address", "")},
        {"smtp_from_name", Map.get(email, "from_name", params["site_name"] || "ForgeNexus")},
        {"smtp_encryption", Map.get(email, "encryption", "tls")}
      ]

      upsert_settings(settings)
    end

    {:ok, :email_configured}
  end

  defp save_feature_settings(params) do
    features = Map.get(params, "features", %{})

    if features != %{} do
      settings =
        Enum.map(features, fn {key, value} -> {key, to_string(value)} end)

      upsert_settings(settings)
    end

    {:ok, :features_configured}
  end

  defp upsert_settings(settings) do
    Enum.each(settings, fn {key, value} ->
      %SiteSetting{}
      |> SiteSetting.changeset(%{key: key, value: value || "", value_type: "string"})
      |> Repo.insert!(on_conflict: :replace_all, conflict_target: :key)
    end)
  end

  # -------------------------------------------------------------------
  # Forum creation
  # -------------------------------------------------------------------

  defp create_forums(nil), do: create_default_forums()
  defp create_forums([]), do: create_default_forums()

  defp create_forums(custom_forums) when is_list(custom_forums) do
    Enum.with_index(custom_forums)
    |> Enum.each(fn {cat_data, cat_idx} ->
      cat_name = Map.get(cat_data, "name", "Category #{cat_idx + 1}")
      cat_slug = Slug.slugify(cat_name) || "category-#{cat_idx}"
      cat_color = Map.get(cat_data, "color", default_category_color(cat_idx))

      {:ok, category} =
        %Category{}
        |> Category.changeset(%{
          name: cat_name,
          slug: cat_slug,
          position: cat_idx,
          color: cat_color,
          is_visible: true
        })
        |> Repo.insert()

      forums = Map.get(cat_data, "forums", [])
      Enum.with_index(forums)
      |> Enum.each(fn {forum_data, forum_idx} ->
        forum_name = if is_binary(forum_data), do: forum_data, else: Map.get(forum_data, "name", "Forum #{forum_idx + 1}")
        forum_desc = if is_binary(forum_data), do: "", else: Map.get(forum_data, "description", "")
        forum_slug = Slug.slugify(forum_name) || "forum-#{forum_idx}"

        %Forum{}
        |> Forum.changeset(%{
          name: forum_name,
          slug: forum_slug,
          description: forum_desc,
          position: forum_idx,
          category_id: category.id,
          is_visible: true
        })
        |> Repo.insert!()
      end)
    end)

    {:ok, :forums_created}
  rescue
    e ->
      Logger.warning("Custom forum creation failed, falling back to defaults: #{inspect(e)}")
      create_default_forums()
  end

  defp create_default_forums do
    categories_and_forums = [
      {"General", "general", 0, "#6366f1", [
        {"Announcements", "announcements", "Official announcements and news", 0},
        {"General Discussion", "general-discussion", "Talk about anything and everything", 1},
        {"Introductions", "introductions", "Introduce yourself to the community", 2}
      ]},
      {"Community", "community", 1, "#8b5cf6", [
        {"Events & Contests", "events-contests", "Community events, contests, and giveaways", 0},
        {"Feedback & Suggestions", "feedback-suggestions", "Share your ideas to improve the community", 1}
      ]},
      {"Off Topic", "off-topic", 2, "#a855f7", [
        {"The Lounge", "the-lounge", "Casual conversation and off-topic chat", 0}
      ]}
    ]

    Enum.each(categories_and_forums, fn {cat_name, cat_slug, cat_pos, cat_color, forums} ->
      {:ok, category} =
        %Category{}
        |> Category.changeset(%{
          name: cat_name,
          slug: cat_slug,
          position: cat_pos,
          color: cat_color,
          is_visible: true
        })
        |> Repo.insert()

      Enum.each(forums, fn {forum_name, forum_slug, forum_desc, forum_pos} ->
        %Forum{}
        |> Forum.changeset(%{
          name: forum_name,
          slug: forum_slug,
          description: forum_desc,
          position: forum_pos,
          category_id: category.id,
          is_visible: true
        })
        |> Repo.insert!()
      end)
    end)

    {:ok, :forums_created}
  end

  defp default_category_color(0), do: "#6366f1"
  defp default_category_color(1), do: "#8b5cf6"
  defp default_category_color(2), do: "#a855f7"
  defp default_category_color(3), do: "#ec4899"
  defp default_category_color(4), do: "#f59e0b"
  defp default_category_color(_), do: "#3b82f6"

  # -------------------------------------------------------------------
  # Theme
  # -------------------------------------------------------------------

  defp create_default_theme(admin_id) do
    %Theme{}
    |> Theme.changeset(%{
      name: "Dark",
      slug: "dark",
      description: "Default dark theme",
      is_default: true,
      is_active: true,
      position: 0,
      created_by_id: admin_id,
      variables: %{
        "bg_primary" => "#0f0f0f",
        "bg_secondary" => "#1a1a1a",
        "bg_tertiary" => "#252525",
        "bg_hover" => "#2a2a2a",
        "bg_card" => "#1e1e1e",
        "bg_input" => "#1a1a1a",
        "accent" => "#6366f1",
        "accent_glow" => "rgba(99,102,241,0.4)",
        "accent_hover" => "#818cf8",
        "accent_dim" => "#4f46e5",
        "text_primary" => "#f5f5f5",
        "text_secondary" => "#a3a3a3",
        "text_muted" => "#737373",
        "text_link" => "#818cf8",
        "text_link_hover" => "#a5b4fc",
        "border_color" => "#2a2a2a",
        "border_accent" => "#6366f1"
      }
    })
    |> Repo.insert()
  end

  # -------------------------------------------------------------------
  # Search index setup (optional)
  # -------------------------------------------------------------------

  defp setup_search_indexes do
    if Code.ensure_loaded?(ForgeNexus.Search) and
       function_exported?(ForgeNexus.Search, :setup_indexes, 0) do
      case ForgeNexus.Search.setup_indexes() do
        {:ok, _} -> {:ok, :search_indexes_created}
        _ -> {:ok, :search_skipped}
      end
    else
      {:ok, :search_skipped}
    end
  rescue
    _ -> {:ok, :search_skipped}
  end

  # -------------------------------------------------------------------
  # Slash commands
  # -------------------------------------------------------------------

  defp seed_slash_commands do
    if Code.ensure_loaded?(ForgeNexus.Plugins.SlashCommands) and
       function_exported?(ForgeNexus.Plugins.SlashCommands, :seed_built_in_commands, 0) do
      ForgeNexus.Plugins.SlashCommands.seed_built_in_commands()
    end

    {:ok, :commands_seeded}
  end

  # -------------------------------------------------------------------
  # Params normalization
  # -------------------------------------------------------------------

  defp normalize_params(params) do
    flat =
      Map.new(params, fn
        {key, value} when is_atom(key) -> {Atom.to_string(key), value}
        {key, value} -> {key, value}
      end)

    # Flatten nested "site" and "admin" keys from the frontend wizard payload
    site = Map.get(flat, "site", %{})
    admin = Map.get(flat, "admin", %{})

    flat
    |> maybe_put("site_name", Map.get(site, "name"))
    |> maybe_put("site_description", Map.get(site, "description"))
    |> maybe_put("site_tagline", Map.get(site, "tagline"))
    |> maybe_put("site_url", Map.get(site, "url"))
    |> maybe_put("site_logo_url", Map.get(site, "logo_url"))
    |> maybe_put("admin_username", Map.get(admin, "username"))
    |> maybe_put("admin_email", Map.get(admin, "email"))
    |> maybe_put("admin_password", Map.get(admin, "password"))
    |> maybe_put("admin_display_name", Map.get(admin, "display_name"))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put_new(map, key, value)
end
