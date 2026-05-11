<script lang="ts">
  import { api } from '$lib/api/client';

  let {
    value = $bindable<string[]>([])
  }: {
    value: string[];
  } = $props();

  let friends = $state<any[]>([]);
  let loaded = $state(false);

  $effect(() => {
    loadFriends();
  });

  async function loadFriends() {
    try {
      const data = await api.getFriends();
      friends = data.friends || [];
    } catch {
      friends = [];
    }
    loaded = true;
  }

  function toggleFriend(friendId: string) {
    if (value.includes(friendId)) {
      value = value.filter(id => id !== friendId);
    } else if (value.length < 10) {
      value = [...value, friendId];
    }
  }

  function moveUp(idx: number) {
    if (idx <= 0) return;
    const arr = [...value];
    [arr[idx - 1], arr[idx]] = [arr[idx], arr[idx - 1]];
    value = arr;
  }

  function moveDown(idx: number) {
    if (idx >= value.length - 1) return;
    const arr = [...value];
    [arr[idx], arr[idx + 1]] = [arr[idx + 1], arr[idx]];
    value = arr;
  }

  function getFriend(id: string) {
    return friends.find(f => f.id === id || f.friend_id === id);
  }
</script>

<div class="top-friends-editor">
  <label class="editor-label">Top Friends ({value.length}/10)</label>

  {#if value.length > 0}
    <div class="selected-friends">
      {#each value as friendId, idx}
        {@const friend = getFriend(friendId)}
        <div class="selected-friend">
          <span class="friend-position">#{idx + 1}</span>
          <span class="friend-name">{friend?.username || friendId}</span>
          <div class="friend-actions">
            <button type="button" class="move-btn" onclick={() => moveUp(idx)} disabled={idx === 0}>&#9650;</button>
            <button type="button" class="move-btn" onclick={() => moveDown(idx)} disabled={idx === value.length - 1}>&#9660;</button>
            <button type="button" class="remove-btn" onclick={() => toggleFriend(friendId)}>x</button>
          </div>
        </div>
      {/each}
    </div>
  {/if}

  {#if loaded}
    <div class="available-friends">
      <span class="section-label">Add from friends list:</span>
      <div class="friend-grid">
        {#each friends as friend}
          {@const id = friend.id || friend.friend_id}
          {@const selected = value.includes(id)}
          <button
            type="button"
            class="friend-chip"
            class:selected
            onclick={() => toggleFriend(id)}
            disabled={!selected && value.length >= 10}
          >
            {friend.username || friend.friend_username}
          </button>
        {/each}
        {#if friends.length === 0}
          <span class="no-friends">No friends yet. Add friends via the buddy list!</span>
        {/if}
      </div>
    </div>
  {:else}
    <div class="loading">Loading friends...</div>
  {/if}
</div>

<style>
  .top-friends-editor {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .editor-label {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary);
  }

  .selected-friends {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .selected-friend {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 10px;
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    font-size: 13px;
  }

  .friend-position {
    color: var(--accent);
    font-weight: 700;
    font-size: 11px;
    min-width: 20px;
  }

  .friend-name {
    flex: 1;
    color: var(--text-primary);
    font-weight: 500;
  }

  .friend-actions {
    display: flex;
    gap: 4px;
  }

  .move-btn, .remove-btn {
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    color: var(--text-muted);
    width: 24px;
    height: 24px;
    border-radius: var(--radius);
    cursor: pointer;
    font-size: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .move-btn:hover:not(:disabled) { color: var(--accent); border-color: var(--border-accent); }
  .remove-btn:hover { color: var(--danger); border-color: var(--danger); }
  .move-btn:disabled { opacity: 0.3; cursor: default; }

  .section-label {
    font-size: 11px;
    color: var(--text-muted);
  }

  .friend-grid {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
  }

  .friend-chip {
    padding: 4px 10px;
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    color: var(--text-secondary);
    font-size: 12px;
    cursor: pointer;
    transition: all 0.15s;
  }
  .friend-chip:hover:not(:disabled) {
    background: var(--bg-hover);
    border-color: var(--border-accent);
    color: var(--accent);
  }
  .friend-chip.selected {
    background: var(--accent-glow);
    border-color: var(--accent);
    color: var(--accent);
  }
  .friend-chip:disabled {
    opacity: 0.3;
    cursor: default;
  }

  .no-friends {
    font-size: 12px;
    color: var(--text-muted);
    font-style: italic;
  }

  .loading {
    font-size: 12px;
    color: var(--text-muted);
  }
</style>
