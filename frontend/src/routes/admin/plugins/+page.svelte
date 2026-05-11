<script lang="ts">
  import { plugins } from '$lib/stores/plugins.svelte';
  let loaded = $state(false);

  $effect(() => {
    if (!loaded) {
      plugins.loadFlows();
      plugins.loadExecutions({ limit: '5' });
      loaded = true;
    }
  });
</script>

<div class="plugin-dash">
  <h1>Plugin Dashboard</h1>

  <div class="stats-grid">
    <div class="stat-card">
      <div class="stat-value">{plugins.flows.filter(f => f.status === 'active').length}</div>
      <div class="stat-label">Active Flows</div>
    </div>
    <div class="stat-card">
      <div class="stat-value">{plugins.flows.length}</div>
      <div class="stat-label">Total Flows</div>
    </div>
    <div class="stat-card">
      <div class="stat-value">{plugins.executions.length}</div>
      <div class="stat-label">Recent Executions</div>
    </div>
  </div>

  <div class="quick-links">
    <a href="/admin/plugins/flows/new" class="btn btn-primary">Create Flow</a>
    <a href="/admin/plugins/data-tables/new" class="btn">New Data Table</a>
  </div>

  {#if plugins.executions.length > 0}
    <section class="section">
      <h2>Recent Executions</h2>
      {#each plugins.executions.slice(0, 5) as exec}
        <div class="item-row">
          <span class="badge badge-{exec.status}">{exec.status}</span>
          <span>{exec.trigger_type}</span>
          <span class="meta">{exec.nodes_executed} nodes, {exec.duration_ms ?? '?'}ms</span>
          <span class="meta">{new Date(exec.started_at).toLocaleString()}</span>
        </div>
      {/each}
    </section>
  {/if}
</div>

<style>
  .plugin-dash h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); margin-bottom: 16px; }
  .stats-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-bottom: 16px; }
  .stat-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; text-align: center; }
  .stat-value { font-size: 28px; font-weight: 800; color: var(--accent); }
  .stat-label { font-size: 12px; color: var(--text-muted); text-transform: uppercase; margin-top: 4px; }
  .quick-links { display: flex; gap: 8px; margin-bottom: 16px; }
  .btn { padding: 8px 18px; border-radius: var(--radius); font-size: 13px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); background: var(--bg-card); color: var(--text-secondary); text-decoration: none; }
  .btn-primary { background: var(--accent); color: #fff; border-color: var(--accent); }
  .section { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; }
  .section h2 { font-size: 14px; font-weight: 700; color: var(--text-primary); margin-bottom: 12px; padding-bottom: 8px; border-bottom: 1px solid var(--border-color); }
  .item-row { display: flex; align-items: center; gap: 8px; padding: 6px 0; font-size: 13px; border-bottom: 1px solid var(--border-color); }
  .item-row:last-child { border-bottom: none; }
  .badge { padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; background: var(--bg-tertiary); color: var(--text-secondary); }
  .badge-completed { background: #22c55e33; color: #4ade80; }
  .badge-failed { background: #dc262633; color: #f87171; }
  .badge-running { background: #3b82f633; color: #60a5fa; }
  .badge-timeout { background: #eab30833; color: #fbbf24; }
  .meta { color: var(--text-muted); font-size: 12px; margin-left: auto; }
</style>
