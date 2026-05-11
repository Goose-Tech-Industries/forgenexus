<script lang="ts">
  import { plugins } from '$lib/stores/plugins.svelte';
  let loaded = $state(false);
  let filter = $state('');
  let expandedId = $state<string | null>(null);

  $effect(() => { if (!loaded) { plugins.loadExecutions(); loaded = true; } });

  function filterByStatus(status: string) {
    filter = filter === status ? '' : status;
    plugins.loadExecutions(filter ? { status: filter } : {});
  }
</script>

<div class="exec-page">
  <h1>Execution Log</h1>

  <div class="filter-bar">
    {#each ['completed', 'failed', 'timeout', 'running'] as s}
      <button class="filter-btn" class:active={filter === s} onclick={() => filterByStatus(s)}>{s}</button>
    {/each}
  </div>

  {#if plugins.loading}
    <p class="empty">Loading...</p>
  {:else if plugins.executions.length === 0}
    <p class="empty">No executions found</p>
  {:else}
    <div class="exec-list">
      {#each plugins.executions as exec (exec.id)}
        <div class="exec-card" class:expanded={expandedId === exec.id}>
          <div class="exec-row" onclick={() => { expandedId = expandedId === exec.id ? null : exec.id; }}>
            <span class="badge badge-{exec.status}">{exec.status}</span>
            <span class="trigger">{exec.trigger_type.replace(/_/g, ' ')}</span>
            <span class="stat">{exec.nodes_executed} nodes</span>
            <span class="stat">{exec.db_operations} DB ops</span>
            <span class="stat">{exec.duration_ms ?? '?'}ms</span>
            <span class="time">{new Date(exec.started_at).toLocaleString()}</span>
          </div>

          {#if expandedId === exec.id}
            <div class="trace-section">
              <h3>Node Trace</h3>
              {#if exec.node_trace && exec.node_trace.length > 0}
                {#each exec.node_trace as step, i}
                  <div class="trace-step">
                    <span class="step-num">#{i + 1}</span>
                    <span class="step-type">{step.type || step.node_type || '?'}</span>
                    {#if step.duration_ms}<span class="step-dur">{step.duration_ms}ms</span>{/if}
                    {#if step.error}<span class="step-err">{step.error}</span>{/if}
                  </div>
                {/each}
              {:else}
                <p class="empty">No trace data</p>
              {/if}

              {#if exec.result && Object.keys(exec.result).length > 0}
                <h3>Result</h3>
                <pre class="result-json">{JSON.stringify(exec.result, null, 2)}</pre>
              {/if}
            </div>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .exec-page h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); margin-bottom: 16px; }
  .filter-bar { display: flex; gap: 6px; margin-bottom: 16px; }
  .filter-btn { padding: 6px 14px; border-radius: 16px; border: 1px solid var(--border-color); background: var(--bg-card); color: var(--text-secondary); font-size: 12px; font-weight: 600; cursor: pointer; text-transform: capitalize; }
  .filter-btn.active { background: var(--accent); color: #fff; border-color: var(--accent); }
  .exec-list { display: flex; flex-direction: column; gap: 6px; }
  .exec-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); overflow: hidden; }
  .exec-row { display: flex; align-items: center; gap: 10px; padding: 12px 16px; cursor: pointer; font-size: 13px; }
  .exec-row:hover { background: var(--bg-hover); }
  .badge { padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; background: var(--bg-tertiary); color: var(--text-secondary); }
  .badge-completed { background: #22c55e33; color: #4ade80; }
  .badge-failed { background: #dc262633; color: #f87171; }
  .badge-timeout { background: #eab30833; color: #fbbf24; }
  .badge-running { background: #3b82f633; color: #60a5fa; }
  .trigger { font-weight: 600; color: var(--text-primary); }
  .stat { color: var(--text-muted); font-size: 12px; }
  .time { margin-left: auto; color: var(--text-muted); font-size: 12px; }
  .trace-section { padding: 0 16px 16px; border-top: 1px solid var(--border-color); }
  .trace-section h3 { font-size: 12px; font-weight: 700; color: var(--text-secondary); margin: 12px 0 8px; text-transform: uppercase; }
  .trace-step { display: flex; align-items: center; gap: 8px; padding: 4px 0; font-size: 12px; border-bottom: 1px solid var(--border-color); }
  .trace-step:last-child { border-bottom: none; }
  .step-num { color: var(--text-muted); font-weight: 600; }
  .step-type { color: var(--text-primary); font-weight: 600; }
  .step-dur { color: var(--text-muted); }
  .step-err { color: #f87171; }
  .result-json { font-size: 11px; background: var(--bg-tertiary); padding: 10px; border-radius: var(--radius); color: var(--text-secondary); overflow-x: auto; font-family: monospace; }
  .empty { color: var(--text-muted); font-size: 13px; text-align: center; padding: 24px 0; }
</style>
