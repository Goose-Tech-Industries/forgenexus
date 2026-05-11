<script lang="ts">
  import { channelStore, type ChannelCategory, type Channel } from '$lib/stores/channels.svelte';
  import { voiceStore } from '$lib/stores/voice.svelte';
  import { auth } from '$lib/stores/auth.svelte';
  import { api } from '$lib/api/client';
  import { toast } from '$lib/stores/toast.svelte';
  import VoiceRoomList from '$lib/components/channels/VoiceRoomList.svelte';

  let { onSelectChannel, onJoinVoiceRoom }: {
    onSelectChannel: (slug: string) => void;
    onJoinVoiceRoom: (roomId: string) => void;
  } = $props();

  let collapsedCategories = $state<Set<string>>(new Set());

  // Discord-style quick create
  let createType = $state<'category' | 'channel' | null>(null);
  let createForCategoryId = $state<string | null>(null);
  let createName = $state('');
  let createChannelType = $state<'text' | 'voice'>('text');
  let creating = $state(false);

  function openCreateChannel(categoryId: string) {
    createType = 'channel';
    createForCategoryId = categoryId;
    createName = '';
    createChannelType = 'text';
  }

  function openCreateCategory() {
    createType = 'category';
    createForCategoryId = null;
    createName = '';
  }

  function cancelCreate() {
    createType = null;
    createForCategoryId = null;
    createName = '';
  }

  async function submitCreate() {
    if (!createName.trim()) return;
    creating = true;
    try {
      if (createType === 'category') {
        await api.createChatCategory({ name: createName.trim() });
        toast.success('Category created');
      } else if (createType === 'channel' && createForCategoryId) {
        await api.createChatChannel({
          name: createName.trim(),
          type: createChannelType,
          category_id: createForCategoryId
        });
        toast.success('Channel created');
      }
      await channelStore.loadChannels();
      cancelCreate();
    } catch (e: any) {
      toast.error(formatCreateError(e));
    }
    creating = false;
  }

  function focusOnMount(node: HTMLInputElement) {
    // Defer until current event loop tick so the modal mount doesn't clash
    // with whichever element the browser just restored focus to.
    setTimeout(() => node.focus(), 50);
  }

  function formatCreateError(e: any): string {
    const err = e?.error;
    if (typeof err === 'string') return err;
    if (err && typeof err === 'object') {
      // e.g. {slug: ["has already been taken"]}
      const [field, msgs] = Object.entries(err)[0] || [];
      if (field && Array.isArray(msgs) && msgs.length) {
        const fieldName = field === 'slug' ? 'Name' : field;
        return `${fieldName} ${msgs[0]}`;
      }
    }
    return 'Failed to create';
  }

  function toggleCategory(id: string) {
    const next = new Set(collapsedCategories);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    collapsedCategories = next;
  }

  function channelIcon(ch: Channel): string {
    if (ch.icon) return ch.icon;
    if (ch.type === 'voice') return '\u{1F50A}';
    if (ch.is_read_only) return '\u{1F4E2}';
    if (ch.is_private) return '\u{1F512}';
    return '#';
  }

  function isActive(ch: Channel): boolean {
    return channelStore.activeChannel?.id === ch.id;
  }
</script>

