<script lang="ts">
  import { channelStore, type ChannelMessage } from '$lib/stores/channels.svelte';
  import { socketStore } from '$lib/stores/socket.svelte';

  let {
    channelName = '',
    replyTo = null,
    disabled = false,
    onSend,
    onCancelReply
  }: {
    channelName?: string;
    replyTo?: ChannelMessage | null;
    disabled?: boolean;
    onSend: (body: string, replyToId?: string) => void;
    onCancelReply: () => void;
  } = $props();

  let input = $state('');
  let textareaEl: HTMLTextAreaElement;
  let sending = $state(false);
  let now = $state(Date.now());

  // Update "now" every 250ms for smooth countdown
  let timer: ReturnType<typeof setInterval>;
  $effect(() => {
    timer = setInterval(() => { now = Date.now(); }, 250);
    return () => clearInterval(timer);
  });

  let slowmodeRemaining = $derived(Math.max(0, Math.ceil((channelStore.slowmodeUntil - now) / 1000)));
  let isSlowmodeActive = $derived(slowmodeRemaining > 0);

  async function handleSend() {
    if (!input.trim() || sending || disabled || isSlowmodeActive) return;
    sending = true;
    const body = input.trim();
    const replyId = replyTo?.id;
    input = '';
    onSend(body, replyId);
    sending = false;
    textareaEl?.focus();
    // Reset height
    if (textareaEl) textareaEl.style.height = 'auto';
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
    if (e.key === 'Escape' && replyTo) {
      onCancelReply();
    }
  }

  let lastTypingSent = 0;
  function autoResize(e: Event) {
    const el = e.target as HTMLTextAreaElement;
    el.style.height = 'auto';
    el.style.height = Math.min(el.scrollHeight, 160) + 'px';
    // Send typing indicator at most every 2s
    const now = Date.now();
    if (now - lastTypingSent > 2000 && channelStore.activeChannel?.slug) {
      lastTypingSent = now;
      socketStore.sendTyping(channelStore.activeChannel.slug);
    }
  }
</script>

<div class="message-input-container">
  {#if replyTo}
    <div class="reply-preview">
      <div class="reply-info">
        <span class="reply-label">Replying to</span>
        <span class="reply-author">{replyTo.user?.username || 'Unknown'}</span>
        <span class="reply-text">{replyTo.body?.slice(0, 100)}</span>
      </div>
      <button class="reply-cancel" onclick={onCancelReply}>{'\u2715'}</button>
    </div>
  {/if}

  {#if isSlowmodeActive}
    <div class="slowmode-bar">
      <span class="slowmode-icon">&#9202;</span>
      Slowmode is enabled. You can send again in <strong>{slowmodeRemaining}s</strong>
    </div>
  {/if}

  <div class="input-row">
    <textarea
      bind:this={textareaEl}
      bind:value={input}
      onkeydown={handleKeydown}
      oninput={autoResize}
      placeholder={disabled ? 'You cannot send messages here' : isSlowmodeActive ? `Slowmode: wait ${slowmodeRemaining}s...` : `Message #${channelName}`}
      rows="1"
      disabled={disabled || isSlowmodeActive}
    ></textarea>
    <button class="send-btn" onclick={handleSend} disabled={!input.trim() || sending || disabled || isSlowmodeActive}>
      {#if isSlowmodeActive}
        {slowmodeRemaining}
      {:else}
        {'\u27A4'}
      {/if}
    </button>
  </div>
</div>

<style>
  .message-input-container {
    border-top: 1px solid var(--border-color);
    background: var(--bg-secondary);
    padding: 0;
  }

  .slowmode-bar {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 16px;
    font-size: 11px;
    color: #06b6d4;
    background: rgba(6, 182, 212, 0.08);
    border-bottom: 1px solid rgba(6, 182, 212, 0.15);
  }
  .slowmode-icon { font-size: 13px; }
  .slowmode-bar strong { font-weight: 700; }

  .reply-preview {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 8px 16px;
    background: rgba(0, 212, 170, 0.05);
    border-bottom: 1px solid var(--border-color);
  }
  .reply-info {
    display: flex;
    align-items: baseline;
    gap: 6px;
    font-size: 12px;
    overflow: hidden;
  }
  .reply-label { color: var(--accent); font-weight: 600; flex-shrink: 0; }
  .reply-author { color: var(--text-primary); font-weight: 700; flex-shrink: 0; }
  .reply-text {
    color: var(--text-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .reply-cancel {
    background: none;
    border: none;
    color: var(--text-muted);
    cursor: pointer;
    font-size: 14px;
    padding: 4px;
    flex-shrink: 0;
  }
  .reply-cancel:hover { color: var(--text-primary); }

  .input-row {
    display: flex;
    align-items: flex-end;
    gap: 8px;
    padding: 12px 16px;
  }

  textarea {
    flex: 1;
    background: var(--bg-primary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 10px 14px;
    font-size: 13px;
    color: var(--text-primary);
    font-family: inherit;
    resize: none;
    line-height: 1.4;
    max-height: 160px;
    overflow-y: auto;
  }
  textarea:focus { outline: none; border-color: var(--accent); }
  textarea:disabled { opacity: 0.5; cursor: not-allowed; }
  textarea::placeholder { color: var(--text-muted); }

  .send-btn {
    width: 38px;
    height: 38px;
    border-radius: 50%;
    background: var(--accent);
    color: var(--bg-primary);
    border: none;
    cursor: pointer;
    font-size: 16px;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    transition: all 0.15s;
  }
  .send-btn:hover:not(:disabled) { opacity: 0.9; transform: scale(1.05); }
  .send-btn:disabled { opacity: 0.3; cursor: not-allowed; }
</style>
