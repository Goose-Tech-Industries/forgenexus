<script lang="ts">
  import { auth } from '$lib/stores/auth.svelte';
  import { channelStore, type ChannelMessage } from '$lib/stores/channels.svelte';
  import ChannelSidebar from '$lib/components/channels/ChannelSidebar.svelte';
  import ChatMessageComponent from '$lib/components/channels/ChatMessage.svelte';
  import MessageInput from '$lib/components/channels/MessageInput.svelte';
  import ChatSearch from '$lib/components/channels/ChatSearch.svelte';
  import ThreadPanel from '$lib/components/channels/ThreadPanel.svelte';
  import VoiceControls from '$lib/components/channels/VoiceControls.svelte';
  import { voiceStore } from '$lib/stores/voice.svelte';
  import { socketStore } from '$lib/stores/socket.svelte';
  import { api } from '$lib/api/client';

  let messagesContainer: HTMLDivElement;
  let replyTo = $state<ChannelMessage | null>(null);
  let editingMessage = $state<ChannelMessage | null>(null);
  let showSearch = $state(false);
  let activeThreadId = $state<string | null>(null);
  let bookmarkedIds = $state<Set<string>>(new Set());
  // Mobile drawer state — closes automatically on channel select
  let mobileSidebarOpen = $state(false);

  // Typing indicator display
  let typingDisplay = $derived.by(() => {
    const users = Array.from(channelStore.typingUsers.values()).map(u => u.username);
    if (users.length === 0) return '';
    if (users.length === 1) return `${users[0]} is typing...`;
    if (users.length === 2) return `${users[0]} and ${users[1]} are typing...`;
    return `${users[0]} and ${users.length - 1} others are typing...`;
  });

  let canPost = $derived.by(() => {
    const ch = channelStore.activeChannel;
    if (!ch) return false;
    if (ch.is_archived) return false;
    if (ch.is_read_only && !auth.isStaff) return false;
    return true;
  });

  $effect(() => {
    channelStore.loadChannels();
    voiceStore.loadRooms();
    loadBookmarkIds();
  });

  async function loadBookmarkIds() {
    try {
      const data = await api.getBookmarkIds();
      bookmarkedIds = new Set(data.message_ids || []);
    } catch { /* silent */ }
  }

  // Auto-scroll when new messages arrive
  $effect(() => {
    // eslint-disable-next-line @typescript-eslint/no-unused-expressions
    channelStore.messages.length;
    scrollToBottom();
  });

  function scrollToBottom() {
    requestAnimationFrame(() => {
      if (messagesContainer) {
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
      }
    });
  }

  let prevChannelSlug: string | null = null;

  async function selectChannel(slug: string) {
    replyTo = null;
    editingMessage = null;
    // Leave previous real-time channel, join new one
    if (prevChannelSlug) socketStore.leaveChatChannel(prevChannelSlug);
    await channelStore.selectChannel(slug);
    socketStore.joinChatChannel(slug);
    prevChannelSlug = slug;
    mobileSidebarOpen = false;
    scrollToBottom();
  }

  async function handleSend(body: string, replyToId?: string) {
    await channelStore.sendMessage(body, replyToId);
    replyTo = null;
    scrollToBottom();
  }

  function handleReply(msg: ChannelMessage) { replyTo = msg; }
  function handleCancelReply() { replyTo = null; }

  function handleEdit(msg: ChannelMessage) {
    const newBody = prompt('Edit message:', msg.body);
    if (newBody !== null && newBody.trim() !== msg.body) {
      channelStore.editMessage(msg.id, newBody.trim());
    }
  }

  function handleDelete(msg: ChannelMessage) {
    if (confirm('Delete this message?')) {
      channelStore.deleteMessage(msg.id);
    }
  }

  function handleReaction(msgId: string, emoji: string, hasReacted: boolean) {
    channelStore.toggleReaction(msgId, emoji, hasReacted);
  }

  async function handleJoinVoiceRoom(roomId: string) {
    const socket = socketStore.getSocket();
    if (socket) {
      voiceStore.joinRoom(roomId, socket);
    }
  }

  async function handleJumpToMessage(channelSlug: string, messageId: string) {
    showSearch = false;
    if (channelStore.activeChannel?.slug !== channelSlug) {
      await selectChannel(channelSlug);
    }
    // Scroll to the specific message if it's in view
    requestAnimationFrame(() => {
      const el = document.getElementById(`msg-${messageId}`);
      if (el) {
        el.scrollIntoView({ behavior: 'smooth', block: 'center' });
        el.classList.add('highlight-flash');
        setTimeout(() => el.classList.remove('highlight-flash'), 2000);
      }
    });
  }

  async function handlePin(msg: ChannelMessage) {
    if (!channelStore.activeChannel) return;
    try {
      if (msg.is_pinned) {
        await api.unpinMessage(channelStore.activeChannel.slug, msg.id);
      } else {
        await api.pinMessage(channelStore.activeChannel.slug, msg.id);
      }
      // Reload channel to get updated messages
      await channelStore.selectChannel(channelStore.activeChannel.slug);
    } catch { /* silent */ }
  }

  async function handleCreateThread(msg: ChannelMessage) {
    const threadMsg = msg as any;
    if (threadMsg.thread?.id) {
      activeThreadId = threadMsg.thread.id;
      return;
    }
    const name = prompt('Thread name:', msg.body?.slice(0, 60) || 'Thread');
    if (!name || !channelStore.activeChannel) return;
    try {
      const data = await api.createChatThread(channelStore.activeChannel.slug, msg.id, name);
      activeThreadId = data.thread.id;
    } catch { /* silent */ }
  }

  function handleOpenThread(threadId: string) {
    activeThreadId = threadId;
  }

  async function handleBookmark(msg: ChannelMessage) {
    try {
      const data = await api.toggleBookmark(msg.id);
      if (data.bookmarked) {
        bookmarkedIds = new Set([...bookmarkedIds, msg.id]);
      } else {
        bookmarkedIds = new Set([...bookmarkedIds].filter(id => id !== msg.id));
      }
    } catch { /* silent */ }
  }

  function handleScroll(e: Event) {
    const el = e.target as HTMLDivElement;
    // Load more when scrolled near top
    if (el.scrollTop < 100 && channelStore.hasMoreMessages && !channelStore.loadingMessages) {
      const oldHeight = el.scrollHeight;
      channelStore.loadMoreMessages().then(() => {
        // Preserve scroll position
        requestAnimationFrame(() => {
          el.scrollTop = el.scrollHeight - oldHeight;
        });
      });
    }
  }

  // Group consecutive messages from same user
  function shouldShowAvatar(msg: ChannelMessage, idx: number): boolean {
    if (idx === 0) return true;
    const prev = channelStore.messages[idx - 1];
    if (prev.user?.id !== msg.user?.id) return true;
    // Show avatar if more than 5 minutes apart
    const timeDiff = new Date(msg.inserted_at).getTime() - new Date(prev.inserted_at).getTime();
    return timeDiff > 300000;
  }
