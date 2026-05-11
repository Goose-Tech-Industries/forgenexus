<script lang="ts">
  import { onDestroy } from 'svelte';
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';
  import { chatStore } from '$lib/stores/chat.svelte';
  import { socketStore } from '$lib/stores/socket.svelte';
  import { soundStore } from '$lib/stores/sounds.svelte';
  import { toast } from '$lib/stores/toast.svelte';
  import { executeCommand, getCommandSuggestions, getCommandsByCategory, type CommandDef, type CommandResult } from '$lib/chat/commands';
  import { detectEffect, renderEffect } from '$lib/chat/effects';
  import { getChatTheme, applyThemeToElement, type ChatTheme } from '$lib/chat/themes';
  import GifPicker from './GifPicker.svelte';
  import StickerPicker from './StickerPicker.svelte';
  import VoiceRecorder from './VoiceRecorder.svelte';
  import DrawCanvas from './DrawCanvas.svelte';
  import ChatSettings from './ChatSettings.svelte';

  let {
    id,
    name,
    avatar = null,
    conversationId,
    nudging = false,
    onMinimize,
    onClose
  }: {
    id: string;
    name: string;
    avatar?: string | null;
    conversationId: string;
    nudging?: boolean;
    onMinimize: () => void;
    onClose: () => void;
  } = $props();

  let messages = $state<any[]>([]);
  let messageInput = $state('');
  let messagesEl: HTMLDivElement;
  let inputEl: HTMLTextAreaElement;
  let typingUser = $state<string | null>(null);
  let typingTimeout: ReturnType<typeof setTimeout> | null = null;

  // Command autocomplete
  let showAutocomplete = $state(false);
  let suggestions = $state<CommandDef[]>([]);
  let selectedSuggestion = $state(0);

  // Reply state
  let replyTo = $state<any>(null);

  // Edit state
  let editingMessageId = $state<string | null>(null);

  // Emoji picker
  let showEmojiPicker = $state(false);
  let emojiPickerMsgId = $state<string | null>(null);
  const QUICK_EMOJIS = ['\u2764\uFE0F', '\uD83D\uDE02', '\uD83D\uDC4D', '\uD83D\uDE2E', '\uD83D\uDE22', '\uD83D\uDE21', '\uD83C\uDF89', '\uD83D\uDD25'];

  // Context menu
  let contextMenu = $state<{ x: number; y: number; msg: any } | null>(null);

  // Countdown timer
  let countdownActive = $state(false);
  let countdownRemaining = $state(0);
  let countdownTimer: ReturnType<typeof setInterval> | null = null;

  // Read receipt
  let lastSeenByOther = $state<string | null>(null);

  // Panel toggles (only one open at a time)
  let activePanel = $state<'gif' | 'sticker' | 'draw' | 'settings' | null>(null);

  // Chat theme
  let chatTheme = $state<ChatTheme>(getChatTheme(conversationId));
  let effectContainer: HTMLDivElement;
  let windowEl: HTMLDivElement;

  // Search within conversation
  let showSearch = $state(false);
  let searchQuery = $state('');
  let searchResults = $derived.by(() => {
    if (!searchQuery.trim()) return [];
    const q = searchQuery.toLowerCase();
    return messages.filter(m => !m.is_system && m.body?.toLowerCase().includes(q));
  });

  // Image paste
  let pendingImage = $state<{ file: File; preview: string } | null>(null);

  // Quick thumbs up
  let lastQuickReactId = $state<string | null>(null);

  // Phoenix channel
  let dmChannel: any = null;

  $effect(() => {
    loadMessages();
    joinDmChannel();
    return () => {
      if (dmChannel) { dmChannel.leave(); dmChannel = null; }
    };
  });

  // Apply chat theme
  $effect(() => {
    if (windowEl) {
      applyThemeToElement(windowEl, chatTheme);
    }
  });

  function joinDmChannel() {
    const socket = socketStore.getSocket();
    if (!socket) return;
    dmChannel = socket.channel(`chat:${conversationId}`, {});

    dmChannel.on('new_message', (msg: any) => {
      if (msg.user?.id === auth.user?.id) return;
      messages = [...messages, msg];
      scrollToBottom();
      soundStore.messageReceived();
      checkAndPlayEffect(msg.body || '');
    });

    dmChannel.on('typing', (data: any) => {
      if (data.user_id !== auth.user?.id) {
        typingUser = data.username;
        if (typingTimeout) clearTimeout(typingTimeout);
        typingTimeout = setTimeout(() => { typingUser = null; }, 3000);
      }
    });

    dmChannel.on('nudge', () => { chatStore.triggerNudge(conversationId); });
    dmChannel.on('message_edited', (data: any) => {
      messages = messages.map(m => m.id === data.id ? { ...m, body: data.body, is_edited: true } : m);
    });
    dmChannel.on('message_deleted', (data: any) => {
      messages = messages.map(m => m.id === (data.id || data.message_id) ? { ...m, is_deleted: true } : m);
    });
    dmChannel.on('reaction', (data: any) => {
      messages = messages.map(m => m.id === data.message_id ? { ...m, reactions: data.reactions } : m);
    });
    dmChannel.on('read', (data: any) => {
      if (data.user_id !== auth.user?.id) lastSeenByOther = data.message_id;
    });

    dmChannel.join().receive('error', (err: any) => console.error('DM join error:', err));
  }

  async function loadMessages() {
    try {
      const data = await api.getMessages(conversationId);
      messages = data.messages || [];
      scrollToBottom();
    } catch { /* silent */ }
  }

  function scrollToBottom() {
    requestAnimationFrame(() => { if (messagesEl) messagesEl.scrollTop = messagesEl.scrollHeight; });
  }

  // ---- Command handling ----

  function getCommandContext() {
    return {
      username: auth.user?.username || 'You',
      userId: auth.user?.id || '',
      conversationId,
      recipientName: name
    };
  }

  function handleCommandResult(result: CommandResult) {
    switch (result.type) {
      case 'message':
        sendRegularMessage(result.body!);
        break;
      case 'action':
        sendRegularMessage(result.body!);
        break;
      case 'system':
        addSystemMessage(result.body!);
        break;
      case 'special':
        handleSpecialCommand(result);
        break;
    }
  }

  function handleSpecialCommand(result: CommandResult) {
    switch (result.kind) {
      case 'nudge':
        if (!chatStore.canNudge(conversationId)) {
          addSystemMessage('You can only nudge once every 5 seconds.');
          return;
        }
        if (dmChannel) dmChannel.push('nudge', {});
        chatStore.markNudgeSent(conversationId);
        chatStore.triggerNudge(conversationId);
        addSystemMessage('You sent a nudge!');
        break;
      case 'clear':
        messages = [];
        addSystemMessage('Chat history cleared locally.');
        break;
      case 'help':
        showHelpPanel();
        break;
      case 'countdown':
        startCountdown(result.data.seconds);
        break;
      case 'remind':
        setReminder(result.data.minutes, result.data.message);
        break;
      case 'edit':
        editLastMessage(result.data.body);
        break;
      case 'delete':
        deleteLastMessage();
        break;
      case 'react':
        reactToLastMessage(result.data.emoji);
        break;
      case 'status':
        setStatus(result.data.text);
        break;
      case 'afk':
        setStatus(`\uD83D\uDCA4 ${result.data.message}`);
        addSystemMessage(`You are now AFK: ${result.data.message}`);
        break;
    }
  }

  function showHelpPanel() {
    const groups = getCommandsByCategory();
    const categoryNames: Record<string, string> = {
      fun: '\uD83C\uDFB2 Fun', utility: '\uD83D\uDD27 Utility', action: '\uD83C\uDFAD Actions',
      text: '\u2328\uFE0F Text', moderation: '\uD83D\uDEE1\uFE0F Mod'
    };
    let helpText = 'Available commands:\n';
    for (const [cat, cmds] of Object.entries(groups)) {
      helpText += `\n${categoryNames[cat] || cat}:\n`;
      for (const cmd of cmds) {
        helpText += `  /${cmd.name}${cmd.args ? ' ' + cmd.args : ''}\n`;
      }
    }
    addSystemMessage(helpText);
  }

  function startCountdown(seconds: number) {
    countdownActive = true;
    countdownRemaining = seconds;
    addSystemMessage(`\u23F3 Countdown: ${seconds} seconds...`);
    countdownTimer = setInterval(() => {
      countdownRemaining--;
      if (countdownRemaining <= 0) {
        if (countdownTimer) clearInterval(countdownTimer);
        countdownActive = false;
        addSystemMessage('\uD83D\uDD14 Time\'s up!');
        soundStore.alert();
      }
    }, 1000);
  }

  function setReminder(minutes: number, message: string) {
    addSystemMessage(`\u23F0 Reminder set for ${minutes} minute${minutes > 1 ? 's' : ''}: ${message}`);
    setTimeout(() => {
      addSystemMessage(`\uD83D\uDD14 Reminder: ${message}`);
      soundStore.alert();
    }, minutes * 60000);
  }

  async function editLastMessage(newBody: string) {
    const myMessages = messages.filter(m => m.user?.id === auth.user?.id && !m.is_system && !m.is_deleted);
    const last = myMessages[myMessages.length - 1];
    if (!last) { addSystemMessage('No message to edit.'); return; }
    try {
      await api.editDmMessage(conversationId, last.id, newBody);
      messages = messages.map(m => m.id === last.id ? { ...m, body: newBody, is_edited: true } : m);
      addSystemMessage('Message edited.');
    } catch {
      // If API doesn't support DM editing, update locally
      messages = messages.map(m => m.id === last.id ? { ...m, body: newBody, is_edited: true } : m);
      addSystemMessage('Message updated locally.');
    }
  }

  async function deleteLastMessage() {
    const myMessages = messages.filter(m => m.user?.id === auth.user?.id && !m.is_system && !m.is_deleted);
    const last = myMessages[myMessages.length - 1];
    if (!last) { addSystemMessage('No message to delete.'); return; }
    try {
      await api.deleteDmMessage(conversationId, last.id);
    } catch { /* local delete */ }
    messages = messages.map(m => m.id === last.id ? { ...m, is_deleted: true } : m);
    addSystemMessage('Message deleted.');
  }

  function reactToLastMessage(emoji: string) {
    const nonSystem = messages.filter(m => !m.is_system && !m.is_deleted);
    const last = nonSystem[nonSystem.length - 1];
    if (!last) return;
    toggleReaction(last.id, emoji);
  }

  async function setStatus(text: string) {
    try {
      await api.updatePresence({ custom_status_text: text });
      addSystemMessage(`Status set: ${text}`);
    } catch {
      addSystemMessage(`Status: ${text} (local only)`);
    }
  }

  // ---- Message sending ----

  function addSystemMessage(text: string) {
    messages = [...messages, {
      id: crypto.randomUUID(),
      body: text,
      is_system: true,
      inserted_at: new Date().toISOString(),
      user: { username: 'System' }
    }];
    scrollToBottom();
  }

  async function sendRegularMessage(body: string) {
    const tempId = crypto.randomUUID();
    messages = [...messages, {
      id: tempId,
      body,
      inserted_at: new Date().toISOString(),
      user: { id: auth.user?.id, username: auth.user?.username || 'You' },
      reply_to: replyTo ? { id: replyTo.id, body: replyTo.body, user: replyTo.user } : null,
      status: 'sending'
    }];
    replyTo = null;
    scrollToBottom();
    soundStore.messageSent();

    try {
      const data = await api.sendDmMessage(conversationId, body);
      messages = messages.map(m => m.id === tempId ? { ...data.message, status: 'sent' } : m);
    } catch {
      messages = messages.map(m => m.id === tempId ? { ...m, status: 'failed' } : m);
    }
  }

  async function sendMessage() {
    if (!messageInput.trim()) return;
    const input = messageInput.trim();
    messageInput = '';
    showAutocomplete = false;

    // Handle editing mode
    if (editingMessageId) {
      await editMessage(editingMessageId, input);
      editingMessageId = null;
      return;
    }

    // Try command
    const result = executeCommand(input, getCommandContext());
    if (result) {
      handleCommandResult(result);
      return;
    }

    await sendRegularMessage(input);
  }

  // ---- Reactions ----

  async function toggleReaction(messageId: string, emoji: string) {
    const msg = messages.find(m => m.id === messageId);
    if (!msg) return;
    const reactions = msg.reactions || {};
    const existing = reactions[emoji];
    const hasReacted = existing?.users?.includes(auth.user?.id);

    // Optimistic update
    const newReactions = { ...reactions };
    if (hasReacted) {
      newReactions[emoji] = {
        count: (existing.count || 1) - 1,
        users: existing.users.filter((u: string) => u !== auth.user?.id)
      };
      if (newReactions[emoji].count <= 0) delete newReactions[emoji];
    } else {
      newReactions[emoji] = {
        count: (existing?.count || 0) + 1,
        users: [...(existing?.users || []), auth.user?.id],
        me: true
      };
    }
    messages = messages.map(m => m.id === messageId ? { ...m, reactions: newReactions } : m);

    // Broadcast via channel
    if (dmChannel) {
      dmChannel.push('reaction', { message_id: messageId, emoji, action: hasReacted ? 'remove' : 'add' });
    }
    showEmojiPicker = false;
    emojiPickerMsgId = null;
  }

  // ---- Edit/Delete via context ----

  async function editMessage(messageId: string, newBody: string) {
    try {
      await api.editDmMessage(conversationId, messageId, newBody);
    } catch { /* local only */ }
    messages = messages.map(m => m.id === messageId ? { ...m, body: newBody, is_edited: true } : m);
  }

  function startEditing(msg: any) {
    editingMessageId = msg.id;
    messageInput = msg.body;
    inputEl?.focus();
    contextMenu = null;
  }

  async function deleteMessage(msg: any) {
    try { await api.deleteDmMessage(conversationId, msg.id); } catch { /* local */ }
    messages = messages.map(m => m.id === msg.id ? { ...m, is_deleted: true } : m);
    contextMenu = null;
  }

  function startReply(msg: any) {
    replyTo = msg;
    inputEl?.focus();
    contextMenu = null;
  }

  // ---- Input handling ----

  let lastTypingSent = 0;
  function handleInput() {
    const val = messageInput;

    // Command autocomplete
    if (val.startsWith('/') && !val.includes(' ')) {
      suggestions = getCommandSuggestions(val);
      showAutocomplete = suggestions.length > 0 && val.length > 1;
      selectedSuggestion = 0;
    } else {
      showAutocomplete = false;
    }

    // Typing indicator
    const now = Date.now();
    if (now - lastTypingSent > 2000 && dmChannel) {
      lastTypingSent = now;
      dmChannel.push('typing', {});
    }
  }

  function handleKeydown(e: KeyboardEvent) {
    if (showAutocomplete) {
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        selectedSuggestion = Math.min(selectedSuggestion + 1, suggestions.length - 1);
        return;
      }
      if (e.key === 'ArrowUp') {
        e.preventDefault();
        selectedSuggestion = Math.max(selectedSuggestion - 1, 0);
        return;
      }
      if (e.key === 'Tab' || (e.key === 'Enter' && suggestions[selectedSuggestion])) {
        e.preventDefault();
        const cmd = suggestions[selectedSuggestion];
        messageInput = `/${cmd.name} `;
        showAutocomplete = false;
        return;
      }
      if (e.key === 'Escape') {
        showAutocomplete = false;
        return;
      }
    }

    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
    if (e.key === 'Escape') {
      if (replyTo) { replyTo = null; return; }
      if (editingMessageId) { editingMessageId = null; messageInput = ''; return; }
    }
    // Up arrow with empty input → edit last message
    if (e.key === 'ArrowUp' && !messageInput) {
      const myMsgs = messages.filter(m => m.user?.id === auth.user?.id && !m.is_system && !m.is_deleted);
      const last = myMsgs[myMsgs.length - 1];
      if (last) startEditing(last);
    }
  }

  // ---- Context menu ----

  function handleContextMenu(e: MouseEvent, msg: any) {
    if (msg.is_system || msg.is_deleted) return;
    e.preventDefault();
    contextMenu = { x: e.offsetX, y: e.offsetY, msg };
  }

  function closeContextMenu() { contextMenu = null; }

  // ---- Rich text rendering ----

  function renderBody(body: string): string {
    if (!body) return '';
    let html = escapeHtml(body);
    // Bold **text**
    html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
    // Italic *text* (not inside **)
    html = html.replace(/(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)/g, '<em>$1</em>');
    // Code `text`
    html = html.replace(/`(.+?)`/g, '<code>$1</code>');
    // Spoiler ||text||
    html = html.replace(/\|\|(.+?)\|\|/g, '<span class="spoiler" onclick="this.classList.toggle(\'revealed\')">$1</span>');
    // Code blocks ```text```
    html = html.replace(/```(\w*)\n?([\s\S]*?)```/g, '<pre><code>$2</code></pre>');
    // Newlines
    html = html.replace(/\n/g, '<br>');
    // URLs
    html = html.replace(/(https?:\/\/[^\s<]+)/g, '<a href="$1" target="_blank" rel="noopener">$1</a>');
    return html;
  }

  function escapeHtml(str: string): string {
    return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function formatTime(dateStr: string): string {
    return new Date(dateStr).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }

  function isMyMessage(msg: any): boolean {
    return msg.user?.id === auth.user?.id;
  }

  function togglePanel(panel: 'gif' | 'sticker' | 'draw' | 'settings') {
    activePanel = activePanel === panel ? null : panel;
  }

  // ---- GIF / Sticker / Draw / Voice handlers ----

  function handleGifSelect(url: string, preview: string) {
    sendRegularMessage(`![GIF](${url})`);
    activePanel = null;
  }

  function handleStickerSelect(emoji: string) {
    sendRegularMessage(emoji);
    activePanel = null;
  }

  function handleDrawSend(dataUrl: string) {
    sendRegularMessage(`[Drawing](${dataUrl})`);
    activePanel = null;
  }

  async function handleVoiceSend(blob: Blob, duration: number) {
    addSystemMessage(`\uD83C\uDFA4 Voice message (${duration}s) — uploading...`);
    try {
      const data = await api.uploadFile(new File([blob], `voice_${Date.now()}.webm`, { type: 'audio/webm' }), 'chat', conversationId);
      sendRegularMessage(`\uD83C\uDFA4 [Voice message — ${duration}s](${data.url || data.upload?.url || '#'})`);
    } catch {
      addSystemMessage('Failed to upload voice message.');
    }
  }

  // ---- Image paste from clipboard ----

  function handlePaste(e: ClipboardEvent) {
    const items = e.clipboardData?.items;
    if (!items) return;
    for (const item of items) {
      if (item.type.startsWith('image/')) {
        e.preventDefault();
        const file = item.getAsFile();
        if (file) {
          const preview = URL.createObjectURL(file);
          pendingImage = { file, preview };
        }
        return;
      }
    }
  }

  async function sendPendingImage() {
    if (!pendingImage) return;
    const file = pendingImage.file;
    pendingImage = null;
    addSystemMessage('Uploading image...');
    try {
      const data = await api.uploadFile(file, 'chat', conversationId);
      sendRegularMessage(`![Image](${data.url || data.upload?.url || '#'})`);
    } catch {
      addSystemMessage('Failed to upload image.');
    }
  }

  function cancelPendingImage() {
    if (pendingImage) URL.revokeObjectURL(pendingImage.preview);
    pendingImage = null;
  }

  // ---- Message effects ----

  function checkAndPlayEffect(body: string) {
    const effect = detectEffect(body);
    if (effect && effectContainer) {
      renderEffect(effectContainer, effect);
    }
  }

  // ---- Quick thumbs up (FB Messenger style) ----

  function sendQuickThumbsUp() {
    sendRegularMessage('\uD83D\uDC4D');
  }

  // ---- Search ----

  function scrollToMessage(msgId: string) {
    const el = document.getElementById(`dm-${msgId}`);
    if (el) {
      el.scrollIntoView({ behavior: 'smooth', block: 'center' });
      el.classList.add('search-highlight');
      setTimeout(() => el.classList.remove('search-highlight'), 2000);
    }
    showSearch = false;
    searchQuery = '';
  }

  // ---- Display name (nickname support) ----

  let displayName = $derived(chatTheme.nickname || name);

  function refreshTheme() {
    chatTheme = getChatTheme(conversationId);
  }

  onDestroy(() => {
    if (typingTimeout) clearTimeout(typingTimeout);
    if (countdownTimer) clearInterval(countdownTimer);
  });
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="chat-window" class:nudge-shake={nudging} class:compact={chatTheme.compact} bind:this={windowEl} onclick={closeContextMenu}>
  <!-- Effects overlay -->
  <div class="effect-container" bind:this={effectContainer}></div>

  <!-- Title bar -->
  <div class="chat-titlebar">
    <span class="chat-name">{displayName}</span>
    <div class="titlebar-actions">
      <button class="action" onclick={() => { showSearch = !showSearch; }} title="Search">&#128269;</button>
      {#if countdownActive}
        <span class="countdown-badge">{countdownRemaining}s</span>
      {/if}
      <button class="action" onclick={onMinimize} title="Minimize">&minus;</button>
      <button class="action close" onclick={onClose} title="Close">&times;</button>
    </div>
  </div>

  <!-- Search bar -->
  {#if showSearch}
    <div class="search-bar">
      <input type="text" placeholder="Search messages..." bind:value={searchQuery} class="search-input" />
      {#if searchResults.length > 0}
        <div class="search-results">
          {#each searchResults.slice(0, 5) as result}
            <button class="search-result" onclick={() => scrollToMessage(result.id)}>
              <span class="sr-user">{result.user?.username}:</span>
              <span class="sr-text">{result.body?.slice(0, 50)}</span>
            </button>
          {/each}
        </div>
      {/if}
    </div>
  {/if}

  <!-- Messages -->
  <div class="chat-messages" bind:this={messagesEl}>
    {#each messages as msg (msg.id)}
      {#if msg.is_deleted}
        <div class="msg deleted">
          <span class="msg-system">Message deleted</span>
        </div>
      {:else if msg.is_system}
        <div class="msg system">
          <span class="msg-system">{msg.body}</span>
        </div>
      {:else}
        <!-- svelte-ignore a11y_no_static_element_interactions -->
        <div
          id="dm-{msg.id}"
          class="msg"
          class:action={msg.body?.startsWith('*') && msg.body?.endsWith('*')}
          class:mine={isMyMessage(msg)}
          oncontextmenu={(e) => handleContextMenu(e, msg)}
        >
          {#if msg.reply_to}
            <div class="reply-preview">
              <span class="reply-arrow">\u21B3</span>
              <span class="reply-user">{msg.reply_to.user?.username}:</span>
              <span class="reply-text">{msg.reply_to.body?.slice(0, 60)}{msg.reply_to.body?.length > 60 ? '...' : ''}</span>
            </div>
          {/if}
          <div class="msg-line">
            <span class="msg-time">{formatTime(msg.inserted_at)}</span>
            <span class="msg-user">{msg.user?.username || 'Unknown'}:</span>
            <span class="msg-body">{@html renderBody(msg.body)}</span>
            {#if msg.is_edited}
              <span class="edited-tag">(edited)</span>
            {/if}
            {#if msg.status === 'sending'}
              <span class="status-icon sending">\u23F3</span>
            {:else if msg.status === 'failed'}
              <span class="status-icon failed">\u26A0\uFE0F</span>
            {:else if isMyMessage(msg) && lastSeenByOther === msg.id}
              <span class="status-icon seen">\u2705</span>
            {/if}
          </div>

          <!-- Reactions -->
          {#if msg.reactions && Object.keys(msg.reactions).length > 0}
            <div class="reactions-row">
              {#each Object.entries(msg.reactions) as [emoji, data]}
                <button
                  class="reaction-chip"
                  class:mine={(data as any).users?.includes(auth.user?.id)}
                  onclick={() => toggleReaction(msg.id, emoji)}
                >
                  {emoji} {(data as any).count || 1}
                </button>
              {/each}
              <button class="reaction-add" onclick={() => { emojiPickerMsgId = msg.id; showEmojiPicker = true; }}>+</button>
            </div>
          {/if}

          <!-- Hover actions -->
          <div class="msg-actions">
            <button title="Reply" onclick={() => startReply(msg)}>\u21A9</button>
            <button title="React" onclick={() => { emojiPickerMsgId = msg.id; showEmojiPicker = true; }}>\uD83D\uDE00</button>
            {#if isMyMessage(msg)}
              <button title="Edit" onclick={() => startEditing(msg)}>\u270F\uFE0F</button>
              <button title="Delete" onclick={() => deleteMessage(msg)}>\uD83D\uDDD1\uFE0F</button>
            {/if}
          </div>
        </div>
      {/if}

      <!-- Mini emoji picker -->
      {#if showEmojiPicker && emojiPickerMsgId === msg.id}
        <div class="emoji-popup">
          {#each QUICK_EMOJIS as emoji}
            <button onclick={() => toggleReaction(msg.id, emoji)}>{emoji}</button>
          {/each}
        </div>
      {/if}
    {/each}

    {#if messages.length === 0}
      <div class="empty-chat">
        Start a conversation with {name}
        <div class="command-hint">Type / for commands</div>
      </div>
    {/if}
  </div>

  <!-- Typing indicator -->
  {#if typingUser}
    <div class="typing-indicator">
      <span class="typing-dots"><span></span><span></span><span></span></span>
      {typingUser} is typing...
    </div>
  {/if}

  <!-- Reply bar -->
  {#if replyTo}
    <div class="reply-bar">
      <span>Replying to <strong>{replyTo.user?.username}</strong>: {replyTo.body?.slice(0, 40)}</span>
      <button onclick={() => { replyTo = null; }}>\u2715</button>
    </div>
  {/if}

  <!-- Edit bar -->
  {#if editingMessageId}
    <div class="edit-bar">
      <span>Editing message — Esc to cancel</span>
    </div>
  {/if}

  <!-- Command autocomplete -->
  {#if showAutocomplete}
    <div class="autocomplete-panel">
      {#each suggestions.slice(0, 8) as cmd, i}
        <button
          class="autocomplete-item"
          class:selected={i === selectedSuggestion}
          onclick={() => { messageInput = `/${cmd.name} `; showAutocomplete = false; }}
        >
          <span class="cmd-name">/{cmd.name}</span>
          <span class="cmd-desc">{cmd.description}</span>
        </button>
      {/each}
    </div>
  {/if}

  <!-- Image paste preview -->
  {#if pendingImage}
    <div class="image-preview-bar">
      <img src={pendingImage.preview} alt="Paste preview" class="preview-thumb" />
      <span class="preview-label">Send image?</span>
      <button class="preview-send" onclick={sendPendingImage}>Send</button>
      <button class="preview-cancel" onclick={cancelPendingImage}>✕</button>
    </div>
  {/if}

  <!-- Panels (GIF, Sticker, Draw, Settings) -->
  {#if activePanel === 'gif'}
    <div class="panel-container">
      <GifPicker onSelect={handleGifSelect} />
    </div>
  {:else if activePanel === 'sticker'}
    <div class="panel-container">
      <StickerPicker onSelect={handleStickerSelect} />
    </div>
  {:else if activePanel === 'draw'}
    <div class="panel-container">
      <DrawCanvas onSend={handleDrawSend} onClose={() => { activePanel = null; }} />
    </div>
  {:else if activePanel === 'settings'}
    <div class="panel-container">
      <ChatSettings {conversationId} recipientName={name} onClose={() => { activePanel = null; }} onThemeChange={refreshTheme} />
    </div>
  {/if}

  <!-- Toolbar -->
  <div class="chat-toolbar">
    <button class="toolbar-btn" class:active={activePanel === 'gif'} onclick={() => togglePanel('gif')} title="GIF">GIF</button>
    <button class="toolbar-btn" class:active={activePanel === 'sticker'} onclick={() => togglePanel('sticker')} title="Stickers">&#128522;</button>
    <button class="toolbar-btn" class:active={activePanel === 'draw'} onclick={() => togglePanel('draw')} title="Draw">&#9998;</button>
    <VoiceRecorder onSend={handleVoiceSend} />
    <div class="toolbar-spacer"></div>
    <button class="toolbar-btn" class:active={activePanel === 'settings'} onclick={() => togglePanel('settings')} title="Settings">&#9881;</button>
  </div>

  <!-- Input -->
  <div class="chat-input-area">
    <textarea
      class="chat-input"
      bind:this={inputEl}
      placeholder={editingMessageId ? 'Edit message...' : 'Message... (/ for commands)'}
      bind:value={messageInput}
      onkeydown={handleKeydown}
      oninput={handleInput}
      onpaste={handlePaste}
      rows="2"
    ></textarea>
    {#if !messageInput.trim() && !editingMessageId}
      <button class="quick-thumbs" onclick={sendQuickThumbsUp} title="Send thumbs up">&#128077;</button>
    {/if}
  </div>
</div>

<!-- Context menu -->
{#if contextMenu}
  <div class="context-overlay" role="button" tabindex="-1" onclick={closeContextMenu} onkeydown={() => {}}>
    <div class="context-menu" style="left:{contextMenu.x}px;top:{contextMenu.y}px">
      <button onclick={() => startReply(contextMenu?.msg)}>\u21A9 Reply</button>
      <button onclick={() => { emojiPickerMsgId = contextMenu?.msg?.id; showEmojiPicker = true; contextMenu = null; }}>\uD83D\uDE00 React</button>
      {#if isMyMessage(contextMenu.msg)}
        <button onclick={() => startEditing(contextMenu?.msg)}>\u270F\uFE0F Edit</button>
        <button class="danger" onclick={() => deleteMessage(contextMenu?.msg)}>\uD83D\uDDD1\uFE0F Delete</button>
      {/if}
    </div>
  </div>
{/if}

<style>
  .chat-window {
    width: var(--chat-window-width);
    height: var(--chat-window-height);
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-bottom: none;
    border-radius: var(--radius-lg) var(--radius-lg) 0 0;
    display: flex;
    flex-direction: column;
    box-shadow: 0 -4px 16px rgba(0, 0, 0, 0.3);
    position: relative;
  }

  .chat-window.nudge-shake { animation: nudge-shake 0.6s ease-in-out; }

  @keyframes nudge-shake {
    0%, 100% { transform: translate(0, 0); }
    10% { transform: translate(-8px, -4px); }
    20% { transform: translate(6px, 3px); }
    30% { transform: translate(-6px, 5px); }
    40% { transform: translate(5px, -3px); }
    50% { transform: translate(-4px, 4px); }
    60% { transform: translate(4px, -2px); }
    70% { transform: translate(-3px, 3px); }
    80% { transform: translate(2px, -2px); }
    90% { transform: translate(-1px, 1px); }
  }

  .chat-titlebar {
    background: linear-gradient(180deg, var(--bg-tertiary) 0%, var(--bg-secondary) 100%);
    border-bottom: 1px solid var(--accent);
    padding: 6px 10px;
    display: flex; align-items: center; justify-content: space-between;
    cursor: move;
  }
  .chat-name { font-size: 12px; font-weight: 700; color: var(--text-primary); }
  .titlebar-actions { display: flex; gap: 4px; align-items: center; }
  .countdown-badge { font-size: 10px; background: var(--accent); color: var(--bg-primary); padding: 1px 6px; border-radius: 8px; font-weight: 700; font-variant-numeric: tabular-nums; }

  .action { background: none; border: none; color: var(--text-muted); font-size: 16px; cursor: pointer; padding: 0 4px; line-height: 1; border-radius: 2px; }
  .action:hover { background: var(--bg-hover); color: var(--text-primary); }
  .action.close:hover { background: var(--danger); color: white; }

  .chat-messages { flex: 1; overflow-y: auto; padding: 8px 10px; font-size: 13px; }

  .msg { margin-bottom: 4px; line-height: 1.4; position: relative; padding: 2px 4px; border-radius: 4px; transition: background 0.1s; }
  .msg:hover { background: rgba(255,255,255,0.03); }
  .msg.system { text-align: center; }
  .msg.deleted { text-align: center; opacity: 0.5; }
  .msg.action .msg-body { font-style: italic; color: var(--text-secondary); }

  .msg-line { display: flex; gap: 4px; align-items: baseline; flex-wrap: wrap; }
  .msg-time { font-size: 9px; color: var(--text-muted); flex-shrink: 0; }
  .msg-user { font-weight: 700; color: var(--accent); font-size: 12px; flex-shrink: 0; }
  .msg-body { color: var(--text-primary); word-break: break-word; }
  .msg-body :global(strong) { font-weight: 700; }
  .msg-body :global(em) { font-style: italic; }
  .msg-body :global(code) { background: rgba(0,0,0,0.3); padding: 1px 4px; border-radius: 3px; font-family: monospace; font-size: 0.9em; }
  .msg-body :global(pre) { background: rgba(0,0,0,0.3); padding: 6px 8px; border-radius: 4px; margin: 4px 0; overflow-x: auto; }
  .msg-body :global(a) { color: var(--accent); text-decoration: underline; }
  .msg-body :global(.spoiler) { background: var(--text-primary); color: transparent; border-radius: 3px; padding: 0 4px; cursor: pointer; transition: all 0.2s; }
  .msg-body :global(.spoiler.revealed) { background: rgba(0,0,0,0.3); color: var(--text-primary); }
  .msg-system { font-size: 11px; color: var(--text-muted); font-style: italic; white-space: pre-wrap; }

  .edited-tag { font-size: 9px; color: var(--text-muted); font-style: italic; }

  .status-icon { font-size: 10px; flex-shrink: 0; }
  .status-icon.sending { opacity: 0.5; }
  .status-icon.failed { cursor: pointer; }

  /* Reply preview on messages */
  .reply-preview { font-size: 10px; color: var(--text-muted); margin-bottom: 2px; display: flex; gap: 4px; padding-left: 4px; border-left: 2px solid var(--accent); }
  .reply-arrow { color: var(--accent); }
  .reply-user { font-weight: 600; }
  .reply-text { opacity: 0.7; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 200px; }

  /* Reactions */
  .reactions-row { display: flex; gap: 3px; flex-wrap: wrap; padding: 2px 0 0 20px; }
  .reaction-chip { font-size: 11px; padding: 1px 5px; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-secondary); cursor: pointer; display: flex; align-items: center; gap: 2px; }
  .reaction-chip:hover { border-color: var(--accent); }
  .reaction-chip.mine { border-color: var(--accent); background: rgba(0,212,170,0.1); }
  .reaction-add { font-size: 10px; padding: 1px 4px; border-radius: 8px; border: 1px dashed var(--border-color); background: none; cursor: pointer; color: var(--text-muted); }
  .reaction-add:hover { border-color: var(--accent); color: var(--accent); }

  /* Hover actions on messages */
  .msg-actions { position: absolute; right: 2px; top: -2px; display: none; gap: 2px; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: 4px; padding: 1px; }
  .msg:hover .msg-actions { display: flex; }
  .msg-actions button { font-size: 11px; padding: 1px 4px; background: none; border: none; cursor: pointer; border-radius: 2px; }
  .msg-actions button:hover { background: var(--bg-hover); }

  /* Emoji popup */
  .emoji-popup { display: flex; gap: 2px; padding: 4px; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: 6px; box-shadow: 0 4px 12px rgba(0,0,0,0.3); margin-left: 20px; }
  .emoji-popup button { font-size: 16px; padding: 2px 4px; background: none; border: none; cursor: pointer; border-radius: 3px; }
  .emoji-popup button:hover { background: var(--bg-hover); }

  /* Reply / Edit bar */
  .reply-bar, .edit-bar { padding: 4px 8px; font-size: 11px; color: var(--text-muted); background: var(--bg-secondary); border-top: 1px solid var(--border-color); display: flex; justify-content: space-between; align-items: center; }
  .reply-bar button, .edit-bar button { background: none; border: none; color: var(--text-muted); cursor: pointer; font-size: 12px; }
  .reply-bar button:hover { color: var(--danger); }

  /* Command autocomplete */
  .autocomplete-panel { position: absolute; bottom: 100%; left: 0; right: 0; background: var(--bg-card); border: 1px solid var(--border-color); border-bottom: none; border-radius: var(--radius-lg) var(--radius-lg) 0 0; max-height: 240px; overflow-y: auto; z-index: 10; }
  .autocomplete-item { display: flex; gap: 8px; align-items: baseline; width: 100%; padding: 6px 10px; background: none; border: none; border-bottom: 1px solid var(--border-color); color: var(--text-primary); cursor: pointer; text-align: left; font-size: 12px; }
  .autocomplete-item:hover, .autocomplete-item.selected { background: var(--bg-hover); }
  .cmd-name { font-weight: 700; color: var(--accent); flex-shrink: 0; }
  .cmd-desc { color: var(--text-muted); font-size: 11px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

  .typing-indicator { padding: 2px 10px 4px; font-size: 11px; color: var(--text-muted); font-style: italic; display: flex; align-items: center; gap: 4px; }
  .typing-dots { display: inline-flex; gap: 2px; align-items: center; }
  .typing-dots span { width: 4px; height: 4px; border-radius: 50%; background: var(--text-muted); animation: typing-bounce 1.4s infinite ease-in-out both; }
  .typing-dots span:nth-child(1) { animation-delay: 0s; }
  .typing-dots span:nth-child(2) { animation-delay: 0.16s; }
  .typing-dots span:nth-child(3) { animation-delay: 0.32s; }
  @keyframes typing-bounce { 0%, 80%, 100% { transform: scale(0); opacity: 0.4; } 40% { transform: scale(1); opacity: 1; } }

  .empty-chat { color: var(--text-muted); font-size: 12px; text-align: center; padding: 40px 0; }
  .command-hint { margin-top: 8px; font-size: 10px; opacity: 0.6; }

  .chat-input-area { border-top: 1px solid var(--border-color); padding: 4px; }
  .chat-input { width: 100%; background: var(--bg-input); border: 1px solid var(--border-color); border-radius: var(--radius); padding: 6px 8px; color: var(--text-primary); font-size: 13px; font-family: var(--font-body); resize: none; }
  .chat-input:focus { outline: none; border-color: var(--accent); }

  /* Context menu */
  .context-overlay { position: fixed; inset: 0; z-index: 2000; }
  .context-menu { position: absolute; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius); box-shadow: 0 4px 16px rgba(0,0,0,0.4); padding: 4px 0; min-width: 120px; z-index: 2001; }
  .context-menu button { display: flex; align-items: center; gap: 6px; width: 100%; padding: 6px 12px; background: none; border: none; color: var(--text-primary); font-size: 12px; cursor: pointer; text-align: left; }
  .context-menu button:hover { background: var(--bg-hover); }
  .context-menu button.danger:hover { background: rgba(239, 68, 68, 0.1); color: #ef4444; }

  /* Effects container */
  .effect-container { position: absolute; inset: 0; pointer-events: none; overflow: hidden; z-index: 100; }
  :global(.effect-particle) { position: absolute; top: -20px; font-size: 18px; animation: effect-fall linear forwards; pointer-events: none; }
  @keyframes effect-fall { 0% { transform: translateY(-20px) rotate(0deg); opacity: 1; } 100% { transform: translateY(400px) rotate(720deg); opacity: 0; } }

  /* Compact mode */
  .chat-window.compact .msg { margin-bottom: 1px; padding: 1px 4px; }
  .chat-window.compact .msg-user { display: none; }
  .chat-window.compact .msg-time { font-size: 8px; }

  /* Search bar */
  .search-bar { padding: 4px 6px; border-bottom: 1px solid var(--border-color); background: var(--bg-secondary); }
  .search-input { width: 100%; padding: 4px 6px; font-size: 11px; background: var(--bg-input); border: 1px solid var(--border-color); border-radius: 4px; color: var(--text-primary); }
  .search-input:focus { outline: none; border-color: var(--accent); }
  .search-results { max-height: 100px; overflow-y: auto; }
  .search-result { display: flex; gap: 4px; width: 100%; padding: 3px 6px; background: none; border: none; border-bottom: 1px solid var(--border-color); font-size: 11px; color: var(--text-primary); cursor: pointer; text-align: left; }
  .search-result:hover { background: var(--bg-hover); }
  .sr-user { font-weight: 600; color: var(--accent); flex-shrink: 0; }
  .sr-text { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: var(--text-muted); }
  :global(.search-highlight) { animation: search-flash 2s ease-out; }
  @keyframes search-flash { 0%, 30% { background: rgba(0,212,170,0.15); } 100% { background: transparent; } }

  /* Image paste preview */
  .image-preview-bar { display: flex; align-items: center; gap: 6px; padding: 4px 8px; border-top: 1px solid var(--border-color); background: var(--bg-secondary); }
  .preview-thumb { width: 40px; height: 40px; object-fit: cover; border-radius: 4px; }
  .preview-label { font-size: 11px; color: var(--text-muted); flex: 1; }
  .preview-send { padding: 2px 8px; font-size: 10px; font-weight: 600; background: var(--accent); color: var(--bg-primary); border: none; border-radius: 4px; cursor: pointer; }
  .preview-cancel { background: none; border: none; color: var(--text-muted); cursor: pointer; font-size: 12px; }

  /* Toolbar */
  .chat-toolbar { display: flex; align-items: center; gap: 2px; padding: 2px 4px; border-top: 1px solid var(--border-color); background: var(--bg-secondary); }
  .toolbar-btn { padding: 2px 6px; font-size: 12px; background: none; border: 1px solid transparent; border-radius: 4px; cursor: pointer; color: var(--text-muted); }
  .toolbar-btn:hover { background: var(--bg-hover); color: var(--text-primary); }
  .toolbar-btn.active { border-color: var(--accent); color: var(--accent); }
  .toolbar-spacer { flex: 1; }

  /* Panel container */
  .panel-container { position: absolute; bottom: 100%; left: 0; z-index: 50; }

  /* Quick thumbs up */
  .chat-input-area { border-top: 1px solid var(--border-color); padding: 4px; position: relative; }
  .quick-thumbs { position: absolute; right: 8px; bottom: 8px; background: none; border: none; font-size: 18px; cursor: pointer; opacity: 0.5; transition: opacity 0.15s; }
  .quick-thumbs:hover { opacity: 1; }
</style>
