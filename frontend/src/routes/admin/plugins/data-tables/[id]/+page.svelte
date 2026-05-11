<script lang="ts">
  import { page } from '$app/stores';
  import { api } from '$lib/api/client';
  import type { DataTable, DataRow, DataColumn } from '$lib/stores/plugins.svelte';

  let tableId = $derived(($page.params as Record<string, string>).id);
  let table = $state<DataTable | null>(null);
  let rows = $state<DataRow[]>([]);
  let rowCount = $state(0);
  let loading = $state(true);
  let tab = $state('schema');

  $effect(() => { loadTable(); });

  async function loadTable() {
    loading = true;
    try {
      const d = await api.getDataTable(tableId);
      table = d.table;
      const rd = await api.getDataRows(tableId, { limit: '25' });
      rows = rd.rows;
      rowCount = rd.count;
    } finally { loading = false; }
  }

  // Add column
  let colName = $state('');
  let colType = $state('string');
  let colRequired = $state(false);

  async function addColumn() {
    if (!colName.trim()) return;
    await api.addDataColumn(tableId, { name: colName, data_type: colType, is_required: colRequired });
    colName = ''; colType = 'string'; colRequired = false;
    await loadTable();
  }

  async function deleteColumn(colId: string) {
    if (!confirm('Delete this column?')) return;
    await api.deleteDataColumn(tableId, colId);
    await loadTable();
  }

  // Add row
  let showRowForm = $state(false);
  let rowData = $state('{}');

  async function addRow() {
    try {
      const data = JSON.parse(rowData);
      await api.createDataRow(tableId, { data });
      showRowForm = false; rowData = '{}';
      await loadTable();
    } catch { alert('Invalid JSON'); }
  }

  async function deleteRow(rowId: string) {
    await api.deleteDataRow(tableId, rowId);
    rows = rows.filter(r => r.id !== rowId);
    rowCount--;
  }
</script>

