<script lang="ts">
  import { page } from '$app/stores';
  import { api } from '$lib/api/client';
  import Breadcrumb from '$lib/components/layout/Breadcrumb.svelte';
  import UsernameDisplay from '$lib/components/common/UsernameDisplay.svelte';
  import AvatarFrame from '$lib/components/common/AvatarFrame.svelte';
  import { auth } from '$lib/stores/auth.svelte';
  import ThreadModToolbar from '$lib/components/moderation/ThreadModToolbar.svelte';
  import PostModToolbar from '$lib/components/moderation/PostModToolbar.svelte';
  import ReportButton from '$lib/components/moderation/ReportButton.svelte';
  import FormattingToolbar from '$lib/components/editor/FormattingToolbar.svelte';
  import EmojiPicker from '$lib/components/editor/EmojiPicker.svelte';
  import MentionAutocomplete from '$lib/components/editor/MentionAutocomplete.svelte';
  import UserHoverCard from '$lib/components/common/UserHoverCard.svelte';
  import { toast } from '$lib/stores/toast.svelte';
  import { socketStore } from '$lib/stores/socket.svelte';
  import { onDestroy } from 'svelte';
  import LinkPreview from "$lib/components/common/LinkPreview.svelte";

  let currentThreadId: string | null = null;

  let thread = $state<any>(null);
  let posts = $state<any[]>([]);
  let loading = $state(true);
  let error = $state('');
  let replyBody = $state('');
  let replying = $state(false);
  let subscription = $state<string | null>(null);
  let isMuted = $state(false);
  let currentPage = $state(1);
  let totalPages = $state(1);

  // Edit state
  let editingPostId = $state<string | null>(null);
  let editBody = $state('');
  let saving = $state(false);

  // Multi-quote
  let selectedQuotes = $state<Set<string>>(new Set());

  // Edit history
  let historyPostId = $state<string | null>(null);
  let editHistory = $state<any[]>([]);
  let loadingHistory = $state(false);

  // Textarea ref
  let replyTextarea = $state<HTMLTextAreaElement | null>(null);

  // Post preview
  let showPreview = $state(false);
  let previewHtml = $state('');
  let previewTimer: ReturnType<typeof setTimeout> | null = null;

  // Re-render the BBCode preview via the server whenever the user pauses
  // typing for 300ms. Single-source-of-truth with stored body_html.
  $effect(() => {
    if (!showPreview) return;
    const body = replyBody;
    if (previewTimer) clearTimeout(previewTimer);
    if (!body.trim()) { previewHtml = ''; return; }
    previewTimer = setTimeout(async () => {
      try {
        const data = await api.renderBbcode(body);
        previewHtml = data.html || '';
      } catch {
        previewHtml = escapeHtml(body);
      }
    }, 300);
  });

  // Post bookmarks
  let bookmarkedPostIds = $state<Set<string>>(new Set());

  // Post edit time limit (minutes, 0 = unlimited)
  let postEditTimeLimit = $state(60);

  // Draft auto-save
  let draftStatus = $state<'idle' | 'saving' | 'saved'>('idle');
  let draftTimer: ReturnType<typeof setTimeout> | null = null;
  let draftFadeTimer: ReturnType<typeof setTimeout> | null = null;

  $effect(() => {
    const slug = $page.params.slug;
    const pageParam = $page.url.searchParams.get('page');
    const pg = pageParam ? parseInt(pageParam, 10) : 1;
    if (slug) loadThread(slug, pg);
  });

  async function loadThread(slug: string, pg = 1) {
    loading = true;
    try {
      const [data, settingsData] = await Promise.all([
        api.getThread(slug, pg),
        api.getPublicSettings().catch(() => null)
      ]);
      thread = data.thread;
      posts = data.posts || [];
      subscription = data.subscription?.notification_level || null;
      currentPage = pg;

      if (settingsData?.settings?.post_edit_time_limit !== undefined) {
        postEditTimeLimit = settingsData.settings.post_edit_time_limit;
      }

      // Estimate total pages
      if (thread) {
        totalPages = Math.max(1, Math.ceil((thread.reply_count + 1) / 25));
        loadSimilarThreads(thread.title);
        loadBookmarkIds();
        loadDraft(thread.id);

        // Join real-time thread channel for live post updates
        if (currentThreadId && currentThreadId !== thread.id) {
          socketStore.leaveThreadChannel(currentThreadId);
        }
        currentThreadId = thread.id;
        socketStore.joinThreadChannel(
          thread.id,
          (newPost: any) => {
            // Only add if we're on the last page and post isn't already present
            if (currentPage === totalPages && !posts.find((p: any) => p.id === newPost.id)) {
              posts = [...posts, newPost];
              if (thread) thread.reply_count = (thread.reply_count || 0) + 1;
            }
          },
          (updatedPost: any) => {
            // Live-replace any post the user is viewing when its author edits it.
            posts = posts.map((p: any) => p.id === updatedPost.id ? updatedPost : p);
          }
        );
      }
    } catch (err: any) {
      error = err?.status === 404 ? 'Thread not found' : (err?.error || 'Failed to load thread');
    }
    loading = false;
  }

  function canEditPost(post: any): boolean {
    if (!auth.user || auth.user.id !== post.user.id) return false;
    if (auth.isStaff) return true;
    if (postEditTimeLimit <= 0) return true;
    const postAge = (Date.now() - new Date(post.inserted_at).getTime()) / 1000 / 60;
    return postAge <= postEditTimeLimit;
  }

  function editWindowExpired(post: any): boolean {
    if (postEditTimeLimit <= 0) return false;
    if (auth.isStaff) return false;
    const postAge = (Date.now() - new Date(post.inserted_at).getTime()) / 1000 / 60;
    return postAge > postEditTimeLimit;
  }

  // Bookmark helpers
  async function loadBookmarkIds() {
    if (!auth.isLoggedIn) return;
    try {
      const data = await api.getPostBookmarkIds();
      bookmarkedPostIds = new Set(data.post_ids || []);
    } catch { /* ignore */ }
  }

  async function toggleBookmark(postId: string) {
    if (!auth.isLoggedIn) return;
    try {
      const data = await api.togglePostBookmark(postId);
      const newSet = new Set(bookmarkedPostIds);
      if (data.bookmarked) {
        newSet.add(postId);
        toast.success('Post bookmarked');
      } else {
        newSet.delete(postId);
        toast.success('Bookmark removed');
      }
      bookmarkedPostIds = newSet;
    } catch { toast.error('Failed to toggle bookmark'); }
  }

  // Draft auto-save
  async function loadDraft(threadId: string) {
    if (!auth.isLoggedIn) return;
    try {
      const data = await api.getDraft('thread_reply', threadId);
      if (data.draft?.body && !replyBody) {
        replyBody = data.draft.body;
      }
    } catch { /* ignore */ }
  }

  onDestroy(() => {
    if (currentThreadId) socketStore.leaveThreadChannel(currentThreadId);
  });

  function scheduleDraftSave() {
    if (draftTimer) clearTimeout(draftTimer);
    if (draftFadeTimer) clearTimeout(draftFadeTimer);
    draftStatus = 'idle';

    if (!thread || !replyBody.trim()) return;

    draftTimer = setTimeout(async () => {
      if (!thread || !replyBody.trim()) return;
      draftStatus = 'saving';
      try {
        await api.saveDraft('thread_reply', thread.id, replyBody);
        draftStatus = 'saved';
        draftFadeTimer = setTimeout(() => { draftStatus = 'idle'; }, 2000);
      } catch {
        draftStatus = 'idle';
      }
    }, 2000);
  }

  async function clearDraft() {
    if (!thread) return;
    try { await api.deleteDraft('thread_reply', thread.id); } catch { /* ignore */ }
  }

  async function goToPage(pg: number) {
    if (!thread || pg < 1 || pg > totalPages) return;
    await loadThread(thread.slug, pg);
    window.scrollTo(0, 0);
  }

  async function setSubscription(level: string) {
    if (!thread) return;
    try {
      if (level === 'none') {
        await api.deleteThreadSubscription(thread.slug);
        subscription = null;
      } else {
        const data = await api.updateThreadSubscription(thread.slug, level);
        subscription = data.subscription?.notification_level || level;
      }
    } catch (err) { console.error('Failed to update subscription:', err); }
  }

  async function toggleMuteThread() {
    if (!thread) return;
    try {
      if (isMuted) { await api.unignoreThread(thread.id); isMuted = false; }
      else { await api.ignoreThread(thread.id); isMuted = true; }
    } catch (err) { console.error('Failed to toggle mute:', err); }
  }

  async function shareThread() {
    if (!thread) return;
    const url = `${window.location.origin}/threads/${thread.slug}`;
    if (navigator.share) {
      try {
        await navigator.share({ title: thread.title, url });
        toast.success('Shared!');
      } catch {
        // User cancelled share — ignore
      } finally {
        // Web Share sheet dismissal sometimes leaves the page horizontally
        // scrolled on iOS Safari. Reset the scroll anchor explicitly.
        window.scrollTo({ left: 0, top: window.scrollY, behavior: 'instant' as ScrollBehavior });
      }
    } else {
      try {
        await navigator.clipboard.writeText(url);
        toast.success('Link copied!');
      } catch {
        toast.error('Failed to copy link');
      }
    }
  }

  async function submitReply() {
    if (!replyBody.trim() || !thread) return;
    replying = true;
    try {
      const data = await api.replyToThread(thread.slug, replyBody);
      // Append only if the realtime broadcast hasn't already inserted it
      if (!posts.find((p: any) => p.id === data.post.id)) {
        posts = [...posts, data.post];
      }
      replyBody = '';
      draftStatus = 'idle';
      if (draftTimer) clearTimeout(draftTimer);
      clearDraft();
      toast.success('Reply posted!');
    } catch (err) { console.error('Reply failed:', err); toast.error('Failed to post reply'); }
    replying = false;
  }

  // Quote
  function quotePost(post: any) {
    const quoted = `[quote="${post.user.username}"]\n${post.body}\n[/quote]\n\n`;
    replyBody = quoted + replyBody;
    // Scroll to reply box
    (document.querySelector('.reply-textarea') as HTMLTextAreaElement)?.focus();
  }

  // Like/Rate
  async function toggleLike(post: any) {
    if (!auth.isLoggedIn) return;
    try {
      const data = await api.ratePost(post.id, 'like');
      // Update the post's like count in-place
      posts = posts.map(p => p.id === post.id ? { ...p, like_count: (data.ratings || []).find((r: any) => r.type === 'like')?.count || p.like_count } : p);
    } catch (err) { console.error('Rate failed:', err); }
  }

  // Edit
  function startEdit(post: any) {
    editingPostId = post.id;
    editBody = post.body;
  }

  function cancelEdit() {
    editingPostId = null;
    editBody = '';
  }

  async function saveEdit() {
    if (!editingPostId || !editBody.trim()) return;
    saving = true;
    try {
      const data = await api.editPost(editingPostId, editBody);
      posts = posts.map(p => p.id === editingPostId ? data.post : p);
      editingPostId = null;
      editBody = '';
    } catch (err) { console.error('Edit failed:', err); }
    saving = false;
  }

  // Multi-quote
  function toggleQuoteSelect(post: any) {
    const newSet = new Set(selectedQuotes);
    if (newSet.has(post.id)) newSet.delete(post.id);
    else newSet.add(post.id);
    selectedQuotes = newSet;
  }

  function insertMultiQuotes() {
    const quoted = posts
      .filter(p => selectedQuotes.has(p.id))
      .map(p => `[quote="${p.user.username}"]\n${p.body}\n[/quote]`)
      .join('\n\n');
    replyBody = quoted + '\n\n' + replyBody;
    selectedQuotes = new Set();
    replyTextarea?.focus();
  }

  // Header "Reply" button — scroll to composer + focus the textarea.
  function jumpToReply() {
    if (replyTextarea) {
      replyTextarea.scrollIntoView({ behavior: 'smooth', block: 'center' });
      // Focus after scroll settles so the keyboard doesn't fight the scroll on iOS.
      setTimeout(() => replyTextarea?.focus(), 250);
    }
  }

  // Edit history
  async function showEditHistory(postId: string) {
    historyPostId = postId;
    loadingHistory = true;
    try {
      const data = await api.getPostHistory(postId);
      editHistory = data.edits || [];
    } catch { editHistory = []; }
    loadingHistory = false;
  }

  // Emoji insert
  function insertEmoji(emoji: string) {
    if (!replyTextarea) return;
    const start = replyTextarea.selectionStart;
    const before = replyTextarea.value.substring(0, start);
    const after = replyTextarea.value.substring(replyTextarea.selectionEnd);
    replyTextarea.value = before + emoji + after;
    replyTextarea.dispatchEvent(new Event('input'));
    replyBody = replyTextarea.value;
    replyTextarea.focus();
  }

  // Convert media URLs to embeds
  function renderPostHtml(html: string | null, body: string): string {
    let content = html || escapeHtml(body);
    // Auto-embed YouTube
    content = content.replace(
      /(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/watch\?v=|youtu\.be\/)([\w-]+)/g,
      '<div class="embed-video"><iframe src="https://www.youtube.com/embed/$1" frameborder="0" allowfullscreen loading="lazy"></iframe></div>'
    );
    // Auto-link bare URLs (that aren't already in tags)
    content = content.replace(
      /(?<![="'])(https?:\/\/[^\s<]+)/g,
      '<a href="$1" target="_blank" rel="noopener noreferrer">$1</a>'
    );
    return content;
  }


  // Extract standalone URLs from post body for link previews (max 3)
  function extractPreviewUrls(body: string): string[] {
    if (!body) return [];
    const urlRegex = /(?:^|\n)\s*(https?:\/\/[^\s<\[\]]+)\s*(?:\n|$)/gm;
    const urls: string[] = [];
    let match;
    while ((match = urlRegex.exec(body)) !== null && urls.length < 3) {
      const url = match[1];
      // Skip YouTube URLs (already embedded)
      if (/(?:youtube\.com\/watch|youtu\.be\/)/.test(url)) continue;
      // Skip image URLs
      if (/\.(png|jpg|jpeg|gif|webp|svg|bmp)(\?.*)?$/i.test(url)) continue;
      if (!urls.includes(url)) urls.push(url);
    }
    return urls;
  }

  function escapeHtml(text: string): string {
    return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\n/g, '<br />');
  }

  function formatDate(dateStr: string): string {
    return new Date(dateStr).toLocaleString();
  }

  function getInitial(username: string): string {
    return username?.charAt(0)?.toUpperCase() || '?';
  }

  // === Quote Scroll & Highlight ===
  function handleQuoteClick(event: MouseEvent) {
    const target = event.target as HTMLElement;
    // Check if clicked element is a <cite> inside a bbcode-quote blockquote
    if (target.tagName !== 'CITE') return;
    const blockquote = target.closest('.bbcode-quote');
    if (!blockquote) return;

    // Extract username from "username wrote:" text
    const citeText = target.textContent || '';
    const match = citeText.match(/^(.+?)\s+wrote:/);
    if (!match) return;
    const quotedUsername = match[1].trim();

    // Find the most recent post by that username in the current page
    const matchingPost = [...posts].reverse().find(p => p.user.username === quotedUsername);
    if (!matchingPost) return;

    const el = document.getElementById(`post-${matchingPost.id}`);
    if (!el) return;

    el.scrollIntoView({ behavior: 'smooth', block: 'center' });
    el.classList.add('post-highlight');
    setTimeout(() => el.classList.remove('post-highlight'), 2000);
  }

  // === Quoted Post Navigator ===
  // Build a map: postIndex -> array of {username, postId} of posts that quote it
  let quotedByMap = $derived.by(() => {
    const map = new Map<number, Array<{ username: string; postId: string; postIndex: number }>>();
    if (!posts.length) return map;

    for (let i = 0; i < posts.length; i++) {
      const post = posts[i];
      const body = post.body || '';
      // Find all [quote="USERNAME"] patterns in this post's body
      const quoteRegex = /\[quote="([^"]+)"\]/gi;
      let m;
      while ((m = quoteRegex.exec(body)) !== null) {
        const quotedUsername = m[1];
        // Find the most recent earlier post by that username
        for (let j = i - 1; j >= 0; j--) {
          if (posts[j].user.username === quotedUsername) {
            if (!map.has(j)) map.set(j, []);
            // Avoid duplicates (same quoting post)
            const existing = map.get(j)!;
            if (!existing.some(e => e.postId === post.id)) {
              existing.push({ username: post.user.username, postId: post.id, postIndex: i });
            }
            break;
          }
        }
      }
    }
    return map;
  });

  function scrollToPost(postId: string) {
    const el = document.getElementById(`post-${postId}`);
    if (!el) return;
    el.scrollIntoView({ behavior: 'smooth', block: 'center' });
    el.classList.add('post-highlight');
    setTimeout(() => el.classList.remove('post-highlight'), 2000);
  }

  // === Image Paste Upload ===
  let pasteUploading = $state(false);

  async function handlePaste(event: ClipboardEvent) {
    const items = event.clipboardData?.items;
    if (!items) return;

    for (const item of items) {
      if (item.type.startsWith('image/')) {
        event.preventDefault();
        const file = item.getAsFile();
        if (!file) return;

        pasteUploading = true;
        try {
          const data = await api.uploadFile(file, 'post', thread?.id || 'draft');
          const url = data.url || data.attachment?.url;
          if (url && replyTextarea) {
            const start = replyTextarea.selectionStart;
            const before = replyTextarea.value.substring(0, start);
            const after = replyTextarea.value.substring(replyTextarea.selectionEnd);
            const tag = `[img]${url}[/img]`;
            replyTextarea.value = before + tag + after;
            replyTextarea.dispatchEvent(new Event('input'));
            replyBody = replyTextarea.value;
            const newPos = start + tag.length;
            replyTextarea.setSelectionRange(newPos, newPos);
            replyTextarea.focus();
            toast.success('Image uploaded!');
          }
        } catch (err: any) {
          toast.error(err?.error || 'Failed to upload image');
        }
        pasteUploading = false;
        return;
      }
    }
  }

  // === Similar Threads ===
  let similarThreads = $state<any[]>([]);
  let loadingSimilar = $state(false);

  async function loadSimilarThreads(title: string) {
    loadingSimilar = true;
    try {
      const data = await api.getSimilarThreads(title);
      similarThreads = (data.threads || []).slice(0, 5);
    } catch { similarThreads = []; }
    loadingSimilar = false;
  }

  function timeAgo(dateStr: string): string {
    const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    if (diff < 2592000) return `${Math.floor(diff / 86400)}d ago`;
    return new Date(dateStr).toLocaleDateString();
  }
