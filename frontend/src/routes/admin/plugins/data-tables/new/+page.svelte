<script lang="ts">
  import { goto } from '$app/navigation';
  import { plugins } from '$lib/stores/plugins.svelte';

  let name = $state('');
  let description = $state('');
  let scope = $state('global');
  let maxRows = $state(10000);
  let columns = $state<{name: string; data_type: string; is_required: boolean}[]>([]);
  let submitting = $state(false);
  let error = $state('');

  function addColumn() { columns = [...columns, { name: '', data_type: 'string', is_required: false }]; }
  function removeColumn(i: number) { columns = columns.filter((_, idx) => idx !== i); }

  async function handleCreate() {
    if (!name.trim()) { error = 'Name is required'; return; }
    submitting = true; error = '';
    try {
      const table = await plugins.createDataTable({ name, description, scope, max_rows: maxRows, columns });
      goto(`/admin/plugins/data-tables/${table.id}`);
    } catch (e: any) { error = e.error || 'Failed to create table'; }
    finally { submitting = false; }
  }
</script>

<div class="new-table">
  <h1>Create Data Table</h1>
  {#if error}<div class="alert-error">{error}</div>{/if}

  <div class="form-card">
    <div class="form-group">
      <label>Name</label>
      <input type="text" bind:value={name} placeholder="e.g., user_inventory" />
    </div>
    <div class="form-group">
      <label>Description</label>
      <textarea bind:value={description} rows="2" placeholder="What data does this table store?"></textarea>
    </div>
    <div class="form-row">
      <div class="form-group">
        <label>Scope</label>
        <select bind:value={scope}>
          <option value="global">Global</option>
          <option value="per_user">Per User</option>
          <option value="per_thread">Per Thread</option>
          <option value="per_forum">Per Forum</option>
        </select>
      </div>
      <div class="form-group">
        <label>Max Rows</label>
        <input type="number" bind:value={maxRows} min="100" max="100000" />
      </div>
    </div>

    <div class="columns-section">
      <div class="section-header">
        <h3>Columns</h3>
        <button class="btn-sm" onclick={addColumn}>Add Column</button>
      </div>
      {#each columns as col, i}
        <div class="col-row">
          <input type="text" bind:value={col.name} placeholder="Column name" />
          <select bind:value={col.data_type}>
            <option value="string">String</option>
            <option value="integer">Integer</option>
            <option value="float">Float</option>
            <option value="boolean">Boolean</option>
            <option value="json">JSON</option>
            <option value="datetime">Datetime</option>
          </select>
          <label class="checkbox"><input type="checkbox" bind:checked={col.is_required} /> Required</label>
          <button class="btn-tiny" onclick={() => removeColumn(i)}>x</button>
        </div>
      {/each}
    </div>

    <button class="btn btn-primary" onclick={handleCreate} disabled={submitting}>
      {submitting ? 'Creating...' : 'Create Table'}
    </button>
  </div>
</div>

<style>
  .new-table h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); margin-bottom: 16px; }
  .form-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 20px; max-width: 640px; }
  .form-group { margin-bottom: 12px; }
  .form-group label { display: block; font-size: 12px; font-weight: 600; color: var(--text-secondary); margin-bottom: 4px; }
  .form-group input, .form-group select, .form-group textarea { width: 100%; padding: 8px 12px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-primary); color: var(--text-primary); font-size: 13px; font-family: inherit; }
  .form-row { display: flex; gap: 12px; }
  .form-row .form-group { flex: 1; }
  .columns-section { margin-bottom: 16px; }
  .section-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
  .section-header h3 { font-size: 14px; font-weight: 700; color: var(--text-primary); }
  .col-row { display: flex; align-items: center; gap: 8px; margin-bottom: 6px; }
  .col-row input, .col-row select { padding: 6px 8px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-primary); color: var(--text-primary); font-size: 12px; }
  .col-row input[type="text"] { flex: 1; }
  .checkbox { display: flex; align-items: center; gap: 4px; font-size: 12px; color: var(--text-secondary); white-space: nowrap; }
  .btn { padding: 8px 18px; border-radius: var(--radius); font-size: 13px; font-weight: 600; cursor: pointer; border: none; }
  .btn:disabled { opacity: 0.5; }
  .btn-primary { background: var(--accent); color: #fff; }
  .btn-sm { padding: 4px 12px; font-size: 11px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-card); color: var(--text-secondary); }
  .btn-tiny { padding: 2px 6px; font-size: 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-tertiary); color: var(--text-muted); cursor: pointer; }
  .alert-error { padding: 10px; border-radius: var(--radius); font-size: 13px; margin-bottom: 12px; background: #dc262620; color: #f87171; border: 1px solid #dc262640; }
</style>
