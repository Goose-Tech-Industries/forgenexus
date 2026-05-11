<script lang="ts">
  import { api } from '$lib/api/client';
  import Shoutbox from '$lib/components/chat/Shoutbox.svelte';
  import SocialFeed from '$lib/components/home/SocialFeed.svelte';
  import WelcomeCenter from '$lib/components/home/WelcomeCenter.svelte';
  import WhosOnline from '$lib/components/home/WhosOnline.svelte';
  import TodaysStats from '$lib/components/home/TodaysStats.svelte';
  import UsernameDisplay from '$lib/components/common/UsernameDisplay.svelte';
  import Skeleton from '$lib/components/common/Skeleton.svelte';
  import { siteSettings } from '$lib/stores/settings.svelte';
  import { auth } from '$lib/stores/auth.svelte';
  import { socketStore } from '$lib/stores/socket.svelte';
  import { onDestroy } from 'svelte';

  let viewMode = $state<'forums' | 'feed'>(
    typeof localStorage !== 'undefined'
      ? ((localStorage.getItem('home:viewMode') as 'forums' | 'feed') || 'feed')
      : 'feed'
  );

  $effect(() => {
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem('home:viewMode', viewMode);
    }
  });

  interface Forum {
    id: string;
    name: string;
    slug: string;
    description: string;
    icon: string;
    thread_count: number;
    post_count: number;
    last_post_at: string | null;
    last_post_user: {
      username: string;
      slug: string;
      username_color: string | null;
      username_effect: string | null;
    } | null;
    viewers_count: number;
    parent_id: string | null;
    children?: Forum[];
  }

  interface Category {
    id: string;
    name: string;
    slug: string;
    description: string;
    icon: string;
    color: string;
    forums: Forum[];
  }

  let categories = $state<Category[]>([]);
  let unreadCounts = $state<Record<string, number>>({});
  let welcomeStats = $state<any>(null);
  let loading = $state(true);

  $effect(() => {
    loadData();
  });

  async function loadData() {
    // Load forums and welcome stats in parallel
    const [forumsData, statsData] = await Promise.allSettled([
      api.getForums(),
      api.getWelcomeStats()
    ]);

    if (forumsData.status === 'fulfilled') {
      categories = forumsData.value.categories || [];
      unreadCounts = forumsData.value.unread_counts || {};
    }
    if (statsData.status === 'fulfilled') {
      welcomeStats = statsData.value;
    }

    loading = false;
  }

  // --- Realtime forum index updates ---
  // Listens for `forum_updated` broadcasts from the backend and applies the
  // delta to the loaded categories so counters refresh without a hard reload.
  let forumIndexChannel: any = null;
  $effect(() => {
    const phoenixSocket = socketStore.getSocket();
    if (!phoenixSocket) return;
    if (forumIndexChannel) return;
    forumIndexChannel = phoenixSocket.channel('forums:index', {});
    forumIndexChannel.on('forum_updated', (payload: any) => {
      const { forum_id, delta, last_post_at, last_post_user_id } = payload;
      categories = categories.map((cat) => ({
        ...cat,
        forums: cat.forums.map((f) => applyDelta(f, forum_id, delta, last_post_at, last_post_user_id))
      }));
    });
    forumIndexChannel.join();
  });

  function applyDelta(forum: Forum, forumId: string, delta: any, lastPostAt: string, lastPostUserId: string | null): Forum {
    if (forum.id !== forumId) {
      if (forum.children?.length) {
        return { ...forum, children: forum.children.map((c) => applyDelta(c, forumId, delta, lastPostAt, lastPostUserId)) };
      }
      return forum;
    }
    return {
      ...forum,
      thread_count: forum.thread_count + (delta.thread_count ?? 0),
      post_count: forum.post_count + (delta.post_count ?? 0),
      last_post_at: lastPostAt
    };
  }

  onDestroy(() => {
    if (forumIndexChannel) {
      forumIndexChannel.leave();
      forumIndexChannel = null;
    }
  });

  let hasUnread = $derived(Object.values(unreadCounts).some(c => c > 0));
  let markingAllRead = $state(false);

  async function markAllForumsRead() {
    markingAllRead = true;
    try {
      await api.markAllForumsRead();
      unreadCounts = {};
    } catch (err) {
      console.error('Failed to mark all forums read:', err);
    }
    markingAllRead = false;
  }

  function timeAgo(dateStr: string | null): string {
    if (!dateStr) return 'Never';
    const date = new Date(dateStr);
    const now = new Date();
    const diff = Math.floor((now.getTime() - date.getTime()) / 1000);
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return date.toLocaleDateString();
  }
