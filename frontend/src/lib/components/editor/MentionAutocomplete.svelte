<script lang="ts">
  import { api } from '$lib/api/client';

  let { textarea = $bindable() }: { textarea?: HTMLTextAreaElement | null } = $props();
  let suggestions = $state<any[]>([]);
  let showDropdown = $state(false);
  let mentionStart = $state(-1);
  let selectedIndex = $state(0);

  function handleInput() {
    if (!textarea) return;
    const pos = textarea.selectionStart;
    const text = textarea.value.substring(0, pos);
    const atMatch = text.match(/@(\w{1,25})$/);

    if (atMatch) {
      mentionStart = pos - atMatch[0].length;
      searchUsers(atMatch[1]);
    } else {
      showDropdown = false;
    }
  }

  async function searchUsers(query: string) {
    if (query.length < 1) { showDropdown = false; return; }
    try {
      const data = await api.searchUsers(query);
      suggestions = data.users || [];
      showDropdown = suggestions.length > 0;
      selectedIndex = 0;
    } catch { showDropdown = false; }
  }

  function selectUser(user: any) {
    if (!textarea) return;
    const before = textarea.value.substring(0, mentionStart);
    const after = textarea.value.substring(textarea.selectionStart);
    textarea.value = before + '@' + user.username + ' ' + after;
    textarea.dispatchEvent(new Event('input'));
    showDropdown = false;
    textarea.focus();
    const newPos = mentionStart + user.username.length + 2;
    textarea.selectionStart = newPos;
    textarea.selectionEnd = newPos;
  }

  function handleKeydown(e: KeyboardEvent) {
    if (!showDropdown) return;
    if (e.key === 'ArrowDown') { e.preventDefault(); selectedIndex = Math.min(selectedIndex + 1, suggestions.length - 1); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); selectedIndex = Math.max(selectedIndex - 1, 0); }
    else if (e.key === 'Enter' || e.key === 'Tab') {
      if (suggestions[selectedIndex]) { e.preventDefault(); selectUser(suggestions[selectedIndex]); }
    }
    else if (e.key === 'Escape') { showDropdown = false; }
  }

  $effect(() => {
    if (textarea) {
      textarea.addEventListener('input', handleInput);
      textarea.addEventListener('keydown', handleKeydown);
      return () => {
        textarea?.removeEventListener('input', handleInput);
        textarea?.removeEventListener('keydown', handleKeydown);
      };
    }
  });
</script>

{#if showDropdown}
  <div class="mention-dropdown">
    {#each suggestions as user, i (user.id)}
      <button
        type="button"
        class="mention-item"
        class:selected={i === selectedIndex}
        onclick={() => selectUser(user)}
      >
        <div class="mention-avatar">
          {#if user.avatar_url}<img src={user.avatar_url} alt="" />{:else}{user.username.charAt(0).toUpperCase()}{/if}
        </div>
        <span class="mention-name">{user.username}</span>
      </button>
    {/each}
  </div>
{/if}

<style>
  .mention-dropdown {
    position: absolute; bottom: 100%; left: 0; z-index: 50;
    background: var(--bg-card); border: 1px solid var(--border-color);
    border-radius: var(--radius); box-shadow: 0 4px 16px rgba(0,0,0,0.3);
    max-height: 200px; overflow-y: auto; min-width: 200px;
  }
  .mention-item {
    display: flex; align-items: center; gap: 8px; width: 100%;
    padding: 6px 10px; border: none; background: none;
    color: var(--text-primary); font-size: 13px; cursor: pointer; text-align: left;
  }
  .mention-item:hover, .mention-item.selected { background: var(--bg-hover); }
  .mention-avatar {
    width: 24px; height: 24px; border-radius: 4px; background: var(--bg-tertiary);
    display: flex; align-items: center; justify-content: center; overflow: hidden;
    font-size: 11px; font-weight: 700; color: var(--text-muted); flex-shrink: 0;
  }
  .mention-avatar img { width: 100%; height: 100%; object-fit: cover; }
  .mention-name { font-weight: 600; }
</style>
