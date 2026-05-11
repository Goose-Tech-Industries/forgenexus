<script lang="ts">
  import { admin } from '$lib/stores/admin.svelte';
  import FunnelChart from '$lib/components/admin/FunnelChart.svelte';
  import HeatmapGrid from '$lib/components/admin/HeatmapGrid.svelte';

  let loading = $state(true);

  $effect(() => { load(); });

  let whatIfResults = $state<any[]>([]);
  let whatIfThreshold = $state(6);

  async function load() {
    loading = true;
    await Promise.all([
      admin.loadFunnel(),
      admin.loadPluginImpact(),
      admin.loadHeatmap(),
      admin.loadSentimentTrends(),
      admin.loadMergeSuggestions(),
    ]);
    loading = false;
  }

  async function runWhatIf() {
    whatIfResults = await admin.whatIf([
      { points: whatIfThreshold, sanction: 'temp_ban' }
    ]);
  }

  function failRate(total: number, failures: number): string {
    if (total === 0) return '0%';
    return Math.round((failures / total) * 100) + '%';
  }

  function formatDuration(ms: number | null): string {
    if (ms === null) return '-';
    if (ms < 1000) return `${Math.round(ms)}ms`;
    return `${(ms / 1000).toFixed(1)}s`;
  }
</script>

