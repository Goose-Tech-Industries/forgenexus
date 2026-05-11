<script lang="ts">
  import UsernameDisplay from '$lib/components/common/UsernameDisplay.svelte';
  import { processCodeBlocks } from '$lib/utils/code-highlight';
  import AvatarFrame from '$lib/components/common/AvatarFrame.svelte';
  import EditHistoryModal from '$lib/components/channels/EditHistoryModal.svelte';
  import { auth } from '$lib/stores/auth.svelte';
  import { channelStore, type ChannelMessage } from '$lib/stores/channels.svelte';

  let {
    message,
    channelSlug = '',
    onReply,
    onEdit,
    onDelete,
    onReaction,
    onPin,
    onCreateThread = () => {},
    onOpenThread = () => {},
    onBookmark = () => {},
    isBookmarked = false
  }: {
    message: ChannelMessage;
    channelSlug?: string;
    onReply: (msg: ChannelMessage) => void;
    onEdit: (msg: ChannelMessage) => void;
    onDelete: (msg: ChannelMessage) => void;
    onReaction: (msgId: string, emoji: string, hasReacted: boolean) => void;
    onPin: (msg: ChannelMessage) => void;
    onCreateThread?: (msg: ChannelMessage) => void;
    onOpenThread?: (threadId: string) => void;
    onBookmark?: (msg: ChannelMessage) => void;
    isBookmarked?: boolean;
  } = $props();

  let threadInfo = $derived((message as any).thread as { id: string; name: string; message_count: number } | null);

  let showActions = $state(false);
  let showEmojiPicker = $state(false);
  let isEditing = $state(false);
  let editValue = $state('');
  let showEditHistory = $state(false);

  let isOwn = $derived(auth.user?.id === message.user?.id);
  let isStaff = $derived(auth.isStaff);
  let canEdit = $derived(isOwn && !message.is_deleted);
  let canDelete = $derived((isOwn || isStaff) && !message.is_deleted);
  let canPin = $derived(isStaff);

  const quickEmojis = ['\u{1F44D}', '\u{2764}', '\u{1F602}', '\u{1F60E}', '\u{1F525}', '\u{1F389}', '\u{1F914}', '\u{1F44E}'];

  // Custom emoji rendering — :shortcode: → <img>
  // The store/page should load custom emojis and pass them via a global or context
  // For now, render :shortcode: as styled text that can be replaced when emoji data is loaded

  // Format message body — highlight @mentions and custom emojis
  function formatBody(body: string): string {
    // Escape HTML first
    let safe = body
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
    // Highlight @mentions
    safe = safe.replace(/@(\w+)/g, '<span class="mention">@$1</span>');
    // Highlight @everyone and @here
    safe = safe.replace(/@(everyone|here)/g, '<span class="mention mention-all">@$1</span>');
    // Custom emoji shortcodes — :shortcode: rendered as styled inline
    safe = safe.replace(/:([a-z0-9_]{2,32}):/g, '<span class="custom-emoji" title=":$1:">:$1:</span>');
    // Code blocks
    safe = processCodeBlocks(safe);
    return safe;
  }

  function formatTime(dateStr: string): string {
    const d = new Date(dateStr);
    const now = new Date();
    const isToday = d.toDateString() === now.toDateString();
    const yesterday = new Date(now);
    yesterday.setDate(yesterday.getDate() - 1);
    const isYesterday = d.toDateString() === yesterday.toDateString();

    const time = d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    if (isToday) return `Today at ${time}`;
    if (isYesterday) return `Yesterday at ${time}`;
    return `${d.toLocaleDateString()} ${time}`;
  }
</script>

<div
  id="msg-{message.id}"
  class="chat-message"
  class:deleted={message.is_deleted}
  class:pinned={message.is_pinned}
  onmouseenter={() => showActions = true}
  onmouseleave={() => { showActions = false; showEmojiPicker = false; }}
