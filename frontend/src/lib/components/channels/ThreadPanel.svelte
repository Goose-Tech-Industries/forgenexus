<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';

  interface ThreadMessage {
    id: string;
    body: string;
    thread_id: string;
    user: { id: string; username: string; avatar_url: string | null; username_color: string | null } | null;
    is_edited: boolean;
    is_deleted: boolean;
    inserted_at: string;
  }

  interface Thread {
    id: string;
    name: string;
    message_count: number;
    is_locked: boolean;
    is_archived: boolean;
    created_by: { username: string } | null;
  }

  let {
    threadId,
    onClose
  }: {
    threadId: string;
    onClose: () => void;
  } = $props();

  let thread = $state<Thread | null>(null);
  let messages = $state<ThreadMessage[]>([]);
  let loading = $state(true);
  let input = $state('');
  let sending = $state(false);
  let messagesEl: HTMLDivElement;

  $effect(() => {
    loadThread(threadId);
  });

  async function loadThread(id: string) {
    loading = true;
    try {
      const data = await api.getChatThread(id);
      thread = data.thread;
      messages = data.messages || [];
      scrollToBottom();
    } catch { /* silent */ }
    loading = false;
  }

  function scrollToBottom() {
    requestAnimationFrame(() => {
      if (messagesEl) messagesEl.scrollTop = messagesEl.scrollHeight;
    });
  }

  async function handleSend() {
    if (!input.trim() || sending || !thread) return;
    sending = true;
    const body = input.trim();
    input = '';
    try {
      const data = await api.sendThreadMessage(thread.id, body);
      messages = [...messages, data.message];
      if (thread) thread.message_count++;
      scrollToBottom();
    } catch { /* silent */ }
    sending = false;
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleSend(); }
    if (e.key === 'Escape') onClose();
  }

  function formatTime(ts: string) {
    const d = new Date(ts);
    return d.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' });
  }

  let canPost = $derived(!thread?.is_locked && !thread?.is_archived);
</script>

<div class="thread-panel">
  <div class="thread-header">
    <div class="thread-title">
      <span class="thread-icon">&#128172;</span>
      <h3>{thread?.name || 'Thread'}</h3>
    </div>
    <button class="thread-close" onclick={onClose}>&times;</button>
  </div>

  {#if loading}
    <div class="thread-loading">Loading thread...</div>
  {:else}
    <div class="thread-messages" bind:this={messagesEl}>
      {#if messages.length === 0}
        <div class="thread-empty">No messages yet. Start the conversation!</div>
      {/if}
      {#each messages as msg (msg.id)}
        <div class="thread-msg" class:deleted={msg.is_deleted}>
          <div class="thread-msg-header">
            <span class="thread-msg-author" style:color={msg.user?.username_color || 'var(--text-primary)'}>
              {msg.user?.username || 'Unknown'}
            </span>
            <span class="thread-msg-time">{formatTime(msg.inserted_at)}</span>
            {#if msg.is_edited}
              <span class="thread-msg-edited">(edited)</span>
            {/if}
          </div>
          <div class="thread-msg-body">
            {#if msg.is_deleted}
              <em class="deleted-text">Message deleted</em>
            {:else}
              {msg.body}
            {/if}
          </div>
        </div>
      {/each}
    </div>

    <div class="thread-input">
      {#if canPost}
        <textarea
          bind:value={input}
          onkeydown={handleKeydown}
          placeholder="Reply to thread..."
          rows="1"
        ></textarea>
        <button class="thread-send" onclick={handleSend} disabled={!input.trim() || sending}>
          &#10148;
        </button>
      {:else}
        <div class="thread-locked">This thread is {thread?.is_locked ? 'locked' : 'archived'}</div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .thread-panel {
    width: 360px;
    border-left: 1px solid var(--border-color);
    background: var(--bg-secondary);
    display: flex;
    flex-direction: column;
    flex-shrink: 0;
  }

  .thread-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 14px;
    border-bottom: 1px solid var(--border-color);
  }
  .thread-title {
    display: flex;
    align-items: center;
    gap: 6px;
    overflow: hidden;
  }
  .thread-icon { font-size: 16px; }
  .thread-title h3 {
    font-size: 14px;
    font-weight: 700;
    margin: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .thread-close {
    background: none;
    border: none;
    font-size: 18px;
    color: var(--text-muted);
    cursor: pointer;
    padding: 4px;
    flex-shrink: 0;
  }
  .thread-close:hover { color: var(--text-primary); }

  .thread-loading, .thread-empty {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--text-muted);
    font-size: 13px;
    padding: 24px;
  }

  .thread-messages {
    flex: 1;
    overflow-y: auto;
    padding: 8px 0;
  }

  .thread-msg {
    padding: 6px 14px;
  }
  .thread-msg:hover { background: rgba(255, 255, 255, 0.02); }
  .thread-msg.deleted { opacity: 0.4; }

  .thread-msg-header {
    display: flex;
    align-items: baseline;
    gap: 6px;
    margin-bottom: 2px;
  }
  .thread-msg-author { font-size: 13px; font-weight: 600; }
  .thread-msg-time { font-size: 10px; color: var(--text-muted); }
  .thread-msg-edited { font-size: 10px; color: var(--text-muted); font-style: italic; }

  .thread-msg-body {
    font-size: 13px;
    color: var(--text-secondary);
    line-height: 1.4;
    word-break: break-word;
  }
  .deleted-text { color: var(--text-muted); }

  .thread-input {
    border-top: 1px solid var(--border-color);
    padding: 10px 14px;
    display: flex;
    gap: 8px;
    align-items: flex-end;
  }
  .thread-input textarea {
    flex: 1;
    background: var(--bg-primary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 8px 12px;
    font-size: 13px;
    color: var(--text-primary);
    font-family: inherit;
    resize: none;
    line-height: 1.4;
  }
  .thread-input textarea:focus { outline: none; border-color: var(--accent); }
  .thread-send {
    width: 34px;
    height: 34px;
    border-radius: 50%;
    background: var(--accent);
    color: var(--bg-primary);
    border: none;
    cursor: pointer;
    font-size: 14px;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .thread-send:disabled { opacity: 0.3; cursor: not-allowed; }
  .thread-locked {
    flex: 1;
    text-align: center;
    color: var(--text-muted);
    font-size: 12px;
    padding: 4px;
  }

  .thread-messages::-webkit-scrollbar { width: 4px; }
  .thread-messages::-webkit-scrollbar-track { background: transparent; }
  .thread-messages::-webkit-scrollbar-thumb { background: var(--border-color); border-radius: 2px; }
</style>
