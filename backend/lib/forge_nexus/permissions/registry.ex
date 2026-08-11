defmodule ForgeNexus.Permissions.Registry do
  @moduledoc """
  Canonical registry of every permission flag recognised by the platform.

  Each entry is a tuple:

      {key, default_for_member_role, label, description, category}

  - `key` — atom used everywhere in the codebase / serialised as a map key
  - `default_for_member_role` — boolean default for the baseline `:member` role
  - `label` — short UI label
  - `description` — long form help text for admin UIs
  - `category` — one of #{inspect(~w(posting moderation administration profile messaging creator)a)}

  This module is the single source of truth. Anything adding a permission should
  add it here first, then `ForgeNexus.Permissions.Roles` will inherit it.
  """

  @categories ~w(posting moderation administration profile messaging creator)a

  @permissions [
    # --- Posting ---
    {:create_thread, true, "Create Threads", "Start new threads in forums", :posting},
    {:reply_to_thread, true, "Reply to Threads", "Post replies in existing threads", :posting},
    {:edit_own_post, true, "Edit Own Posts", "Edit posts you authored", :posting},
    {:delete_own_post, false, "Delete Own Posts", "Remove posts you authored", :posting},
    {:use_bbcode, true, "Use BBCode", "Use BBCode formatting tags in posts", :posting},
    {:upload_attachment, true, "Upload Attachments", "Attach files to posts", :posting},
    {:create_poll, true, "Create Polls", "Attach polls to threads", :posting},
    {:use_reactions, true, "Use Reactions", "React to posts with emoji", :posting},
    {:rate_post, true, "Rate Posts", "Give post ratings / karma", :posting},
    {:view_private_threads, false, "View Private Threads",
     "Read private threads you are invited to", :posting},

    # --- Moderation ---
    {:edit_any_post, false, "Edit Any Post", "Edit posts authored by other users", :moderation},
    {:delete_any_post, false, "Delete Any Post", "Remove posts authored by other users",
     :moderation},
    {:lock_thread, false, "Lock Threads", "Prevent further replies in a thread", :moderation},
    {:pin_thread, false, "Pin Threads", "Sticky a thread to the top of a forum", :moderation},
    {:move_thread, false, "Move Threads", "Relocate threads between forums", :moderation},
    {:merge_thread, false, "Merge Threads", "Combine two threads into one", :moderation},
    {:warn_user, false, "Warn Users", "Issue warnings against users", :moderation},
    {:ban_user, false, "Ban Users", "Ban users from the community", :moderation},
    {:view_reports, false, "View Reports", "Access the moderation report queue", :moderation},
    {:view_ip, false, "View IP Addresses", "See IP addresses in logs / profiles", :moderation},

    # --- Administration ---
    {:manage_forums, false, "Manage Forums", "Create, edit and delete forum categories",
     :administration},
    {:manage_users, false, "Manage Users", "Edit users, groups and permissions", :administration},
    {:manage_webhooks, false, "Manage Webhooks", "Configure outbound webhooks", :administration},
    {:manage_settings, false, "Manage Settings", "Change site configuration", :administration},
    {:access_admin, false, "Access Admin Panel", "Open the admin control panel", :administration},
    {:impersonate_user, false, "Impersonate Users", "Log in as another user for support",
     :administration},

    # --- Profile ---
    {:customize_profile, true, "Customize Profile", "Edit avatar, bio and profile fields",
     :profile},
    {:use_signature, true, "Use Signature", "Display a signature below posts", :profile},
    {:change_username, false, "Change Username", "Rename your own account", :profile},

    # --- Messaging ---
    {:send_dm, true, "Send Direct Messages", "Send private messages to other users", :messaging},
    {:create_group_chat, true, "Create Group Chats", "Start group conversations", :messaging},

    # --- Creator ---
    {:monetize_content, false, "Monetize Content", "Gate content behind paid tiers", :creator},
    {:create_subscription_tier, false, "Create Subscription Tiers",
     "Define paid subscription tiers", :creator}
  ]

  @doc "All permission keys as atoms, in registration order."
  def all_permissions, do: Enum.map(@permissions, fn {k, _, _, _, _} -> k end)

  @doc "All permission entries (the raw tuples) — useful for admin UIs."
  def entries, do: @permissions

  @doc "All known category atoms."
  def categories, do: @categories

  @doc """
  Default permission map for the baseline `:member` role.

  Returns a map of `%{permission_key => boolean}`.
  """
  def default_permissions do
    for {key, default, _l, _d, _c} <- @permissions, into: %{}, do: {key, default}
  end

  @doc """
  Return the permission map for a given role, delegating to
  `ForgeNexus.Permissions.Roles.compute/1`.
  """
  def permissions_for_role(role) when is_atom(role) do
    ForgeNexus.Permissions.Roles.compute(role)
  end

  @doc """
  Return `{label, description, category}` for a given permission key, or
  `:error` if the key is not registered.
  """
  def describe(key) when is_atom(key) do
    case Enum.find(@permissions, fn {k, _, _, _, _} -> k == key end) do
      nil ->
        :error

      {_k, _d, label, description, category} ->
        %{label: label, description: description, category: category}
    end
  end

  @doc "Filter the registry to entries matching a category."
  def by_category(category) when category in @categories do
    Enum.filter(@permissions, fn {_k, _d, _l, _desc, c} -> c == category end)
  end
end
