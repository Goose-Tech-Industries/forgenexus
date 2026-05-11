<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';
  import { soundStore } from '$lib/stores/sounds.svelte';
  import { page } from '$app/stores';
  import UsernameDisplay from '$lib/components/common/UsernameDisplay.svelte';

  interface Conversation {
    id: string;
    type: string;
    title: string | null;
    last_message_at: string | null;
    message_count: number;
    participants: { id: string; username: string; avatar_url: string | null; is_online: boolean }[];
  }

  interface Message {
    id: string;
    body: string;
    body_html: string | null;
    is_system: boolean;
    inserted_at: string;
    user: { id: string; username: string; avatar_url: string | null };
  }

  let conversations = $state<Conversation[]>([]);
  let selectedConversation = $state<Conversation | null>(null);
  let messages = $state<Message[]>([]);
  let loading = $state(true);
  let loadingMessages = $state(false);
  let messageInput = $state('');
  let messagesEl: HTMLDivElement;

  // New message modal with typeahead multi-select
  interface RecipientHit { id: string; username: string; slug: string; avatar_url: string | null; }

  let showNewMessage = $state(false);
  let recipientInput = $state('');
  let selectedRecipients = $state<RecipientHit[]>([]);
  let recipientResults = $state<RecipientHit[]>([]);
  let recipientSearching = $state(false);
  let recipientFocused = $state(false);
  let newTitle = $state('');
  let newBody = $state('');
  let creating = $state(false);

  $effect(() => {
    if (auth.isLoggedIn) {
      loadConversations();
    }
  });

  // When ?to=<username_or_id> is present, open modal with that user preloaded.
  $effect(() => {
    const to = $page.url.searchParams.get('to');
    if (to && auth.isLoggedIn && !showNewMessage && selectedRecipients.length === 0) {
      preloadRecipient(to);
    }
  });

  async function preloadRecipient(handle: string) {
    showNewMessage = true;
    try {
      const res = await api.searchMembers(handle, 5);
      const hit = (res.users || []).find((u: any) => u.id === handle || u.slug === handle || u.username?.toLowerCase() === handle.toLowerCase()) || (res.users || [])[0];
      if (hit) selectedRecipients = [hit];
    } catch {}
  }

  let searchTimer: any = null;
  $effect(() => {
    const q = recipientInput.trim();
    clearTimeout(searchTimer);
    if (q.length < 2) { recipientResults = []; return; }
    searchTimer = setTimeout(async () => {
      recipientSearching = true;
      try {
        const res = await api.searchMembers(q, 8);
        recipientResults = (res.users || []).filter((u: any) =>
          u.id !== auth.user?.id && !selectedRecipients.some(s => s.id === u.id)
        );
      } catch { recipientResults = []; }
      recipientSearching = false;
    }, 180);
  });

  function addRecipient(u: RecipientHit) {
    if (!selectedRecipients.some(s => s.id === u.id)) {
      selectedRecipients = [...selectedRecipients, u];
    }
    recipientInput = '';
    recipientResults = [];
  }

  function removeRecipient(id: string) {
    selectedRecipients = selectedRecipients.filter(s => s.id !== id);
  }

  function handleRecipientKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' && recipientResults[0]) {
      e.preventDefault();
      addRecipient(recipientResults[0]);
    } else if (e.key === 'Backspace' && recipientInput === '' && selectedRecipients.length > 0) {
      selectedRecipients = selectedRecipients.slice(0, -1);
    }
  }

  async function loadConversations() {
    loading = true;
    try {
      const data = await api.getConversations();
      conversations = data.conversations || [];
    } catch {
      conversations = [];
    }
    loading = false;
  }

  async function selectConversation(conv: Conversation) {
    selectedConversation = conv;
    loadingMessages = true;
    try {
      const data = await api.getMessages(conv.id);
      messages = data.messages || [];
      scrollToBottom();
    } catch {
      messages = [];
    }
    loadingMessages = false;
  }

  function scrollToBottom() {
    requestAnimationFrame(() => {
      if (messagesEl) {
        messagesEl.scrollTop = messagesEl.scrollHeight;
      }
    });
  }

  function getConversationName(conv: Conversation): string {
    if (conv.title) return conv.title;
    if (conv.participants.length > 0) {
      return conv.participants.map(p => p.username).join(', ');
    }
    return 'Conversation';
  }

  function timeAgo(dateStr: string | null): string {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    const now = new Date();
    const diff = Math.floor((now.getTime() - date.getTime()) / 1000);
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return date.toLocaleDateString();
  }

  function formatDate(dateStr: string): string {
    return new Date(dateStr).toLocaleString();
  }

  async function sendMessage() {
    if (!selectedConversation || !messageInput.trim()) return;
    const body = messageInput.trim();
    messageInput = '';

    const tempId = crypto.randomUUID();
    messages = [...messages, {
      id: tempId,
      body,
      body_html: null,
      is_system: false,
      inserted_at: new Date().toISOString(),
      user: { id: auth.user?.id || '', username: auth.user?.username || 'You', avatar_url: null }
    }];
    scrollToBottom();
    soundStore.messageSent();

    try {
      const data = await api.sendDmMessage(selectedConversation.id, body);
      messages = messages.map(m => m.id === tempId ? data.message : m);
    } catch {
      messages = messages.filter(m => m.id !== tempId);
    }
  }

  function handleMessageKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  }

  async function createNewMessage() {
    if (selectedRecipients.length === 0 || !newBody.trim()) return;
    creating = true;
    try {
      const participantIds = selectedRecipients.map(u => u.id);
      const data = await api.createGroupChat(newTitle || '', participantIds);
      if (data.conversation) {
        await api.sendDmMessage(data.conversation.id, newBody.trim());
        showNewMessage = false;
        selectedRecipients = [];
        recipientInput = '';
        newTitle = '';
        newBody = '';
        await loadConversations();
        await selectConversation(data.conversation);
      }
    } catch {
      // silent
    }
    creating = false;
  }

  function getInitial(username: string): string {
    return username?.charAt(0)?.toUpperCase() || '?';
  }
