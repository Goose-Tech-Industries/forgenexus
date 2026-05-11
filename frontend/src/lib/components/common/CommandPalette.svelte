<script lang="ts">
  import { api } from '$lib/api/client';

  let isOpen = $state(false);
  let query = $state('');
  let results = $state<any[]>([]);
  let selectedIndex = $state(0);
  let inputEl: HTMLInputElement;

  const defaultCommands = [
    { type: 'nav', label: 'Go to Home Feed', icon: '🏠', action: () => goto('/') },
    { type: 'nav', label: 'Go to Forums', icon: '💬', action: () => goto('/forums') },
    { type: 'nav', label: 'Go to Voice Rooms', icon: '🎙', action: () => goto('/live') },
    { type: 'nav', label: 'Go to Messages', icon: '✉️', action: () => goto('/messages') },
    { type: 'nav', label: 'Go to Profile', icon: '👤', action: () => goto('/settings/profile') },
    { type: 'nav', label: 'Go to Admin', icon: '⚙️', action: () => goto('/admin') },
    { type: 'action', label: 'Create New Thread', icon: '📝', action: () => goto('/forums?new=1') },
    { type: 'action', label: 'Create New Status Post', icon: '💭', action: () => { isOpen = false; } },
    { type: 'action', label: 'Toggle Dark/Light Mode', icon: '🌓', action: () => { isOpen = false; } },
    { type: 'action', label: 'Search Everything', icon: '🔍', action: () => goto('/search') },
  ];

  function goto(path: string) {
    isOpen = false;
    window.location.href = path;
  }

  function open() {
    isOpen = true;
    query = '';
    results = defaultCommands;
    selectedIndex = 0;
    setTimeout(() => inputEl?.focus(), 50);
  }

  function close() {
    isOpen = false;
    query = '';
  }

  function handleKeydown(e: KeyboardEvent) {
    if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
      e.preventDefault();
      if (isOpen) close(); else open();
    }

    if (!isOpen) return;

    if (e.key === 'Escape') close();
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      selectedIndex = Math.min(selectedIndex + 1, results.length - 1);
    }
    if (e.key === 'ArrowUp') {
      e.preventDefault();
      selectedIndex = Math.max(selectedIndex - 1, 0);
    }
    if (e.key === 'Enter' && results[selectedIndex]) {
      results[selectedIndex].action();
    }
  }

  $effect(() => {
    if (query.length === 0) {
      results = defaultCommands;
    } else {
      const q = query.toLowerCase();
      results = defaultCommands.filter(cmd =>
        cmd.label.toLowerCase().includes(q)
      );
    }
    selectedIndex = 0;
  });

  if (typeof window !== 'undefined') {
    window.addEventListener('keydown', handleKeydown);
  }
</script>

{#if isOpen}
  <!-- svelte-ignore a11y-click-events-have-key-events -->
  <div class="palette-overlay" onclick={close} role="dialog" aria-modal="true">
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <div class="palette" onclick={(e) => e.stopPropagation()} role="document" tabindex="-1">
      <div class="palette-input-wrap">
        <span class="palette-icon">⌘</span>
        <input
          bind:this={inputEl}
          bind:value={query}
          type="text"
          class="palette-input"
          placeholder="Type a command or search..."
          autocomplete="off"
          spellcheck="false"
        />
        <kbd class="palette-kbd">ESC</kbd>
      </div>

      <div class="palette-results">
        {#each results as result, i}
          <!-- svelte-ignore a11y-click-events-have-key-events -->
          <div
            class="palette-item"
            class:selected={i === selectedIndex}
            onclick={() => result.action()}
            role="option"
            aria-selected={i === selectedIndex}
            tabindex="-1"
          >
            <span class="palette-item-icon">{result.icon}</span>
            <span class="palette-item-label">{result.label}</span>
            <span class="palette-item-type">{result.type}</span>
          </div>
        {/each}

        {#if results.length === 0}
          <div class="palette-empty">No results for "{query}"</div>
        {/if}
      </div>

      <div class="palette-footer">
        <span><kbd>↑↓</kbd> navigate</span>
        <span><kbd>↵</kbd> select</span>
        <span><kbd>esc</kbd> close</span>
      </div>
    </div>
  </div>
{/if}

<style>
  .palette-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.6);
    backdrop-filter: blur(8px);
    z-index: 9999;
    display: flex;
    justify-content: center;
    padding-top: 15vh;
    animation: fadeIn 0.15s ease;
  }

  .palette {
    width: 560px;
    max-height: 60vh;
    background: var(--bg-card);
    border: 1px solid var(--border-accent);
    border-radius: var(--radius-xl);
    box-shadow: var(--shadow-xl), var(--shadow-glow-lg);
    overflow: hidden;
    animation: scaleIn 0.2s cubic-bezier(0.34, 1.56, 0.64, 1);
  }

  .palette-input-wrap {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 14px 18px;
    border-bottom: 1px solid var(--border-color);
  }

  .palette-icon {
    color: var(--accent);
    font-size: 16px;
    font-weight: 700;
  }

  .palette-input {
    flex: 1;
    background: transparent;
    border: none;
    outline: none;
    color: var(--text-primary);
    font-size: 16px;
    font-weight: 400;
  }

  .palette-input::placeholder { color: var(--text-muted); }

  .palette-kbd {
    background: var(--bg-elevated);
    color: var(--text-muted);
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 11px;
    font-family: var(--font-mono);
    border: 1px solid var(--border-color);
  }

  .palette-results {
    max-height: 45vh;
    overflow-y: auto;
    padding: 6px;
  }

  .palette-item {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 14px;
    border-radius: var(--radius-md);
    cursor: pointer;
    transition: all 0.1s;
  }

  .palette-item:hover,
  .palette-item.selected {
    background: var(--accent-muted);
  }

  .palette-item.selected {
    border-left: 2px solid var(--accent);
  }

  .palette-item-icon { font-size: 18px; width: 24px; text-align: center; }
  .palette-item-label { flex: 1; font-size: 14px; color: var(--text-primary); }
  .palette-item-type { font-size: 11px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; }

  .palette-empty {
    padding: 20px;
    text-align: center;
    color: var(--text-muted);
    font-size: 14px;
  }

  .palette-footer {
    display: flex;
    gap: 16px;
    padding: 10px 18px;
    border-top: 1px solid var(--border-color);
    font-size: 12px;
    color: var(--text-muted);
  }

  .palette-footer kbd {
    background: var(--bg-elevated);
    padding: 1px 5px;
    border-radius: 3px;
    font-family: var(--font-mono);
    font-size: 10px;
    border: 1px solid var(--border-color);
    margin-right: 4px;
  }

  @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
  @keyframes scaleIn {
    from { opacity: 0; transform: scale(0.95) translateY(-10px); }
    to { opacity: 1; transform: scale(1) translateY(0); }
  }
</style>
