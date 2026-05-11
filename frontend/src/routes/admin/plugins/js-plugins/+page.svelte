<script lang="ts">
  import { plugins, type JsPlugin } from '$lib/stores/plugins.svelte';
  import { goto } from '$app/navigation';

  let loading = $state(true);

  $effect(() => { loadPlugins(); });

  async function loadPlugins() {
    loading = true;
    await plugins.loadJsPlugins();
    loading = false;
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this plugin?')) return;
    await plugins.deleteJsPlugin(id);
  }

  async function handleActivate(id: string) {
    await plugins.activateJsPlugin(id);
  }

  async function handleDeactivate(id: string) {
    await plugins.deactivateJsPlugin(id);
  }

  function hookBadge(hook: string) {
    return hook.replace('on_', '').replace(/_/g, ' ');
  }
</script>

<div class="page-header">
  <h1>JS Plugins</h1>
  <button class="btn btn-primary" onclick={() => goto('/admin/plugins/js-plugins/new')}>New Plugin</button>
</div>

{#if loading}
  <p class="loading">Loading plugins...</p>
{:else if plugins.jsPlugins.length === 0}
  <div class="empty-state">
    <p>No JavaScript plugins yet.</p>
    <p class="hint">JS plugins let you write forum automation in TypeScript, executed in a sandboxed Deno runtime.</p>
  </div>
{:else}
  <div class="plugin-grid">
    {#each plugins.jsPlugins as plugin (plugin.id)}
      <div class="plugin-card" onclick={() => goto(`/admin/plugins/js-plugins/${plugin.id}`)}>
        <div class="card-header">
          <span class="plugin-name">{plugin.name}</span>
          <span class="badge badge-{plugin.status}">{plugin.status}</span>
        </div>
        <p class="plugin-desc">{plugin.description || 'No description'}</p>
        <div class="hooks-row">
          {#each plugin.manifest?.hooks ?? [] as hook}
            <span class="hook-badge">{hookBadge(hook)}</span>
          {/each}
        </div>
        <div class="card-meta">
          <span>v{plugin.version}</span>
          <span>{plugin.execution_count} runs</span>
          <span>{plugin.last_executed_at ? new Date(plugin.last_executed_at).toLocaleDateString() : 'Never run'}</span>
        </div>
        <div class="card-actions" onclick={(e: MouseEvent) => e.stopPropagation()}>
          {#if plugin.status !== 'active'}
            <button class="btn-sm" onclick={() => handleActivate(plugin.id)}>Activate</button>
          {:else}
            <button class="btn-sm" onclick={() => handleDeactivate(plugin.id)}>Deactivate</button>
          {/if}
          <button class="btn-sm btn-danger" onclick={() => handleDelete(plugin.id)}>Delete</button>
        </div>
      </div>
    {/each}
  </div>
{/if}

<style>
  .page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
  .page-header h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); }
  .btn { padding: 6px 16px; border-radius: var(--radius); font-size: 12px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); background: var(--bg-card); color: var(--text-secondary); font-family: inherit; }
  .btn-primary { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); font-weight: 700; }
  .btn-primary:hover { background: var(--accent-hover); }
  .loading { color: var(--text-muted); text-align: center; padding: 32px 0; }
  .empty-state { text-align: center; padding: 48px 0; color: var(--text-secondary); }
  .empty-state .hint { font-size: 12px; color: var(--text-muted); margin-top: 4px; }

  .plugin-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 12px; }

  .plugin-card {
    background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg);
    padding: 14px; cursor: pointer; transition: border-color 0.15s;
  }
  .plugin-card:hover { border-color: var(--border-accent); }

  .card-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; }
  .plugin-name { font-size: 14px; font-weight: 700; color: var(--text-primary); }
  .plugin-desc { font-size: 12px; color: var(--text-muted); margin-bottom: 8px; }

  .hooks-row { display: flex; flex-wrap: wrap; gap: 4px; margin-bottom: 8px; }
  .hook-badge { font-size: 10px; padding: 2px 6px; border-radius: 6px; background: var(--bg-tertiary); color: var(--accent); font-weight: 500; text-transform: capitalize; }

  .card-meta { display: flex; gap: 12px; font-size: 11px; color: var(--text-muted); margin-bottom: 8px; }
  .card-actions { display: flex; gap: 6px; }

  .btn-sm { padding: 3px 10px; font-size: 11px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-tertiary); color: var(--text-secondary); font-family: inherit; }
  .btn-sm:hover { background: var(--bg-hover); }
  .btn-danger { color: #f87171; border-color: #dc262640; }
  .btn-danger:hover { background: #dc262620; }

  .badge { padding: 2px 8px; border-radius: 10px; font-size: 10px; font-weight: 600; background: var(--bg-tertiary); color: var(--text-secondary); }
  .badge-active { background: #22c55e33; color: #4ade80; }
  .badge-draft { background: #eab30833; color: #fbbf24; }
  .badge-error { background: #dc262633; color: #f87171; }
  .badge-disabled { background: var(--bg-tertiary); color: var(--text-muted); }
</style>