</script>

<div class="home-layout">
  <!-- View toggle -->
  <div class="view-toggle glass">
    <button class="toggle-btn" class:active={viewMode === 'feed'} onclick={() => viewMode = 'feed'}>
      <span>🏠</span> Feed
    </button>
    <button class="toggle-btn" class:active={viewMode === 'forums'} onclick={() => viewMode = 'forums'}>
      <span>💬</span> Forums
    </button>
  </div>

  <div class="home-content">
    <div class="home-main">
      {#if viewMode === 'feed'}
        <!-- Social Feed View -->
        <SocialFeed />
      {:else}
        <!-- Forum View -->
        <div class="forum-index">
          <!-- Welcome Center -->
          <WelcomeCenter />

          <!-- Shoutbox -->
          {#if siteSettings.shoutboxEnabled}
            <Shoutbox />
          {/if}

          {#if !loading && auth.isLoggedIn && hasUnread}
            <div class="index-toolbar">
              <button class="btn-mark-all-read" onclick={markAllForumsRead} disabled={markingAllRead}>
                {markingAllRead ? 'Marking...' : 'Mark All Read'}
              </button>
            </div>
          {/if}

  {#if loading}
    <div class="skeleton-loading">
      {#each [1, 2] as _}
        <div class="skeleton-category">
          <Skeleton width="200px" height="24px" rounded />
          <div class="skeleton-table">
            {#each [1, 2, 3] as __}
              <div class="skeleton-row">
                <Skeleton width="60%" height="14px" />
                <Skeleton width="40%" height="11px" />
              </div>
            {/each}
          </div>
        </div>
      {/each}
    </div>
  {:else}
    {#each categories as category (category.id)}
      <!-- Category block -->
      <div class="category-block">
        <div class="category-header" style="border-left-color: {category.color}">
          <h2>{category.name}</h2>
          {#if category.description}
            <span class="category-desc">{category.description}</span>
          {/if}
        </div>

        <table class="forum-table">
          <thead>
            <tr class="forum-table-header">
              <th style="width: 50%">Forum</th>
              <th class="stat-col">Threads</th>
              <th class="stat-col">Posts</th>
              <th>Last Post</th>
            </tr>
          </thead>
          <tbody>
            {#each category.forums as forum (forum.id)}
              <tr class="forum-table-row">
                <td>
                  <div class="forum-info">
                    <div class="forum-icon" style="color: {category.color}">
                      &#128172;
                    </div>
                    <div>
                      <a href="/forums/{forum.slug}" class="forum-name">
                        {forum.name}
                        {#if unreadCounts[forum.id]}
                          <span class="unread-badge">{unreadCounts[forum.id]}</span>
                        {/if}
                      </a>
                      {#if forum.description}
                        <div class="forum-desc">{forum.description}</div>
                      {/if}
                      {#if forum.children?.length}
                        <div class="subforum-links">
                          <span class="subforum-label">Sub-forums:</span>
                          {#each forum.children as child, i}
                            <a href="/forums/{child.slug}" class="subforum-link">{child.name}</a>{#if i < forum.children.length - 1}<span class="subforum-sep">,</span>{/if}
                          {/each}
                        </div>
                      {/if}
                    </div>
                  </div>
                </td>
                <td class="stat-cell">
                  <div class="count">{forum.thread_count}</div>
                  <div class="label">Threads</div>
                </td>
                <td class="stat-cell">
                  <div class="count">{forum.post_count}</div>
                  <div class="label">Posts</div>
                </td>
                <td class="lastpost-cell">
                  {#if forum.last_post_at}
                    <div class="last-post-info">
                      <span class="post-time">{timeAgo(forum.last_post_at)}</span>
                      {#if forum.last_post_user}
                        <span class="last-post-by">
                          by <UsernameDisplay
                            username={forum.last_post_user.username}
                            color={forum.last_post_user.username_color}
                            effect={forum.last_post_user.username_effect}
                            href="/profile/{forum.last_post_user.slug}"
                            size="small"
                          />
                        </span>
                      {/if}
                    </div>
                  {:else}
                    <span class="no-posts">No posts yet</span>
                  {/if}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/each}
  {/if}

          <!-- Today's Stats Bar -->
          <TodaysStats stats={welcomeStats} />
        </div>
      {/if}
    </div>

    <!-- Sidebar -->
    <aside class="home-sidebar">
      <WhosOnline />

      <div class="sidebar-card glass">
        <h3 class="sidebar-heading">Quick Links</h3>
        <a href="/search" class="sidebar-link">🔍 Search</a>
        <a href="/members" class="sidebar-link">👥 Members</a>
        <a href="/trending" class="sidebar-link">🔥 Trending</a>
        <a href="/new-posts" class="sidebar-link">📰 New Posts</a>
        <a href="/live" class="sidebar-link">🎙 Voice Rooms</a>
        <a href="/stats" class="sidebar-link">📊 Statistics</a>
      </div>

      {#if auth.isLoggedIn}
        <div class="sidebar-card glass">
          <h3 class="sidebar-heading">Your Activity</h3>
          <div class="sidebar-stat">
            <span>Posts</span>
            <strong>{auth.user?.post_count || 0}</strong>
          </div>
          <div class="sidebar-stat">
            <span>Threads</span>
            <strong>{auth.user?.thread_count || 0}</strong>
          </div>
          <div class="sidebar-stat">
            <span>Points</span>
            <strong>{auth.user?.points || 0}</strong>
          </div>
          <div class="sidebar-stat">
            <span>Rep</span>
            <strong>{auth.user?.reputation || 0}</strong>
          </div>
        </div>
      {/if}
    </aside>
  </div>
</div>

<style>
  .home-layout { max-width: 1200px; margin: 0 auto; padding: 16px; }

  .view-toggle {
    display: flex; gap: 4px; margin-bottom: 16px;
    padding: 4px; border-radius: var(--radius-lg);
    width: fit-content;
  }

  .toggle-btn {
    display: flex; align-items: center; gap: 6px;
    padding: 8px 20px; border-radius: var(--radius-md);
    border: none; background: transparent; color: var(--text-muted);
    font-size: 14px; font-weight: 600; cursor: pointer;
    transition: all var(--transition-fast);
  }

  .toggle-btn:hover { background: var(--bg-hover); color: var(--text-primary); }
  .toggle-btn.active {
    background: var(--accent-gradient); color: var(--bg-primary);
    box-shadow: 0 2px 8px var(--accent-glow);
  }

  .home-content { display: flex; gap: 20px; }
  .home-main { flex: 1; min-width: 0; }

  .home-sidebar {
    width: 280px; flex-shrink: 0;
    display: flex; flex-direction: column; gap: 12px;
  }

  .sidebar-card { padding: 14px; }

  .sidebar-heading {
    font-size: 12px; font-weight: 700; text-transform: uppercase;
    letter-spacing: 0.06em; color: var(--accent); margin-bottom: 10px;
  }

  .sidebar-link {
    display: block; padding: 6px 0;
    font-size: 13px; color: var(--text-secondary);
    text-decoration: none; transition: color var(--transition-fast);
  }

  .sidebar-link:hover { color: var(--accent); }

  .sidebar-stat {
    display: flex; justify-content: space-between; padding: 4px 0;
    font-size: 13px; color: var(--text-secondary);
  }

  .sidebar-stat strong { color: var(--text-primary); }

  @media (max-width: 900px) {
    .home-content { flex-direction: column; gap: 12px; }
    .home-sidebar { width: 100%; }
  }

  @media (max-width: 768px) {
    .home-content { gap: 10px; }
    .toggle-btn { padding: 8px 14px; font-size: 13px; }
    .sidebar-card { padding: 10px; }
    .sidebar-heading { font-size: 11px; margin-bottom: 6px; }
    .sidebar-link, .sidebar-stat { font-size: 12px; }
    .forum-icon { font-size: 18px; }
    .forum-name { font-size: 13px; }
    .category-desc { margin-left: 0; font-size: 11px; }
  }

  @media (max-width: 600px) {
    .home-content { gap: 8px; }
    .home-main { padding: 0; }
  }

  .forum-index {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .category-block {
    margin-bottom: 8px;
  }

  .category-desc {
    font-size: 12px;
    color: var(--text-secondary);
    font-weight: 400;
    margin-left: 12px;
  }

  .stat-col {
    width: 80px;
    text-align: center;
  }

  .forum-info {
    display: flex;
    align-items: flex-start;
    gap: 12px;
  }

  .forum-icon {
    font-size: 24px;
    margin-top: 2px;
  }

  .forum-name {
    font-size: 14px;
    font-weight: 700;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    margin-bottom: 2px;
  }

  .unread-badge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 18px;
    height: 18px;
    padding: 0 5px;
    border-radius: 9px;
    background: var(--accent);
    color: var(--bg-primary);
    font-size: 10px;
    font-weight: 700;
    line-height: 1;
  }

  .forum-desc {
    font-size: 12px;
    color: var(--text-secondary);
  }

  .subforum-links {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 2px;
    margin-top: 3px;
    font-size: 11px;
  }

  .subforum-label {
    color: var(--text-muted);
    font-weight: 600;
    margin-right: 2px;
  }

  .subforum-link {
    color: var(--text-secondary);
    font-weight: 500;
  }

  .subforum-link:hover {
    color: var(--accent);
  }

  .subforum-sep {
    color: var(--text-muted);
    margin-right: 2px;
  }

  .no-posts {
    color: var(--text-muted);
    font-style: italic;
    font-size: 12px;
  }

  .post-time {
    font-size: 12px;
    color: var(--text-secondary);
  }

  .last-post-info {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .last-post-by {
    font-size: 11px;
    color: var(--text-muted);
    display: flex;
    align-items: center;
    gap: 3px;
  }

  .loading {
    text-align: center;
    padding: 60px 0;
    color: var(--text-muted);
  }

  .index-toolbar {
    display: flex;
    justify-content: flex-end;
  }

  .btn-mark-all-read {
    padding: 4px 12px;
    border-radius: var(--radius, 6px);
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    border: 1px solid var(--border-color);
    background: var(--bg-tertiary);
    color: var(--accent);
    transition: all 0.15s;
  }
  .btn-mark-all-read:hover:not(:disabled) {
    background: var(--bg-hover);
    color: var(--accent);
  }
  .btn-mark-all-read:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .skeleton-loading {
    display: flex;
    flex-direction: column;
    gap: 24px;
    padding: 16px 0;
  }

  .skeleton-category {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .skeleton-table {
    display: flex;
    flex-direction: column;
    gap: 16px;
    padding: 12px 16px;
    background: var(--bg-secondary);
    border-radius: var(--radius, 6px);
    border: 1px solid var(--border-color);
  }

  .skeleton-row {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
</style>
