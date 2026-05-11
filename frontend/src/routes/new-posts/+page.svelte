<script lang="ts">
  import { api } from '$lib/api/client';

  let posts = $state<any[]>([]);
  let loading = $state(true);
  let error = $state('');

  $effect(() => { loadRecent(); });

  async function loadRecent() {
    loading = true;
    try {
      const data = await api.getRecentPosts(50);
      posts = data.posts || [];
    } catch (err: any) { error = err?.error || 'Failed to load recent posts'; }
    loading = false;
  }

  function timeAgo(dateStr: string): string {
    const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return new Date(dateStr).toLocaleDateString();
  }
</script>

<div class="new-posts-page">
  <h1 class="page-title">What's New</h1>
  <p class="page-desc">Recent posts across all forums</p>

  {#if loading}
    <div class="loading">Loading...</div>
  {:else if error}
    <div class="error-box">{error}</div>
  {:else if posts.length === 0}
    <div class="empty">No recent posts.</div>
  {:else}
    <div class="posts-list">
      {#each posts as post (post.id)}
        <div class="post-item">
          <div class="post-avatar">
            {#if post.user.avatar_url}
              <img src={post.user.avatar_url} alt={post.user.username} />
            {:else}
              <span>{post.user.username.charAt(0).toUpperCase()}</span>
            {/if}
          </div>
          <div class="post-info">
            <div class="post-header">
              <a href="/profile/{post.user.slug}" class="post-author">{post.user.username}</a>
              <span class="post-action">posted in</span>
              <a href="/threads/{post.thread.slug}" class="post-thread">{post.thread.title}</a>
            </div>
            <div class="post-meta">
              <a href="/forums/{post.forum.slug}" class="post-forum">{post.forum.name}</a>
              &middot; {timeAgo(post.inserted_at)}
            </div>
            {#if post.body}
              <p class="post-excerpt">{post.body}</p>
            {/if}
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .new-posts-page { display: flex; flex-direction: column; gap: 12px; }
  .page-title { font-size: 20px; font-weight: 800; color: var(--text-primary); }
  .page-desc { font-size: 13px; color: var(--text-secondary); }

  .posts-list { display: flex; flex-direction: column; gap: 4px; }
  .post-item { display: flex; gap: 10px; padding: 10px 12px; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius); }
  .post-avatar { width: 36px; height: 36px; border-radius: var(--radius); background: var(--bg-tertiary); display: flex; align-items: center; justify-content: center; flex-shrink: 0; overflow: hidden; font-size: 14px; font-weight: 700; color: var(--text-muted); }
  .post-avatar img { width: 100%; height: 100%; object-fit: cover; }
  .post-author { font-weight: 700; font-size: 13px; color: var(--text-link); }
  .post-action { font-size: 12px; color: var(--text-muted); margin: 0 4px; }
  .post-thread { font-size: 13px; font-weight: 600; color: var(--text-primary); }
  .post-meta { font-size: 11px; color: var(--text-muted); margin-top: 2px; }
  .post-forum { color: var(--text-secondary); }
  .post-excerpt { font-size: 12px; color: var(--text-secondary); margin-top: 4px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

  .empty, .loading { text-align: center; padding: 40px 0; color: var(--text-muted); }
</style>
