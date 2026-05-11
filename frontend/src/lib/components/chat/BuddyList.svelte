<script lang="ts">
  import { api } from '$lib/api/client';
  import { chatStore } from '$lib/stores/chat.svelte';
  import { auth } from '$lib/stores/auth.svelte';
  import { socketStore } from '$lib/stores/socket.svelte';
  import { soundStore } from '$lib/stores/sounds.svelte';

  let friends = $state<any[]>([]);
  let loading = $state(true);
  let pollTimer: ReturnType<typeof setInterval> | null = null;

  // Track previous online state to detect sign on/off transitions
  let prevOnlineIds = new Set<string>();
  let initialLoadDone = false;

  $effect(() => {
    if (auth.isLoggedIn) {
      loadFriends();
      // Poll every 10s to catch status changes
      pollTimer = setInterval(loadFriends, 10000);
    }
    return () => {
      if (pollTimer) clearInterval(pollTimer);
    };
  });

  // Also reactively update from socket presence data
  $effect(() => {
    const presenceIds = new Set(socketStore.onlineUsers.map(u => u.user_id));
    if (!initialLoadDone || friends.length === 0) return;

    let changed = false;
    for (const f of friends) {
      const nowOnline = presenceIds.has(f.id);
      if (f.is_online !== nowOnline) {
        // Status changed — play sound
        if (nowOnline && !prevOnlineIds.has(f.id)) {
          soundStore.buddySignOn();
        } else if (!nowOnline && prevOnlineIds.has(f.id)) {
          soundStore.buddySignOff();
        }
        f.is_online = nowOnline;
        changed = true;
      }
    }
    if (changed) {
      friends = [...friends]; // trigger reactivity
    }

    // Update tracking set
    prevOnlineIds = new Set(friends.filter(f => f.is_online).map(f => f.id));
  });

  async function loadFriends() {
    try {
      const data = await api.getFriends();
      const newFriends = data.friends || [];

      if (initialLoadDone) {
        // Compare with previous state to detect sign on/off
        const newOnlineIds = new Set<string>(newFriends.filter((f: any) => f.is_online).map((f: any) => f.id as string));

        for (const id of newOnlineIds) {
          if (!prevOnlineIds.has(id)) {
            soundStore.buddySignOn();
            break; // one sound per poll cycle is enough
          }
        }
        for (const id of prevOnlineIds) {
          if (!newOnlineIds.has(id)) {
            soundStore.buddySignOff();
            break;
          }
        }

        prevOnlineIds = newOnlineIds;
      } else {
        // First load — don't play sounds, just record state
        prevOnlineIds = new Set<string>(newFriends.filter((f: any) => f.is_online).map((f: any) => f.id as string));
        initialLoadDone = true;
      }

      friends = newFriends;
    } catch {
      friends = [];
    }
    loading = false;
  }

  async function openChat(friend: any) {
    try {
      const data = await api.createDirectChat(friend.id);
      chatStore.openChat(data.conversation.id, friend.username, friend.avatar_url);
    } catch {
      chatStore.openChat(`temp-${friend.id}`, friend.username, friend.avatar_url);
    }
  }

  // Custom status text display
  function statusText(friend: any): string {
    if (friend.custom_status_text) return friend.custom_status_text;
    if (friend.is_online) return 'Online';
    return 'Offline';
  }
</script>

<div class="buddy-list">
  <div class="buddy-header">
    <span>Friends</span>
    <span class="online-count">
      {friends.filter(f => f.is_online).length} online
    </span>
  </div>

  <div class="buddy-body">
    {#if loading}
      <div class="empty">Loading...</div>
    {:else if !auth.isLoggedIn}
      <div class="empty">Login to see friends</div>
    {:else if friends.length === 0}
      <div class="empty">No friends yet</div>
    {:else}
      <!-- Online friends first -->
      {#each friends.filter(f => f.is_online) as friend (friend.id)}
        <button class="buddy-item" onclick={() => openChat(friend)}>
          <span class="status-dot online"></span>
          <div class="buddy-info">
            <span class="buddy-name">{friend.username}</span>
            {#if friend.custom_status_text}
              <span class="buddy-status">{friend.custom_status_text}</span>
            {/if}
          </div>
        </button>
      {/each}

      <!-- Offline friends -->
      {#each friends.filter(f => !f.is_online) as friend (friend.id)}
        <button class="buddy-item offline" onclick={() => openChat(friend)}>
          <span class="status-dot offline"></span>
          <div class="buddy-info">
            <span class="buddy-name">{friend.username}</span>
          </div>
        </button>
      {/each}
    {/if}
  </div>

  <!-- Sound toggle at bottom -->
  <div class="buddy-footer">
    <button
      class="sound-toggle"
      onclick={() => soundStore.setEnabled(!soundStore.enabled)}
      title={soundStore.enabled ? 'Mute sounds' : 'Enable sounds'}
    >
      {soundStore.enabled ? '\uD83D\uDD0A' : '\uD83D\uDD07'}
      <span>{soundStore.enabled ? 'Sounds On' : 'Sounds Off'}</span>
    </button>
  </div>
</div>

<style>
  .buddy-list {
    position: fixed;
    bottom: var(--chatbar-height);
    right: 0;
    width: 220px;
    max-height: 400px;
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-bottom: none;
    border-radius: var(--radius-lg) 0 0 0;
    display: flex;
    flex-direction: column;
    box-shadow: -4px -4px 16px rgba(0, 0, 0, 0.3);
  }

  .buddy-header {
    background: linear-gradient(180deg, var(--bg-tertiary) 0%, var(--bg-secondary) 100%);
    border-bottom: 1px solid var(--accent);
    padding: 8px 12px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 12px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .online-count {
    font-weight: 400;
    color: var(--online);
    font-size: 11px;
  }

  .buddy-body {
    flex: 1;
    overflow-y: auto;
    padding: 4px 0;
  }

  .buddy-item {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    padding: 6px 12px;
    background: none;
    border: none;
    color: var(--text-primary);
    font-size: 12px;
    cursor: pointer;
    text-align: left;
    transition: background 0.1s;
  }
  .buddy-item:hover {
    background: var(--bg-hover);
  }
  .buddy-item.offline {
    color: var(--text-muted);
  }

  .buddy-info {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }

  .buddy-name {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .buddy-status {
    font-size: 10px;
    color: var(--text-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-style: italic;
  }

  .buddy-footer {
    border-top: 1px solid var(--border-color);
    padding: 4px 8px;
    background: var(--bg-secondary);
  }

  .sound-toggle {
    display: flex;
    align-items: center;
    gap: 4px;
    width: 100%;
    padding: 4px 6px;
    background: none;
    border: none;
    color: var(--text-muted);
    font-size: 11px;
    cursor: pointer;
    border-radius: var(--radius);
    transition: background 0.1s;
  }
  .sound-toggle:hover {
    background: var(--bg-hover);
    color: var(--text-primary);
  }

  .empty {
    padding: 24px 12px;
    text-align: center;
    color: var(--text-muted);
    font-size: 12px;
  }
</style>
