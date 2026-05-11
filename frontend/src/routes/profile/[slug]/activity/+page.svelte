<script lang="ts">
  import { page } from '$app/stores';
  import { api } from '$lib/api/client';
  import Breadcrumb from '$lib/components/layout/Breadcrumb.svelte';

  let posts = $state<any[]>([]);
  let threads = $state<any[]>([]);
  let loading = $state(true);
  let error = $state('');
  let tab = $state<'posts' | 'threads'>('posts');
  let slug = $derived($page.params.slug);

  $effect(() => {
    if (slug) loadActivity(slug);
  });

  async function loadActivity(s: string) {
    loading = true;
    try {
      const data = await api.getUserActivity(s);
      posts = data.activity?.posts || [];
      threads = data.activity?.threads || [];
    } catch (err: any) {
      if (err.status === 403) {
        error = 'This user\'s activity is private';
      } else {
        error = err?.error || 'Failed to load activity';
      }
    }
    loading = false;
  }

  function timeAgo(dateStr: string): string {
    const date = new Date(dateStr);
    const diff = Math.floor((Date.now() - date.getTime()) / 1000);
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return date.toLocaleDateString();
  }
</script>

<Breadcrumb crumbs={[
  { label: slug ?? '', href: `/profile/${slug}` },
  { label: 'Activity' }
]} />

<div class="activity-page">
  <h1 class="page-title">{slug}'s Activity</h1>

  <div class="tab-bar">
    <button class="tab" class:active={tab === 'posts'} onclick={() => tab = 'posts'}>
      Posts ({posts.length})
    </button>
    <button class="tab" class:active={tab === 'threads'} onclick={() => tab = 'threads'}>
      Threads ({threads.length})
    </button>
  </div>

  {#if loading}
    <div class="loading">Loading activity...</div>
  {:else if error}
    <div class="error-box">{error}</div>
  {:else if tab === 'posts'}
    {#if posts.length === 0}
      <div class="empty">No posts yet.</div>
    {:else}
      <div class="activity-list">
        {#each posts as post (post.id)}
          <div class="activity-item">
            <div class="activity-meta">
              <a href="/threads/{post.thread.slug}" class="activity-link">{post.thread.title}</a>
              <span class="activity-forum">in <a href="/forums/{post.thread.forum.slug}">{post.thread.forum.name}</a></span>
            </div>
            <p class="activity-excerpt">{post.body}</p>
            <span class="activity-time">{timeAgo(post.inserted_at)}</span>
          </div>
        {/each}
      </div>
    {/if}
  {:else}
    {#if threads.length === 0}
      <div class="empty">No threads yet.</div>
    {:else}
      <div class="activity-list">
        {#each threads as thread (thread.id)}
          <div class="activity-item">
            <div class="activity-meta">
              <a href="/threads/{thread.slug}" class="activity-link">{thread.title}</a>
              <span class="activity-forum">in <a href="/forums/{thread.forum.slug}">{thread.forum.name}</a></span>
            </div>
            <div class="activity-stats">
              {thread.reply_count} replies &middot; {thread.view_count} views
            </div>
            <span class="activity-time">{timeAgo(thread.inserted_at)}</span>
          </div>
        {/each}
      </div>
    {/if}
  {/if}
</div>

<style>
  .activity-page { display: flex; flex-direction: column; gap: 12px; }
  .page-title { font-size: 20px; font-weight: 800; color: var(--text-primary); }

  .tab-bar { display: flex; gap: 4px; border-bottom: 1px solid var(--border-color); padding-bottom: 0; }
  .tab {
    padding: 8px 16px; font-size: 13px; font-weight: 600; border: none; cursor: pointer;
    background: none; color: var(--text-secondary); border-bottom: 2px solid transparent;
    transition: all 0.15s;
  }
  .tab:hover { color: var(--text-primary); }
  .tab.active { color: var(--accent); border-bottom-color: var(--accent); }

  .activity-list { display: flex; flex-direction: column; gap: 4px; }
  .activity-item {
    padding: 10px 12px; background: var(--bg-card);
    border: 1px solid var(--border-color); border-radius: var(--radius);
  }
  .activity-link { font-size: 14px; font-weight: 700; color: var(--text-link); }
  .activity-forum { font-size: 12px; color: var(--text-muted); margin-left: 4px; }
  .activity-forum a { color: var(--text-secondary); }
  .activity-excerpt {
    font-size: 12px; color: var(--text-secondary); margin-top: 4px;
    overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  }
  .activity-stats { font-size: 12px; color: var(--text-muted); margin-top: 4px; }
  .activity-time { font-size: 11px; color: var(--text-muted); }

  .empty, .loading { text-align: center; padding: 40px 0; color: var(--text-muted); }
</style>