<div class="page">
  <h1>Analytics</h1>

  {#if loading}
    <p class="loading">Loading analytics...</p>
  {:else}
    <!-- Registration Funnel -->
    <section class="section">
      <h2>Registration Funnel <span class="period">(last 30 days)</span></h2>
      {#if admin.funnel}
        <FunnelChart data={admin.funnel} />
      {/if}
    </section>

    <!-- Plugin Impact -->
    <section class="section">
      <h2>Plugin Impact</h2>
      {#if admin.pluginImpact.length === 0}
        <p class="empty">No plugin execution data yet.</p>
      {:else}
        <table class="impact-table">
          <thead>
            <tr>
              <th>Plugin</th>
              <th>Type</th>
              <th>Status</th>
              <th>Executions</th>
              <th>Fail Rate</th>
              <th>Avg Duration</th>
            </tr>
          </thead>
          <tbody>
            {#each admin.pluginImpact as plugin (plugin.id + plugin.type)}
              <tr>
                <td class="plugin-name">{plugin.name}</td>
                <td><span class="type-badge" class:flow={plugin.type === 'flow'} class:js={plugin.type === 'js_plugin'}>{plugin.type === 'js_plugin' ? 'JS' : 'Flow'}</span></td>
                <td><span class="status-dot" class:active={plugin.status === 'active'}></span> {plugin.status}</td>
                <td class="num">{plugin.total}</td>
                <td class="num" class:high-fail={plugin.failures / Math.max(plugin.total, 1) > 0.1}>{failRate(plugin.total, plugin.failures)}</td>
                <td class="num">{formatDuration(plugin.avg_duration)}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </section>

    <!-- Activity Heatmap -->
    <section class="section">
      <h2>Mod Activity Heatmap <span class="period">(last 90 days)</span></h2>
      <p class="heatmap-hint">Shows when your moderation team is active. Dark cells = coverage gaps.</p>
      <HeatmapGrid cells={admin.heatmap} />
    </section>

    <!-- What If Simulator -->
    <section class="section">
      <h2>What If Simulator</h2>
      <p class="hint">Preview the impact of changing moderation thresholds</p>
      <div class="what-if-controls">
        <label class="slider-label">
          Temp ban at <strong>{whatIfThreshold}</strong> points
          <input type="range" min="2" max="20" bind:value={whatIfThreshold} />
        </label>
        <button class="btn btn-primary" onclick={runWhatIf}>Simulate</button>
      </div>
      {#if whatIfResults.length > 0}
        {#each whatIfResults as result}
          <div class="what-if-result">
            <span class="wi-count">{result.affected_count}</span> users would be affected
            <span class="wi-detail">({result.currently_active} currently active)</span>
            {#if result.users.length > 0}
              <div class="wi-users">
                {#each result.users as user}
                  <span class="wi-user" class:online={user.is_online}>{user.username}</span>
                {/each}
              </div>
            {/if}
          </div>
        {/each}
      {/if}
    </section>

    <!-- Sentiment Trends -->
    {#if admin.sentimentTrends?.trends?.length > 0}
      <section class="section">
        <h2>Sentiment Trends <span class="period">(last 30 days)</span></h2>
        <p class="hint">Per-forum mood based on keyword analysis. Score: -1 (negative) to +1 (positive)</p>
        <div class="sentiment-grid">
          {#each Object.entries(admin.sentimentTrends.forum_names || {}) as [forumId, forumName]}
            {@const forumTrends = admin.sentimentTrends.trends.filter((t: any) => t.forum_id === forumId)}
            {#if forumTrends.length > 0}
              <div class="sentiment-card">
                <span class="sentiment-forum">{forumName}</span>
                <div class="sentiment-bars">
                  {#each forumTrends as trend}
                    {@const color = trend.avg_score > 0.1 ? '#4ade80' : trend.avg_score < -0.1 ? '#f87171' : '#64748b'}
                    <div class="sentiment-bar" style="height: {Math.abs(trend.avg_score) * 24 + 4}px; background: {color};" title="{new Date(trend.week).toLocaleDateString()}: {trend.avg_score} ({trend.post_count} posts)"></div>
                  {/each}
                </div>
              </div>
            {/if}
          {/each}
        </div>
      </section>
    {/if}

    <!-- Smart Merge Suggestions -->
    {#if admin.mergeSuggestions.length > 0}
      <section class="section">
        <h2>Smart Merge Suggestions</h2>
        <p class="hint">Similar threads that might be duplicates</p>
        {#each admin.mergeSuggestions as suggestion}
          <div class="merge-row">
            <span class="merge-title">{suggestion.thread_1.title}</span>
            <span class="merge-arrow">&harr;</span>
            <span class="merge-title">{suggestion.thread_2.title}</span>
            <span class="merge-score">{Math.round(suggestion.similarity * 100)}%</span>
          </div>
        {/each}
      </section>
    {/if}
  {/if}
</div>

<style>
  .page h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); margin-bottom: 20px; }
  .section { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; margin-bottom: 16px; }
  .section h2 { font-size: 14px; font-weight: 700; color: var(--text-primary); margin-bottom: 12px; }
  .period { font-size: 11px; font-weight: 400; color: var(--text-muted); }
  .heatmap-hint { font-size: 11px; color: var(--text-muted); margin-bottom: 10px; }
  .loading, .empty { color: var(--text-muted); text-align: center; padding: 24px 0; font-size: 13px; }

  .impact-table { width: 100%; border-collapse: collapse; font-size: 12px; }
  .impact-table th { text-align: left; padding: 8px 10px; font-size: 10px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; border-bottom: 1px solid var(--border-color); }
  .impact-table td { padding: 8px 10px; border-bottom: 1px solid rgba(30, 41, 59, 0.4); color: var(--text-secondary); }
  .impact-table tr:last-child td { border-bottom: none; }
  .plugin-name { font-weight: 600; color: var(--text-primary); }
  .num { font-variant-numeric: tabular-nums; text-align: right; }
  .high-fail { color: #f87171; font-weight: 600; }

  .type-badge { font-size: 10px; padding: 1px 6px; border-radius: 6px; font-weight: 600; }
  .type-badge.flow { background: #3b82f620; color: #60a5fa; }
  .type-badge.js { background: #f59e0b20; color: #fbbf24; }

  .status-dot { width: 6px; height: 6px; border-radius: 50%; display: inline-block; background: var(--text-muted); }
  .status-dot.active { background: #4ade80; }

  .hint { font-size: 11px; color: var(--text-muted); margin-bottom: 10px; }

  /* What If */
  .what-if-controls { display: flex; align-items: center; gap: 12px; margin-bottom: 10px; }
  .slider-label { font-size: 12px; color: var(--text-secondary); display: flex; align-items: center; gap: 8px; }
  .slider-label input[type="range"] { width: 200px; }
  .what-if-result { padding: 10px; background: var(--bg-tertiary); border-radius: var(--radius); margin-top: 8px; font-size: 13px; }
  .wi-count { font-size: 20px; font-weight: 800; color: #fbbf24; }
  .wi-detail { font-size: 11px; color: var(--text-muted); }
  .wi-users { display: flex; flex-wrap: wrap; gap: 4px; margin-top: 6px; }
  .wi-user { font-size: 11px; padding: 2px 8px; border-radius: 8px; background: var(--bg-card); color: var(--text-secondary); }
  .wi-user.online { color: #4ade80; }

  /* Sentiment */
  .sentiment-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 10px; }
  .sentiment-card { background: var(--bg-tertiary); border-radius: var(--radius); padding: 10px; }
  .sentiment-forum { font-size: 12px; font-weight: 600; color: var(--text-primary); display: block; margin-bottom: 6px; }
  .sentiment-bars { display: flex; gap: 2px; align-items: flex-end; height: 32px; }
  .sentiment-bar { width: 8px; min-height: 4px; border-radius: 2px; }

  /* Merge */
  .merge-row { display: flex; align-items: center; gap: 8px; padding: 8px 0; border-bottom: 1px solid var(--border-color); font-size: 12px; }
  .merge-row:last-child { border-bottom: none; }
  .merge-title { flex: 1; color: var(--text-primary); font-weight: 500; }
  .merge-arrow { color: var(--text-muted); }
  .merge-score { font-weight: 700; color: var(--accent); min-width: 40px; text-align: right; }
</style>
