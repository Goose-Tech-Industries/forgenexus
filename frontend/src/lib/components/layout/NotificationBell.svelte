<script lang="ts">
  import { notificationStore, type Notification } from '$lib/stores/notifications.svelte';
  import UsernameDisplay from '$lib/components/common/UsernameDisplay.svelte';

  let open = $state(false);
  let filter = $state<'all' | 'unread'>('all');

  let filtered = $derived(
    filter === 'unread'
      ? notificationStore.notifications.filter(n => !n.is_read)
      : notificationStore.notifications
  );

  const typeIcons: Record<string, string> = {
    mention: '@',
    reply: '\u{21A9}',
    reaction: '\u{2764}',
    dm: '\u{1F4AC}',
    system: '\u{1F514}',
  };

  const typeColors: Record<string, string> = {
    mention: '#3b82f6',
    reply: '#06b6d4',
    reaction: '#f97316',
    dm: '#a855f7',
    system: '#64748b',
  };

  function toggle() {
    open = !open;
    if (open) {
      // Always refresh on open so the dropdown reflects newly-arrived items.
      notificationStore.load();
      // Opening the bell counts as "I saw them" — clear the unread badge.
      if (notificationStore.unreadCount > 0) notificationStore.markAllRead();
    }
  }

  function close() { open = false; }

  function handleClick(notif: Notification) {
    if (!notif.is_read) notificationStore.markRead(notif.id);
    if (notif.url) window.location.href = notif.url;
    close();
  }

  function timeAgo(dateStr: string): string {
    const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
    if (diff < 60) return 'now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
    return `${Math.floor(diff / 86400)}d`;
  }

  // Close on outside click
  function handleWindowClick(e: MouseEvent) {
    const target = e.target as HTMLElement;
    if (!target.closest('.notif-container')) close();
  }
</script>

<svelte:window onclick={handleWindowClick} />

<div class="notif-container">
  <button
    class="bell-btn"
    onclick={toggle}
    title="Notifications"
    aria-label="Notifications ({notificationStore.unreadCount} unread)"
    aria-expanded={open}
  >
    <span class="bell-icon">{'\u{1F514}'}</span>
    {#if notificationStore.unreadCount > 0}
      <span class="bell-badge">{notificationStore.unreadCount > 99 ? '99+' : notificationStore.unreadCount}</span>
    {/if}
  </button>

  {#if open}
    <div class="notif-dropdown" role="menu">
      <div class="notif-header">
        <h3>Notifications</h3>
        <div class="notif-actions">
          <button class="filter-btn" class:active={filter === 'all'} onclick={() => filter = 'all'}>All</button>
          <button class="filter-btn" class:active={filter === 'unread'} onclick={() => filter = 'unread'}>Unread</button>
          {#if notificationStore.unreadCount > 0}
            <button class="mark-all-btn" onclick={() => notificationStore.markAllRead()}>Mark all read</button>
          {/if}
        </div>
      </div>

      <div class="notif-list">
        {#if notificationStore.loading}
          <div class="notif-empty">Loading...</div>
        {:else if filtered.length === 0}
          <div class="notif-empty">
            {filter === 'unread' ? 'No unread notifications' : 'No notifications yet'}
          </div>
        {:else}
          {#each filtered as notif (notif.id)}
            <button class="notif-item" class:unread={!notif.is_read} onclick={() => handleClick(notif)}>
              <div class="notif-icon" style="color: {typeColors[notif.type] || '#64748b'}">
                {typeIcons[notif.type] || '\u{2022}'}
              </div>
              <div class="notif-content">
                {#if notif.actor}
                  <span class="notif-actor">
                    <UsernameDisplay
                      username={notif.actor.username}
                      color={notif.actor.username_color}
                      size="small"
                    />
                  </span>
                {/if}
                <span class="notif-body">{notif.body || notif.title || 'Notification'}</span>
                <span class="notif-time">{timeAgo(notif.inserted_at)}</span>
              </div>
              {#if !notif.is_read}
                <div class="unread-dot"></div>
              {/if}
            </button>
          {/each}
        {/if}
      </div>
    </div>
  {/if}
</div>

<style>
  .notif-container { position: relative; }

  .bell-btn {
    background: none;
    border: none;
    cursor: pointer;
    position: relative;
    padding: 4px;
    font-size: 18px;
    opacity: 0.7;
    transition: opacity 0.15s;
    color: inherit;
  }
  .bell-btn:hover { opacity: 1; }

  .bell-badge {
    position: absolute;
    top: -2px;
    right: -4px;
    background: #f87171;
    color: white;
    font-size: 9px;
    font-weight: 800;
    padding: 1px 4px;
    border-radius: 8px;
    min-width: 14px;
    text-align: center;
    line-height: 1.2;
  }

  .notif-dropdown {
    position: absolute;
    top: 100%;
    right: 0;
    width: 360px;
    max-height: 480px;
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
    z-index: 200;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .notif-header {
    padding: 12px 14px;
    border-bottom: 1px solid var(--border-color);
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .notif-header h3 {
    font-size: 14px;
    font-weight: 700;
    margin: 0;
  }

  .notif-actions { display: flex; gap: 4px; align-items: center; }
  .filter-btn {
    padding: 3px 8px;
    font-size: 10px;
    font-weight: 600;
    border: 1px solid var(--border-color);
    background: none;
    border-radius: var(--radius);
    cursor: pointer;
    color: var(--text-muted);
    font-family: inherit;
  }
  .filter-btn.active { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); }
  .mark-all-btn {
    padding: 3px 8px;
    font-size: 10px;
    font-weight: 600;
    background: none;
    border: none;
    cursor: pointer;
    color: var(--accent);
    font-family: inherit;
  }
  .mark-all-btn:hover { text-decoration: underline; }

  .notif-list {
    overflow-y: auto;
    max-height: 400px;
  }

  .notif-item {
    display: flex;
    align-items: flex-start;
    gap: 10px;
    padding: 10px 14px;
    width: 100%;
    background: none;
    border: none;
    border-bottom: 1px solid rgba(255, 255, 255, 0.03);
    cursor: pointer;
    text-align: left;
    color: inherit;
    font-family: inherit;
    transition: background 0.1s;
  }
  .notif-item:hover { background: rgba(255, 255, 255, 0.03); }
  .notif-item.unread { background: rgba(0, 212, 170, 0.03); }
  .notif-item:last-child { border-bottom: none; }

  .notif-icon {
    font-size: 16px;
    font-weight: 800;
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 50%;
  }

  .notif-content {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }
  .notif-actor { line-height: 1; }
  .notif-body {
    font-size: 12px;
    color: var(--text-secondary);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .notif-time {
    font-size: 10px;
    color: var(--text-muted);
  }

  .unread-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: var(--accent);
    flex-shrink: 0;
    margin-top: 8px;
  }

  .notif-empty {
    padding: 32px 16px;
    text-align: center;
    font-size: 12px;
    color: var(--text-muted);
  }

  .notif-list::-webkit-scrollbar { width: 4px; }
  .notif-list::-webkit-scrollbar-track { background: transparent; }
  .notif-list::-webkit-scrollbar-thumb { background: var(--border-color); border-radius: 2px; }
</style>