</script>

<svelte:head>
  <title>{thread ? `${thread.title} - ForgeNexus` : 'ForgeNexus'}</title>
  {#if thread}
    <meta property="og:title" content={thread.title} />
    <meta property="og:type" content="article" />
    <meta property="og:url" content={`http://localhost:5173/threads/${thread.slug}`} />
    <meta property="og:description" content={`${thread.reply_count} replies, ${thread.view_count} views - ${thread.forum.name}`} />
    <meta property="og:site_name" content="ForgeNexus" />
    <meta name="description" content={`${thread.title} - Discussion in ${thread.forum.name}`} />
  {/if}
</svelte:head>

{#if thread}
  <Breadcrumb crumbs={[
    { label: thread.forum.name, href: `/forums/${thread.forum.slug}` },
    { label: thread.title }
  ]} />
{/if}

<div class="thread-view thread-layout">
  {#if loading}
    <div class="loading">Loading thread...</div>
  {:else if error}
    <div class="error-box">{error}</div>
  {:else if thread}
    <div class="thread-main">
    <div class="thread-header">
      <h1 class="thread-title">
        {#if thread.is_pinned}<span class="badge pin">Pinned</span>{/if}
        {#if thread.is_locked}<span class="badge lock">Locked</span>{/if}
        {#if thread.is_hidden}<span class="badge hidden" title="Hidden — only staff can see this thread">Hidden</span>{/if}
        {thread.title}
      </h1>
      <div class="thread-controls">
        <div class="thread-stats">
          <span>{thread.view_count} views</span>
          <span>&middot;</span>
          <span>{thread.reply_count} replies</span>
        </div>
        {#if auth.isLoggedIn}
          <div class="thread-actions">
            {#if !thread.is_locked}
              <button class="btn-jump-reply" onclick={jumpToReply} title="Jump to reply box">↓ Reply</button>
            {/if}
            <select class="sub-select" value={subscription || 'none'} onchange={(e) => setSubscription(e.currentTarget.value)}>
              <option value="none">Not Subscribed</option>
              <option value="watching">Watching</option>
              <option value="tracking">Tracking</option>
              <option value="muted">Muted</option>
            </select>
            <button class="btn-mute" class:muted={isMuted} onclick={toggleMuteThread}>
              {isMuted ? 'Unmute' : 'Mute'}
            </button>
            <button class="btn-share" onclick={shareThread}>Share</button>
          </div>
        {/if}
      </div>
    </div>

    <!-- Pagination (top) -->
    {#if totalPages > 1}
      <div class="pagination">
        <button class="pg-btn" disabled={currentPage <= 1} onclick={() => goToPage(currentPage - 1)}>&laquo; Prev</button>
        {#each Array.from({length: Math.min(totalPages, 10)}, (_, i) => i + 1) as pg}
          <button class="pg-btn" class:active={pg === currentPage} onclick={() => goToPage(pg)}>{pg}</button>
        {/each}
        {#if totalPages > 10}
          <span class="pg-ellipsis">...</span>
          <button class="pg-btn" class:active={currentPage === totalPages} onclick={() => goToPage(totalPages)}>{totalPages}</button>
        {/if}
        <button class="pg-btn" disabled={currentPage >= totalPages} onclick={() => goToPage(currentPage + 1)}>Next &raquo;</button>
      </div>
    {/if}

    <ThreadModToolbar threadId={thread.id} isLocked={thread.is_locked} isPinned={thread.is_pinned} isHidden={thread.is_hidden ?? false} onUpdate={() => loadThread(thread.slug)} />

    <!-- Posts -->
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <div class="posts-list" onclick={handleQuoteClick} role="list">
      {#each posts as post, idx (post.id)}
        <div class="post-box" id="post-{post.id}">
          <div class="post-user-panel" style:position="relative">
            {#if post.user.postbit_background_url}
              <div class="custom-bg" style="background-image: url({post.user.postbit_background_url}); opacity: {post.user.postbit_background_opacity ?? 0.15};"></div>
            {/if}
            <AvatarFrame frame={post.user.avatar_frame} frameColor={post.user.avatar_frame_color} size={100}>
              <div class="avatar">
                {#if post.user.avatar_url}
                  <img src={post.user.avatar_url} alt={post.user.username} />
                {:else}
                  {getInitial(post.user.username)}
                {/if}
              </div>
            </AvatarFrame>
            <UserHoverCard username={post.user.username} slug={post.user.slug} avatarUrl={post.user.avatar_url} postCount={post.user.post_count} reputation={post.user.reputation} customTitle={post.user.display_title || post.user.custom_title}>
              <UsernameDisplay username={post.user.username} color={post.user.username_color} effect={post.user.username_effect} href="/profile/{post.user.slug}" customTitle={post.user.display_title || post.user.custom_title} nameplateColor={post.user.nameplate_color} nameplateImageUrl={post.user.nameplate_image_url} />
            </UserHoverCard>
            {#if post.user.group_name}
              <div class="user-title" style:color={post.user.username_color || undefined}>{post.user.group_name}</div>
            {/if}
            <div class="user-stats">
              <div class="stat-line">Posts: <strong>{post.user.post_count}</strong></div>
              <div class="stat-line">Threads: <strong>{post.user.thread_count || 0}</strong></div>
              <div class="stat-line">Rep: <strong>{post.user.reputation}</strong></div>
              {#if post.user.location}
                <div class="stat-line loc">{post.user.location}</div>
              {/if}
              <div class="stat-line joined">Joined {new Date(post.user.inserted_at).toLocaleDateString()}</div>
            </div>
            <div class="user-online-status">
              <span class="online-dot" class:online={post.user.is_online}></span>
              {post.user.is_online ? 'Online' : 'Offline'}
              {#if post.user.custom_status_text}
                <span class="custom-status">{post.user.custom_status_emoji || ''} {post.user.custom_status_text}</span>
              {/if}
            </div>
          </div>

          <div class="post-content-panel" style:position="relative">
            {#if post.user.post_background_url}
              <div class="custom-bg" style="background-image: url({post.user.post_background_url}); opacity: {post.user.post_background_opacity ?? 0.15};"></div>
            {/if}
            <div class="post-header">
              <span class="post-date">{formatDate(post.inserted_at)}</span>
              <span class="post-num">#{(currentPage - 1) * 25 + idx + 1}</span>
            </div>

            {#if editingPostId === post.id}
              <!-- Edit mode -->
              <div class="post-edit">
                <textarea bind:value={editBody} class="edit-textarea" rows="6"></textarea>
                <div class="edit-actions">
                  <button class="btn-sm" onclick={cancelEdit}>Cancel</button>
                  <button class="btn-sm btn-primary" onclick={saveEdit} disabled={saving}>{saving ? 'Saving...' : 'Save'}</button>
                </div>
              </div>
            {:else}
              <div class="post-body">{@html renderPostHtml(post.body_html, post.body)}</div>
              {#each extractPreviewUrls(post.body) as previewUrl (previewUrl)}
                <LinkPreview url={previewUrl} />
              {/each}
            {/if}

            {#if (post.user.signature || post.user.signature_html) && editingPostId !== post.id}
              <div class="post-signature" style:position="relative">
                {#if post.user.signature_background_url}
                  <div class="custom-bg" style="background-image: url({post.user.signature_background_url}); opacity: 0.15;"></div>
                {/if}
                <div class="sig-divider"></div>
                <div class="sig-content">
                  {#if post.user.signature_html}{@html post.user.signature_html}{:else}{post.user.signature}{/if}
                </div>
              </div>
            {/if}

            {#if quotedByMap.has(idx)}
              <div class="quoted-by-links">
                {#each quotedByMap.get(idx)! as qb}
                  <button class="quoted-by-link" onclick={() => scrollToPost(qb.postId)}>
                    Quoted by {qb.username} <span class="quoted-by-arrow">&#8595;</span>
                  </button>
                {/each}
              </div>
            {/if}

            <div class="post-footer">
              <button class="action-btn" class:liked={false} onclick={() => toggleLike(post)}>&#128077; Like ({post.like_count})</button>
              {#if auth.isLoggedIn}
                <button class="action-btn" class:bookmarked={bookmarkedPostIds.has(post.id)} onclick={() => toggleBookmark(post.id)} title={bookmarkedPostIds.has(post.id) ? 'Remove bookmark' : 'Bookmark post'}>
                  {bookmarkedPostIds.has(post.id) ? '🔖' : '🔖'} {bookmarkedPostIds.has(post.id) ? 'Saved' : 'Save'}
                </button>
                <button class="action-btn" onclick={() => quotePost(post)}>&#x21A9; Quote</button>
                <label class="action-btn mq-check" title="Add to multi-quote">
                  <input type="checkbox" checked={selectedQuotes.has(post.id)} onchange={() => toggleQuoteSelect(post)} /> +Q
                </label>
                {#if auth.user?.id === post.user.id}
                  {#if canEditPost(post)}
                    <button class="action-btn" onclick={() => startEdit(post)}>&#9998; Edit</button>
                  {:else if editWindowExpired(post)}
                    <span class="action-btn expired" title="Edit window expired">&#9998; Edit window expired</span>
                  {/if}
                {/if}
              {/if}
              <ReportButton reportableType="post" reportableId={post.id} />
              {#if post.is_edited}
                <button class="action-btn edited-notice" onclick={() => showEditHistory(post.id)}>Edited ({post.edit_count}x)</button>
              {/if}
              <PostModToolbar postId={post.id} userId={post.user.id} isHidden={post.is_hidden ?? false} />
            </div>
          </div>
        </div>
      {/each}
    </div>

    <!-- Pagination (bottom) -->
    {#if totalPages > 1}
      <div class="pagination">
        <button class="pg-btn" disabled={currentPage <= 1} onclick={() => goToPage(currentPage - 1)}>&laquo; Prev</button>
        {#each Array.from({length: Math.min(totalPages, 10)}, (_, i) => i + 1) as pg}
          <button class="pg-btn" class:active={pg === currentPage} onclick={() => goToPage(pg)}>{pg}</button>
        {/each}
        {#if totalPages > 10}
          <span class="pg-ellipsis">...</span>
          <button class="pg-btn" class:active={currentPage === totalPages} onclick={() => goToPage(totalPages)}>{totalPages}</button>
        {/if}
        <button class="pg-btn" disabled={currentPage >= totalPages} onclick={() => goToPage(currentPage + 1)}>Next &raquo;</button>
      </div>
    {/if}

    <!-- Edit History Modal -->
    {#if historyPostId}
      <!-- svelte-ignore a11y-click-events-have-key-events -->
      <div class="modal-overlay" onclick={() => historyPostId = null} role="dialog" tabindex="-1">
        <!-- svelte-ignore a11y-click-events-have-key-events -->
        <div class="modal-content" onclick={(e) => e.stopPropagation()} role="document" tabindex="-1">
          <div class="modal-header">
            <h3>Edit History</h3>
            <button class="modal-close" onclick={() => historyPostId = null}>&times;</button>
          </div>
          {#if loadingHistory}
            <p class="loading-text">Loading...</p>
          {:else if editHistory.length === 0}
            <p class="loading-text">No edit history available.</p>
          {:else}
            <div class="history-list">
              {#each editHistory as edit (edit.id)}
                <div class="history-item">
                  <div class="history-meta">
                    Edited by <strong>{edit.editor?.username || 'Unknown'}</strong> &middot; {formatDate(edit.inserted_at)}
                    {#if edit.edit_reason}<span class="edit-reason">({edit.edit_reason})</span>{/if}
                  </div>
                  <div class="history-diff">
                    <div class="diff-before"><strong>Before:</strong><pre>{edit.body_before}</pre></div>
                    <div class="diff-after"><strong>After:</strong><pre>{edit.body_after}</pre></div>
                  </div>
                </div>
              {/each}
            </div>
          {/if}
        </div>
      </div>
    {/if}

    <!-- Reply box -->
    {#if auth.isLoggedIn && !thread.is_locked && auth.user && !auth.user.email_verified}
      <div class="email-verify-banner">
        <span class="verify-icon">&#9888;</span>
        <span>Please verify your email to post replies. Check your inbox or <a href="/settings/account">resend verification</a>.</span>
      </div>
    {:else if auth.isLoggedIn && !thread.is_locked}
      <div class="reply-box">
        <h3>Reply to this thread</h3>

        {#if selectedQuotes.size > 0}
          <div class="mq-bar">
            <span>{selectedQuotes.size} post{selectedQuotes.size > 1 ? 's' : ''} selected</span>
            <button class="btn-sm" onclick={insertMultiQuotes}>Insert Quotes</button>
            <button class="btn-sm" onclick={() => selectedQuotes = new Set()}>Clear</button>
          </div>
        {/if}

        <FormattingToolbar bind:textarea={replyTextarea} />
        <div class="reply-editor" style="position: relative;">
          <textarea bind:value={replyBody} bind:this={replyTextarea} placeholder="Write your reply... Use @ to mention users, paste images from clipboard" rows="6" class="reply-textarea" oninput={scheduleDraftSave} onpaste={handlePaste}></textarea>
          <MentionAutocomplete bind:textarea={replyTextarea} />
        </div>
        {#if pasteUploading}
          <div class="draft-indicator saving">Uploading image...</div>
        {:else if draftStatus === 'saving'}
          <div class="draft-indicator saving">Saving draft...</div>
        {:else if draftStatus === 'saved'}
          <div class="draft-indicator saved">Draft saved</div>
        {/if}
        {#if showPreview && replyBody}
          <div class="preview-box">
            <div class="preview-header">Preview</div>
            <div class="preview-body post-body">{@html renderPostHtml(previewHtml, replyBody)}</div>
          </div>
        {/if}

        <div class="reply-actions">
          <div class="reply-tools">
            <EmojiPicker onSelect={insertEmoji} />
            <button type="button" class="tb-btn" class:active={showPreview} onclick={() => showPreview = !showPreview} title="Preview">&#128065;</button>
          </div>
          <button class="btn btn-primary" onclick={submitReply} disabled={replying || !replyBody.trim()}>
            {replying ? 'Posting...' : 'Post Reply'}
          </button>
        </div>
      </div>
    {:else if !auth.isLoggedIn}
      <div class="login-prompt">
        <a href="/auth/login">Login</a> or <a href="/auth/register">Register</a> to reply
      </div>
    {/if}

    </div><!-- end thread-main -->

    <!-- Sticky Sidebar (desktop only) -->
    <aside class="thread-sidebar">
      <div class="sidebar-sticky">
        <!-- Thread Info -->
        <div class="sidebar-card">
          <h3 class="sidebar-heading">Thread Info</h3>
          <div class="sidebar-info">
            <div class="info-row"><span class="info-label">Author</span><a href="/profile/{thread.user.slug}" class="info-value accent">{thread.user.username}</a></div>
            <div class="info-row"><span class="info-label">Created</span><span class="info-value">{new Date(thread.inserted_at).toLocaleDateString()}</span></div>
            <div class="info-row"><span class="info-label">Views</span><span class="info-value">{thread.view_count.toLocaleString()}</span></div>
            <div class="info-row"><span class="info-label">Replies</span><span class="info-value">{thread.reply_count.toLocaleString()}</span></div>
            <div class="info-row"><span class="info-label">Forum</span><a href="/forums/{thread.forum.slug}" class="info-value accent">{thread.forum.name}</a></div>
          </div>
        </div>

        <!-- Thread Actions -->
        {#if auth.isLoggedIn}
          <div class="sidebar-card">
            <h3 class="sidebar-heading">Actions</h3>
            <div class="sidebar-actions">
              <select class="sidebar-select" value={subscription || 'none'} onchange={(e) => setSubscription(e.currentTarget.value)}>
                <option value="none">Not Watching</option>
                <option value="watching">Watching</option>
                <option value="tracking">Tracking</option>
                <option value="muted">Muted</option>
              </select>
              <button class="sidebar-btn" class:active={isMuted} onclick={toggleMuteThread}>
                {isMuted ? 'Unmute Thread' : 'Mute Thread'}
              </button>
              <button class="sidebar-btn" onclick={shareThread}>
                Share Link
              </button>
            </div>
          </div>
        {/if}

        <!-- Similar Threads -->
        {#if similarThreads.length > 0}
          <div class="sidebar-card">
            <h3 class="sidebar-heading">Similar Threads</h3>
            <div class="similar-list">
              {#each similarThreads as st (st.id)}
                <a href="/threads/{st.slug}" class="similar-item">
                  <div class="similar-title">{st.title}</div>
                  <div class="similar-meta">
                    <span>{st.reply_count} {st.reply_count === 1 ? 'reply' : 'replies'}</span>
                    <span>&middot; {timeAgo(st.inserted_at)}</span>
                  </div>
                </a>
              {/each}
            </div>
          </div>
        {/if}
      </div>
    </aside>
  {/if}
</div>

<style>
  .thread-view { display: flex; flex-direction: column; gap: 8px; }
  .thread-layout { flex-direction: row; flex-wrap: wrap; }
  .thread-main { flex: 1; min-width: 0; max-width: 100%; display: flex; flex-direction: column; gap: 8px; }

  /* Sticky Sidebar */
  .thread-sidebar { width: 280px; flex-shrink: 0; display: none; }
  .sidebar-sticky { position: sticky; top: 80px; display: flex; flex-direction: column; gap: 10px; max-height: calc(100vh - 100px); overflow-y: auto; }
  .sidebar-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 12px 14px; }
  .sidebar-heading { font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.04em; margin-bottom: 8px; }
  .sidebar-info { display: flex; flex-direction: column; gap: 6px; }
  .info-row { display: flex; justify-content: space-between; align-items: center; font-size: 12px; }
  .info-label { color: var(--text-muted); }
  .info-value { color: var(--text-secondary); font-weight: 600; }
  .info-value.accent { color: var(--accent); text-decoration: none; }
  .info-value.accent:hover { text-decoration: underline; }
  .sidebar-actions { display: flex; flex-direction: column; gap: 6px; }
  .sidebar-select { width: 100%; background: var(--bg-input); border: 1px solid var(--border-color); border-radius: var(--radius); padding: 6px 8px; font-size: 12px; color: var(--text-primary); cursor: pointer; }
  .sidebar-select:focus { border-color: var(--accent); outline: none; }
  .sidebar-btn { width: 100%; padding: 6px 10px; font-size: 12px; font-weight: 600; border-radius: var(--radius); background: var(--bg-tertiary); color: var(--text-secondary); border: 1px solid var(--border-color); cursor: pointer; transition: all 0.15s; }
  .sidebar-btn:hover { background: var(--bg-hover); color: var(--text-primary); }
  .sidebar-btn.active { background: var(--danger); color: white; border-color: var(--danger); }

  @media (min-width: 1024px) {
    .thread-sidebar { display: block; }
    .thread-main { max-width: calc(100% - 292px); }
  }
  .thread-header {
    padding: 16px 0;
    border-bottom: 1px solid var(--border-color);
    margin-bottom: 8px;
  }
  .thread-title {
    font-size: 22px; font-weight: 800; display: flex; align-items: center; gap: 10px;
    color: var(--text-heading);
    letter-spacing: -0.02em;
  }

  .badge { font-size: 10px; font-weight: 700; text-transform: uppercase; padding: 2px 8px; border-radius: var(--radius); letter-spacing: 0.03em; }
  .badge.pin { background: var(--accent-glow); color: var(--accent); border: 1px solid var(--border-accent); }
  .badge.lock { background: rgba(239, 68, 68, 0.1); color: var(--danger); border: 1px solid rgba(239, 68, 68, 0.3); }
  .badge.hidden { background: rgba(245, 158, 11, 0.12); color: #f59e0b; border: 1px solid rgba(245, 158, 11, 0.3); }

  /* "Reply" button in the thread header — scroll to composer */
  .btn-jump-reply {
    font-size: 12px; font-weight: 600; padding: 4px 12px; border-radius: var(--radius);
    background: var(--accent); color: var(--bg-primary); border: 1px solid var(--accent);
    cursor: pointer;
  }
  .btn-jump-reply:hover { filter: brightness(1.08); }

  .thread-controls { display: flex; justify-content: space-between; align-items: center; margin-top: 4px; }
  .thread-stats { font-size: 12px; color: var(--text-muted); display: flex; gap: 6px; }
  .thread-actions { display: flex; gap: 6px; align-items: center; }

  .sub-select { background: var(--bg-input); border: 1px solid var(--border-color); border-radius: var(--radius); padding: 4px 8px; font-size: 11px; color: var(--text-primary); cursor: pointer; }
  .sub-select:focus { border-color: var(--accent); outline: none; }
  .btn-mute { font-size: 11px; padding: 4px 10px; border-radius: var(--radius); background: var(--bg-tertiary); color: var(--text-secondary); border: 1px solid var(--border-color); cursor: pointer; }
  .btn-mute:hover { background: var(--bg-hover); }
  .btn-mute.muted { background: var(--danger); color: white; border-color: var(--danger); }
  .btn-share { font-size: 11px; padding: 4px 10px; border-radius: var(--radius); background: var(--bg-tertiary); color: var(--text-secondary); border: 1px solid var(--border-color); cursor: pointer; }
  .btn-share:hover { background: var(--bg-hover); color: var(--text-primary); }

  /* Pagination */
  .pagination { display: flex; gap: 4px; justify-content: center; padding: 8px 0; flex-wrap: wrap; }
  .pg-btn { padding: 4px 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-card); color: var(--text-secondary); font-size: 12px; cursor: pointer; }
  .pg-btn:hover:not(:disabled) { background: var(--bg-hover); color: var(--text-primary); }
  .pg-btn.active { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); font-weight: 700; }
  .pg-btn:disabled { opacity: 0.4; cursor: default; }
  .pg-ellipsis { color: var(--text-muted); padding: 4px; font-size: 12px; }

  .posts-list { display: flex; flex-direction: column; gap: 10px; }

  /* Modern post cards with glass effect */
  :global(.post-box) {
    background: var(--glass-bg);
    backdrop-filter: blur(var(--glass-blur));
    -webkit-backdrop-filter: blur(var(--glass-blur));
    border: 1px solid var(--glass-border);
    border-radius: var(--radius-lg);
    box-shadow: var(--shadow-sm);
    transition: all var(--transition-base);
  }

  :global(.post-box:hover) {
    border-color: var(--border-hover);
    box-shadow: var(--shadow-md);
  }

  :global(.post-box:first-child) {
    border-color: var(--border-accent);
    box-shadow: var(--shadow-sm), inset 0 0 30px rgba(0, 229, 184, 0.02);
  }

  .avatar img { width: 100%; height: 100%; object-fit: cover; border-radius: var(--radius-lg); }
  .post-date { color: var(--text-muted); font-size: 12px; }
  .post-num { color: var(--text-muted); font-weight: 700; font-size: 12px; }

  .action-btn { background: none; border: none; color: var(--text-secondary); font-size: 12px; cursor: pointer; padding: 4px 8px; border-radius: var(--radius); transition: all 0.15s; }
  .action-btn:hover { background: var(--bg-hover); color: var(--accent); }
  .action-btn.expired { cursor: default; opacity: 0.5; font-style: italic; }
  .action-btn.expired:hover { background: none; color: var(--text-secondary); }

  .edited-notice { color: var(--text-muted); font-style: italic; font-size: 11px; margin-left: auto; }

  /* Edit mode */
  .post-edit { padding: 12px 16px; }
  .edit-textarea { width: 100%; resize: vertical; min-height: 100px; background: var(--bg-input); border: 1px solid var(--border-color); border-radius: var(--radius); padding: 8px; color: var(--text-primary); font-size: 13px; font-family: inherit; }
  .edit-actions { display: flex; gap: 6px; justify-content: flex-end; margin-top: 8px; }
  .btn-sm { padding: 4px 12px; border-radius: var(--radius); font-size: 12px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-secondary); }
  .btn-sm.btn-primary { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); }

  .reply-box { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; margin-top: 8px; }
  .reply-box h3 { font-size: 14px; font-weight: 700; margin-bottom: 8px; color: var(--text-primary); }
  .reply-textarea { resize: vertical; min-height: 100px; margin-bottom: 8px; }
  .reply-actions { display: flex; justify-content: flex-end; }

  .login-prompt { text-align: center; padding: 16px; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); color: var(--text-secondary); font-size: 13px; }

  .email-verify-banner { display: flex; align-items: center; gap: 8px; padding: 12px 16px; background: rgba(245, 158, 11, 0.1); border: 1px solid rgba(245, 158, 11, 0.3); border-radius: var(--radius-lg); color: var(--text-secondary); font-size: 13px; margin-top: 8px; }
  .email-verify-banner a { color: var(--accent); text-decoration: underline; }
  .verify-icon { font-size: 18px; }
  .loading { text-align: center; padding: 60px 0; color: var(--text-muted); }

  .custom-bg { position: absolute; inset: 0; background-size: cover; background-position: center; background-repeat: no-repeat; pointer-events: none; z-index: 0; }
  .post-user-panel > :not(.custom-bg), .post-content-panel > :not(.custom-bg) { position: relative; z-index: 1; }

  .post-signature { padding: 8px 16px 12px; overflow: hidden; }
  .sig-divider { border-top: 1px dashed var(--border-color); margin-bottom: 8px; }
  .sig-content { font-size: 12px; color: var(--text-secondary); line-height: 1.5; max-height: 120px; overflow: hidden; }
  .post-signature > :not(.custom-bg) { position: relative; z-index: 1; }

  /* Postbit */
  .user-stats { font-size: 11px; color: var(--text-muted); line-height: 1.6; }
  .stat-line strong { color: var(--text-secondary); }
  .stat-line.loc { color: var(--text-secondary); font-style: italic; }
  .stat-line.joined { font-size: 10px; }
  .user-online-status { font-size: 10px; color: var(--text-muted); display: flex; align-items: center; gap: 4px; margin-top: 4px; flex-wrap: wrap; }
  .online-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--offline); flex-shrink: 0; }
  .online-dot.online { background: var(--online); }
  .custom-status { color: var(--text-muted); font-style: italic; }

  /* Multi-quote */
  .mq-check { display: flex; align-items: center; gap: 3px; font-size: 11px; }
  .mq-check input { width: auto; margin: 0; }
  .mq-bar { display: flex; align-items: center; gap: 8px; padding: 6px 10px; background: var(--accent-glow); border: 1px solid var(--border-accent); border-radius: var(--radius); margin-bottom: 8px; font-size: 12px; color: var(--accent); }

  /* Preview */
  .preview-box { background: var(--bg-tertiary); border: 1px solid var(--border-color); border-radius: var(--radius); margin-top: 8px; }
  .preview-header { padding: 6px 10px; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; border-bottom: 1px solid var(--border-color); }
  .preview-body { padding: 10px; font-size: 14px; color: var(--text-primary); line-height: 1.6; }
  .tb-btn { width: 28px; height: 28px; display: flex; align-items: center; justify-content: center; border: none; background: none; color: var(--text-secondary); font-size: 14px; cursor: pointer; border-radius: 3px; }
  .tb-btn:hover, .tb-btn.active { background: var(--bg-hover); color: var(--accent); }

  /* Reply editor */
  .reply-editor { position: relative; }
  .reply-textarea { border-radius: 0 0 var(--radius) var(--radius) !important; }
  .reply-actions { display: flex; justify-content: space-between; align-items: center; margin-top: 8px; }
  .reply-tools { display: flex; gap: 4px; }

  /* Embed video */
  :global(.embed-video) { position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; margin: 8px 0; border-radius: var(--radius); }
  :global(.embed-video iframe) { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }

  /* Post body links and images */
  :global(.post-body a) { color: var(--accent); }
  :global(.post-body img) { max-width: 100%; height: auto; border-radius: var(--radius); cursor: zoom-in; }

  /* Edit history modal */
  .modal-overlay { position: fixed; inset: 0; z-index: 100; background: rgba(0,0,0,0.7); display: flex; align-items: center; justify-content: center; }
  .modal-content { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); max-width: 600px; width: 90%; max-height: 80vh; overflow-y: auto; }
  .modal-header { display: flex; justify-content: space-between; align-items: center; padding: 12px 16px; border-bottom: 1px solid var(--border-color); }
  .modal-header h3 { font-size: 16px; font-weight: 700; }
  .modal-close { background: none; border: none; color: var(--text-muted); font-size: 20px; cursor: pointer; }
  .loading-text { padding: 20px; text-align: center; color: var(--text-muted); font-size: 13px; }
  .history-list { padding: 12px 16px; }
  .history-item { margin-bottom: 16px; border-bottom: 1px solid var(--border-color); padding-bottom: 12px; }
  .history-meta { font-size: 12px; color: var(--text-secondary); margin-bottom: 8px; }
  .edit-reason { color: var(--text-muted); font-style: italic; }
  .diff-before, .diff-after { margin-bottom: 4px; }
  .diff-before strong, .diff-after strong { font-size: 11px; color: var(--text-muted); display: block; margin-bottom: 2px; }
  .diff-before pre, .diff-after pre { font-size: 12px; color: var(--text-secondary); background: var(--bg-tertiary); padding: 6px 8px; border-radius: var(--radius); white-space: pre-wrap; word-wrap: break-word; margin: 0; }

  /* Quote scroll & highlight */
  :global(.bbcode-quote cite) { cursor: pointer; }
  :global(.bbcode-quote cite:hover) { color: var(--accent); text-decoration: underline; }
  :global(.post-highlight) { animation: highlightFade 2s ease; }
  @keyframes highlightFade { 0% { background: rgba(0, 212, 170, 0.15); } 100% { background: transparent; } }

  /* Similar Threads */
  .similar-threads { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 14px 16px; margin-top: 8px; }
  .similar-heading { font-size: 12px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.04em; margin-bottom: 10px; }
  .similar-list { display: flex; flex-direction: column; gap: 6px; }
  .similar-item { display: block; padding: 8px 10px; border: 1px solid var(--border-color); border-radius: var(--radius); text-decoration: none; transition: background 0.15s, border-color 0.15s; }
  .similar-item:hover { background: var(--bg-hover); border-color: var(--accent); }
  .similar-title { font-size: 13px; font-weight: 600; color: var(--text-primary); }
  .similar-meta { font-size: 11px; color: var(--text-muted); margin-top: 2px; display: flex; gap: 4px; }

  /* Quoted-by navigator */
  .quoted-by-links { padding: 4px 16px 0; display: flex; flex-wrap: wrap; gap: 6px; }
  .quoted-by-link { background: none; border: none; color: var(--text-muted); font-size: 11px; cursor: pointer; padding: 2px 6px; border-radius: var(--radius); transition: color 0.15s, background 0.15s; }
  .quoted-by-link:hover { color: var(--accent); background: var(--bg-hover); }
  .quoted-by-arrow { font-size: 10px; }

  /* Bookmark button */
  .action-btn.bookmarked { color: var(--accent); font-weight: 600; }

  /* Draft auto-save indicator */
  .draft-indicator { font-size: 11px; color: var(--text-muted); margin-top: 4px; transition: opacity 0.3s; }
  .draft-indicator.saving { color: var(--text-secondary); }
  .draft-indicator.saved { color: var(--accent); }

  /* === Mobile === */
  @media (max-width: 768px) {
    .thread-header { padding: 10px 0; margin-bottom: 4px; }
    .thread-title { font-size: 18px; line-height: 1.25; flex-wrap: wrap; gap: 6px; }
    .thread-controls { flex-direction: column; align-items: stretch; gap: 8px; }
    .thread-stats { flex-wrap: wrap; gap: 4px 8px; font-size: 11px; }
    .thread-actions { flex-wrap: wrap; gap: 4px 6px; }
    .thread-actions :global(button), .thread-actions :global(select) { min-height: 36px; }
    .sub-select, .btn-mute, .btn-share { font-size: 12px; padding: 6px 10px; min-height: 36px; }

    /* Post boxes: avatar + name as a slim row above content. user-panel is
       already flipped to row by app.css; just shrink internals here. */
    :global(.post-user-panel .avatar) { width: 36px !important; height: 36px !important; font-size: 16px; margin: 0 !important; border-width: 1px; }
    :global(.post-user-panel .user-title), :global(.post-user-panel .user-stats) { display: none; }
    :global(.post-user-panel .username) { font-size: 14px; margin: 0; }
    :global(.post-header) { padding: 6px 10px; font-size: 11px; flex-wrap: wrap; }
    :global(.post-body) { padding: 10px 12px !important; font-size: 14px; }
    :global(.post-footer) { flex-wrap: wrap; gap: 4px 6px !important; padding: 6px 10px !important; }
    :global(.action-btn) { font-size: 12px; padding: 6px 8px; min-height: 36px; }

    /* Reply composer */
    .reply-textarea { min-height: 90px; font-size: 14px; }
    :global(.tb-btn) { width: 36px !important; height: 36px !important; font-size: 16px; }

    /* Pagination buttons big enough for thumbs */
    .pg-btn { min-height: 36px; min-width: 36px; padding: 6px 10px; font-size: 13px; }

    /* Post date / num collapse onto one line */
    .post-date, .post-num { font-size: 11px; }

    /* Edit history / spoiler modals don't dwarf viewport */
    .modal-content { width: 96vw !important; max-width: 96vw; max-height: 90vh; }
  }

  @media (max-width: 480px) {
    .thread-title { font-size: 16px; }
    :global(.post-body) { font-size: 13px; }
  }
</style>
