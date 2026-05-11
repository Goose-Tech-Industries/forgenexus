<script lang="ts">
  import { admin } from '$lib/stores/admin.svelte';
  import AuditTimeline from '$lib/components/admin/AuditTimeline.svelte';

  let loading = $state(true);
  let categoryFilter = $state('');

  const categories = ['', 'settings', 'forums', 'plugins', 'themes', 'permissions'];

  $effect(() => { load(); });

  async function load() {
    loading = true;
    const params: Record<string, string> = {};
    if (categoryFilter) params.category = categoryFilter;
    await admin.loadAuditLogs(params);
    loading = false;
  }

  async function handleRollback(id: string) {
    if (!confirm('Revert this action? This will restore the previous state.')) return;
    await admin.rollbackAction(id);
  }

  function handleFilterChange() {
    load();
  }
</script>

<div class="page">
  <div class="page-header">
    <div>
      <h1>Admin Audit Trail</h1>
      <p class="subtitle">Every admin action with one-click rollback</p>
    </div>
    <div class="filters">
      <select bind:value={categoryFilter} onchange={handleFilterChange}>
        {#each categories as cat}
          <option value={cat}>{cat || 'All categories'}</option>
        {/each}
      </select>
    </div>
  </div>

  {#if loading}
    <p class="loading">Loading audit trail...</p>
  {:else if admin.auditLogs.length === 0}
    <div class="empty">No audit log entries found.</div>
  {:else}
    <div class="timeline">
      {#each admin.auditLogs as log (log.id)}
        <AuditTimeline {log} onRollback={handleRollback} />
      {/each}
    </div>
  {/if}
</div>

<style>
  .page h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); }
  .subtitle { font-size: 12px; color: var(--text-muted); margin-top: 2px; }
  .page-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 20px; }
  .filters select {
    padding: 6px 12px; border: 1px solid var(--border-color); border-radius: var(--radius);
    background: var(--bg-input); color: var(--text-primary); font-size: 12px; font-family: inherit;
    text-transform: capitalize;
  }
  .timeline { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 8px 16px; }
  .loading, .empty { color: var(--text-muted); text-align: center; padding: 32px 0; font-size: 13px; }
</style>