>
  {#if message.is_pinned}
    <div class="pin-indicator">Pinned</div>
  {/if}

  {#if message.reply_to}
    <div class="reply-context">
      <span class="reply-bar"></span>
      <span class="reply-author">{message.reply_to.user?.username || 'Unknown'}</span>
      <span class="reply-preview">{message.reply_to.body?.slice(0, 80)}{message.reply_to.body?.length > 80 ? '...' : ''}</span>
    </div>
  {/if}

  <div class="message-row">
    <div class="message-avatar">
      {#if message.user?.avatar_url}
        <img src={message.user.avatar_url} alt="" class="avatar-img" />
      {:else}
        <div class="avatar-placeholder">{message.user?.username?.[0]?.toUpperCase() || '?'}</div>
      {/if}
    </div>

    <div class="message-content">
      {#if message.is_deleted}
        <div class="message-header">
          <UsernameDisplay
            username={message.user?.username || 'Unknown'}
            color={message.user?.username_color}
            effect={message.user?.username_effect}
            href="/profile/{message.user?.slug}"
            size="small"
          />
          <span class="message-time">{formatTime(message.inserted_at)}</span>
        </div>
        <div class="deleted-text">This message was deleted</div>
      {:else}
        <div class="message-header">
          <UsernameDisplay
            username={message.user?.username || 'Unknown'}
            color={message.user?.username_color}
            effect={message.user?.username_effect}
            href="/profile/{message.user?.slug}"
            size="small"
          />
          <span class="message-time">{formatTime(message.inserted_at)}</span>
          {#if message.is_edited}
            <span class="edited-tag">(edited)</span>
          {/if}
        </div>
        {#if isEditing}
          <div class="edit-inline">
            <textarea
              bind:value={editValue}
              onkeydown={(e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                  e.preventDefault();
                  if (editValue.trim() && editValue.trim() !== message.body) {
                    channelStore.editMessage(message.id, editValue.trim());
                  }
                  isEditing = false;
                }
                if (e.key === 'Escape') isEditing = false;
              }}
              rows="2"
            ></textarea>
            <div class="edit-hint">Enter to save, Escape to cancel</div>
          </div>
        {:else}
          <div class="message-body">{@html formatBody(message.body)}</div>
        {/if}

        <!-- Reactions -->
        {#if message.reactions && Object.keys(message.reactions).length > 0}
          <div class="reactions-row">
            {#each Object.entries(message.reactions) as [emoji, data]}
              <button
                class="reaction-chip"
                class:reacted={data.me}
                onclick={() => onReaction(message.id, emoji, data.me)}
                title={data.users.join(', ')}
              >
                <span class="reaction-emoji">{emoji}</span>
                <span class="reaction-count">{data.count}</span>
              </button>
            {/each}
          </div>
        {/if}

        <!-- Link Embeds -->
        {#if message.embeds && message.embeds.length > 0}
          <div class="embeds-row">
            {#each message.embeds as embed}
              {#if embed.title || embed.description}
                <a href={embed.url} target="_blank" rel="noopener noreferrer" class="embed-card">
                  {#if embed.image}
                    <div class="embed-image">
                      <img src={embed.image} alt="" loading="lazy" />
                    </div>
                  {/if}
                  <div class="embed-content">
                    {#if embed.site_name}
                      <div class="embed-site">{embed.site_name}</div>
                    {/if}
                    {#if embed.title}
                      <div class="embed-title">{embed.title}</div>
                    {/if}
                    {#if embed.description}
                      <div class="embed-desc">{embed.description}</div>
                    {/if}
                  </div>
                </a>
              {/if}
            {/each}
          </div>
        {/if}

        <!-- Thread indicator -->
        {#if threadInfo}
          <button class="thread-indicator" onclick={() => onOpenThread(threadInfo!.id)}>
            <span class="thread-icon-small">&#128172;</span>
            <span class="thread-name">{threadInfo.name}</span>
            <span class="thread-count">{threadInfo.message_count} {threadInfo.message_count === 1 ? 'reply' : 'replies'}</span>
          </button>
        {/if}
      {/if}
    </div>
  </div>

  <!-- Hover action bar -->
  {#if showActions && !message.is_deleted}
    <div class="action-bar">
      <button class="action-btn" onclick={() => showEmojiPicker = !showEmojiPicker} title="React">{'\u{1F600}'}</button>
      <button class="action-btn" onclick={() => onReply(message)} title="Reply">{'\u{21A9}'}</button>
      <button class="action-btn" onclick={() => onCreateThread(message)} title={threadInfo ? 'Open Thread' : 'Create Thread'}>{'\u{1F9F5}'}</button>
      <button class="action-btn" class:bookmarked={isBookmarked} onclick={() => onBookmark(message)} title={isBookmarked ? 'Remove Bookmark' : 'Bookmark'}>{isBookmarked ? '\u{1F516}' : '\u{1F516}'}</button>
      {#if canEdit}
        <button class="action-btn" onclick={() => { editValue = message.body; isEditing = true; showActions = false; }} title="Edit">{'\u{270F}'}</button>
      {/if}
      {#if message.is_edited}
        <button class="action-btn" onclick={() => showEditHistory = true} title="View edit history">{'\u{1F4DC}'}</button>
      {/if}
      {#if canDelete}
        <button class="action-btn danger" onclick={() => onDelete(message)} title="Delete">{'\u{1F5D1}'}</button>
      {/if}
      {#if canPin}
        <button class="action-btn" onclick={() => onPin(message)} title={message.is_pinned ? 'Unpin' : 'Pin'}>
          {message.is_pinned ? '\u{1F4CC}' : '\u{1F4CC}'}
        </button>
      {/if}
    </div>

    {#if showEmojiPicker}
      <div class="quick-emoji-picker">
        {#each quickEmojis as emoji}
          <button class="emoji-btn" onclick={() => { onReaction(message.id, emoji, false); showEmojiPicker = false; }}>{emoji}</button>
        {/each}
      </div>
    {/if}
  {/if}
</div>

{#if showEditHistory && channelSlug}
  <EditHistoryModal
    {channelSlug}
    messageId={message.id}
    onClose={() => showEditHistory = false}
  />
{/if}

<style>
  .chat-message {
    position: relative;
    padding: 4px 16px 4px 16px;
    transition: background 0.1s;
  }
  .chat-message:hover { background: rgba(255, 255, 255, 0.02); }
  .chat-message.pinned { border-left: 3px solid #fbbf24; padding-left: 13px; }
  .chat-message.deleted { opacity: 0.5; }

  .pin-indicator {
    font-size: 9px;
    font-weight: 700;
    color: #fbbf24;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-bottom: 2px;
    padding-left: 48px;
  }

  /* Reply context */
  .reply-context {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 2px 0 2px 48px;
    font-size: 11px;
    color: var(--text-muted);
    margin-bottom: 2px;
  }
  .reply-bar {
    width: 2px;
    height: 12px;
    background: var(--accent);
    border-radius: 1px;
    flex-shrink: 0;
  }
  .reply-author { font-weight: 600; color: var(--text-secondary); }
  .reply-preview {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .message-row {
    display: flex;
    gap: 12px;
  }

  .message-avatar {
    width: 36px;
    height: 36px;
    border-radius: 50%;
    overflow: hidden;
    flex-shrink: 0;
    margin-top: 2px;
  }
  .avatar-img { width: 100%; height: 100%; object-fit: cover; }
  .avatar-placeholder {
    width: 100%;
    height: 100%;
    background: var(--accent);
    color: var(--bg-primary);
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 800;
    font-size: 15px;
  }

  .message-content { flex: 1; min-width: 0; }

  .message-header {
    display: flex;
    align-items: baseline;
    gap: 6px;
    margin-bottom: 1px;
  }
  .message-time {
    font-size: 10px;
    color: var(--text-muted);
  }
  .edited-tag {
    font-size: 9px;
    color: var(--text-muted);
    font-style: italic;
  }

  .message-body {
    font-size: 13px;
    color: var(--text-primary);
    line-height: 1.45;
    word-break: break-word;
    white-space: pre-wrap;
  }

  .deleted-text {
    font-size: 12px;
    color: var(--text-muted);
    font-style: italic;
  }

  /* Reactions */
  .reactions-row {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    margin-top: 4px;
  }
  .reaction-chip {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 2px 6px;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    cursor: pointer;
    font-family: inherit;
    font-size: 12px;
    transition: all 0.1s;
    color: var(--text-secondary);
  }
  .reaction-chip:hover { background: rgba(255, 255, 255, 0.08); }
  .reaction-chip.reacted { border-color: var(--accent); background: rgba(0, 212, 170, 0.08); }
  .reaction-emoji { font-size: 14px; }
  .reaction-count { font-size: 11px; font-weight: 600; }

  /* Hover actions */
  .action-bar {
    position: absolute;
    top: -8px;
    right: 16px;
    display: flex;
    gap: 2px;
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    padding: 2px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
    z-index: 10;
  }
  .action-btn {
    padding: 4px 6px;
    background: none;
    border: none;
    border-radius: 3px;
    cursor: pointer;
    font-size: 14px;
    transition: background 0.1s;
    color: var(--text-secondary);
  }
  .action-btn:hover { background: rgba(255, 255, 255, 0.08); }
  .action-btn.danger:hover { background: rgba(248, 113, 113, 0.15); }
  .action-btn.bookmarked { color: #fbbf24; }

  /* Quick emoji picker */
  .quick-emoji-picker {
    position: absolute;
    top: -40px;
    right: 16px;
    display: flex;
    gap: 2px;
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    padding: 4px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
    z-index: 11;
  }
  .emoji-btn {
    padding: 4px;
    background: none;
    border: none;
    border-radius: 3px;
    cursor: pointer;
    font-size: 18px;
    transition: background 0.1s;
  }
  .emoji-btn:hover { background: rgba(255, 255, 255, 0.1); transform: scale(1.2); }

  /* Inline editing */
  .edit-inline { margin-top: 2px; }
  .edit-inline textarea {
    width: 100%;
    background: var(--bg-primary);
    border: 1px solid var(--accent);
    border-radius: var(--radius);
    padding: 8px 10px;
    font-size: 13px;
    color: var(--text-primary);
    font-family: inherit;
    resize: none;
    line-height: 1.4;
  }
  .edit-inline textarea:focus { outline: none; }
  .edit-hint {
    font-size: 10px;
    color: var(--text-muted);
    margin-top: 2px;
  }

  /* Link embeds */
  .embeds-row {
    display: flex;
    flex-direction: column;
    gap: 6px;
    margin-top: 6px;
  }
  .embed-card {
    display: flex;
    gap: 12px;
    padding: 10px 12px;
    background: var(--bg-primary);
    border-left: 3px solid var(--accent);
    border-radius: 0 var(--radius) var(--radius) 0;
    text-decoration: none;
    color: inherit;
    max-width: 420px;
    overflow: hidden;
    transition: background 0.1s;
  }
  .embed-card:hover { background: rgba(255, 255, 255, 0.04); }
  .embed-image {
    width: 80px;
    height: 80px;
    flex-shrink: 0;
    border-radius: var(--radius);
    overflow: hidden;
  }
  .embed-image img { width: 100%; height: 100%; object-fit: cover; }
  .embed-content { flex: 1; min-width: 0; }
  .embed-site { font-size: 10px; color: var(--text-muted); margin-bottom: 2px; }
  .embed-title {
    font-size: 13px;
    font-weight: 600;
    color: var(--accent);
    margin-bottom: 2px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .embed-desc {
    font-size: 12px;
    color: var(--text-muted);
    line-height: 1.3;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  /* Thread indicator */
  .thread-indicator {
    display: flex;
    align-items: center;
    gap: 6px;
    margin-top: 4px;
    padding: 4px 8px;
    background: rgba(99, 102, 241, 0.08);
    border: 1px solid rgba(99, 102, 241, 0.15);
    border-radius: var(--radius);
    cursor: pointer;
    font-family: inherit;
    font-size: 12px;
    color: #818cf8;
    transition: all 0.1s;
    width: fit-content;
  }
  .thread-indicator:hover { background: rgba(99, 102, 241, 0.14); border-color: rgba(99, 102, 241, 0.3); }
  .thread-icon-small { font-size: 13px; }
  .thread-name { font-weight: 600; }
  .thread-count { color: var(--text-muted); font-size: 11px; }

  /* @mention highlighting */
  :global(.mention) {
    color: var(--accent);
    background: rgba(0, 212, 170, 0.1);
    padding: 0 2px;
    border-radius: 3px;
    font-weight: 600;
    cursor: pointer;
  }
  :global(.mention:hover) { background: rgba(0, 212, 170, 0.2); }
  :global(.mention-all) {
    color: #fbbf24;
    background: rgba(251, 191, 36, 0.1);
  }
  :global(.mention-all:hover) { background: rgba(251, 191, 36, 0.2); }
  /* Code blocks */
  :global(.code-block) {
    margin: 6px 0;
    border-radius: var(--radius);
    overflow: hidden;
    border: 1px solid var(--border-color);
  }
  :global(.code-header) {
    padding: 4px 10px;
    background: rgba(0, 0, 0, 0.3);
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.03em;
  }
  :global(.code-lang) { color: var(--accent); }
  :global(.code-block pre) {
    margin: 0;
    padding: 10px 12px;
    background: rgba(0, 0, 0, 0.2);
    overflow-x: auto;
    font-size: 12px;
    line-height: 1.5;
  }
  :global(.code-block code) { font-family: 'Consolas', 'Monaco', 'Courier New', monospace; }
  :global(.inline-code) {
    background: rgba(0, 0, 0, 0.2);
    padding: 1px 5px;
    border-radius: 3px;
    font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
    font-size: 0.9em;
  }
  :global(.hl-keyword) { color: #c792ea; font-weight: 600; }
  :global(.hl-string) { color: #c3e88d; }
  :global(.hl-number) { color: #f78c6c; }
  :global(.hl-comment) { color: #546e7a; font-style: italic; }
  :global(.hl-builtin) { color: #82aaff; }

  :global(.custom-emoji) {
    background: rgba(99, 102, 241, 0.1);
    padding: 0 3px;
    border-radius: 3px;
    font-style: italic;
    font-size: 12px;
    color: #818cf8;
  }

  :global(.highlight-flash) {
    animation: msg-flash 2s ease-out;
  }
  @keyframes msg-flash {
    0%, 30% { background: rgba(0, 212, 170, 0.15); }
    100% { background: transparent; }
  }
</style>
