<script lang="ts">
  import { api } from '$lib/api/client';
  import type { ChannelMessage } from '$lib/stores/channels.svelte';

  let {
    onClose,
    onJumpToMessage
  }: {
    onClose: () => void;
    onJumpToMessage: (channelSlug: string, messageId: string) => void;
  } = $props();

  let query = $state('');
  let channelFilter = $state('');
  let hasFilter = $state('');
  let results = $state<(ChannelMessage & { channel_name?: string; channel_slug?: string })[]>([]);
  let searching = $state(false);
  let searched = $state(false);
  let searchTimeout: ReturnType<typeof setTimeout>;

  function handleInput() {
    clearTimeout(searchTimeout);
    if (query.trim().length < 2) {
      results = [];
      searched = false;
      return;
    }
    searchTimeout = setTimeout(doSearch, 400);
  }

  async function doSearch() {
    if (query.trim().length < 2) return;
    searching = true;
    searched = true;
    try {
      const data = await api.searchMessages({
        q: query.trim(),
        channel: channelFilter || undefined,
        has: hasFilter || undefined
      });
      results = data.messages || [];
    } catch {
      results = [];
    }
    searching = false;
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') onClose();
    if (e.key === 'Enter') {
      clearTimeout(searchTimeout);
      doSearch();
    }
  }

  function formatTime(ts: string) {
    const d = new Date(ts);
    return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }) + ' ' +
      d.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' });
  }

  function highlightMatch(text: string) {
    if (!query.trim()) return text;
    const escaped = query.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    return text.replace(new RegExp(`(${escaped})`, 'gi'), '<mark>$1</mark>');
  }
</script>

<div class="search-overlay" role="dialog">
  <div class="search-panel">
    <div class="search-header">
      <div class="search-input-row">
        <span class="search-icon">&#128269;</span>
        <input
          type="text"
          bind:value={query}
          oninput={handleInput}
          onkeydown={handleKeydown}
          placeholder="Search messages..."
          autofocus
        />
        <button class="close-btn" onclick={onClose}>&times;</button>
      </div>

      <div class="search-filters">
        <input
          type="text"
          bind:value={channelFilter}
          placeholder="Channel slug filter..."
          class="filter-input"
          oninput={handleInput}
        />
        <select bind:value={hasFilter} onchange={doSearch} class="filter-select">
          <option value="">All messages</option>
          <option value="pinned">Pinned only</option>
          <option value="attachment">Has attachment</option>
        </select>
      </div>
    </div>

    <div class="search-results">
      {#if searching}
        <div class="search-status">Searching...</div>
      {:else if searched && results.length === 0}
        <div class="search-status">No results found for "{query}"</div>
      {:else if results.length > 0}
        <div class="results-count">{results.length} result{results.length !== 1 ? 's' : ''}</div>
        {#each results as msg (msg.id)}
          <button
            class="result-item"
            onclick={() => onJumpToMessage(msg.channel_slug || '', msg.id)}
          >
            <div class="result-meta">
              <span class="result-channel">#{msg.channel_name || 'unknown'}</span>
              <span class="result-author">{msg.user?.username || 'Unknown'}</span>
              <span class="result-time">{formatTime(msg.inserted_at)}</span>
            </div>
            <div class="result-body">{@html highlightMatch(msg.body?.slice(0, 300) || '')}</div>
          </button>
        {/each}
      {:else}
        <div class="search-status search-hint">Type at least 2 characters to search</div>
      {/if}
    </div>
  </div>
</div>

<style>
  .search-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.6);
    z-index: 500;
    display: flex;
    justify-content: center;
    padding-top: 80px;
  }

  .search-panel {
    width: 560px;
    max-height: 70vh;
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    box-shadow: 0 16px 48px rgba(0, 0, 0, 0.4);
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .search-header {
    padding: 12px 16px;
    border-bottom: 1px solid var(--border-color);
  }

  .search-input-row {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .search-icon { font-size: 16px; opacity: 0.5; }

  .search-input-row input {
    flex: 1;
    background: none;
    border: none;
    font-size: 16px;
    color: var(--text-primary);
    font-family: inherit;
    outline: none;
  }
  .search-input-row input::placeholder { color: var(--text-muted); }

  .close-btn {
    background: none;
    border: none;
    font-size: 20px;
    color: var(--text-muted);
    cursor: pointer;
    padding: 4px;
  }
  .close-btn:hover { color: var(--text-primary); }

  .search-filters {
    display: flex;
    gap: 8px;
    margin-top: 8px;
  }
  .filter-input, .filter-select {
    flex: 1;
    background: var(--bg-primary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    padding: 4px 8px;
    font-size: 11px;
    color: var(--text-secondary);
    font-family: inherit;
  }
  .filter-input:focus, .filter-select:focus { outline: none; border-color: var(--accent); }

  .search-results {
    overflow-y: auto;
    flex: 1;
  }

  .search-status {
    padding: 32px 16px;
    text-align: center;
    color: var(--text-muted);
    font-size: 13px;
  }
  .search-hint { opacity: 0.6; }

  .results-count {
    padding: 6px 16px;
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    color: var(--text-muted);
    letter-spacing: 0.05em;
  }

  .result-item {
    display: block;
    width: 100%;
    text-align: left;
    padding: 10px 16px;
    background: none;
    border: none;
    border-bottom: 1px solid rgba(255, 255, 255, 0.03);
    cursor: pointer;
    font-family: inherit;
    color: inherit;
    transition: background 0.1s;
  }
  .result-item:hover { background: rgba(255, 255, 255, 0.04); }

  .result-meta {
    display: flex;
    align-items: baseline;
    gap: 8px;
    font-size: 11px;
    margin-bottom: 4px;
  }
  .result-channel { color: var(--accent); font-weight: 600; }
  .result-author { color: var(--text-primary); font-weight: 600; }
  .result-time { color: var(--text-muted); margin-left: auto; }

  .result-body {
    font-size: 13px;
    color: var(--text-secondary);
    line-height: 1.4;
    overflow: hidden;
    text-overflow: ellipsis;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
  }
  .result-body :global(mark) {
    background: rgba(251, 191, 36, 0.3);
    color: var(--text-primary);
    padding: 0 2px;
    border-radius: 2px;
  }

  .search-results::-webkit-scrollbar { width: 6px; }
  .search-results::-webkit-scrollbar-track { background: transparent; }
  .search-results::-webkit-scrollbar-thumb { background: var(--border-color); border-radius: 3px; }
</style>
