<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';
  import UsernameDisplay from '$lib/components/common/UsernameDisplay.svelte';

  interface FeedItem {
    type: string;
    id: string;
    data: any;
    inserted_at: string;
  }

  let items = $state<FeedItem[]>([]);
  let loading = $state(true);
  let filter = $state('all');
  let newPostBody = $state('');
  let posting = $state(false);

  const filters = [
    { key: 'all', label: 'All', icon: '🏠' },
    { key: 'posts', label: 'Posts', icon: '💬' },
    { key: 'threads', label: 'Threads', icon: '📋' },
    { key: 'clips', label: 'Clips', icon: '🎬' },
    { key: 'live', label: 'Live', icon: '🔴' },
    { key: 'polls', label: 'Polls', icon: '📊' },
  ];

  $effect(() => {
    loadFeed();
  });

  async function loadFeed() {
    loading = true;
    try {
      const data = await api.request(`/feed?filter=${filter}`);
      items = data.items || [];
    } catch (e) {
      console.error('Failed to load feed:', e);
    }
    loading = false;
  }

  async function likePost(item: FeedItem) {
    try {
      await api.request(`/feed/${item.id}/like`, { method: 'POST' });
      item.data.like_count = (item.data.like_count || 0) + 1;
      item.data.liked = true;
      items = [...items];
    } catch { /* silent */ }
  }

  let commentingId = $state<string | null>(null);
  let commentBody = $state('');

  async function submitComment(item: FeedItem) {
    if (!commentBody.trim()) return;
    try {
      await api.request(`/feed/${item.id}/comment`, { method: 'POST', body: JSON.stringify({ body: commentBody }) });
      item.data.comment_count = (item.data.comment_count || 0) + 1;
      items = [...items];
      commentBody = '';
      commentingId = null;
    } catch { /* silent */ }
  }

  async function submitPost() {
    if (!newPostBody.trim() || posting) return;
    posting = true;
    try {
      await api.request('/feed/status', {
        method: 'POST',
        body: JSON.stringify({ body: newPostBody })
      });
      newPostBody = '';
      await loadFeed();
    } catch (e) {
      console.error('Failed to post:', e);
    }
    posting = false;
  }

  function selectFilter(f: string) {
    filter = f;
    loadFeed();
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

  function getItemIcon(type: string): string {
    const icons: Record<string, string> = {
      status_post: '💬', thread: '📋', clip: '🎬', announcement: '📢',
      achievement: '🏆', poll: '📊', live_room: '🔴'
    };
    return icons[type] || '📄';
  }
</script>

<div class="social-feed">
  <!-- Status composer -->
  {#if auth.isLoggedIn}
    <div class="compose-box glass">
      <div class="compose-avatar">
        {#if auth.user?.avatar_url}
          <img src={auth.user.avatar_url} alt="" class="avatar" width="40" height="40" />
        {:else}
          <div class="avatar-placeholder">{auth.user?.username?.[0]?.toUpperCase() || '?'}</div>
        {/if}
      </div>
      <div class="compose-input-wrap">
        <textarea
          bind:value={newPostBody}
          placeholder="What's on your mind?"
          class="compose-input input"
          rows="2"
          maxlength="500"
          onkeydown={(e) => { if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) submitPost(); }}
        ></textarea>
        <div class="compose-actions">
          <span class="char-count">{newPostBody.length}/500</span>
          <button class="btn btn-primary" onclick={submitPost} disabled={posting || !newPostBody.trim()}>
            {posting ? 'Posting...' : 'Post'}
          </button>
        </div>
      </div>
    </div>
  {/if}

  <!-- Filter tabs -->
  <div class="feed-filters">
    {#each filters as f}
      <button
        class="filter-tab"
        class:active={filter === f.key}
        onclick={() => selectFilter(f.key)}
      >
        <span class="filter-icon">{f.icon}</span>
        <span>{f.label}</span>
      </button>
    {/each}
  </div>

  <!-- Feed items -->
  <div class="feed-items stagger">
    {#if loading}
      {#each Array(5) as _}
        <div class="skeleton feed-skeleton"></div>
      {/each}
    {:else if items.length === 0}
      <div class="feed-empty glass">
        <p>Nothing here yet. Be the first to post!</p>
      </div>
    {:else}
      {#each items as item (item.id)}
        <div class="feed-item card card-glow slide-up">
          <div class="feed-item-header">
            <span class="feed-item-icon">{getItemIcon(item.type)}</span>
            <span class="feed-item-type">{item.type.replace('_', ' ')}</span>
            <span class="feed-item-time">{timeAgo(item.inserted_at)}</span>
          </div>

          <div class="feed-item-body">
            {#if item.type === 'status_post'}
              <p class="feed-text">{item.data.body}</p>
            {:else if item.type === 'thread'}
              <a href="/threads/{item.data.slug}" class="feed-thread-link">
                <strong>{item.data.title}</strong>
                <span class="feed-meta">💬 {item.data.reply_count} replies · 👁 {item.data.view_count} views</span>
              </a>
            {:else if item.type === 'clip'}
              <div class="feed-clip">
                <strong>{item.data.title || 'Clip'}</strong>
                <span class="feed-meta">🎬 {Math.round((item.data.end_ms - item.data.start_ms) / 1000)}s · 👁 {item.data.view_count} views</span>
              </div>
            {:else if item.type === 'announcement'}
              <div class="feed-announcement neon-border">
                <strong>{item.data.title}</strong>
                <p>{@html item.data.body?.slice(0, 200)}</p>
              </div>
            {:else if item.type === 'achievement'}
              <div class="feed-achievement">
                <span class="achievement-icon">🏆</span>
                <span>Badge earned!</span>
              </div>
            {:else if item.type === 'poll'}
              <div class="feed-poll">
                <strong>📊 {item.data.question}</strong>
                <span class="feed-meta">{item.data.voter_count || 0} votes</span>
              </div>
            {:else if item.type === 'live_room'}
              <div class="feed-live">
                <span class="badge badge-live">LIVE</span>
                <strong>{item.data.name}</strong>
                <span class="feed-meta">{item.data.participant_count} in room</span>
              </div>
            {:else}
              <p>{JSON.stringify(item.data).slice(0, 200)}</p>
            {/if}
          </div>

          {#if item.type === 'status_post'}
            <div class="feed-item-actions">
              <button class="btn btn-ghost" class:liked={item.data.liked} onclick={() => likePost(item)}>❤️ {item.data.like_count || 0}</button>
              <button class="btn btn-ghost" onclick={() => { commentingId = commentingId === item.id ? null : item.id; }}>💬 {item.data.comment_count || 0}</button>
            </div>
            {#if commentingId === item.id}
              <div class="comment-input-row">
                <input type="text" placeholder="Write a comment..." bind:value={commentBody} class="comment-input" onkeydown={(e) => { if (e.key === 'Enter') submitComment(item); }} />
                <button class="btn btn-sm" onclick={() => submitComment(item)}>Post</button>
              </div>
            {/if}
          {/if}
        </div>
      {/each}
    {/if}
  </div>
</div>

<style>
  .social-feed { max-width: 680px; margin: 0 auto; }

  .compose-box {
    display: flex; gap: 12px; padding: 16px; margin-bottom: 16px;
  }

  .compose-avatar { flex-shrink: 0; }
  .avatar-placeholder {
    width: 40px; height: 40px; border-radius: 50%;
    background: var(--accent-muted); color: var(--accent);
    display: flex; align-items: center; justify-content: center;
    font-weight: 700; font-size: 16px;
  }

  .compose-input-wrap { flex: 1; display: flex; flex-direction: column; gap: 8px; }

  .compose-input {
    resize: none; font-family: var(--font-body);
    background: var(--bg-input); border: 1px solid var(--border-color);
    border-radius: var(--radius-md); padding: 10px 14px;
    color: var(--text-primary); font-size: 14px;
  }

  .compose-input:focus {
    border-color: var(--accent);
    box-shadow: 0 0 0 3px var(--accent-glow);
    outline: none;
  }

  .compose-actions {
    display: flex; justify-content: space-between; align-items: center;
  }

  .char-count { font-size: 12px; color: var(--text-muted); }

  .feed-filters {
    display: flex; gap: 4px; margin-bottom: 16px;
    padding: 4px; background: var(--bg-card); border-radius: var(--radius-lg);
    border: 1px solid var(--border-color);
  }

  .filter-tab {
    flex: 1; display: flex; align-items: center; justify-content: center; gap: 6px;
    padding: 8px 12px; border-radius: var(--radius-md);
    border: none; background: transparent; color: var(--text-muted);
    font-size: 13px; font-weight: 500; cursor: pointer;
    transition: all var(--transition-fast);
  }

  .filter-tab:hover { background: var(--bg-hover); color: var(--text-primary); }
  .filter-tab.active {
    background: var(--accent-muted); color: var(--accent);
    font-weight: 600;
  }

  .filter-icon { font-size: 14px; }

  .feed-items { display: flex; flex-direction: column; gap: 8px; }

  .feed-skeleton { height: 80px; border-radius: var(--radius-lg); }

  .feed-empty { padding: 40px; text-align: center; color: var(--text-muted); }

  .feed-item { padding: 14px 16px; }

  .feed-item-header {
    display: flex; align-items: center; gap: 8px; margin-bottom: 8px;
    font-size: 12px; color: var(--text-muted);
  }

  .feed-item-icon { font-size: 14px; }
  .feed-item-type { text-transform: capitalize; font-weight: 500; }
  .feed-item-time { margin-left: auto; }

  .feed-item-body { font-size: 14px; line-height: 1.6; }

  .feed-text { color: var(--text-primary); white-space: pre-wrap; }

  .feed-thread-link {
    display: flex; flex-direction: column; gap: 4px;
    color: var(--text-primary); text-decoration: none;
  }

  .feed-thread-link:hover strong { color: var(--accent); }

  .feed-meta { font-size: 12px; color: var(--text-muted); }

  .feed-announcement { padding: 12px; border-radius: var(--radius-md); }
  .feed-announcement p { margin-top: 6px; color: var(--text-secondary); font-size: 13px; }

  .feed-live {
    display: flex; align-items: center; gap: 10px;
  }

  .feed-item-actions {
    display: flex; gap: 8px; margin-top: 10px; padding-top: 8px;
    border-top: 1px solid var(--border-color);
  }

  .feed-item-actions .btn { font-size: 13px; padding: 4px 10px; }
  .feed-item-actions .btn.liked { color: #ef4444; }
  .comment-input-row { display: flex; gap: 6px; margin-top: 8px; }
  .comment-input { flex: 1; padding: 6px 8px; font-size: 12px; background: var(--bg-input); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); }
  .comment-input:focus { outline: none; border-color: var(--accent); }
  .btn-sm { padding: 4px 10px; font-size: 11px; }

  @media (max-width: 768px) {
    .social-feed { max-width: 100%; padding: 0 4px; }
    .compose-box { padding: 12px; gap: 8px; margin-bottom: 12px; }
    .compose-avatar .avatar-placeholder { width: 36px; height: 36px; font-size: 14px; }
    .compose-input { font-size: 16px; padding: 8px 12px; min-height: 60px; }
    .compose-actions { flex-wrap: wrap; gap: 6px; }
    .feed-filters { gap: 2px; padding: 2px; margin-bottom: 12px; overflow-x: auto; }
    .filter-tab { padding: 8px 10px; font-size: 12px; min-height: 40px; white-space: nowrap; }
    .filter-icon { font-size: 13px; }
    .feed-item { padding: 12px; }
    .feed-item-header { font-size: 11px; flex-wrap: wrap; }
    .feed-item-time { margin-left: auto; flex-shrink: 0; }
    .feed-item-body { font-size: 14px; }
    .feed-item-actions { flex-wrap: wrap; gap: 4px; }
    .feed-item-actions :global(.btn) { font-size: 12px; padding: 6px 10px; min-height: 36px; }
    .comment-input-row { flex-direction: column; gap: 4px; }
    .comment-input { font-size: 14px; padding: 8px; min-height: 36px; }
    .btn-sm { min-height: 36px; padding: 6px 14px; font-size: 12px; }
    .feed-thread-link strong { word-break: break-word; }
  }
</style>
