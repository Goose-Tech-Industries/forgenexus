<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';

  let {
    postId,
    userId,
    isHidden = false,
    onUpdate
  }: {
    postId: string;
    userId: string;
    isHidden?: boolean;
    onUpdate?: () => void;
  } = $props();

  let hidden = $state(isHidden);

  async function toggleHide() {
    if (hidden) {
      await api.unhidePost(postId);
    } else {
      await api.hidePost(postId);
    }
    hidden = !hidden;
    onUpdate?.();
  }
</script>

{#if auth.isStaff}
  <div class="post-mod-toolbar">
    <button class="mod-btn" onclick={toggleHide} title={hidden ? 'Unhide post' : 'Hide post'}>
      {hidden ? 'Unhide' : 'Hide'}
    </button>
    <a href="/mod/users/{userId}" class="mod-btn" title="View user infractions">
      Infractions
    </a>
  </div>
{/if}

<style>
  .post-mod-toolbar {
    display: flex;
    gap: 4px;
  }

  .mod-btn {
    padding: 2px 8px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-tertiary);
    color: var(--text-muted);
    font-size: 10px;
    cursor: pointer;
    text-decoration: none;
  }
  .mod-btn:hover {
    background: var(--bg-hover);
    color: var(--text-secondary);
  }
</style>
