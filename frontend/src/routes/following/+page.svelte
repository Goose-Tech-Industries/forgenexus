<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';

  let posts = $state<any[]>([]);
  let loading = $state(true);
  let loadingMore = $state(false);
  let hasMore = $state(true);

  $effect(() => {
    if (auth.isLoggedIn) loadFeed();
  });

  async function loadFeed() {
    loading = true;
    try {
      const data = await api.getFollowingFeed(25, 0);
      posts = data.posts || [];
      hasMore = posts.length >= 25;
    } catch (err) {
      console.error('Failed to load feed:', err);
    }
    loading = false;
  }

  async function loadMore() {
    if (loadingMore || !hasMore) return;
    loadingMore = true;
    try {
      const data = await api.getFollowingFeed(25, posts.length);
      const newPosts = data.posts || [];
      posts = [...posts, ...newPosts];
      hasMore = newPosts.length >= 25;
    } catch (err) {
      console.error('Failed to load more:', err);
    }
    loadingMore = false;
  }

  function timeAgo(dateStr: string): string {
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

  function truncateBody(html: string, maxLen = 200): string {
    const text = html.replace(/<[^>]*>/g, '');
    return text.length > maxLen ? text.substring(0, maxLen) + '...' : text;
  }
</script>

<svelte:head>
  <title>Following Feed - ForgeNexus</title>
</svelte:head>

<div class="following-page">
  <h1 class="page-title">Following Feed</h1>
  <p class="page-desc">Recent posts from users you follow</p>

  {#if !auth.isLoggedIn}
    <div class="empty-state">
      <p>Please <a href="/auth/login">log in</a> to see your following feed.</p>
    </div>
  {:else if loading}
    <div class="loading">Loading feed...</div>
  {:else if posts.length === 0}
    <div class="empty-state">
      <p>No posts to show. Follow some users to see their activity here!</p>
      <a href="/members" class="btn btn-primary">Browse Members</a>
    </div>
  {:else}
    <div class="feed-list">
      {#each posts as post (post.id)}
        <div class="feed-item">
          <div class="feed-avatar">
            {#if post.user.avatar_url}
              <img src={post.user.avatar_url} alt={post.user.username} />
            {:else}
              <span class="avatar-initial">{getInitial(post.user.username)}</span>
            {/if}
          </div>
          <div class="feed-content">
            <div class="feed-header">
              <a href="/profile/{post.user.slug}" class="feed-username" style:color={post.user.username_color || undefined}>
                {post.user.username}
              </a>
              <span class="feed-action">posted in</span>
              <a href="/threads/{post.thread.slug}" class="feed-thread-title">{post.thread.title}</a>
            </div>
            <div class="feed-meta">
              <a href="/forums/{post.thread.forum.slug}" class="feed-forum">{post.thread.forum.name}</a>
              <span class="feed-time">{timeAgo(post.inserted_at)}</span>
            </div>
            <div class="feed-body">
              {truncateBody(post.body_html || post.body)}
            </div>
          </div>
        </div>
      {/each}
    </div>

    {#if hasMore}
      <div class="load-more">
        <button class="btn btn-secondary" onclick={loadMore} disabled={loadingMore}>
          {loadingMore ? 'Loading...' : 'Load More'}
        </button>
      </div>
    {/if}
  {/if}
</div>

<style>
  .following-page {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .page-title {
    font-size: 20px;
    font-weight: 800;
    color: var(--text-primary);
  }

  .page-desc {
    font-size: 13px;
    color: var(--text-muted);
    margin-top: -8px;
  }

  .feed-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .feed-item {
    display: flex;
    gap: 12px;
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 14px;
    transition: border-color 0.15s;
  }
  .feed-item:hover {
    border-color: var(--border-accent, var(--accent));
  }

  .feed-avatar {
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
  .feed-avatar img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
  .avatar-initial {
    font-size: 18px;
    color: var(--text-muted);
    font-weight: 600;
  }

  .feed-content {
    flex: 1;
    min-width: 0;
  }

  .feed-header {
    font-size: 13px;
    display: flex;
    align-items: baseline;
    gap: 4px;
    flex-wrap: wrap;
  }

  .feed-username {
    font-weight: 700;
    color: var(--accent);
    text-decoration: none;
  }
  .feed-username:hover {
    text-decoration: underline;
  }

  .feed-action {
    color: var(--text-muted);
  }

  .feed-thread-title {
    font-weight: 600;
    color: var(--text-primary);
    text-decoration: none;
  }
  .feed-thread-title:hover {
    color: var(--accent);
  }

  .feed-meta {
    display: flex;
    gap: 8px;
    font-size: 11px;
    color: var(--text-muted);
    margin-top: 2px;
  }

  .feed-forum {
    color: var(--text-muted);
    text-decoration: none;
  }
  .feed-forum:hover {
    color: var(--accent);
  }

  .feed-body {
    font-size: 13px;
    color: var(--text-secondary);
    line-height: 1.5;
    margin-top: 6px;
    overflow: hidden;
    text-overflow: ellipsis;
    display: -webkit-box;
    -webkit-line-clamp: 3;
    -webkit-box-orient: vertical;
  }

  .empty-state {
    text-align: center;
    padding: 60px 0;
    color: var(--text-muted);
    font-size: 14px;
  }
  .empty-state a {
    color: var(--accent);
  }

  .loading {
    text-align: center;
    padding: 60px 0;
    color: var(--text-muted);
  }

  .load-more {
    text-align: center;
    padding: 12px 0;
  }

  .btn {
    padding: 8px 20px;
    border-radius: var(--radius);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    border: none;
    transition: all 0.15s;
  }
  .btn-primary {
    background: var(--accent);
    color: var(--bg-primary);
    margin-top: 12px;
    display: inline-block;
    text-decoration: none;
  }
  .btn-primary:hover {
    background: var(--accent-hover);
  }
  .btn-secondary {
    background: var(--bg-tertiary);
    color: var(--text-primary);
    border: 1px solid var(--border-color);
  }
  .btn-secondary:hover:not(:disabled) {
    border-color: var(--accent);
    color: var(--accent);
  }
  .btn:disabled {
    opacity: 0.5;
    cursor: default;
  }
</style>
