<script lang="ts">
  import { api } from '$lib/api/client';
  import { page } from '$app/stores';

  type Period = 'today' | 'week' | 'month' | 'all';

  let threads = $state<any[]>([]);
  let loading = $state(true);
  let activePeriod = $state<Period>('week');

  const tabs: { label: string; value: Period }[] = [
    { label: 'Today', value: 'today' },
    { label: 'This Week', value: 'week' },
    { label: 'This Month', value: 'month' },
    { label: 'All Time', value: 'all' }
  ];

  $effect(() => {
    loadTrending(activePeriod);
  });

  async function loadTrending(period: Period) {
    loading = true;
    try {
      const data = await api.getTrendingThreads(period);
      threads = data.threads || [];
    } catch (err) {
      console.error('Failed to load trending threads:', err);
      threads = [];
    }
    loading = false;
  }

  function switchTab(period: Period) {
    activePeriod = period;
  }

  function timeAgo(dateStr: string): string {
    if (!dateStr) return '';
    const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    if (diff < 2592000) return `${Math.floor(diff / 86400)}d ago`;
    return new Date(dateStr).toLocaleDateString();
  }

  function getInitial(username: string): string {
    return username?.charAt(0)?.toUpperCase() || '?';
  }
</script>

<svelte:head>
  <title>Trending Threads - ForgeNexus</title>
</svelte:head>

<div class="trending-page">
  <div class="page-header">
    <h1>Trending Threads</h1>
    <p class="subtitle">Discover the most active discussions</p>
  </div>

  <div class="tab-bar">
    {#each tabs as tab (tab.value)}
      <button
        class="tab-btn"
        class:active={activePeriod === tab.value}
        onclick={() => switchTab(tab.value)}
      >
        {tab.label}
      </button>
    {/each}
  </div>

  {#if loading}
    <div class="loading">Loading trending threads...</div>
  {:else if threads.length === 0}
    <div class="empty">No trending threads found for this period.</div>
  {:else}
    <div class="thread-list">
      {#each threads as thread, idx (thread.id)}
        <a href="/threads/{thread.slug}" class="thread-row">
          <div class="thread-rank">#{idx + 1}</div>
          <div class="thread-avatar">
            {#if thread.user?.avatar_url}
              <img src={thread.user.avatar_url} alt={thread.user.username} />
            {:else}
              <span class="avatar-initial">{getInitial(thread.user?.username)}</span>
            {/if}
          </div>
          <div class="thread-info">
            <div class="thread-title-row">
              <span class="thread-title">{thread.title}</span>
              {#if thread.is_pinned}
                <span class="badge pin">Pinned</span>
              {/if}
              {#if thread.is_locked}
                <span class="badge lock">Locked</span>
              {/if}
            </div>
            <div class="thread-meta">
              <span class="meta-author">by {thread.user?.username}</span>
              <span class="meta-sep">&middot;</span>
              <span class="meta-forum">{thread.forum?.name}</span>
              <span class="meta-sep">&middot;</span>
              <span class="meta-time">{timeAgo(thread.last_post_at || thread.inserted_at)}</span>
            </div>
          </div>
          <div class="thread-stats-col">
            <div class="stat">
              <strong>{thread.reply_count}</strong>
              <span>replies</span>
            </div>
            <div class="stat">
              <strong>{thread.view_count}</strong>
              <span>views</span>
            </div>
          </div>
        </a>
      {/each}
    </div>
  {/if}
</div>

<style>
  .trending-page {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .page-header h1 {
    font-size: 22px;
    font-weight: 800;
    color: var(--text-primary);
  }

  .subtitle {
    font-size: 13px;
    color: var(--text-muted);
    margin-top: 2px;
  }

  .tab-bar {
    display: flex;
    gap: 4px;
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 4px;
  }

  .tab-btn {
    flex: 1;
    padding: 8px 16px;
    border: none;
    border-radius: var(--radius);
    background: transparent;
    color: var(--text-secondary);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    font-family: inherit;
    transition: all 0.15s;
  }

  .tab-btn:hover {
    background: var(--bg-tertiary);
    color: var(--text-primary);
  }

  .tab-btn.active {
    background: var(--accent);
    color: var(--bg-primary);
  }

  .thread-list {
    display: flex;
    flex-direction: column;
    gap: 2px;
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    overflow: hidden;
  }

  .thread-row {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 16px;
    text-decoration: none;
    transition: background 0.1s;
    border-bottom: 1px solid var(--border-color);
  }

  .thread-row:last-child {
    border-bottom: none;
  }

  .thread-row:hover {
    background: var(--bg-hover);
  }

  .thread-rank {
    font-size: 14px;
    font-weight: 800;
    color: var(--accent);
    min-width: 28px;
    text-align: center;
  }

  .thread-avatar {
    width: 40px;
    height: 40px;
    border-radius: var(--radius);
    background: var(--bg-tertiary);
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .thread-avatar img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .avatar-initial {
    font-size: 16px;
    font-weight: 700;
    color: var(--text-muted);
  }

  .thread-info {
    flex: 1;
    min-width: 0;
  }

  .thread-title-row {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .thread-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .badge {
    font-size: 10px;
    font-weight: 700;
    padding: 1px 5px;
    border-radius: 3px;
    text-transform: uppercase;
    flex-shrink: 0;
  }

  .badge.pin {
    background: #fbbf24;
    color: #000;
  }

  .badge.lock {
    background: #ef4444;
    color: #fff;
  }

  .thread-meta {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 12px;
    color: var(--text-muted);
    margin-top: 2px;
  }

  .meta-forum {
    color: var(--accent);
    text-decoration: none;
  }

  .meta-forum:hover {
    text-decoration: underline;
  }

  .thread-stats-col {
    display: flex;
    gap: 16px;
    flex-shrink: 0;
  }

  .stat {
    display: flex;
    flex-direction: column;
    align-items: center;
    min-width: 50px;
  }

  .stat strong {
    font-size: 14px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .stat span {
    font-size: 10px;
    color: var(--text-muted);
    text-transform: uppercase;
  }

  .loading, .empty {
    text-align: center;
    padding: 48px 0;
    color: var(--text-muted);
    font-size: 14px;
  }

  @media (max-width: 640px) {
    .thread-stats-col {
      display: none;
    }

    .thread-rank {
      font-size: 12px;
      min-width: 20px;
    }
  }
</style>