{#if loading}
  <p class="loading">Loading...</p>
{:else if table}
  <div class="table-detail">
    <div class="table-header">
      <div>
        <h1>{table.name}</h1>
        <p class="desc">{table.description || ''} <span class="badge">{table.scope}</span></p>
      </div>
    </div>

    <div class="tabs">
      <button class="tab" class:active={tab === 'schema'} onclick={() => { tab = 'schema'; }}>Schema</button>
      <button class="tab" class:active={tab === 'data'} onclick={() => { tab = 'data'; }}>Data ({rowCount})</button>
    </div>

    {#if tab === 'schema'}
      <div class="section">
        <h2>Columns ({table.columns.length})</h2>
        {#each table.columns as col (col.id)}
          <div class="col-row">
            <span class="col-name">{col.name}</span>
            <span class="badge">{col.data_type}</span>
            {#if col.is_required}<span class="flag">required</span>{/if}
            {#if col.is_indexed}<span class="flag">indexed</span>{/if}
            <button class="btn-tiny" onclick={() => deleteColumn(col.id)}>x</button>
          </div>
        {/each}

        <div class="add-col-form">
          <input type="text" bind:value={colName} placeholder="Column name" />
          <select bind:value={colType}>
            <option value="string">String</option>
            <option value="integer">Integer</option>
            <option value="float">Float</option>
            <option value="boolean">Boolean</option>
            <option value="json">JSON</option>
            <option value="datetime">Datetime</option>
          </select>
          <label class="checkbox"><input type="checkbox" bind:checked={colRequired} /> Req</label>
          <button class="btn-sm" onclick={addColumn}>Add</button>
        </div>
      </div>

    {:else if tab === 'data'}
      <div class="section">
        <div class="section-header">
          <h2>Rows</h2>
          <button class="btn-sm" onclick={() => { showRowForm = !showRowForm; }}>Add Row</button>
        </div>

        {#if showRowForm}
          <div class="inline-form">
            <label>Data (JSON matching column schema)</label>
            <textarea bind:value={rowData} rows="3" placeholder="Enter JSON data matching columns"></textarea>
            <button class="btn btn-primary" onclick={addRow}>Insert</button>
          </div>
        {/if}

        {#if rows.length === 0}
          <p class="empty">No rows</p>
        {:else}
          {#each rows as row (row.id)}
            <div class="row-card">
              <div class="row-data">
                {#each Object.entries(row.data) as [key, val]}
                  <span class="kv"><strong>{key}:</strong> {JSON.stringify(val)}</span>
                {/each}
              </div>
              <div class="row-meta">
                <span>v{row.version}</span>
                <span>{new Date(row.inserted_at).toLocaleDateString()}</span>
                <button class="btn-tiny" onclick={() => deleteRow(row.id)}>x</button>
              </div>
            </div>
          {/each}
        {/if}
      </div>
    {/if}
  </div>
{/if}

<style>
  .table-detail h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); }
  .desc { font-size: 13px; color: var(--text-muted); margin-top: 2px; }
  .table-header { margin-bottom: 16px; }
  .tabs { display: flex; gap: 4px; margin-bottom: 16px; }
  .tab { padding: 6px 14px; border-radius: 16px; border: 1px solid var(--border-color); background: var(--bg-card); color: var(--text-secondary); font-size: 12px; font-weight: 600; cursor: pointer; }
  .tab.active { background: var(--accent); color: #fff; border-color: var(--accent); }
  .section { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; }
  .section h2 { font-size: 14px; font-weight: 700; color: var(--text-primary); margin-bottom: 12px; }
  .section-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }
  .col-row { display: flex; align-items: center; gap: 8px; padding: 6px 0; font-size: 13px; border-bottom: 1px solid var(--border-color); }
  .col-row:last-child { border-bottom: none; }
  .col-name { font-weight: 600; color: var(--text-primary); }
  .badge { padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; background: var(--bg-tertiary); color: var(--text-secondary); }
  .flag { font-size: 10px; color: var(--text-muted); background: var(--bg-tertiary); padding: 1px 6px; border-radius: 8px; }
  .add-col-form { display: flex; align-items: center; gap: 8px; margin-top: 12px; padding-top: 12px; border-top: 1px solid var(--border-color); }
  .add-col-form input, .add-col-form select { padding: 6px 8px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-primary); color: var(--text-primary); font-size: 12px; }
  .add-col-form input { flex: 1; }
  .checkbox { display: flex; align-items: center; gap: 4px; font-size: 12px; color: var(--text-secondary); white-space: nowrap; }
  .inline-form { background: var(--bg-tertiary); padding: 12px; border-radius: var(--radius); margin-bottom: 12px; display: flex; flex-direction: column; gap: 8px; }
  .inline-form label { font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  .inline-form textarea { padding: 8px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-primary); color: var(--text-primary); font-size: 13px; font-family: monospace; }
  .row-card { background: var(--bg-tertiary); border-radius: var(--radius); padding: 10px; margin-bottom: 6px; }
  .row-data { display: flex; flex-wrap: wrap; gap: 8px; font-size: 12px; margin-bottom: 4px; }
  .kv { color: var(--text-secondary); }
  .kv strong { color: var(--text-primary); }
  .row-meta { display: flex; gap: 8px; font-size: 11px; color: var(--text-muted); align-items: center; }
  .btn { padding: 6px 16px; border-radius: var(--radius); font-size: 12px; font-weight: 600; cursor: pointer; border: none; }
  .btn-primary { background: var(--accent); color: #fff; }
  .btn-sm { padding: 4px 12px; font-size: 11px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-card); color: var(--text-secondary); }
  .btn-tiny { padding: 2px 6px; font-size: 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-tertiary); color: var(--text-muted); cursor: pointer; }
  .loading, .empty { color: var(--text-muted); font-size: 13px; text-align: center; padding: 24px 0; }
</style>
