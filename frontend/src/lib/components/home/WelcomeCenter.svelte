<script lang="ts">
  import { auth } from '$lib/stores/auth.svelte';
  import { api } from '$lib/api/client';
  import UsernameDisplay from '$lib/components/common/UsernameDisplay.svelte';
  import AvatarFrame from '$lib/components/common/AvatarFrame.svelte';
  import { notificationStore } from '$lib/stores/notifications.svelte';

  interface WelcomeStats {
    total_members: number;
    total_threads: number;
    total_posts: number;
    online_count: number;
    newest_member: {
      username: string;
      slug: string;
      avatar_url: string | null;
      username_color: string | null;
      username_effect: string | null;
      inserted_at: string;
    } | null;
    recent_threads: Array<{
      id: string;
      title: string;
      slug: string;
      author: {
        username: string;
        slug: string;
        username_color: string | null;
        username_effect: string | null;
      };
      last_post_at: string;
      reply_count: number;
    }>;
    new_members_this_week: Array<{
      username: string;
      slug: string;
      avatar_url: string | null;
      username_color: string | null;
      username_effect: string | null;
    }>;
  }

  let stats = $state<WelcomeStats | null>(null);
  let collapsed = $state(false);
  let loading = $state(true);
  let loadError = $state(false);

  // Checklist for new members
  let checklist = $derived.by(() => {
    if (!auth.user) return [];
    const u = auth.user;
    return [
      { label: 'Set your avatar', done: !!u.avatar_url, link: '/settings' },
      { label: 'Write an introduction', done: (u.post_count ?? 0) > 0, link: '/forums' },
      { label: 'Customize your profile', done: !!(u.nameplate_color || u.avatar_frame), link: '/settings' },
      { label: 'Pick a theme', done: !!u.theme_id, link: '/settings' },
    ];
  });

  let checklistProgress = $derived(
    checklist.length > 0 ? Math.round((checklist.filter(c => c.done).length / checklist.length) * 100) : 0
  );

  let isNewMember = $derived.by(() => {
    if (!auth.user) return false;
    const joined = new Date(auth.user.inserted_at);
    const daysAgo = (Date.now() - joined.getTime()) / (1000 * 60 * 60 * 24);
    return daysAgo < 7 || (auth.user.post_count ?? 0) < 5;
  });

  // Load collapsed state from localStorage on init (not in $effect to avoid race)
  if (typeof window !== 'undefined') {
    const saved = localStorage.getItem('fn_welcome_collapsed');
    if (saved !== null) collapsed = saved === 'true';
  }

  $effect(() => {
    loadStats();
  });

  async function loadStats() {
    try {
      const data = await api.getWelcomeStats();
      stats = data;
    } catch {
      loadError = true;
    }
    loading = false;
  }

  function toggleCollapse() {
    collapsed = !collapsed;
    localStorage.setItem('fn_welcome_collapsed', String(collapsed));
  }

  function timeAgo(dateStr: string): string {
    const date = new Date(dateStr);
    const now = new Date();
    const diff = Math.floor((now.getTime() - date.getTime()) / 1000);
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return date.toLocaleDateString();
  }
</script>

