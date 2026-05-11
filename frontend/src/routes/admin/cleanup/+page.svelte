<script lang="ts">
  import { api } from '$lib/api/client';
  let rules = $state<any[]>([]);
  let loading = $state(true);
  let runningRule = $state<string | null>(null);
  let results = $state<Record<string, any>>({});

  $effect(() => { load(); });
  async function load() {
    loading = true;
    try { const data = await api.getCleanupPreview(); rules = data.rules || []; } catch {}
    loading = false;
  }

  async function executeRule(ruleId: string) {
    if (!confirm(`Run "${rules.find(r => r.id === ruleId)?.name}"? This action may be irreversible.`)) return;
    runningRule = ruleId;
    try {
      const data = await api.runCleanup(ruleId);
      results[ruleId] = data.result;
      await load(); // Refresh counts
    } catch {}
    runningRule = null;
  }
</script>

<div class="admin-page">
  <h1>Automated Cleanup</h1>
  <p class="subtitle">Preview and execute maintenance tasks. Review affected counts before running.</p>

  {#if loading}
    <p class="loading">Loading...</p>
  {:else}
    <div class="rules-list">
      {#each rules as rule}
        <div class="rule-card">
          <div class="rule-header">
            <h3>{rule.name}</h3>
            {#if rule.affected > 0}
              <span class="affected-badge">{rule.affected} affected</span>
            {:else}
              <span class="clean-badge">Clean</span>
            {/if}
          </div>
          <p class="rule-desc">{rule.description}</p>
          <div class="rule-actions">
            {#if results[rule.id]}
              <span class="result-msg">Done! {results[rule.id].affected} items processed.</span>
            {/if}
            <button
              class="btn-run"
              onclick={() => executeRule(rule.id)}
              disabled={runningRule === rule.id || rule.affected === 0}
            >
              {runningRule === rule.id ? 'Running...' : 'Run Now'}
            </button>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .admin-page { max-width: 700px; }
  h1 { font-size: 20px; font-weight: 800; margin-bottom: 4px; }
  .subtitle { font-size: 12px; color: var(--text-muted); margin-bottom: 20px; }
  .rules-list { display: flex; flex-direction: column; gap: 12px; }
  .rule-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px 20px; }
  .rule-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; }
  .rule-header h3 { font-size: 14px; font-weight: 700; margin: 0; }
  .affected-badge { font-size: 11px; font-weight: 700; color: #fbbf24; background: rgba(251,191,36,0.1); padding: 2px 8px; border-radius: 10px; }
  .clean-badge { font-size: 11px; font-weight: 700; color: #4ade80; background: rgba(74,222,128,0.1); padding: 2px 8px; border-radius: 10px; }
  .rule-desc { font-size: 12px; color: var(--text-muted); margin-bottom: 10px; }
  .rule-actions { display: flex; align-items: center; gap: 10px; justify-content: flex-end; }
  .result-msg { font-size: 11px; color: #4ade80; font-weight: 600; }
  .btn-run { padding: 6px 14px; font-size: 12px; border-radius: var(--radius); border: 1px solid var(--accent); background: rgba(0,212,170,0.08); color: var(--accent); cursor: pointer; font-family: inherit; font-weight: 600; }
  .btn-run:disabled { opacity: 0.4; cursor: not-allowed; }
  .loading { text-align: center; color: var(--text-muted); padding: 40px; }
</style>
