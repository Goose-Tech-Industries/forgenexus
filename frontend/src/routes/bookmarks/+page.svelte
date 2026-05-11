<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';

  interface Bookmark {
    id: string;
    note: string | null;
    bookmarked_at: string;
    message: {
      id: string; body: string; channel_id: string; channel_name: string | null;
      channel_slug: string | null; user: { id: string; username: string; avatar_url: string | null; username_color: string | null } | null;
      inserted_at: string;
    };
  }

  interface PostBookmark {
    id: string;
    note: string | null;
    bookmarked_at: string;
    post: {
      id: string; body: string; body_html: string | null; inserted_at: string;
      user: { id: string; username: string; slug: string; avatar_url: string | null } | null;
      thread: { id: string; title: string; slug: string; forum: { id: string; name: string; slug: string } | null } | null;
    };
  }

  let activeTab = $state<'messages' | 'posts'>('messages');
  let bookmarks = $state<Bookmark[]>([]);
  let postBookmarks = $state<PostBookmark[]>([]);
  let loading = $state(true);
  let error = $state('');
  let msgPage = $state(1);
  let postPage = $state(1);
  const pageSize = 20;

  $effect(() => { loadBookmarks(); });

  async function loadBookmarks() {
    loading = true;
    error = '';
    try {
      if (activeTab === 'messages') {
        const data = await api.getBookmarks();
        bookmarks = data.bookmarks || [];
      } else {
        const data = await api.getPostBookmarks();
        postBookmarks = data.bookmarks || [];
      }
    } catch (err: any) { error = err?.error || 'Failed to load bookmarks'; }
    loading = false;
  }

  let paginatedBookmarks = $derived(bookmarks.slice((msgPage - 1) * pageSize, msgPage * pageSize));
  let msgTotalPages = $derived(Math.ceil(bookmarks.length / pageSize) || 1);
  let paginatedPostBookmarks = $derived(postBookmarks.slice((postPage - 1) * pageSize, postPage * pageSize));
  let postTotalPages = $derived(Math.ceil(postBookmarks.length / pageSize) || 1);

  function goMsgPage(pg: number) { msgPage = pg; }
  function goPostPage(pg: number) { postPage = pg; }

  function switchTab(tab: 'messages' | 'posts') {
    activeTab = tab;
    loadBookmarks();
  }

  async function removeBookmark(messageId: string) {
    await api.toggleBookmark(messageId);
    bookmarks = bookmarks.filter(b => b.message.id !== messageId);
  }

  async function removePostBookmark(postId: string) {
    await api.togglePostBookmark(postId);
    postBookmarks = postBookmarks.filter(b => b.post.id !== postId);
  }

  function formatTime(ts: string): string {
    const d = new Date(ts);
    return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' }) + ' at ' +
      d.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' });
  }
</script>

