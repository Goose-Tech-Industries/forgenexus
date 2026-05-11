<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';

  let {
    threadId,
    isLocked = false,
    isPinned = false,
    isHidden = false,
    onUpdate
  }: {
    threadId: string;
    isLocked?: boolean;
    isPinned?: boolean;
    isHidden?: boolean;
    onUpdate?: () => void;
  } = $props();

  let locked = $state(isLocked);
  let pinned = $state(isPinned);
  let hidden = $state(isHidden);
  let showMoveForm = $state(false);
  let showMergeForm = $state(false);
  let moveForumId = $state('');
  let mergeTargetId = $state('');

  async function toggleLock() {
    if (locked) {
      await api.unlockThread(threadId);
    } else {
      await api.lockThread(threadId);
    }
    locked = !locked;
    onUpdate?.();
  }

  async function togglePin() {
    if (pinned) {
      await api.unpinThread(threadId);
    } else {
      await api.pinThread(threadId);
    }
    pinned = !pinned;
    onUpdate?.();
  }

  async function toggleHide() {
    if (hidden) {
      await api.unhideThread(threadId);
    } else {
      await api.hideThread(threadId);
    }
    hidden = !hidden;
    onUpdate?.();
  }

  async function moveThread() {
    if (!moveForumId) return;
    await api.moveThread(threadId, moveForumId);
    showMoveForm = false;
    moveForumId = '';
    onUpdate?.();
  }

  async function mergeThread() {
    if (!mergeTargetId) return;
    await api.mergeThreads(threadId, mergeTargetId);
    showMergeForm = false;
    mergeTargetId = '';
    onUpdate?.();
  }
</script>

{#if auth.isStaff}
  <div class="thread-mod-toolbar">
    <div class="mod-actions">
      <button class="mod-btn" class:active={locked} onclick={toggleLock}>
        {locked ? 'Unlock' : 'Lock'}
      </button>
      <button class="mod-btn" class:active={pinned} onclick={togglePin}>
        {pinned ? 'Unpin' : 'Pin'}
      </button>
      <button class="mod-btn" class:active={hidden} onclick={toggleHide}>
        {hidden ? 'Unhide' : 'Hide'}
      </button>
      <button class="mod-btn" onclick={() => { showMoveForm = !showMoveForm; showMergeForm = false; }}>Move</button>
      <button class="mod-btn" onclick={() => { showMergeForm = !showMergeForm; showMoveForm = false; }}>Merge</button>
    </div>

    {#if showMoveForm}
      <div class="move-form">
        <input
          type="text"
          bind:value={moveForumId}
          placeholder="Target forum ID"
        />
        <button class="mod-btn mod-btn-action" onclick={moveThread}>Move Thread</button>
      </div>
    {/if}

    {#if showMergeForm}
      <div class="move-form">
        <input
          type="text"
          bind:value={mergeTargetId}
          placeholder="Target thread ID to merge into"
        />
        <button class="mod-btn mod-btn-action" onclick={mergeThread}>Merge Into</button>
      </div>
    {/if}
  </div>
{/if}

<style>
  .thread-mod-toolbar {
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    padding: 6px 10px;
    margin-bottom: 8px;
  }

  .mod-actions {
    display: flex;
    gap: 4px;
    flex-wrap: wrap;
  }

  .mod-btn {
    padding: 4px 10px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-card);
    color: var(--text-secondary);
    font-size: 11px;
    cursor: pointer;
  }
  .mod-btn:hover { background: var(--bg-hover); }
  .mod-btn.active { background: var(--accent); color: white; border-color: var(--accent); }
  .mod-btn-action { background: var(--accent); color: white; border-color: var(--accent); }

  .move-form {
    display: flex;
    gap: 6px;
    margin-top: 8px;
  }

  input {
    flex: 1;
    padding: 6px 8px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-input);
    color: var(--text-primary);
    font-size: 12px;
  }
</style>
