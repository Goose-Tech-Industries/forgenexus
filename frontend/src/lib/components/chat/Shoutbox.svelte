<script lang="ts">
  import { onDestroy } from 'svelte';
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';
  import { socketStore } from '$lib/stores/socket.svelte';
  import UsernameDisplay from '$lib/components/common/UsernameDisplay.svelte';

  interface ShoutboxMessage {
    id: string;
    body: string;
    inserted_at: string;
    user: {
      id: string;
      username: string;
      avatar_url: string | null;
      username_color: string | null;
      username_effect: string | null;
    };
  }

  let messages = $state<ShoutboxMessage[]>([]);
  let messageInput = $state('');
  let collapsed = $state(false);
  let messagesEl: HTMLDivElement;
  let sending = $state(false);

  // Track existing message IDs to prevent duplicates from real-time + optimistic
  let knownIds = new Set<string>();

  $effect(() => {
    loadMessages();
  });

  // Subscribe to real-time shoutbox messages via Phoenix channel
  const unsubShoutbox = socketStore.onShoutboxMessage((msg: any) => {
    // Skip our own messages (we already added them optimistically)
    if (msg.user?.id === auth.user?.id) return;
    if (knownIds.has(msg.id)) return;
    knownIds.add(msg.id);
    messages = [...messages, msg];
    scrollToBottom();
  });

  onDestroy(() => {
    unsubShoutbox();
  });

  async function loadMessages() {
    try {
      const data = await api.getShoutbox();
      messages = data.messages || [];
      knownIds = new Set(messages.map(m => m.id));
      scrollToBottom();
    } catch {
      // silent
    }
  }

  function scrollToBottom() {
    requestAnimationFrame(() => {
      if (messagesEl) {
        messagesEl.scrollTop = messagesEl.scrollHeight;
      }
    });
  }

  async function sendMessage() {
    if (!messageInput.trim() || sending) return;
    sending = true;
    const body = messageInput.trim();
    messageInput = '';

    // Optimistic add
    messages = [...messages, {
      id: crypto.randomUUID(),
      body,
      inserted_at: new Date().toISOString(),
      user: {
        id: auth.user?.id || '',
        username: auth.user?.username || 'You',
        avatar_url: null,
        username_color: null,
        username_effect: null
      }
    }];
    scrollToBottom();

    try {
      await socketStore.sendShoutboxMessage(body);
    } catch {
      // Channel not connected yet — fall back to HTTP so the message still
      // persists to the DB and everyone else sees it on next refresh.
      try {
        await api.sendShoutbox(body);
      } catch {
        // Still fails: the optimistic message stays visible so the user
        // knows what they tried to send.
      }
    }
    sending = false;
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  }

  function formatTime(dateStr: string): string {
    const date = new Date(dateStr);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }
</script>

<div class="shoutbox" class:collapsed>
  <div class="shoutbox-header" role="button" tabindex="0" onclick={() => collapsed = !collapsed} onkeydown={(e) => { if (e.key === 'Enter') collapsed = !collapsed; }}>
    <span class="shoutbox-title">Shoutbox</span>
    <span class="toggle-icon">{collapsed ? '\u25B6' : '\u25BC'}</span>
  </div>

  {#if !collapsed}
    <div class="shoutbox-messages" bind:this={messagesEl}>
      {#each messages as msg (msg.id)}
        <div class="shout-msg">
          <span class="shout-time">{formatTime(msg.inserted_at)}</span>
          <UsernameDisplay
            username={msg.user.username}
            color={msg.user.username_color}
            effect={msg.user.username_effect}
            size="small"
          />
          <span class="shout-sep">:</span>
          <span class="shout-body">{msg.body}</span>
        </div>
      {/each}
      {#if messages.length === 0}
        <div class="shout-empty">No shouts yet. Be the first!</div>
      {/if}
    </div>

    {#if auth.isLoggedIn}
      <div class="shoutbox-input">
        <input
          type="text"
          placeholder="Type a shout..."
          bind:value={messageInput}
          onkeydown={handleKeydown}
        />
        <button class="shout-send" onclick={sendMessage} disabled={sending || !messageInput.trim()}>
          Send
        </button>
      </div>
    {:else}
      <div class="shoutbox-login">
        <a href="/auth/login">Login</a> to shout
      </div>
    {/if}
  {/if}
</div>

<style>
  .shoutbox {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    overflow: hidden;
  }

  .shoutbox-header {
    background: linear-gradient(180deg, var(--bg-tertiary) 0%, var(--bg-secondary) 100%);
    border-bottom: 2px solid var(--accent);
    padding: 8px 12px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    cursor: pointer;
    user-select: none;
  }

  .shoutbox-title {
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--accent);
  }

  .toggle-icon {
    font-size: 10px;
    color: var(--text-muted);
  }

  .shoutbox.collapsed .shoutbox-header {
    border-bottom-color: var(--border-color);
  }

  .shoutbox-messages {
    height: 160px;
    overflow-y: auto;
    padding: 8px 12px;
    font-size: 13px;
  }

  .shout-msg {
    display: flex;
    align-items: baseline;
    gap: 6px;
    margin-bottom: 2px;
    line-height: 1.5;
  }

  .shout-time {
    font-size: 10px;
    color: var(--text-muted);
    white-space: nowrap;
  }

  .shout-sep {
    color: var(--text-muted);
  }

  .shout-body {
    color: var(--text-primary);
    word-break: break-word;
  }

  .shout-empty {
    text-align: center;
    padding: 40px 0;
    color: var(--text-muted);
    font-size: 12px;
  }

  .shoutbox-input {
    display: flex;
    gap: 4px;
    padding: 6px 8px;
    border-top: 1px solid var(--border-color);
    background: var(--bg-secondary);
  }

  .shoutbox-input input {
    flex: 1;
    padding: 4px 8px;
    font-size: 13px;
  }

  .shout-send {
    padding: 4px 12px;
    background: var(--accent);
    color: var(--bg-primary);
    border: none;
    border-radius: var(--radius);
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s;
  }
  .shout-send:hover {
    background: var(--accent-hover);
  }
  .shout-send:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .shoutbox-login {
    text-align: center;
    padding: 8px;
    border-top: 1px solid var(--border-color);
    background: var(--bg-secondary);
    font-size: 12px;
    color: var(--text-muted);
  }
</style>