</script>

<div class="messages-page">
  <div class="messages-header">
    <h1>Messages</h1>
    <button class="btn btn-primary" onclick={() => showNewMessage = true}>New Message</button>
  </div>

  {#if !auth.isLoggedIn}
    <div class="login-prompt">
      <a href="/auth/login">Login</a> to view your messages
    </div>
  {:else}
    <div class="messages-layout" class:has-selection={!!selectedConversation}>
      <!-- Conversation list (left) -->
      <div class="conversation-list">
        {#if loading}
          <div class="empty">Loading conversations...</div>
        {:else if conversations.length === 0}
          <div class="empty">No messages yet</div>
        {:else}
          {#each conversations as conv (conv.id)}
            <button
              class="conversation-item"
              class:active={selectedConversation?.id === conv.id}
              onclick={() => selectConversation(conv)}
            >
              <div class="conv-avatar">
                {#if conv.participants[0]?.avatar_url}
                  <img src={conv.participants[0].avatar_url} alt="" />
                {:else}
                  {getInitial(conv.participants[0]?.username || '?')}
                {/if}
                {#if conv.participants[0]?.is_online}
                  <span class="status-dot online"></span>
                {/if}
              </div>
              <div class="conv-info">
                <div class="conv-name">{getConversationName(conv)}</div>
                <div class="conv-meta">
                  {#if conv.type === 'group'}
                    <span class="conv-type">Group</span>
                  {/if}
                  <span>{timeAgo(conv.last_message_at)}</span>
                  <span>&middot; {conv.message_count} msgs</span>
                </div>
              </div>
            </button>
          {/each}
        {/if}
      </div>

      <!-- Message view (right) -->
      <div class="message-view">
        {#if !selectedConversation}
          <div class="no-selection">Select a conversation to view messages</div>
        {:else if loadingMessages}
          <div class="no-selection">Loading messages...</div>
        {:else}
          <div class="message-view-header">
            <button class="back-btn" onclick={() => selectedConversation = null} aria-label="Back to conversations">&larr;</button>
            <h2>{getConversationName(selectedConversation)}</h2>
            {#if selectedConversation.type === 'group'}
              <span class="participant-count">{selectedConversation.participants.length + 1} participants</span>
            {/if}
          </div>

          <div class="message-list" bind:this={messagesEl}>
            {#each messages as msg (msg.id)}
              <div class="dm-message" class:system={msg.is_system}>
                <div class="dm-avatar">
                  {#if msg.user.avatar_url}
                    <img src={msg.user.avatar_url} alt={msg.user.username} />
                  {:else}
                    {getInitial(msg.user.username)}
                  {/if}
                </div>
                <div class="dm-content">
                  <div class="dm-header">
                    <span class="dm-username">{msg.user.username}</span>
                    <span class="dm-time">{formatDate(msg.inserted_at)}</span>
                  </div>
                  <div class="dm-body">{msg.body}</div>
                </div>
              </div>
            {/each}
            {#if messages.length === 0}
              <div class="no-selection">No messages in this conversation</div>
            {/if}
          </div>

          <div class="message-input-area">
            <textarea
              placeholder="Type a message..."
              bind:value={messageInput}
              onkeydown={handleMessageKeydown}
              rows="3"
            ></textarea>
            <button class="btn btn-primary" disabled={!messageInput.trim()} onclick={sendMessage}>Send</button>
          </div>
        {/if}
      </div>
    </div>
  {/if}

  <!-- New Message Modal -->
  {#if showNewMessage}
    <div class="modal-overlay" role="button" tabindex="-1" onclick={() => showNewMessage = false} onkeydown={() => {}}>
      <div class="modal" role="dialog" onclick={(e) => e.stopPropagation()} onkeydown={() => {}}>
        <div class="modal-header">
          <h3>New Message</h3>
          <button class="modal-close" onclick={() => showNewMessage = false}>&times;</button>
        </div>
        <div class="modal-body">
          <label>
            Recipients
            <div class="recipient-picker" class:focused={recipientFocused}>
              {#each selectedRecipients as u (u.id)}
                <span class="recipient-chip">
                  {#if u.avatar_url}<img src={u.avatar_url} alt="" />{/if}
                  {u.username}
                  <button type="button" onclick={() => removeRecipient(u.id)} aria-label="Remove">×</button>
                </span>
              {/each}
              <input
                type="text"
                bind:value={recipientInput}
                placeholder={selectedRecipients.length === 0 ? 'Start typing a username…' : ''}
                onkeydown={handleRecipientKeydown}
                onfocus={() => (recipientFocused = true)}
                onblur={() => setTimeout(() => (recipientFocused = false), 150)}
                autocomplete="off"
              />
            </div>
            {#if recipientFocused && (recipientResults.length > 0 || recipientSearching)}
              <div class="typeahead-results">
                {#if recipientSearching && recipientResults.length === 0}
                  <div class="typeahead-empty">Searching…</div>
                {:else}
                  {#each recipientResults as u (u.id)}
                    <button type="button" class="typeahead-row" onmousedown={() => addRecipient(u)}>
                      <span class="typeahead-avatar">
                        {#if u.avatar_url}<img src={u.avatar_url} alt="" />{:else}{u.username?.charAt(0)?.toUpperCase()}{/if}
                      </span>
                      <span class="typeahead-name">{u.username}</span>
                    </button>
                  {/each}
                {/if}
              </div>
            {/if}
          </label>
          <label>
            Title (optional, for group messages)
            <input type="text" bind:value={newTitle} placeholder="Conversation title" />
          </label>
          <label>
            Message
            <textarea bind:value={newBody} rows="4" placeholder="Write your message..."></textarea>
          </label>
        </div>
        <div class="modal-footer">
          <button class="btn" onclick={() => showNewMessage = false}>Cancel</button>
          <button class="btn btn-primary" disabled={creating || selectedRecipients.length === 0 || !newBody.trim()} onclick={createNewMessage}>
            {creating ? 'Sending...' : 'Send Message'}
          </button>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .messages-page {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .messages-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .messages-header h1 {
    font-size: 20px;
    font-weight: 800;
  }

  .messages-layout {
    display: grid;
    grid-template-columns: 280px 1fr;
    gap: 0;
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    overflow: hidden;
    /* Constrain height so the inner message-list flex:1 actually works.
       Without this the list grew forever and pushed the input below the viewport. */
    height: calc(100vh - 180px);
    min-height: 500px;
  }

  .back-btn {
    display: none;
    background: none;
    border: none;
    color: var(--accent);
    font-size: 22px;
    line-height: 1;
    padding: 4px 10px;
    cursor: pointer;
    margin-right: 4px;
  }
  .back-btn:hover { color: var(--accent-hover); }

  .conversation-list {
    background: var(--bg-secondary);
    border-right: 1px solid var(--border-color);
    overflow-y: auto;
  }

  .conversation-item {
    display: flex;
    align-items: center;
    gap: 10px;
    width: 100%;
    padding: 10px 12px;
    background: none;
    border: none;
    border-bottom: 1px solid var(--border-color);
    color: var(--text-primary);
    cursor: pointer;
    text-align: left;
    transition: background 0.1s;
  }
  .conversation-item:hover {
    background: var(--bg-hover);
  }
  .conversation-item.active {
    background: var(--bg-card);
    border-left: 3px solid var(--accent);
  }

  .conv-avatar {
    width: 36px;
    height: 36px;
    border-radius: 50%;
    background: var(--bg-tertiary);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 14px;
    font-weight: 700;
    color: var(--text-muted);
    flex-shrink: 0;
    position: relative;
  }
  .conv-avatar img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    border-radius: 50%;
  }
  .conv-avatar .status-dot {
    position: absolute;
    bottom: -1px;
    right: -1px;
    width: 10px;
    height: 10px;
    border: 2px solid var(--bg-secondary);
  }

  .conv-info {
    flex: 1;
    min-width: 0;
  }

  .conv-name {
    font-size: 13px;
    font-weight: 600;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .conv-meta {
    font-size: 11px;
    color: var(--text-muted);
    display: flex;
    gap: 4px;
  }

  .conv-type {
    background: var(--accent-glow);
    color: var(--accent);
    padding: 0 4px;
    border-radius: 2px;
    font-size: 10px;
    font-weight: 600;
  }

  .message-view {
    display: flex;
    flex-direction: column;
    background: var(--bg-card);
  }

  .message-view-header {
    padding: 12px 16px;
    border-bottom: 1px solid var(--border-color);
    background: var(--bg-secondary);
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .message-view-header h2 {
    font-size: 15px;
    font-weight: 700;
  }
  .participant-count {
    font-size: 11px;
    color: var(--text-muted);
  }

  .message-list {
    flex: 1;
    overflow-y: auto;
    padding: 12px 16px;
  }

  .dm-message {
    display: flex;
    gap: 10px;
    margin-bottom: 12px;
  }

  .dm-avatar {
    width: 32px;
    height: 32px;
    border-radius: 50%;
    background: var(--bg-tertiary);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 13px;
    font-weight: 700;
    color: var(--text-muted);
    flex-shrink: 0;
  }
  .dm-avatar img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    border-radius: 50%;
  }

  .dm-content {
    flex: 1;
  }

  .dm-header {
    display: flex;
    gap: 8px;
    align-items: baseline;
    margin-bottom: 2px;
  }

  .dm-username {
    font-weight: 700;
    font-size: 13px;
    color: var(--accent);
  }

  .dm-time {
    font-size: 11px;
    color: var(--text-muted);
  }

  .dm-body {
    font-size: 14px;
    line-height: 1.5;
    color: var(--text-primary);
  }

  .message-input-area {
    padding: 12px 16px;
    border-top: 1px solid var(--border-color);
    background: var(--bg-secondary);
    display: flex;
    gap: 8px;
    align-items: flex-end;
  }
  .message-input-area textarea {
    flex: 1;
    resize: none;
  }

  .no-selection {
    display: flex;
    align-items: center;
    justify-content: center;
    flex: 1;
    color: var(--text-muted);
    font-size: 14px;
  }

  .empty {
    padding: 40px 12px;
    text-align: center;
    color: var(--text-muted);
    font-size: 13px;
  }

  .login-prompt {
    text-align: center;
    padding: 40px;
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    color: var(--text-secondary);
  }

  /* Modal */
  .modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.6);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 2000;
  }

  .modal {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    width: 480px;
    max-width: 90vw;
  }

  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 16px;
    border-bottom: 1px solid var(--border-color);
  }
  .modal-header h3 {
    font-size: 15px;
    font-weight: 700;
  }
  .modal-close {
    background: none;
    border: none;
    color: var(--text-muted);
    font-size: 20px;
    cursor: pointer;
  }

  .modal-body {
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .modal-body label {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary);
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .modal-footer {
    padding: 12px 16px;
    border-top: 1px solid var(--border-color);
    display: flex;
    justify-content: flex-end;
    gap: 8px;
  }

/* Recipient typeahead */
.recipient-picker {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  padding: 6px 8px;
  border: 1px solid var(--border, #2a3040);
  border-radius: 4px;
  background: var(--bg-primary, #0a0e17);
  min-height: 40px;
  align-items: center;
}
.recipient-picker.focused { border-color: var(--accent, #00d4aa); }
.recipient-picker input {
  flex: 1;
  min-width: 150px;
  padding: 4px;
  background: transparent;
  border: none;
  color: var(--text-primary, #e8eaed);
  outline: none;
  font-size: 0.92rem;
}
.recipient-chip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 4px 3px 8px;
  background: var(--accent, #00d4aa);
  color: #000;
  border-radius: 999px;
  font-size: 0.85rem;
  font-weight: 600;
}
.recipient-chip img { width: 20px; height: 20px; border-radius: 50%; }
.recipient-chip button {
  background: transparent;
  border: none;
  color: #000;
  cursor: pointer;
  font-size: 1rem;
  line-height: 1;
  padding: 0 2px;
}
.recipient-chip button:hover { color: #fff; }
.typeahead-results {
  margin-top: 2px;
  background: var(--bg-secondary, #121826);
  border: 1px solid var(--border, #2a3040);
  border-radius: 4px;
  max-height: 240px;
  overflow-y: auto;
}
.typeahead-row {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  padding: 8px 10px;
  background: transparent;
  border: none;
  color: var(--text-primary, #e8eaed);
  cursor: pointer;
  text-align: left;
  font-size: 0.9rem;
}
.typeahead-row:hover { background: var(--bg-tertiary, #1a2030); }
.typeahead-avatar {
  width: 28px; height: 28px;
  border-radius: 50%;
  background: var(--bg-tertiary, #1a2030);
  display: flex; align-items: center; justify-content: center;
  font-weight: 700;
  overflow: hidden;
}
.typeahead-avatar img { width: 100%; height: 100%; object-fit: cover; }
.typeahead-empty { padding: 8px 10px; color: var(--text-tertiary, #6a748a); font-size: 0.85rem; font-style: italic; }

/* === Mobile: single-pane navigation === */
@media (max-width: 768px) {
  .messages-page {
    height: calc(100vh - 110px);
  }
  .messages-layout {
    grid-template-columns: 1fr;
    height: 100%;
    border-radius: var(--radius-md, 8px);
  }
  /* When no conversation selected, show the list full width and hide the right pane.
     When one IS selected, hide the list and show the right pane (the message view) full width. */
  .messages-layout:not(.has-selection) .message-view {
    display: none;
  }
  .messages-layout.has-selection .conversation-list {
    display: none;
  }
  .back-btn {
    display: inline-flex;
    align-items: center;
    min-width: 44px;
    min-height: 44px;
    justify-content: center;
  }
  /* Make the input area clearly anchored at the bottom even with the keyboard up */
  .message-input-area {
    padding: 8px 10px;
    gap: 6px;
  }
  .message-input-area textarea {
    min-height: 40px;
    max-height: 120px;
  }
  .message-input-area .btn { min-height: 44px; }

  /* Tighter chrome on mobile */
  .message-view-header {
    padding: 8px 10px;
  }
  .message-view-header h2 {
    font-size: 14px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .conversation-item {
    padding: 12px;
  }
  .conv-avatar {
    width: 40px;
    height: 40px;
  }
  .messages-header h1 {
    font-size: 18px;
  }
  /* New Message modal stays inside viewport */
  .modal {
    width: 100%;
    max-height: 92vh;
    border-radius: 12px 12px 0 0;
  }
}

@media (max-width: 600px) {
  .messages-header { padding: 8px 10px; gap: 6px; }
  .messages-header h1 { font-size: 16px; }
  .back-btn { font-size: 18px; padding: 4px 8px; }
  .conversation-item { padding: 10px; gap: 8px; }
  .conv-avatar { width: 36px !important; height: 36px !important; }
  .messages-page { height: calc(100vh - 96px); }
  .message-view-header { padding: 6px 8px; }
  .message-view-header h2 { font-size: 13px; }
}
</style>
