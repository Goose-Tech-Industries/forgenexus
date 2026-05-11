<script lang="ts">
  import type { AuditLog } from '$lib/stores/admin.svelte';

  let { log, onRollback }: { log: AuditLog; onRollback: (id: string) => void } = $props();

  const categoryColors: Record<string, string> = {
    settings: '#3b82f6', forums: '#22c55e', plugins: '#a855f7',
    themes: '#ec4899', permissions: '#f59e0b',
  };

  const color = $derived(categoryColors[log.category] || '#6b7280');
  const canRollback = $derived(!log.is_rolled_back && Object.keys(log.previous_state).length > 0);
</script>

<div class="timeline-entry" class:rolled-back={log.is_rolled_back}>
  <div class="timeline-dot" style="background: {color};"></div>
  <div class="timeline-content">
    <div class="entry-header">
      <span class="entry-action" style="color: {color};">{log.action.replace(/_/g, ' ')}</span>
      <span class="entry-category">{log.category}</span>
      {#if log.is_rolled_back}
        <span class="rolled-back-badge">Reverted</span>
      {/if}
      <span class="entry-date">{new Date(log.inserted_at).toLocaleString()}</span>
    </div>
    {#if log.description}
      <p class="entry-desc">{log.description}</p>
    {/if}
    <div class="entry-meta">
      <span>by {log.admin?.username || 'Unknown'}</span>
      {#if log.target_type}
        <span>on {log.target_type}</span>
      {/if}
      {#if log.is_rolled_back && log.rolled_back_by}
        <span>reverted by {log.rolled_back_by.username}</span>
      {/if}
    </div>
    {#if canRollback}
      <button class="revert-btn" onclick={() => onRollback(log.id)}>Revert</button>
    {/if}
  </div>
</div>

<style>
  .timeline-entry {
    display: flex; gap: 12px; padding: 12px 0;
    border-bottom: 1px solid var(--border-color);
  }
  .timeline-entry:last-child { border-bottom: none; }
  .timeline-entry.rolled-back { opacity: 0.5; }
  .timeline-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; margin-top: 4px; }
  .timeline-content { flex: 1; min-width: 0; }
  .entry-header { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
  .entry-action { font-size: 13px; font-weight: 700; text-transform: capitalize; }
  .entry-category { font-size: 10px; padding: 1px 6px; border-radius: 6px; background: var(--bg-tertiary); color: var(--text-muted); text-transform: capitalize; }
  .rolled-back-badge { font-size: 10px; padding: 1px 6px; border-radius: 6px; background: #f5920b20; color: #fbbf24; }
  .entry-date { font-size: 11px; color: var(--text-muted); margin-left: auto; }
  .entry-desc { font-size: 12px; color: var(--text-secondary); margin-top: 4px; }
  .entry-meta { font-size: 11px; color: var(--text-muted); display: flex; gap: 8px; margin-top: 4px; }
  .revert-btn {
    margin-top: 6px; padding: 3px 10px; font-size: 11px; font-weight: 600;
    border: 1px solid #f59e0b; border-radius: var(--radius);
    background: #f59e0b20; color: #fbbf24; cursor: pointer; font-family: inherit;
  }
  .revert-btn:hover { background: #f59e0b40; }
</style>
