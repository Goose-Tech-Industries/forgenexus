alias ForgeNexus.Repo
alias ForgeNexus.Accounts.{User, UserGroup, UserGroupMembership, Rank}
alias ForgeNexus.Forums.{Category, Forum}

# --- User Groups ---
IO.puts("Seeding user groups...")

admin_group =
  Repo.insert!(%UserGroup{
    name: "Administrators",
    slug: "administrators",
    description: "Full site access and control",
    color: "#e74c3c",
    icon: "shield",
    is_staff: true,
    position: 0,
    permissions: %{"admin" => true}
  })

mod_group =
  Repo.insert!(%UserGroup{
    name: "Moderators",
    slug: "moderators",
    description: "Forum moderation powers",
    color: "#3498db",
    icon: "gavel",
    is_staff: true,
    position: 1,
    permissions: %{"moderate" => true}
  })

member_group =
  Repo.insert!(%UserGroup{
    name: "Members",
    slug: "members",
    description: "Registered members",
    color: "#2ecc71",
    icon: "user",
    is_default: true,
    position: 2,
    permissions: %{}
  })

# --- Ranks ---
IO.puts("Seeding ranks...")

ranks = [
  %Rank{title: "Fresh Meat", min_posts: 0, position: 0},
  %Rank{title: "Newcomer", min_posts: 10, position: 1},
  %Rank{title: "Regular", min_posts: 50, position: 2},
  %Rank{title: "Veteran", min_posts: 200, position: 3},
  %Rank{title: "Elite", min_posts: 500, position: 4},
  %Rank{title: "Legend", min_posts: 1000, position: 5},
  %Rank{title: "Mythic", min_posts: 5000, position: 6}
]

Enum.each(ranks, &Repo.insert!/1)

# --- Admin User ---
IO.puts("Seeding admin user...")

admin_user =
  Repo.insert!(%User{
    username: "admin",
    email: "admin@forgenexus.local",
    password_hash: Bcrypt.hash_pwd_salt("admin123"),
    display_name: "Administrator",
    slug: "admin",
    status: "active",
    trust_level: 4
  })

Repo.insert!(%UserGroupMembership{user_id: admin_user.id, group_id: admin_group.id})

# Set admin's primary group
admin_user
|> Ecto.Changeset.change(primary_group_id: admin_group.id)
|> Repo.update!()

# --- Demo User ---
demo_user =
  Repo.insert!(%User{
    username: "DarkSide",
    email: "darkside@forgenexus.local",
    password_hash: Bcrypt.hash_pwd_salt("demo123"),
    display_name: "DarkSide",
    slug: "darkside",
    status: "active",
    trust_level: 1
  })

Repo.insert!(%UserGroupMembership{user_id: demo_user.id, group_id: member_group.id})

# --- Categories & Forums ---
IO.puts("Seeding categories and forums...")

# General category
general =
  Repo.insert!(%Category{
    name: "General",
    slug: "general",
    description: "General discussion and community talk",
    icon: "message-circle",
    color: "#00d4aa",
    position: 0
  })

Repo.insert!(%Forum{
  name: "Announcements",
  slug: "announcements",
  description: "Official news and updates from the team",
  icon: "megaphone",
  category_id: general.id,
  position: 0
})

Repo.insert!(%Forum{
  name: "General Discussion",
  slug: "general-discussion",
  description: "Talk about anything and everything",
  icon: "message-circle",
  category_id: general.id,
  position: 1
})

Repo.insert!(%Forum{
  name: "Introductions",
  slug: "introductions",
  description: "New here? Say hello!",
  icon: "hand-wave",
  category_id: general.id,
  position: 2
})

# Community category
community =
  Repo.insert!(%Category{
    name: "Community",
    slug: "community",
    description: "Events, contests, and community activities",
    icon: "users",
    color: "#7c3aed",
    position: 1
  })

Repo.insert!(%Forum{
  name: "Events & Contests",
  slug: "events-contests",
  description: "Community events, giveaways, and competitions",
  icon: "trophy",
  category_id: community.id,
  position: 0
})

Repo.insert!(%Forum{
  name: "Feedback & Suggestions",
  slug: "feedback-suggestions",
  description: "Help us improve ForgeNexus",
  icon: "lightbulb",
  category_id: community.id,
  position: 1
})

# Tech category
tech =
  Repo.insert!(%Category{
    name: "Technology",
    slug: "technology",
    description: "Programming, hardware, and tech discussion",
    icon: "cpu",
    color: "#0ea5e9",
    position: 2
  })

Repo.insert!(%Forum{
  name: "Programming",
  slug: "programming",
  description: "Code, frameworks, and dev talk",
  icon: "code",
  category_id: tech.id,
  position: 0
})

Repo.insert!(%Forum{
  name: "Hardware & Builds",
  slug: "hardware-builds",
  description: "PC builds, components, and tech reviews",
  icon: "monitor",
  category_id: tech.id,
  position: 1
})

# Off Topic
offtopic =
  Repo.insert!(%Category{
    name: "Off Topic",
    slug: "off-topic",
    description: "The lounge — anything goes (within reason)",
    icon: "coffee",
    color: "#f59e0b",
    position: 3
  })

Repo.insert!(%Forum{
  name: "The Lounge",
  slug: "the-lounge",
  description: "Chill and chat about whatever",
  icon: "sofa",
  category_id: offtopic.id,
  position: 0
})

Repo.insert!(%Forum{
  name: "Media & Entertainment",
  slug: "media-entertainment",
  description: "Movies, music, games, and more",
  icon: "film",
  category_id: offtopic.id,
  position: 1
})

IO.puts("Seeding complete!")
IO.puts("Admin login: admin@forgenexus.local / admin123")
IO.puts("Demo login: darkside@forgenexus.local / demo123")