<aside class="channel-sidebar">
  <div class="sidebar-header">
    <h2>Chat</h2>
    {#if channelStore.totalUnread > 0}
      <span class="total-unread">{channelStore.totalUnread}</span>
    {/if}
  </div>

  <div class="channel-list">
    {#each channelStore.categories as category (category.id)}
      <div class="category-group">
        <div class="category-header-row">
          <button class="category-header" onclick={() => toggleCategory(category.id)}>
            <span class="cat-arrow" class:collapsed={collapsedCategories.has(category.id)}>{'\u25BC'}</span>
            <span class="cat-name">{category.name}</span>
          </button>
          {#if auth.isStaff}
            <button class="cat-add" onclick={() => openCreateChannel(category.id)} title="Add channel to {category.name}" aria-label="Add channel">+</button>
          {/if}
        </div>

        {#if !collapsedCategories.has(category.id)}
          <div class="category-channels">
            {#each category.channels as channel (channel.id)}
              <button
                class="channel-item"
                class:active={isActive(channel)}
                class:archived={channel.is_archived}
                class:has-unread={channelStore.unreadCounts[channel.id] > 0}
                onclick={() => onSelectChannel(channel.slug)}
              >
                <span class="channel-icon" class:hash={!channel.icon && channel.type === 'text'}>{channelIcon(channel)}</span>
                <span class="channel-name">{channel.name}</span>
                {#if channelStore.unreadCounts[channel.id] > 0}
                  <span class="unread-badge">{channelStore.unreadCounts[channel.id]}</span>
                {/if}
                {#if channel.is_archived}
                  <span class="archived-tag">ARCHIVED</span>
                {/if}
              </button>
            {/each}
          </div>
        {/if}
      </div>
    {/each}

    <!-- Voice Rooms -->
    {#if voiceStore.rooms.length > 0}
      <div class="voice-section-divider"></div>
      <VoiceRoomList onJoinRoom={onJoinVoiceRoom} />
    {/if}
  </div>

  {#if auth.isStaff}
    <div class="sidebar-footer">
      <button class="quick-create-btn" onclick={openCreateCategory}>+ New Category</button>
      <a href="/admin/chat" class="manage-link">Manage Channels</a>
    </div>
  {/if}
</aside>

{#if createType}
  <div class="qc-backdrop" onclick={cancelCreate} role="presentation">
    <div class="qc-modal" onclick={(e) => e.stopPropagation()} role="dialog">
      <h3>{createType === 'category' ? 'New Category' : 'New Channel'}</h3>
      <label>
        Name
        <input
          type="text"
          bind:value={createName}
          placeholder={createType === 'category' ? 'e.g. General' : 'e.g. announcements'}
          maxlength="40"
          onkeydown={(e) => { if (e.key === 'Enter') submitCreate(); if (e.key === 'Escape') cancelCreate(); }}
          use:focusOnMount
        />
      </label>
      {#if createType === 'channel'}
        <label>
          Type
          <select bind:value={createChannelType}>
            <option value="text"># Text</option>
            <option value="voice">🔊 Voice</option>
          </select>
        </label>
      {/if}
      <div class="qc-actions">
        <button class="btn-ghost" onclick={cancelCreate}>Cancel</button>
        <button class="btn-primary" onclick={submitCreate} disabled={creating || !createName.trim()}>
          {creating ? 'Creating…' : 'Create'}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .channel-sidebar {
    width: 240px;
    background: var(--bg-secondary);
    border-right: 1px solid var(--border-color);
    display: flex;
    flex-direction: column;
    height: 100%;
    flex-shrink: 0;
  }

  .sidebar-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 14px 16px;
    border-bottom: 1px solid var(--border-color);
  }
  .sidebar-header h2 {
    font-size: 15px;
    font-weight: 800;
    margin: 0;
  }
  .total-unread {
    background: #f87171;
    color: white;
    font-size: 10px;
    font-weight: 800;
    padding: 2px 6px;
    border-radius: 10px;
    min-width: 18px;
    text-align: center;
  }

  .channel-list {
    flex: 1;
    overflow-y: auto;
    padding: 8px 0;
  }

  .category-group { margin-bottom: 4px; }

  .category-header-row {
    display: flex;
    align-items: center;
    gap: 2px;
    padding: 0 4px;
  }
  .category-header-row .category-header { flex: 1; }
  .cat-add {
    background: transparent;
    border: none;
    color: var(--text-tertiary, #6a748a);
    cursor: pointer;
    font-size: 1.1rem;
    font-weight: 700;
    padding: 0 8px;
    line-height: 1;
    border-radius: 4px;
  }
  .cat-add:hover { background: var(--bg-tertiary, #1a2030); color: var(--accent, #00d4aa); }

  .quick-create-btn {
    width: 100%;
    padding: 8px;
    background: transparent;
    border: 1px dashed var(--border, #2a3040);
    color: var(--text-secondary, #8a94a6);
    border-radius: 6px;
    cursor: pointer;
    font-size: 0.85rem;
    margin-bottom: 6px;
  }
  .quick-create-btn:hover { border-color: var(--accent, #00d4aa); color: var(--accent, #00d4aa); }

  .qc-backdrop {
    position: fixed; inset: 0;
    background: rgba(0,0,0,0.75);
    display: flex; align-items: center; justify-content: center;
    z-index: 200;
  }
  .qc-modal {
    width: min(90vw, 420px);
    background: var(--bg-secondary, #121826);
    border: 1px solid var(--border, #2a3040);
    border-radius: 10px;
    padding: 20px;
    display: flex; flex-direction: column; gap: 12px;
  }
  .qc-modal h3 { margin: 0; }
  .qc-modal label { display: flex; flex-direction: column; gap: 4px; font-size: 0.88rem; color: var(--text-secondary, #8a94a6); }
  .qc-modal input, .qc-modal select {
    padding: 8px 10px;
    background: var(--bg-primary, #0a0e17);
    border: 1px solid var(--border, #2a3040);
    border-radius: 4px;
    color: var(--text-primary, #e8eaed);
  }
  .qc-actions { display: flex; justify-content: flex-end; gap: 8px; }
  .qc-actions .btn-primary {
    padding: 8px 16px; background: var(--accent, #00d4aa); color: #000;
    border: none; border-radius: 6px; font-weight: 700; cursor: pointer;
  }
  .qc-actions .btn-ghost {
    padding: 8px 16px; background: transparent; border: 1px solid var(--border, #2a3040);
    color: var(--text-primary, #e8eaed); border-radius: 6px; cursor: pointer;
  }
  .qc-actions .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }

  .category-header {
    display: flex;
    align-items: center;
    gap: 4px;
    width: 100%;
    padding: 4px 12px;
    background: none;
    border: none;
    color: var(--text-muted);
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    cursor: pointer;
    font-family: inherit;
  }
  .category-header:hover { color: var(--text-secondary); }

  .cat-arrow {
    font-size: 8px;
    transition: transform 0.15s;
  }
  .cat-arrow.collapsed { transform: rotate(-90deg); }

  .category-channels { padding: 2px 0; }

  .channel-item {
    display: flex;
    align-items: center;
    gap: 6px;
    width: 100%;
    padding: 6px 12px 6px 20px;
    background: none;
    border: none;
    color: var(--text-muted);
    font-size: 13px;
    cursor: pointer;
    font-family: inherit;
    border-radius: 0;
    transition: all 0.1s;
    text-align: left;
  }
  .channel-item:hover { background: rgba(255, 255, 255, 0.04); color: var(--text-primary); }
  .channel-item.active { background: rgba(0, 212, 170, 0.08); color: var(--accent); }
  .channel-item.has-unread { color: var(--text-primary); font-weight: 600; }
  .channel-item.archived { opacity: 0.4; }

  .channel-icon {
    font-size: 16px;
    width: 20px;
    text-align: center;
    flex-shrink: 0;
  }
  .channel-icon.hash {
    font-size: 15px;
    font-weight: 800;
    color: var(--text-muted);
    opacity: 0.6;
  }

  .channel-name {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .unread-badge {
    background: #f87171;
    color: white;
    font-size: 9px;
    font-weight: 800;
    padding: 1px 5px;
    border-radius: 8px;
    min-width: 16px;
    text-align: center;
  }

  .archived-tag {
    font-size: 8px;
    font-weight: 700;
    color: var(--text-muted);
    background: rgba(255, 255, 255, 0.05);
    padding: 1px 4px;
    border-radius: 3px;
  }

  .voice-section-divider {
    height: 1px;
    background: var(--border-color);
    margin: 6px 12px;
  }

  .sidebar-footer {
    padding: 10px 16px;
    border-top: 1px solid var(--border-color);
  }
  .manage-link {
    font-size: 11px;
    color: var(--text-muted);
    text-decoration: none;
  }
  .manage-link:hover { color: var(--accent); }

  .channel-list::-webkit-scrollbar { width: 4px; }
  .channel-list::-webkit-scrollbar-track { background: transparent; }
  .channel-list::-webkit-scrollbar-thumb { background: var(--border-color); border-radius: 2px; }
</style>
