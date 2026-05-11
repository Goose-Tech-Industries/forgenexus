<script lang="ts">
  import { page } from '$app/stores';
  import { api } from '$lib/api/client';
  import Breadcrumb from '$lib/components/layout/Breadcrumb.svelte';
  import { auth } from '$lib/stores/auth.svelte';
  import { toast } from '$lib/stores/toast.svelte';

  let forum = $state<any>(null);
  let threads = $state<any[]>([]);
  let loading = $state(true);
  let error = $state('');
  let currentPage = $state(1);
  let isMuted = $state(false);
  let sortBy = $state('newest');
  let filterPrefix = $state('');

  // Bulk moderation
  let modToolsActive = $state(false);
  let selectedThreadIds = $state<Set<string>>(new Set());
  let bulkProcessing = $state(false);
  let moveTargetForumId = $state('');
  let showMoveDialog = $state(false);
  let allForums = $state<any[]>([]);
  let rulesExpanded = $state(false);

  const sortOptions = [
    { value: 'newest', label: 'Newest' },
    { value: 'most_replies', label: 'Most Replies' },
    { value: 'most_views', label: 'Most Views' },
    { value: 'oldest', label: 'Oldest' }
  ];

  let availablePrefixes = $derived(
    [...new Set(threads.map(t => t.prefix).filter(Boolean))]
  );

  $effect(() => {
    const slug = $page.params.slug;
    if (slug) loadThreads(slug);
  });

  function onSortChange(e: Event) {
    sortBy = (e.target as HTMLSelectElement).value;
    currentPage = 1;
    const slug = $page.params.slug;
    if (slug) loadThreads(slug);
  }

  function onPrefixChange(e: Event) {
    filterPrefix = (e.target as HTMLSelectElement).value;
    currentPage = 1;
    const slug = $page.params.slug;
    if (slug) loadThreads(slug);
  }

  async function loadThreads(slug: string) {
    loading = true;
    try {
      const data = await api.getForumThreads(slug, currentPage, {
        sort: sortBy !== 'newest' ? sortBy : undefined,
        prefix: filterPrefix || undefined
      });
      forum = data.forum;
      threads = data.threads || [];
      // Check mute status
      if (auth.isLoggedIn && forum) {
        try {
          const ignoreData = await api.getIgnores();
          isMuted = (ignoreData.ignores || []).some((i: any) => i.forum?.id === forum.id);
        } catch { /* ignore */ }
      }
    } catch (err: any) {
      error = err?.status === 404 ? 'Forum not found' : (err?.error || 'Failed to load forum');
    }
    loading = false;
  }

  async function markForumRead() {
    if (!forum) return;
    try {
      await api.markForumRead(forum.slug);
      threads = threads.map(t => ({ ...t, has_unread: false, new_post_count: 0 }));
    } catch (err) {
      console.error('Failed to mark forum read:', err);
    }
  }

  async function toggleMute() {
    if (!forum) return;
    try {
      if (isMuted) {
        await api.unignoreForum(forum.id);
        isMuted = false;
      } else {
        await api.ignoreForum(forum.id);
        isMuted = true;
      }
    } catch (err) {
      console.error('Failed to toggle mute:', err);
    }
  }

  async function muteThread(threadId: string) {
    try {
      await api.ignoreThread(threadId);
      threads = threads.filter(t => t.id !== threadId);
    } catch (err) {
      console.error('Failed to mute thread:', err);
    }
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

  let hasUnread = $derived(threads.some(t => t.has_unread));

  // Bulk mod helpers
  function toggleModTools() {
    modToolsActive = !modToolsActive;
    if (!modToolsActive) {
      selectedThreadIds = new Set();
      showMoveDialog = false;
    }
  }

  function toggleThreadSelection(threadId: string) {
    const newSet = new Set(selectedThreadIds);
    if (newSet.has(threadId)) newSet.delete(threadId);
    else newSet.add(threadId);
    selectedThreadIds = newSet;
  }

  function selectAll() {
    selectedThreadIds = new Set(threads.map(t => t.id));
  }

  function deselectAll() {
    selectedThreadIds = new Set();
  }

  async function bulkAction(action: string) {
    if (selectedThreadIds.size === 0) return;
    const ids = [...selectedThreadIds];

    if (action === 'move') {
      // Load forums for the move dialog
      if (allForums.length === 0) {
        try {
          const data = await api.getForums();
          const cats = data.categories || [];
          allForums = cats.flatMap((c: any) => c.forums || []);
        } catch { /* ignore */ }
      }
      showMoveDialog = true;
      return;
    }

    if (action === 'hide' && !confirm(`Hide ${ids.length} thread(s)? This cannot be easily undone.`)) return;

    bulkProcessing = true;
    try {
      await api.bulkThreadAction(action, ids);
      toast.success(`${action} applied to ${ids.length} thread(s)`);
      selectedThreadIds = new Set();
      // Reload threads
      const slug = $page.params.slug;
      if (slug) loadThreads(slug);
    } catch (err: any) {
      toast.error(err?.error || `Failed to ${action} threads`);
    }
    bulkProcessing = false;
  }

  async function executeBulkMove() {
    if (!moveTargetForumId || selectedThreadIds.size === 0) return;
    bulkProcessing = true;
    try {
      await api.bulkThreadAction('move', [...selectedThreadIds], moveTargetForumId);
      toast.success(`Moved ${selectedThreadIds.size} thread(s)`);
      selectedThreadIds = new Set();
      showMoveDialog = false;
      const slug = $page.params.slug;
      if (slug) loadThreads(slug);
    } catch (err: any) {
      toast.error(err?.error || 'Failed to move threads');
    }
    bulkProcessing = false;
  }

  // === Inline Thread Preview (Feature 10) ===
  let previewThreadId = $state<string | null>(null);
  let previewContent = $state<string>('');
  let previewLoading = $state(false);
  let previewCache = $state<Record<string, string>>({});

  async function togglePreview(thread: any) {
    if (previewThreadId === thread.id) {
      previewThreadId = null;
      return;
    }

    previewThreadId = thread.id;

    if (previewCache[thread.id]) {
      previewContent = previewCache[thread.id];
      return;
    }

    previewLoading = true;
    previewContent = '';
    try {
      const data = await api.getThread(thread.slug, 1);
      const firstPost = data.posts?.[0];
      const html = firstPost?.body_html || firstPost?.body || 'No content available.';
      previewCache[thread.id] = html;
      // Only set if still viewing this thread
      if (previewThreadId === thread.id) {
        previewContent = html;
      }
    } catch {
      if (previewThreadId === thread.id) {
        previewContent = '<em>Failed to load preview.</em>';
      }
    }
    previewLoading = false;
  }

  function threadPageCount(replyCount: number): number {
    return Math.max(1, Math.ceil((replyCount + 1) / 25));
  }

  function threadPageLinks(replyCount: number): (number | '...')[] {
    const total = threadPageCount(replyCount);
    if (total <= 1) return [];
    if (total <= 4) return Array.from({ length: total }, (_, i) => i + 1);
    return [1, 2, 3, '...', total];
  }
</script>

{#if forum}
  <Breadcrumb crumbs={[
    ...(forum.parent ? [{ label: forum.parent.name, href: `/forums/${forum.parent.slug}` }] : []),
    { label: forum.name }
  ]} />
{/if}

<div class="forum-view">
  {#if loading}
    <div class="loading">Loading threads...</div>
  {:else if error}
    <div class="error-box">{error}</div>
  {:else if forum}
    <div class="forum-header-bar">
      <div>
        <h1 class="forum-title">{forum.name}</h1>
        {#if forum.description}
          <p class="forum-desc">{forum.description}</p>
        {/if}
      </div>
      <div class="forum-actions">
        {#if auth.isStaff}
          <button class="btn btn-sm" class:mod-active={modToolsActive} onclick={toggleModTools} title="Toggle mod tools">
            Mod Tools
          </button>
        {/if}
        {#if auth.isLoggedIn}
          {#if hasUnread}
            <button class="btn btn-sm" onclick={markForumRead} title="Mark all threads read">Mark Read</button>
          {/if}
          <button class="btn btn-sm" class:muted={isMuted} onclick={toggleMute} title={isMuted ? 'Unmute forum' : 'Mute forum'}>
            {isMuted ? 'Unmute' : 'Mute'}
          </button>
          <a href="/forums/{forum.slug}/new" class="btn btn-sm btn-primary">New Thread</a>
        {/if}
      </div>
    </div>

    {#if forum.children?.length > 0}
      <div class="subforums-section">
        <div class="subforums-header">Sub-forums</div>
        <div class="subforums-grid">
          {#each forum.children as child (child.id)}
            <a href="/forums/{child.slug}" class="subforum-card">
              <div class="subforum-icon">&#128172;</div>
              <div class="subforum-detail">
                <div class="subforum-name">{child.name}</div>
                {#if child.description}
                  <div class="subforum-desc">{child.description}</div>
                {/if}
                <div class="subforum-stats">{child.thread_count ?? 0} threads &middot; {child.post_count ?? 0} posts</div>
              </div>
            </a>
          {/each}
        </div>
      </div>
    {/if}

    {#if forum.rules}
      <div class="forum-rules-card">
        <button class="forum-rules-header" onclick={() => rulesExpanded = !rulesExpanded}>
          <span class="rules-arrow" class:expanded={rulesExpanded}>&#9654;</span>
          Forum Rules
        </button>
        {#if rulesExpanded}
          <div class="forum-rules-body">{forum.rules}</div>
        {/if}
      </div>
    {/if}

    <div class="thread-toolbar">
      <div class="toolbar-left">
        <select class="toolbar-select" value={sortBy} onchange={onSortChange}>
          {#each sortOptions as opt}
            <option value={opt.value}>{opt.label}</option>
          {/each}
        </select>
        {#if availablePrefixes.length > 0}
          <select class="toolbar-select" value={filterPrefix} onchange={onPrefixChange}>
            <option value="">All Prefixes</option>
            {#each availablePrefixes as prefix}
              <option value={prefix}>{prefix}</option>
            {/each}
          </select>
        {/if}
      </div>
    </div>

    {#if threads.length === 0}
      <div class="empty-state">
        <p>No threads yet. Be the first to start a discussion!</p>
      </div>
    {:else}
      {#if modToolsActive}
        <div class="bulk-select-bar">
          <button class="btn btn-sm" onclick={selectAll}>Select All</button>
          <button class="btn btn-sm" onclick={deselectAll}>Deselect All</button>
          <span class="bulk-count">{selectedThreadIds.size} selected</span>
        </div>
      {/if}

      <table class="forum-table">
        <thead>
          <tr class="forum-table-header">
            {#if modToolsActive}<th style="width: 32px"></th>{/if}
            <th style="width: 55%">Thread</th>
            <th class="stat-col">Replies</th>
            <th class="stat-col">Views</th>
            <th>Last Post</th>
          </tr>
        </thead>
        <tbody>
          {#each threads as thread (thread.id)}
            <tr class="forum-table-row" class:unread={thread.has_unread}>
              {#if modToolsActive}
                <td class="mod-check-cell">
                  <input type="checkbox" checked={selectedThreadIds.has(thread.id)} onchange={() => toggleThreadSelection(thread.id)} />
                </td>
              {/if}
              <td>
                <div class="thread-info">
                  {#if thread.has_unread}
                    <span class="unread-dot" title="New posts"></span>
                  {/if}
                  {#if thread.is_pinned}
                    <span class="pin-badge" title="Pinned">&#128204;</span>
                  {/if}
                  {#if thread.is_locked}
                    <span class="lock-badge" title="Locked">&#128274;</span>
                  {/if}
                  {#if thread.thumbnail_url}
                    <img class="thread-thumbnail" src={thread.thumbnail_url} alt="" loading="lazy" />
                  {/if}
                  <div class="thread-detail">
                    <div class="thread-title-row">
                      <button class="preview-toggle" class:preview-open={previewThreadId === thread.id} onclick={(e) => { e.preventDefault(); togglePreview(thread); }} title="Preview first post">&#9660;</button>
                      <a href="/threads/{thread.slug}" class="thread-title" class:thread-unread={thread.has_unread} title={thread.excerpt ? thread.excerpt.slice(0, 150) : undefined}>{thread.title}</a>
                      {#if thread.new_post_count > 0}
                        <span class="new-post-badge">+{thread.new_post_count} new</span>
                      {/if}
                      {#if thread.reply_count > 24}
                        <span class="thread-pages">
                          {#each threadPageLinks(thread.reply_count) as pg}
                            {#if pg === '...'}
                              <span class="tp-ellipsis">...</span>
                            {:else}
                              <a href="/threads/{thread.slug}?page={pg}" class="tp-link">{pg}</a>
                            {/if}
                          {/each}
                        </span>
                      {/if}
                    </div>
                    <div class="thread-meta">
                      by <a href="/profile/{thread.user.slug}" class="thread-author">{thread.user.username}</a>
                      &middot; {timeAgo(thread.inserted_at)}
                      {#if thread.tags?.length > 0}
                        {#each thread.tags as tag}
                          <span class="tag">{tag}</span>
                        {/each}
                      {/if}
                    </div>
                    {#if previewThreadId === thread.id}
                      <div class="thread-preview">
                        {#if previewLoading}
                          <div class="preview-loading">Loading preview...</div>
                        {:else}
                          <div class="preview-content">{@html previewContent}</div>
                        {/if}
                      </div>
                    {/if}
                  </div>
                </div>
              </td>
              <td class="stat-cell">
                <div class="count">{thread.reply_count}</div>
              </td>
              <td class="stat-cell">
                <div class="count">{thread.view_count}</div>
              </td>
              <td class="lastpost-cell">
                <span class="post-time">{timeAgo(thread.last_post_at)}</span>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>

      <!-- Bulk action floating bar -->
      {#if modToolsActive && selectedThreadIds.size > 0}
        <div class="bulk-action-bar">
          <span class="bulk-label">{selectedThreadIds.size} thread{selectedThreadIds.size > 1 ? 's' : ''} selected</span>
          <button class="bulk-btn" onclick={() => bulkAction('lock')} disabled={bulkProcessing}>&#128274; Lock</button>
          <button class="bulk-btn" onclick={() => bulkAction('unlock')} disabled={bulkProcessing}>&#128275; Unlock</button>
          <button class="bulk-btn" onclick={() => bulkAction('move')} disabled={bulkProcessing}>&#128193; Move</button>
          <button class="bulk-btn bulk-btn-danger" onclick={() => bulkAction('hide')} disabled={bulkProcessing}>&#128465; Hide</button>
        </div>
      {/if}

      <!-- Move dialog -->
      {#if showMoveDialog}
        <!-- svelte-ignore a11y-click-events-have-key-events -->
        <div class="modal-overlay" onclick={() => showMoveDialog = false} role="dialog" tabindex="-1">
          <!-- svelte-ignore a11y-click-events-have-key-events -->
          <div class="modal-content" onclick={(e) => e.stopPropagation()} role="document" tabindex="-1">
            <h3>Move {selectedThreadIds.size} thread(s) to:</h3>
            <select class="toolbar-select" bind:value={moveTargetForumId} style="width: 100%; margin: 12px 0;">
              <option value="">Select a forum...</option>
              {#each allForums as f}
                {#if f.id !== forum?.id}
                  <option value={f.id}>{f.name}</option>
                {/if}
              {/each}
            </select>
            <div style="display: flex; gap: 8px; justify-content: flex-end;">
              <button class="btn btn-sm" onclick={() => showMoveDialog = false}>Cancel</button>
              <button class="btn btn-primary btn-sm" onclick={executeBulkMove} disabled={!moveTargetForumId || bulkProcessing}>
                {bulkProcessing ? 'Moving...' : 'Move'}
              </button>
            </div>
          </div>
        </div>
      {/if}
    {/if}
  {/if}
</div>

<style>
  .forum-view {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .forum-header-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 0;
  }

  .forum-actions {
    display: flex;
    gap: 8px;
    align-items: center;
  }

  .forum-title {
    font-size: 20px;
    font-weight: 800;
    color: var(--text-primary);
  }

  .forum-desc {
    font-size: 13px;
    color: var(--text-secondary);
    margin-top: 2px;
  }

  .btn {
    padding: 6px 14px;
    border-radius: var(--radius);
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    border: 1px solid var(--border-color);
    background: var(--bg-tertiary);
    color: var(--text-secondary);
    transition: all 0.15s;
  }
  .btn:hover { background: var(--bg-hover); color: var(--text-primary); }
  .btn-primary {
    background: var(--accent);
    color: var(--bg-primary);
    border-color: var(--accent);
    padding: 8px 16px;
    font-size: 13px;
  }
  .btn-primary:hover { background: var(--accent-hover); }
  .btn.muted { background: var(--danger); color: white; border-color: var(--danger); }
  .btn-sm { padding: 4px 10px; font-size: 11px; }

  .stat-col {
    width: 80px;
    text-align: center;
  }

  .thread-info {
    display: flex;
    align-items: flex-start;
    gap: 8px;
  }

  .thread-detail {
    flex: 1;
  }

  .unread-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: var(--accent);
    flex-shrink: 0;
    margin-top: 6px;
    box-shadow: 0 0 6px var(--accent);
  }

  .pin-badge, .lock-badge {
    font-size: 14px;
    margin-top: 2px;
  }

  .thread-title {
    font-size: 14px;
    font-weight: 600;
    display: block;
    margin-bottom: 2px;
    color: var(--text-secondary);
  }

  .thread-title.thread-unread {
    font-weight: 800;
    color: var(--text-primary);
  }

  .forum-table-row.unread {
    background: rgba(0, 212, 170, 0.03);
    border-left: 3px solid var(--accent);
  }

  .thread-meta {
    font-size: 11px;
    color: var(--text-muted);
  }

  .thread-author {
    color: var(--text-secondary);
    font-weight: 500;
  }

  .tag {
    display: inline-block;
    background: var(--bg-tertiary);
    color: var(--text-secondary);
    padding: 1px 6px;
    border-radius: 3px;
    font-size: 10px;
    margin-left: 4px;
  }

  .thread-toolbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 8px 0;
  }

  .toolbar-left {
    display: flex;
    gap: 8px;
    align-items: center;
  }

  .toolbar-select {
    padding: 5px 10px;
    font-size: 12px;
    font-weight: 500;
    background: var(--bg-tertiary);
    color: var(--text-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    cursor: pointer;
    outline: none;
    transition: border-color 0.15s;
  }
  .toolbar-select:hover { border-color: var(--accent); }
  .toolbar-select:focus { border-color: var(--accent); }

  .empty-state {
    text-align: center;
    padding: 60px 0;
    color: var(--text-muted);
  }

  .loading {
    text-align: center;
    padding: 60px 0;
    color: var(--text-muted);
  }

  .post-time {
    font-size: 12px;
    color: var(--text-secondary);
  }

  .thread-title-row {
    display: flex;
    align-items: baseline;
    gap: 6px;
    flex-wrap: wrap;
  }

  .thread-pages {
    display: inline-flex;
    gap: 2px;
    align-items: center;
    flex-shrink: 0;
  }

  .tp-link {
    font-size: 10px;
    color: var(--text-muted);
    padding: 1px 4px;
    border-radius: 3px;
    background: var(--bg-tertiary);
    text-decoration: none;
    line-height: 1;
  }
  .tp-link:hover {
    background: var(--accent);
    color: var(--bg-primary);
  }

  .tp-ellipsis {
    font-size: 10px;
    color: var(--text-muted);
    padding: 0 1px;
  }

  /* Forum Rules Card (Feature 6) */
  .forum-rules-card {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-left: 3px solid var(--info);
    border-radius: var(--radius);
    overflow: hidden;
  }
  .forum-rules-header {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    padding: 10px 14px;
    background: none;
    border: none;
    color: var(--text-secondary);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    font-family: inherit;
    text-align: left;
    transition: color 0.15s;
  }
  .forum-rules-header:hover { color: var(--text-primary); }
  .rules-arrow {
    font-size: 9px;
    transition: transform 0.15s;
    display: inline-block;
  }
  .rules-arrow.expanded { transform: rotate(90deg); }
  .forum-rules-body {
    padding: 0 14px 12px;
    font-size: 13px;
    color: var(--text-secondary);
    line-height: 1.6;
    white-space: pre-wrap;
    border-top: 1px solid var(--border-color);
    padding-top: 10px;
  }

  /* Thread Thumbnail (Feature 7) */
  .thread-thumbnail {
    width: 40px;
    height: 40px;
    border-radius: var(--radius);
    object-fit: cover;
    flex-shrink: 0;
    background: var(--bg-tertiary);
  }

  /* New post badge (Feature 9) */
  .new-post-badge {
    display: inline-block;
    font-size: 10px;
    font-weight: 700;
    color: var(--accent);
    background: rgba(0, 212, 170, 0.1);
    border: 1px solid rgba(0, 212, 170, 0.25);
    padding: 1px 6px;
    border-radius: 10px;
    line-height: 1.4;
    white-space: nowrap;
    flex-shrink: 0;
  }

  /* Inline thread preview (Feature 10) */
  .preview-toggle {
    background: none;
    border: none;
    color: var(--text-muted);
    font-size: 8px;
    cursor: pointer;
    padding: 2px 4px;
    border-radius: 3px;
    transition: color 0.15s, transform 0.2s;
    flex-shrink: 0;
    line-height: 1;
  }
  .preview-toggle:hover { color: var(--accent); }
  .preview-toggle.preview-open { color: var(--accent); transform: rotate(180deg); }

  .thread-preview {
    margin-top: 6px;
    padding: 10px 12px;
    background: var(--bg-tertiary);
    border-top: 2px solid var(--border-color);
    border-radius: 0 0 var(--radius) var(--radius);
    max-height: 200px;
    overflow-y: auto;
    font-size: 13px;
    color: var(--text-secondary);
    line-height: 1.5;
  }
  .thread-preview :global(img) { max-width: 100%; height: auto; }
  .thread-preview :global(a) { color: var(--accent); }

  .preview-loading {
    font-size: 12px;
    color: var(--text-muted);
    font-style: italic;
    padding: 4px 0;
  }

  .preview-content {
    word-break: break-word;
  }

  /* Mod tools */
  .btn.mod-active { background: #fbbf24; color: #000; border-color: #fbbf24; font-weight: 700; }

  .bulk-select-bar { display: flex; align-items: center; gap: 8px; padding: 6px 0; }
  .bulk-count { font-size: 11px; color: var(--text-muted); }

  .mod-check-cell { width: 32px; text-align: center; }
  .mod-check-cell input { width: auto; cursor: pointer; }

  .bulk-action-bar {
    position: fixed;
    bottom: 16px;
    left: 50%;
    transform: translateX(-50%);
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 10px 16px;
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.4);
    z-index: 50;
  }
  .bulk-label { font-size: 12px; font-weight: 600; color: var(--text-primary); margin-right: 4px; }
  .bulk-btn {
    padding: 6px 12px;
    font-size: 12px;
    font-weight: 600;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-tertiary);
    color: var(--text-secondary);
    cursor: pointer;
    transition: all 0.15s;
  }
  .bulk-btn:hover:not(:disabled) { background: var(--bg-hover); color: var(--text-primary); }
  .bulk-btn:disabled { opacity: 0.5; cursor: default; }
  .bulk-btn-danger { color: var(--danger); border-color: rgba(239, 68, 68, 0.3); }
  .bulk-btn-danger:hover:not(:disabled) { background: rgba(239, 68, 68, 0.1); color: var(--danger); }

  /* Move dialog */
  .modal-overlay { position: fixed; inset: 0; z-index: 100; background: rgba(0, 0, 0, 0.7); display: flex; align-items: center; justify-content: center; }
  .modal-content { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 20px; max-width: 400px; width: 90%; }
  .modal-content h3 { font-size: 15px; font-weight: 700; margin-bottom: 8px; }

  /* Sub-forums section */
  .subforums-section {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    overflow: hidden;
  }

  .subforums-header {
    padding: 8px 14px;
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: var(--text-muted);
    background: var(--bg-tertiary);
    border-bottom: 1px solid var(--border-color);
  }

  .subforums-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 1px;
    background: var(--border-color);
  }

  .subforum-card {
    display: flex;
    gap: 10px;
    align-items: flex-start;
    padding: 10px 14px;
    background: var(--bg-card);
    text-decoration: none;
    transition: background 0.15s;
  }

  .subforum-card:hover {
    background: var(--bg-hover);
  }

  .subforum-icon {
    font-size: 20px;
    margin-top: 1px;
    flex-shrink: 0;
  }

  .subforum-detail {
    min-width: 0;
  }

  .subforum-name {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .subforum-desc {
    font-size: 11px;
    color: var(--text-secondary);
    margin-top: 1px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .subforum-stats {
    font-size: 10px;
    color: var(--text-muted);
    margin-top: 2px;
  }

  /* === Mobile === */
  @media (max-width: 768px) {
    .forum-header { flex-direction: column; align-items: stretch; gap: 8px; padding: 10px 0; }
    .forum-info { align-items: flex-start; gap: 8px; }
    .forum-icon { font-size: 18px; }
    .forum-title { font-size: 16px; line-height: 1.25; }
    .forum-desc { font-size: 12px; }
    .forum-actions { flex-wrap: wrap; gap: 6px; }
    .forum-actions :global(button), .forum-actions :global(a) { min-height: 40px; font-size: 12px; padding: 6px 10px; }
    .breadcrumb { font-size: 11px; flex-wrap: wrap; gap: 4px; }
    .subforum-grid { grid-template-columns: 1fr !important; gap: 6px; }
    .subforum-card { padding: 10px; }
    .subforum-name { font-size: 13px; }
    .subforum-desc { font-size: 11px; }
  }

  @media (max-width: 480px) {
    .forum-title { font-size: 15px; }
    .forum-desc { font-size: 11px; }
  }
</style>