</script>

{#if !auth.isLoggedIn}
  <div class="chat-login-prompt">
    <h2>Chat</h2>
    <p>Please <a href="/login">sign in</a> to access chat channels.</p>
  </div>
{:else}
  <div class="chat-layout" class:mobile-sidebar-open={mobileSidebarOpen}>
    <button
      class="mobile-channels-toggle"
      onclick={() => mobileSidebarOpen = !mobileSidebarOpen}
      aria-label="Toggle channel list"
    >
      {#if mobileSidebarOpen}&times;{:else}&#9776;{/if}
    </button>
    <div
      class="mobile-sidebar-backdrop"
      onclick={() => mobileSidebarOpen = false}
      role="presentation"
    ></div>
    <div class="sidebar-wrap">
      <ChannelSidebar onSelectChannel={selectChannel} onJoinVoiceRoom={handleJoinVoiceRoom} />
    </div>

    <div class="chat-main">
      {#if !channelStore.activeChannel}
        <!-- No channel selected -->
        <div class="no-channel">
          <div class="no-channel-content">
            <div class="no-channel-icon">#</div>
            <h2>Welcome to Chat</h2>
            <p>Select a channel from the sidebar to start chatting</p>
          </div>
        </div>
      {:else}
        <!-- Channel header -->
        <div class="channel-header">
          <div class="ch-info">
            <span class="ch-hash">#</span>
            <h2>{channelStore.activeChannel.name}</h2>
            {#if channelStore.activeChannel.topic}
              <span class="ch-divider">|</span>
              <span class="ch-topic">{channelStore.activeChannel.topic}</span>
            {/if}
          </div>
          <div class="ch-actions">
            <button class="ch-action-btn" onclick={() => showSearch = true} title="Search messages">
              &#128269;
            </button>
            {#if channelStore.activeChannel.is_archived}
              <span class="ch-badge archived">ARCHIVED</span>
            {/if}
            {#if channelStore.activeChannel.is_read_only}
              <span class="ch-badge readonly">READ ONLY</span>
            {/if}
            {#if channelStore.activeChannel.slowmode_seconds > 0}
              <span class="ch-badge slowmode">SLOW {channelStore.activeChannel.slowmode_seconds}s</span>
            {/if}
          </div>
        </div>

        {#if channelStore.activeChannel.description}
          <div class="channel-description">{channelStore.activeChannel.description}</div>
        {/if}

        <!-- Messages area -->
        <div class="messages-area" bind:this={messagesContainer} onscroll={handleScroll}>
          {#if channelStore.loadingMessages && channelStore.messages.length === 0}
            <div class="messages-loading">Loading messages...</div>
          {:else if channelStore.messages.length === 0}
            <div class="messages-empty">
              <div class="empty-icon">#</div>
              <h3>Welcome to #{channelStore.activeChannel.name}!</h3>
              <p>This is the beginning of the channel. Say something!</p>
            </div>
          {:else}
            {#if channelStore.loadingMessages}
              <div class="loading-more">Loading older messages...</div>
            {/if}
            {#if !channelStore.hasMoreMessages}
              <div class="channel-start">
                <div class="start-icon">#</div>
                <h3>Welcome to #{channelStore.activeChannel.name}!</h3>
                {#if channelStore.activeChannel.description}
                  <p>{channelStore.activeChannel.description}</p>
                {/if}
              </div>
            {/if}
            {#each channelStore.messages as msg, i (msg.id)}
              <ChatMessageComponent
                message={msg}
                channelSlug={channelStore.activeChannel?.slug || ''}
                onReply={handleReply}
                onEdit={handleEdit}
                onDelete={handleDelete}
                onReaction={handleReaction}
                onPin={handlePin}
                onCreateThread={handleCreateThread}
                onOpenThread={handleOpenThread}
                onBookmark={handleBookmark}
                isBookmarked={bookmarkedIds.has(msg.id)}
              />
            {/each}
          {/if}
        </div>

        <!-- Typing indicator -->
        {#if typingDisplay}
          <div class="typing-indicator">
            <span class="typing-dots">
              <span></span><span></span><span></span>
            </span>
            {typingDisplay}
          </div>
        {/if}

        <!-- Message input -->
        <MessageInput
          channelName={channelStore.activeChannel.name}
          {replyTo}
          disabled={!canPost}
          onSend={handleSend}
          onCancelReply={handleCancelReply}
        />
      {/if}
    </div>

    <!-- Voice controls (persistent at bottom when in a room) -->
    <VoiceControls />

    {#if activeThreadId}
      <ThreadPanel
        threadId={activeThreadId}
        onClose={() => activeThreadId = null}
      />
    {/if}
  </div>

  {#if showSearch}
    <ChatSearch
      onClose={() => showSearch = false}
      onJumpToMessage={handleJumpToMessage}
    />
  {/if}
{/if}

<style>
  .chat-layout {
    display: flex;
    height: calc(100vh - 60px);
    background: var(--bg-primary);
    margin: -16px;
  }

  .chat-main {
    flex: 1;
    display: flex;
    flex-direction: column;
    min-width: 0;
  }

  /* No channel selected */
  .no-channel {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .no-channel-content { text-align: center; }
  .no-channel-icon {
    font-size: 64px;
    font-weight: 800;
    color: var(--border-color);
    margin-bottom: 12px;
  }
  .no-channel-content h2 {
    font-size: 20px;
    font-weight: 800;
    margin: 0 0 6px;
  }
  .no-channel-content p {
    font-size: 13px;
    color: var(--text-muted);
  }

  /* Channel header */
  .channel-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 16px;
    border-bottom: 1px solid var(--border-color);
    background: var(--bg-secondary);
    flex-shrink: 0;
  }
  .ch-info {
    display: flex;
    align-items: center;
    gap: 6px;
    overflow: hidden;
  }
  .ch-hash {
    font-size: 20px;
    font-weight: 800;
    color: var(--text-muted);
  }
  .ch-info h2 {
    font-size: 15px;
    font-weight: 700;
    margin: 0;
    white-space: nowrap;
  }
  .ch-divider { color: var(--border-color); }
  .ch-topic {
    font-size: 12px;
    color: var(--text-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .ch-actions { display: flex; gap: 6px; flex-shrink: 0; align-items: center; }
  .ch-action-btn {
    background: none;
    border: none;
    cursor: pointer;
    font-size: 14px;
    padding: 4px 6px;
    border-radius: var(--radius);
    color: var(--text-muted);
    transition: all 0.1s;
  }
  .ch-action-btn:hover { background: rgba(255, 255, 255, 0.06); color: var(--text-primary); }
  .ch-badge {
    font-size: 9px;
    font-weight: 700;
    padding: 2px 6px;
    border-radius: 3px;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }
  .ch-badge.archived { background: rgba(251, 191, 36, 0.15); color: #fbbf24; }
  .ch-badge.readonly { background: rgba(100, 116, 139, 0.15); color: #94a3b8; }
  .ch-badge.slowmode { background: rgba(6, 182, 212, 0.15); color: #06b6d4; }

  .channel-description {
    padding: 6px 16px;
    font-size: 12px;
    color: var(--text-muted);
    border-bottom: 1px solid var(--border-color);
    background: var(--bg-secondary);
  }

  /* Messages area */
  .messages-area {
    flex: 1;
    overflow-y: auto;
    padding: 8px 0;
    display: flex;
    flex-direction: column;
  }

  .messages-loading, .messages-empty {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--text-muted);
    font-size: 13px;
  }
  .messages-empty {
    flex-direction: column;
    text-align: center;
    gap: 4px;
  }
  .empty-icon, .start-icon {
    font-size: 48px;
    font-weight: 800;
    color: var(--border-color);
  }
  .messages-empty h3, .channel-start h3 {
    font-size: 16px;
    font-weight: 700;
    margin: 8px 0 2px;
  }
  .messages-empty p, .channel-start p {
    font-size: 12px;
    color: var(--text-muted);
  }

  .loading-more {
    text-align: center;
    padding: 8px;
    font-size: 11px;
    color: var(--text-muted);
  }

  .channel-start {
    text-align: center;
    padding: 24px 16px 12px;
    border-bottom: 1px solid var(--border-color);
    margin-bottom: 8px;
  }

  /* Typing indicator */
  .typing-indicator {
    padding: 4px 16px;
    font-size: 11px;
    color: var(--text-muted);
    display: flex;
    align-items: center;
    gap: 6px;
    min-height: 20px;
  }
  .typing-dots {
    display: flex;
    gap: 2px;
  }
  .typing-dots span {
    width: 4px;
    height: 4px;
    border-radius: 50%;
    background: var(--text-muted);
    animation: typing-bounce 1.4s ease-in-out infinite;
  }
  .typing-dots span:nth-child(2) { animation-delay: 0.2s; }
  .typing-dots span:nth-child(3) { animation-delay: 0.4s; }
  @keyframes typing-bounce {
    0%, 60%, 100% { transform: translateY(0); }
    30% { transform: translateY(-4px); }
  }

  /* Login prompt */
  .chat-login-prompt {
    text-align: center;
    padding: 60px 20px;
  }
  .chat-login-prompt h2 { font-size: 20px; font-weight: 800; margin-bottom: 8px; }
  .chat-login-prompt a { color: var(--accent); }

  /* Scrollbar */
  .messages-area::-webkit-scrollbar { width: 6px; }
  .messages-area::-webkit-scrollbar-track { background: transparent; }
  .messages-area::-webkit-scrollbar-thumb { background: var(--border-color); border-radius: 3px; }

  .mobile-channels-toggle {
    display: none;
    position: absolute;
    top: 8px;
    left: 8px;
    z-index: 20;
    width: 40px;
    height: 40px;
    border-radius: 8px;
    border: 1px solid var(--border-color);
    background: var(--bg-secondary);
    color: var(--text-primary);
    font-size: 20px;
    cursor: pointer;
  }

  .mobile-sidebar-backdrop {
    display: none;
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.45);
    z-index: 30;
  }

  .sidebar-wrap {
    display: contents;
  }

  @media (max-width: 768px) {
    .chat-layout {
      /* Stay flex-row so the slide-in sidebar overlays the main pane */
      flex-direction: row;
      height: calc(100vh - 60px);
      position: relative;
    }

    .mobile-channels-toggle {
      display: flex;
      align-items: center;
      justify-content: center;
    }

    /* Push the channel header text right of the hamburger so they don't overlap */
    .channel-header { padding-left: 56px !important; }

    /* Hide the sidebar by default; reveal as a slide-in drawer when toggled */
    .sidebar-wrap {
      display: block;
      position: fixed;
      top: 60px;
      bottom: 0;
      left: 0;
      width: 80vw;
      max-width: 280px;
      z-index: 40;
      transform: translateX(-100%);
      transition: transform 0.2s ease-out;
      box-shadow: 4px 0 16px rgba(0, 0, 0, 0.4);
      background: var(--bg-secondary);
      overflow-y: auto;
    }

    .chat-layout.mobile-sidebar-open .sidebar-wrap {
      transform: translateX(0);
    }

    .chat-layout.mobile-sidebar-open .mobile-sidebar-backdrop {
      display: block;
    }

    .chat-main {
      width: 100%;
    }
  }
</style>
