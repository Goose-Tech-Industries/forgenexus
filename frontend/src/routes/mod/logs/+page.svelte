<script lang="ts">
  import { moderation } from '$lib/stores/moderation.svelte';

  let loaded = $state(false);
  let actionFilter = $state('');

  $effect(() => {
    if (!loaded) {
      moderation.loadModLogs();
      loaded = true;
    }
  });

  async function filterByAction(action: string) {
    actionFilter = action;
    await moderation.loadModLogs(action ? { action } : undefined);
  }

  const actionColors: Record<string, string> = {
    ban: '#dc2626',
    unban: '#16a34a',
    warn: '#ea580c',
    revoke_warning: '#16a34a',
    lock_thread: '#d97706',
    unlock_thread: '#16a34a',
    pin_thread: '#2563eb',
    hide_thread: '#7c3aed',
    hide_post: '#7c3aed',
    resolve_report: '#16a34a',
    dismiss_report: '#6b7280',
    assign_report: '#2563eb',
    move_thread: '#0891b2'
  };

  const actions = ['', 'ban', 'unban', 'warn', 'lock_thread', 'hide_post', 'resolve_report', 'move_thread'];
</script>

<div class="logs-page">
  <h1>Moderation Log</h1>

  <div class="filter-bar">
    {#each actions as action}
      <button
        class="filter-btn"
        class:active={actionFilter === action}
        onclick={() => filterByAction(action)}
      >
        {action || 'All'}
      </button>
    {/each}
  </div>

  {#if moderation.loading}
    <p class="loading">Loading logs...</p>
  {:else if moderation.modLogs.length === 0}
    <p class="empty">No log entries found</p>
  {:else}
    <div class="log-list">
      {#each moderation.modLogs as log}
        <div class="log-entry">
          <div class="log-action" style="color: {actionColors[log.action] || 'var(--text-secondary)'}">
            {log.action.replace(/_/g, ' ')}
          </div>
          <div class="log-details">
            <span class="log-mod">{log.moderator.username}</span>
            <span class="log-arrow">&rarr;</span>
            <span class="log-target">{log.target_type} {log.target_id.slice(0, 8)}</span>
            {#if log.reason}
              <span class="log-reason">"{log.reason}"</span>
            {/if}
          </div>
          <div class="log-time">{new Date(log.inserted_at).toLocaleString()}</div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .logs-page h1 {
    font-size: 20px;
    font-weight: 700;
    color: var(--text-primary);
    margin-bottom: 16px;
  }

  .filter-bar {
    display: flex;
    gap: 4px;
    margin-bottom: 16px;
    flex-wrap: wrap;
  }

  .filter-btn {
    padding: 4px 10px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-card);
    color: var(--text-secondary);
    font-size: 11px;
    cursor: pointer;
    text-transform: capitalize;
  }
  .filter-btn:hover { background: var(--bg-hover); }
  .filter-btn.active {
    background: var(--accent);
    color: white;
    border-color: var(--accent);
  }

  .log-list {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    overflow: hidden;
  }

  .log-entry {
    display: grid;
    grid-template-columns: 140px 1fr 160px;
    align-items: center;
    padding: 10px 14px;
    border-bottom: 1px solid var(--border-color);
    font-size: 13px;
  }
  .log-entry:last-child { border-bottom: none; }

  .log-action {
    font-weight: 700;
    font-size: 12px;
    text-transform: uppercase;
    letter-spacing: 0.02em;
  }

  .log-details {
    display: flex;
    align-items: center;
    gap: 6px;
    color: var(--text-secondary);
  }

  .log-mod { font-weight: 600; color: var(--text-primary); }
  .log-arrow { color: var(--text-muted); }
  .log-target { color: var(--text-secondary); font-family: monospace; font-size: 12px; }
  .log-reason { color: var(--text-muted); font-style: italic; font-size: 12px; }
  .log-time { text-align: right; color: var(--text-muted); font-size: 11px; }

  .loading, .empty {
    color: var(--text-muted);
    font-size: 13px;
    padding: 24px 0;
    text-align: center;
  }
</style>