<div class="bookmarks-page">
  <h1>Bookmarks</h1>

  <div class="tabs">
    <button class="tab" class:active={activeTab === 'messages'} onclick={() => switchTab('messages')}>Chat Messages</button>
    <button class="tab" class:active={activeTab === 'posts'} onclick={() => switchTab('posts')}>Forum Posts</button>
  </div>

  {#if !auth.isLoggedIn}
    <p class="login-prompt">Please <a href="/login">sign in</a> to view your bookmarks.</p>
  {:else if loading}
    <p class="loading">Loading bookmarks...</p>
  {:else if error}
    <div class="error-box">{error}</div>
  {:else if activeTab === 'messages'}
    {#if bookmarks.length === 0}
      <div class="empty">
        <div class="empty-icon">&#128278;</div>
        <h3>No saved messages</h3>
        <p>Click the bookmark icon on any chat message to save it here.</p>
      </div>
    {:else}
      <p class="count">{bookmarks.length} saved message{bookmarks.length !== 1 ? 's' : ''}</p>
      <div class="bookmark-list">
        {#each paginatedBookmarks as bm (bm.id)}
          <div class="bookmark-card">
            <div class="bm-header">
              <a href="/chat" class="bm-channel">#{bm.message.channel_name || 'unknown'}</a>
              <span class="bm-author" style:color={bm.message.user?.username_color || 'var(--text-primary)'}>
                {bm.message.user?.username || 'Unknown'}
              </span>
              <span class="bm-time">{formatTime(bm.message.inserted_at)}</span>
              <button class="bm-remove" onclick={() => removeBookmark(bm.message.id)} title="Remove bookmark">&#10005;</button>
            </div>
            <div class="bm-body">{bm.message.body}</div>
            {#if bm.note}
              <div class="bm-note">Note: {bm.note}</div>
            {/if}
            <div class="bm-footer">
              <span class="bm-saved">Saved {formatTime(bm.bookmarked_at)}</span>
            </div>
          </div>
        {/each}
      </div>
      {#if msgTotalPages > 1}
        <div class="pagination">
          <button class="pg-btn" disabled={msgPage <= 1} onclick={() => goMsgPage(msgPage - 1)}>&laquo;</button>
          {#each Array.from({length: Math.min(msgTotalPages, 10)}, (_, i) => i + 1) as pg}
            <button class="pg-btn" class:active={pg === msgPage} onclick={() => goMsgPage(pg)}>{pg}</button>
          {/each}
          <button class="pg-btn" disabled={msgPage >= msgTotalPages} onclick={() => goMsgPage(msgPage + 1)}>&raquo;</button>
        </div>
      {/if}
    {/if}
  {:else}
    {#if postBookmarks.length === 0}
      <div class="empty">
        <div class="empty-icon">&#128278;</div>
        <h3>No saved posts</h3>
        <p>Click the Save button on any forum post to bookmark it here.</p>
      </div>
    {:else}
      <p class="count">{postBookmarks.length} saved post{postBookmarks.length !== 1 ? 's' : ''}</p>
      <div class="bookmark-list">
        {#each paginatedPostBookmarks as bm (bm.id)}
          <div class="bookmark-card">
            <div class="bm-header">
              {#if bm.post.thread}
                <a href="/threads/{bm.post.thread.slug}" class="bm-channel">{bm.post.thread.title}</a>
              {/if}
              {#if bm.post.thread?.forum}
                <span class="bm-forum">in {bm.post.thread.forum.name}</span>
              {/if}
              <span class="bm-author">
                {bm.post.user?.username || 'Unknown'}
              </span>
              <span class="bm-time">{formatTime(bm.post.inserted_at)}</span>
              <button class="bm-remove" onclick={() => removePostBookmark(bm.post.id)} title="Remove bookmark">&#10005;</button>
            </div>
            <div class="bm-body">{bm.post.body}</div>
            {#if bm.note}
              <div class="bm-note">Note: {bm.note}</div>
            {/if}
            <div class="bm-footer">
              <span class="bm-saved">Saved {formatTime(bm.bookmarked_at)}</span>
            </div>
          </div>
        {/each}
      </div>
      {#if postTotalPages > 1}
        <div class="pagination">
          <button class="pg-btn" disabled={postPage <= 1} onclick={() => goPostPage(postPage - 1)}>&laquo;</button>
          {#each Array.from({length: Math.min(postTotalPages, 10)}, (_, i) => i + 1) as pg}
            <button class="pg-btn" class:active={pg === postPage} onclick={() => goPostPage(pg)}>{pg}</button>
          {/each}
          <button class="pg-btn" disabled={postPage >= postTotalPages} onclick={() => goPostPage(postPage + 1)}>&raquo;</button>
        </div>
      {/if}
    {/if}
  {/if}
</div>

<style>
  .bookmarks-page { max-width: 700px; margin: 0 auto; }
  h1 { font-size: 22px; font-weight: 800; margin-bottom: 16px; }
  .count { font-size: 12px; color: var(--text-muted); margin-bottom: 12px; }
  .loading, .login-prompt { text-align: center; color: var(--text-muted); padding: 40px; }
  .login-prompt a { color: var(--accent); }
  .empty { text-align: center; padding: 60px 20px; color: var(--text-muted); }
  .empty-icon { font-size: 48px; margin-bottom: 12px; }
  .empty h3 { font-size: 16px; font-weight: 700; color: var(--text-primary); margin-bottom: 6px; }
  .empty p { font-size: 13px; }

  .tabs { display: flex; gap: 4px; margin-bottom: 16px; border-bottom: 2px solid var(--border-color); }
  .tab { background: none; border: none; padding: 8px 16px; font-size: 13px; font-weight: 600; color: var(--text-secondary); cursor: pointer; border-bottom: 2px solid transparent; margin-bottom: -2px; transition: all 0.15s; }
  .tab:hover { color: var(--text-primary); }
  .tab.active { color: var(--accent); border-bottom-color: var(--accent); }

  .bookmark-list { display: flex; flex-direction: column; gap: 10px; }
  .bookmark-card { background: var(--bg-card, var(--bg-secondary)); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 14px 16px; }
  .bm-header { display: flex; align-items: baseline; gap: 8px; margin-bottom: 6px; font-size: 12px; flex-wrap: wrap; }
  .bm-channel { color: var(--accent); font-weight: 600; text-decoration: none; }
  .bm-channel:hover { text-decoration: underline; }
  .bm-forum { color: var(--text-muted); font-size: 11px; }
  .bm-author { font-weight: 600; }
  .bm-time { color: var(--text-muted); font-size: 11px; }
  .bm-remove { margin-left: auto; background: none; border: none; color: var(--text-muted); cursor: pointer; font-size: 12px; padding: 2px 4px; }
  .bm-remove:hover { color: #f87171; }
  .bm-body { font-size: 13px; line-height: 1.5; color: var(--text-primary); word-break: break-word; white-space: pre-wrap; }
  .bm-note { font-size: 11px; color: var(--accent); margin-top: 6px; font-style: italic; }
  .bm-footer { margin-top: 8px; font-size: 10px; color: var(--text-muted); }

  .pagination { display: flex; gap: 4px; justify-content: center; padding: 12px 0; }
  .pg-btn { padding: 4px 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-card); color: var(--text-secondary); font-size: 12px; cursor: pointer; }
  .pg-btn.active { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); }
  .pg-btn:disabled { opacity: 0.4; cursor: default; }
</style>
