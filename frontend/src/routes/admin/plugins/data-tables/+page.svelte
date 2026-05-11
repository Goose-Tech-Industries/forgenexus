<script lang="ts">
  import { plugins } from '$lib/stores/plugins.svelte';
  let loaded = $state(false);

  $effect(() => { if (!loaded) { plugins.loadDataTables(); loaded = true; } });

  async function handleDelete(id: string) {
    if (!confirm('Delete this table and all its data?')) return;
    await plugins.deleteDataTable(id);
  }
</script>

<div class="tables-page">
  <div class="page-header">
    <h1>Data Tables</h1>
    <a href="/admin/plugins/data-tables/new" class="btn btn-primary">New Table</a>
  </div>

  {#if plugins.loading}
    <p class="empty">Loading...</p>
  {:else if plugins.dataTables.length === 0}
    <p class="empty">No data tables created yet</p>
  {:else}
    <div class="table-list">
      {#each plugins.dataTables as table (table.id)}
        <div class="table-card">
          <div class="table-header">
            <a href="/admin/plugins/data-tables/{table.id}" class="table-name">{table.name}</a>
            <span class="badge">{table.scope}</span>
          </div>
          <div class="table-meta">
            <span>{table.columns?.length ?? 0} columns</span>
            <span>Max {table.max_rows} rows</span>
          </div>
          <div class="table-actions">
            <a href="/admin/plugins/data-tables/{table.id}" class="btn-sm">View</a>
            <button class="btn-sm btn-danger" onclick={() => handleDelete(table.id)}>Delete</button>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .tables-page h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); }
  .page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
  .btn { padding: 8px 18px; border-radius: var(--radius); font-size: 13px; font-weight: 600; cursor: pointer; border: none; text-decoration: none; }
  .btn-primary { background: var(--accent); color: #fff; }
  .table-list { display: flex; flex-direction: column; gap: 10px; }
  .table-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 14px 16px; }
  .table-header { display: flex; align-items: center; gap: 8px; margin-bottom: 6px; }
  .table-name { font-size: 14px; font-weight: 700; color: var(--accent); text-decoration: none; }
  .badge { padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; background: var(--bg-tertiary); color: var(--text-secondary); }
  .table-meta { display: flex; gap: 16px; font-size: 12px; color: var(--text-muted); margin-bottom: 8px; }
  .table-actions { display: flex; gap: 6px; }
  .btn-sm { padding: 4px 12px; border-radius: var(--radius); font-size: 11px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); background: var(--bg-card); color: var(--text-secondary); text-decoration: none; }
  .btn-danger { color: #f87171; border-color: #dc262640; }
  .empty { color: var(--text-muted); font-size: 13px; text-align: center; padding: 24px 0; }
</style>