<div class="welcome-center">
  <button class="welcome-header" onclick={toggleCollapse} aria-expanded={!collapsed}>
    <div class="welcome-title-row">
      <h2>
        {#if !auth.isLoggedIn}
          Welcome to <span class="accent">ForgeNexus</span>
        {:else}
          Welcome back, <span class="accent">{auth.user?.display_name || auth.user?.username}</span>
        {/if}
      </h2>
      <span class="collapse-icon" class:rotated={collapsed}>&#9660;</span>
    </div>
    {#if !auth.isLoggedIn}
      <p class="welcome-subtitle">The next generation community platform</p>
    {:else if auth.user}
      <p class="welcome-subtitle">
        Member since {new Date(auth.user.inserted_at).toLocaleDateString()}
        {#if stats}
          &middot; {stats.online_count} {stats.online_count === 1 ? 'user' : 'users'} online
        {/if}
        {#if notificationStore.unreadCount > 0}
          &middot; <span
            class="notif-pill"
            role="button"
            tabindex="0"
            onclick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              (document.querySelector('[aria-label^=Notifications]') as HTMLElement)?.click();
            }}
            onkeydown={(e) => {
              if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                e.stopPropagation();
                (document.querySelector('[aria-label^=Notifications]') as HTMLElement)?.click();
              }
            }}
          >
            🔔 <strong>{notificationStore.unreadCount}</strong> unread
          </span>
        {/if}
      </p>
    {/if}
  </button>

  {#if !collapsed}
    <div class="welcome-body">
      {#if loading}
        <div class="welcome-loading">Loading...</div>

      {:else if loadError && !auth.isLoggedIn}
        <!-- Fallback guest CTA when stats fail to load -->
        <div class="welcome-sections">
          <div class="welcome-section guest-cta">
            <div class="cta-content">
              <h3>Join our community</h3>
              <p>Connect with fellow members and start discussions</p>
              <div class="cta-buttons">
                <a href="/auth/register" class="btn btn-primary">Create Account</a>
                <a href="/auth/login" class="btn btn-secondary">Sign In</a>
              </div>
            </div>
          </div>
        </div>

      {:else if !auth.isLoggedIn}
        <!-- GUEST VIEW -->
        <div class="welcome-sections">
          <div class="welcome-section guest-cta">
            <div class="cta-content">
              <h3>Join our community</h3>
              {#if stats}
                <p>Connect with <strong>{(stats.total_members ?? 0).toLocaleString()}</strong> members in <strong>{(stats.total_threads ?? 0).toLocaleString()}</strong> discussions</p>
              {/if}
              <div class="cta-buttons">
                <a href="/auth/register" class="btn btn-primary">Create Account</a>
                <a href="/auth/login" class="btn btn-secondary">Sign In</a>
              </div>
            </div>
            {#if stats}
              <div class="quick-stats-grid">
                <div class="mini-stat">
                  <span class="mini-stat-value">{(stats.total_members ?? 0).toLocaleString()}</span>
                  <span class="mini-stat-label">Members</span>
                </div>
                <div class="mini-stat">
                  <span class="mini-stat-value">{(stats.total_posts ?? 0).toLocaleString()}</span>
                  <span class="mini-stat-label">Posts</span>
                </div>
                <div class="mini-stat">
                  <span class="mini-stat-value">{stats.online_count}</span>
                  <span class="mini-stat-label">Online Now</span>
                </div>
                <div class="mini-stat">
                  <span class="mini-stat-value">{(stats.total_threads ?? 0).toLocaleString()}</span>
                  <span class="mini-stat-label">Threads</span>
                </div>
              </div>
            {/if}
          </div>

          {#if stats?.recent_threads?.length}
            <div class="welcome-section">
              <h4>What's happening now</h4>
              <ul class="recent-threads">
                {#each stats.recent_threads.slice(0, 5) as thread}
                  <li>
                    <a href="/threads/{thread.slug}" class="thread-link">{thread.title}</a>
                    <span class="thread-meta">
                      by <UsernameDisplay
                        username={thread.author.username}
                        color={thread.author.username_color}
                        effect={thread.author.username_effect}
                        href="/profile/{thread.author.slug}"
                        size="small"
                      /> &middot; {timeAgo(thread.last_post_at)}
                      {#if thread.reply_count > 0}
                        &middot; {thread.reply_count} {thread.reply_count === 1 ? 'reply' : 'replies'}
                      {/if}
                    </span>
                  </li>
                {/each}
              </ul>
            </div>
          {/if}

          {#if stats?.newest_member}
            <div class="welcome-section newest-member-section">
              <h4>Newest Member</h4>
              <a href="/profile/{stats.newest_member.slug}" class="newest-member">
                <div class="member-avatar-small">
                  {#if stats.newest_member.avatar_url}
                    <img src={stats.newest_member.avatar_url} alt="" />
                  {:else}
                    <div class="avatar-placeholder">{stats.newest_member.username[0].toUpperCase()}</div>
                  {/if}
                </div>
                <UsernameDisplay
                  username={stats.newest_member.username}
                  color={stats.newest_member.username_color}
                  effect={stats.newest_member.username_effect}
                  size="normal"
                />
              </a>
            </div>
          {/if}
        </div>

      {:else if isNewMember}
        <!-- NEW MEMBER VIEW -->
        <div class="welcome-sections">
          <div class="welcome-section getting-started">
            <h4>Getting Started</h4>
            <div class="progress-bar-container">
              <div class="progress-bar" style="width: {checklistProgress}%"></div>
              <span class="progress-text">{checklistProgress}% complete</span>
            </div>
            <ul class="checklist">
              {#each checklist as item}
                <li class:done={item.done}>
                  <span class="check-icon">{item.done ? '\u2713' : '\u25CB'}</span>
                  {#if item.done}
                    <span class="check-label done-label">{item.label}</span>
                  {:else}
                    <a href={item.link} class="check-label">{item.label}</a>
                  {/if}
                </li>
              {/each}
            </ul>
          </div>

          {#if stats?.new_members_this_week?.length}
            <div class="welcome-section">
              <h4>Joined this week</h4>
              <div class="new-members-grid">
                {#each stats.new_members_this_week.slice(0, 8) as member}
                  <a href="/profile/{member.slug}" class="new-member-chip">
                    <div class="member-avatar-tiny">
                      {#if member.avatar_url}
                        <img src={member.avatar_url} alt="" />
                      {:else}
                        <div class="avatar-placeholder-tiny">{member.username[0].toUpperCase()}</div>
                      {/if}
                    </div>
                    <UsernameDisplay
                      username={member.username}
                      color={member.username_color}
                      effect={member.username_effect}
                      size="small"
                    />
                  </a>
                {/each}
              </div>
            </div>
          {/if}

          {#if stats?.recent_threads?.length}
            <div class="welcome-section">
              <h4>Jump into the conversation</h4>
              <ul class="recent-threads">
                {#each stats.recent_threads.slice(0, 3) as thread}
                  <li>
                    <a href="/threads/{thread.slug}" class="thread-link">{thread.title}</a>
                    <span class="thread-meta">
                      {thread.reply_count} {thread.reply_count === 1 ? 'reply' : 'replies'} &middot; {timeAgo(thread.last_post_at)}
                    </span>
                  </li>
                {/each}
              </ul>
            </div>
          {/if}
        </div>

      {:else}
        <!-- REGULAR MEMBER VIEW -->
        <div class="welcome-sections">
          <div class="welcome-section member-overview">
            <div class="member-stats-row">
              {#if stats}
                <div class="member-stat">
                  <span class="member-stat-icon">&#128172;</span>
                  <div>
                    <span class="member-stat-value">{auth.user?.post_count ?? 0}</span>
                    <span class="member-stat-label">Your Posts</span>
                  </div>
                </div>
                <div class="member-stat">
                  <span class="member-stat-icon">&#11088;</span>
                  <div>
                    <span class="member-stat-value">{auth.user?.reputation ?? 0}</span>
                    <span class="member-stat-label">Reputation</span>
                  </div>
                </div>
                <div class="member-stat">
                  <span class="member-stat-icon">&#128101;</span>
                  <div>
                    <span class="member-stat-value">{stats.online_count}</span>
                    <span class="member-stat-label">Online Now</span>
                  </div>
                </div>
                <div class="member-stat">
                  <span class="member-stat-icon">&#128196;</span>
                  <div>
                    <span class="member-stat-value">{(stats.total_posts ?? 0).toLocaleString()}</span>
                    <span class="member-stat-label">Total Posts</span>
                  </div>
                </div>
              {/if}
            </div>
          </div>

          {#if stats?.recent_threads?.length}
            <div class="welcome-section">
              <h4>Latest Activity</h4>
              <ul class="recent-threads">
                {#each stats.recent_threads.slice(0, 5) as thread}
                  <li>
                    <a href="/threads/{thread.slug}" class="thread-link">{thread.title}</a>
                    <span class="thread-meta">
                      by <UsernameDisplay
                        username={thread.author.username}
                        color={thread.author.username_color}
                        effect={thread.author.username_effect}
                        href="/profile/{thread.author.slug}"
                        size="small"
                      /> &middot; {timeAgo(thread.last_post_at)}
                    </span>
                  </li>
                {/each}
              </ul>
            </div>
          {/if}

          {#if stats?.newest_member}
            <div class="welcome-section newest-member-section">
              <h4>Say hello to</h4>
              <a href="/profile/{stats.newest_member.slug}" class="newest-member">
                <div class="member-avatar-small">
                  {#if stats.newest_member.avatar_url}
                    <img src={stats.newest_member.avatar_url} alt="" />
                  {:else}
                    <div class="avatar-placeholder">{stats.newest_member.username[0].toUpperCase()}</div>
                  {/if}
                </div>
                <div>
                  <UsernameDisplay
                    username={stats.newest_member.username}
                    color={stats.newest_member.username_color}
                    effect={stats.newest_member.username_effect}
                    size="normal"
                  />
                  <div class="newest-member-label">Newest Member</div>
                </div>
              </a>
            </div>
          {/if}
        </div>

      {/if}

      <!-- Staff quick-access (always shown for staff) -->
      {#if auth.isStaff && stats}
        <div class="staff-quick-bar">
          <span class="staff-badge">STAFF</span>
          <a href="/mod">Mod Queue</a>
          <a href="/admin">Admin Panel</a>
          <a href="/admin/audit-trail">Audit Log</a>
        </div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .welcome-center {
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    overflow: hidden;
  }

  .welcome-header {
    display: flex;
    flex-direction: column;
    width: 100%;
    padding: 16px 20px;
    background: linear-gradient(135deg, var(--bg-secondary) 0%, rgba(0, 212, 170, 0.05) 100%);
    border: none;
    border-bottom: 1px solid var(--border-color);
    cursor: pointer;
    text-align: left;
    color: inherit;
    font-family: inherit;
  }
  .welcome-header:hover {
    background: linear-gradient(135deg, var(--bg-secondary) 0%, rgba(0, 212, 170, 0.08) 100%);
  }

  .welcome-title-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .welcome-title-row h2 {
    font-size: 18px;
    font-weight: 800;
    margin: 0;
  }

  .accent { color: var(--accent); }

  .collapse-icon {
    font-size: 10px;
    color: var(--text-muted);
    transition: transform 0.2s;
  }
  .collapse-icon.rotated { transform: rotate(-90deg); }

  .welcome-subtitle {
    font-size: 12px;
    color: var(--text-secondary);
    margin: 2px 0 0;
  }

  .welcome-body {
    padding: 16px 20px;
  }

  .welcome-loading {
    text-align: center;
    color: var(--text-muted);
    padding: 20px 0;
    font-size: 13px;
  }

  .welcome-sections {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
  }

  .welcome-section {
    padding: 12px;
    background: var(--bg-tertiary);
    border-radius: var(--radius);
    border: 1px solid var(--border-color);
  }
  .welcome-section h4 {
    font-size: 12px;
    text-transform: uppercase;
    color: var(--text-muted);
    margin: 0 0 8px;
    letter-spacing: 0.05em;
  }

  /* Guest CTA */
  .guest-cta {
    grid-column: 1 / -1;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 24px;
    padding: 20px;
  }
  .guest-cta h3 {
    font-size: 16px;
    font-weight: 700;
    margin: 0 0 6px;
  }
  .guest-cta p {
    font-size: 13px;
    color: var(--text-secondary);
    margin: 0 0 12px;
  }
  .cta-buttons {
    display: flex;
    gap: 8px;
  }
  .btn {
    padding: 8px 20px;
    border-radius: var(--radius);
    font-size: 13px;
    font-weight: 700;
    text-decoration: none;
    transition: all 0.15s;
  }
  .btn-primary {
    background: var(--accent);
    color: var(--bg-primary);
  }
  .btn-primary:hover { opacity: 0.9; }
  .btn-secondary {
    background: var(--bg-secondary);
    color: var(--text-primary);
    border: 1px solid var(--border-color);
  }
  .btn-secondary:hover { background: var(--bg-primary); }

  .quick-stats-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px;
    min-width: 200px;
  }
  .mini-stat {
    text-align: center;
    padding: 8px;
    background: var(--bg-primary);
    border-radius: var(--radius);
  }
  .mini-stat-value {
    display: block;
    font-size: 18px;
    font-weight: 800;
    color: var(--accent);
  }
  .mini-stat-label {
    font-size: 10px;
    color: var(--text-muted);
    text-transform: uppercase;
  }

  /* Recent threads */
  .recent-threads {
    list-style: none;
    padding: 0;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .recent-threads li {
    display: flex;
    flex-direction: column;
    gap: 1px;
  }
  .thread-link {
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary);
    text-decoration: none;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .thread-link:hover { color: var(--accent); }
  .thread-meta {
    font-size: 11px;
    color: var(--text-muted);
    display: flex;
    align-items: center;
    gap: 4px;
    flex-wrap: wrap;
  }

  /* Newest member */
  .newest-member-section {
    display: flex;
    flex-direction: column;
  }
  .newest-member {
    display: flex;
    align-items: center;
    gap: 10px;
    text-decoration: none;
    color: inherit;
    padding: 6px;
    border-radius: var(--radius);
    transition: background 0.15s;
  }
  .newest-member:hover { background: var(--bg-primary); }
  .newest-member-label {
    font-size: 10px;
    color: var(--text-muted);
  }

  .member-avatar-small {
    width: 36px;
    height: 36px;
    border-radius: 50%;
    overflow: hidden;
    flex-shrink: 0;
  }
  .member-avatar-small img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
  .avatar-placeholder {
    width: 100%;
    height: 100%;
    background: var(--accent);
    color: var(--bg-primary);
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 800;
    font-size: 16px;
  }

  /* Getting started checklist */
  .progress-bar-container {
    height: 20px;
    background: var(--bg-primary);
    border-radius: 10px;
    overflow: hidden;
    position: relative;
    margin-bottom: 10px;
  }
  .progress-bar {
    height: 100%;
    background: linear-gradient(90deg, var(--accent), #00e5b0);
    border-radius: 10px;
    transition: width 0.5s ease;
  }
  .progress-text {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    font-size: 10px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .checklist {
    list-style: none;
    padding: 0;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .checklist li {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 13px;
  }
  .checklist li.done { opacity: 0.5; }
  .check-icon {
    font-size: 14px;
    width: 18px;
    text-align: center;
  }
  .check-label {
    color: var(--text-primary);
    text-decoration: none;
  }
  .check-label:not(.done-label):hover { color: var(--accent); }
  .done-label { text-decoration: line-through; }

  /* New members grid */
  .new-members-grid {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }
  .new-member-chip {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 8px 4px 4px;
    background: var(--bg-primary);
    border-radius: 20px;
    text-decoration: none;
    color: inherit;
    transition: background 0.15s;
  }
  .new-member-chip:hover { background: var(--bg-secondary); }
  .member-avatar-tiny {
    width: 22px;
    height: 22px;
    border-radius: 50%;
    overflow: hidden;
    flex-shrink: 0;
  }
  .member-avatar-tiny img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
  .avatar-placeholder-tiny {
    width: 100%;
    height: 100%;
    background: var(--accent);
    color: var(--bg-primary);
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 700;
    font-size: 10px;
  }

  /* Member overview */
  .member-overview {
    grid-column: 1 / -1;
  }
  .member-stats-row {
    display: flex;
    gap: 16px;
    justify-content: space-around;
  }
  .member-stat {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .member-stat-icon { font-size: 20px; }
  .member-stat-value {
    font-size: 16px;
    font-weight: 800;
    color: var(--accent);
    display: block;
  }
  .member-stat-label {
    font-size: 10px;
    color: var(--text-muted);
    text-transform: uppercase;
  }

  /* Staff quick bar */
  .staff-quick-bar {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 10px 12px;
    margin-top: 12px;
    background: rgba(255, 107, 53, 0.08);
    border: 1px solid rgba(255, 107, 53, 0.2);
    border-radius: var(--radius);
    font-size: 12px;
  }
  .staff-badge {
    background: #ff6b35;
    color: white;
    padding: 2px 8px;
    border-radius: var(--radius);
    font-weight: 800;
    font-size: 10px;
    letter-spacing: 0.05em;
  }
  .staff-quick-bar a {
    color: var(--text-secondary);
    text-decoration: none;
    font-weight: 600;
  }
  .staff-quick-bar a:hover { color: var(--accent); }

  /* Mobile responsive */
  @media (max-width: 640px) {
    .welcome-sections {
      grid-template-columns: 1fr;
    }
    .guest-cta {
      flex-direction: column;
      text-align: center;
    }
    .cta-buttons { justify-content: center; }
    .quick-stats-grid { min-width: auto; }
    .member-stats-row {
      flex-wrap: wrap;
      justify-content: center;
    }
  }

.notif-pill {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 10px;
  background: var(--accent, #00d4aa);
  color: #000;
  border-radius: 999px;
  text-decoration: none;
  font-weight: 600;
}
.notif-pill:hover { filter: brightness(1.1); }
.notif-pill strong { font-weight: 800; }
</style>
