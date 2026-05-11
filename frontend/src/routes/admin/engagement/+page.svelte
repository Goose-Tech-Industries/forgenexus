<script lang="ts">
  import { api } from '$lib/api/client';

  interface EngagementConfig {
    window_days: number;
    weight_post: number;
    cap_post: number;
    weight_thread: number;
    cap_thread: number;
    weight_reputation: number;
    cap_reputation: number;
    recency_max: number;
    tier_power: number;
    tier_active: number;
    tier_casual: number;
  }

  const defaultConfig: EngagementConfig = {
    window_days: 30,
    weight_post: 3,
    cap_post: 30,
    weight_thread: 5,
    cap_thread: 20,
    weight_reputation: 1,
    cap_reputation: 20,
    recency_max: 30,
    tier_power: 80,
    tier_active: 50,
    tier_casual: 20
  };

  let users = $state<any[]>([]);
  let loading = $state(true);
  let config = $state<EngagementConfig>({ ...defaultConfig });
  let showConfig = $state(false);
  let saving = $state(false);
  let saveMessage = $state('');

  $effect(() => { load(); });
  async function load() {
    loading = true;
    try {
      const data = await api.getEngagementScores(100);
      users = data.users || [];
      if (data.config) config = { ...defaultConfig, ...data.config };
    } catch {}
    loading = false;
  }

  async function saveConfig() {
    saving = true;
    saveMessage = '';
    try {
      await api.updateEngagementConfig(config as unknown as Record<string, number>);
      saveMessage = 'Saved. Recalculating scores...';
      await load();
      saveMessage = 'Saved.';
    } catch (err: any) {
      saveMessage = 'Failed: ' + (err?.error || 'unknown error');
    }
    saving = false;
  }

  function resetDefaults() {
    if (!confirm('Reset scoring configuration to defaults?')) return;
    config = { ...defaultConfig };
  }

  const maxScore = $derived(config.cap_post + config.cap_thread + config.cap_reputation + config.recency_max);

  const tierColors: Record<string, string> = { power_user: '#4ade80', active: '#06b6d4', casual: '#fbbf24', lurker: '#94a3b8', inactive: '#64748b' };
  const tierLabels: Record<string, string> = { power_user: 'Power User', active: 'Active', casual: 'Casual', lurker: 'Lurker', inactive: 'Inactive' };
</script>

<div class="admin-page">
  <div class="header-row">
    <div>
      <h1>Engagement Scoring</h1>
      <p class="subtitle">Users ranked by engagement score (posts, threads, reputation, recency).</p>
    </div>
    <button class="btn-config" onclick={() => (showConfig = !showConfig)}>
      {showConfig ? 'Hide Config' : 'Edit Scoring Config'}
    </button>
  </div>

  {#if showConfig}
    <div class="config-card">
      <div class="config-header">
        <h2>Scoring Configuration</h2>
        <span class="config-sub">Max possible score: <strong>{Math.min(maxScore, 100)}</strong> (capped at 100)</span>
      </div>

      <div class="config-section">
        <h3>Time Window</h3>
        <div class="config-grid">
          <label>Window (days)<input type="number" bind:value={config.window_days} min="1" /></label>
        </div>
        <p class="help">How many days back to count recent posts/threads.</p>
      </div>

      <div class="config-section">
        <h3>Activity Weights &amp; Caps</h3>
        <div class="config-grid grid-4">
          <label>Post weight<input type="number" bind:value={config.weight_post} min="0" /></label>
          <label>Post cap<input type="number" bind:value={config.cap_post} min="0" /></label>
          <label>Thread weight<input type="number" bind:value={config.weight_thread} min="0" /></label>
          <label>Thread cap<input type="number" bind:value={config.cap_thread} min="0" /></label>
          <label>Reputation weight<input type="number" bind:value={config.weight_reputation} min="0" /></label>
          <label>Reputation cap<input type="number" bind:value={config.cap_reputation} min="0" /></label>
          <label>Recency max<input type="number" bind:value={config.recency_max} min="0" /></label>
        </div>
        <p class="help">
          Each user earns <code>min(activity_count × weight, cap)</code> per category.
          Recency earns <code>max(0, recency_max − days_inactive)</code>. Total score is capped at 100.
        </p>
      </div>

      <div class="config-section">
        <h3>Tier Thresholds</h3>
        <div class="config-grid grid-3">
          <label><span class="tier-label" style:color={tierColors.power_user}>Power User ≥</span><input type="number" bind:value={config.tier_power} min="0" max="100" /></label>
          <label><span class="tier-label" style:color={tierColors.active}>Active ≥</span><input type="number" bind:value={config.tier_active} min="0" max="100" /></label>
          <label><span class="tier-label" style:color={tierColors.casual}>Casual ≥</span><input type="number" bind:value={config.tier_casual} min="0" max="100" /></label>
        </div>
        <p class="help">Users below the Casual threshold are classified as Lurker (score &gt; 0) or Inactive (score = 0).</p>
      </div>

      <div class="config-actions">
        {#if saveMessage}<span class="save-msg">{saveMessage}</span>{/if}
        <button class="btn-secondary" onclick={resetDefaults} disabled={saving}>Reset Defaults</button>
        <button class="btn-primary" onclick={saveConfig} disabled={saving}>{saving ? 'Saving...' : 'Save & Recalculate'}</button>
      </div>
    </div>
  {/if}

  {#if loading}
    <p class="loading">Loading...</p>
  {:else}
    <div class="tier-summary">
      {#each ['power_user', 'active', 'casual', 'lurker', 'inactive'] as tier}
        {@const count = users.filter(u => u.tier === tier).length}
        <div class="tier-chip" style:border-color={tierColors[tier]}>
          <span class="tier-dot" style:background={tierColors[tier]}></span>
          <span>{tierLabels[tier]}</span>
          <strong>{count}</strong>
        </div>
      {/each}
    </div>

    <table class="admin-table">
      <thead><tr><th>#</th><th>User</th><th>Score</th><th>Tier</th><th>Posts (30d)</th><th>Threads (30d)</th><th>Inactive</th></tr></thead>
      <tbody>
        {#each users as u, i}
          <tr>
            <td>{i + 1}</td>
            <td class="name-cell"><a href="/admin/users/{u.id}">{u.username}</a></td>
            <td><strong>{u.engagement_score}</strong></td>
            <td><span class="tier-badge" style:color={tierColors[u.tier]} style:background="{tierColors[u.tier]}15">{tierLabels[u.tier]}</span></td>
            <td>{u.recent_posts}</td>
            <td>{u.recent_threads}</td>
            <td>{u.days_inactive}d</td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}
</div>

<style>
  .admin-page { max-width: 900px; }
  h1 { font-size: 20px; font-weight: 800; margin-bottom: 4px; }
  .subtitle { font-size: 12px; color: var(--text-muted); margin-bottom: 16px; }
  .tier-summary { display: flex; gap: 10px; margin-bottom: 16px; flex-wrap: wrap; }
  .tier-chip { display: flex; align-items: center; gap: 6px; padding: 6px 12px; background: var(--bg-card); border: 1px solid; border-radius: var(--radius-lg); font-size: 12px; }
  .tier-dot { width: 8px; height: 8px; border-radius: 50%; }
  .admin-table { width: 100%; border-collapse: collapse; }
  .admin-table th { text-align: left; padding: 8px 10px; font-size: 11px; text-transform: uppercase; color: var(--text-muted); border-bottom: 1px solid var(--border-color); }
  .admin-table td { padding: 8px 10px; border-bottom: 1px solid rgba(255,255,255,0.03); font-size: 13px; }
  .name-cell a { color: var(--accent); text-decoration: none; font-weight: 600; }
  .tier-badge { font-size: 10px; padding: 2px 8px; border-radius: 10px; font-weight: 600; }
  .loading { text-align: center; color: var(--text-muted); padding: 40px; }

  .header-row { display: flex; justify-content: space-between; align-items: flex-start; gap: 16px; margin-bottom: 16px; }
  .btn-config { padding: 8px 16px; border-radius: var(--radius); background: var(--bg-secondary); border: 1px solid var(--border-color); color: var(--text-primary); font-family: inherit; font-size: 13px; font-weight: 600; cursor: pointer; }
  .btn-config:hover { background: var(--bg-hover); }

  .config-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 20px; margin-bottom: 20px; }
  .config-header { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 12px; flex-wrap: wrap; gap: 8px; }
  .config-header h2 { font-size: 14px; font-weight: 700; }
  .config-sub { font-size: 11px; color: var(--text-muted); }
  .config-sub strong { color: var(--accent); font-variant-numeric: tabular-nums; }

  .config-section { margin-bottom: 16px; }
  .config-section h3 { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; color: var(--text-muted); margin: 12px 0 8px; }
  .config-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; }
  .config-grid.grid-3 { grid-template-columns: repeat(3, 1fr); }
  .config-grid.grid-4 { grid-template-columns: repeat(4, 1fr); }
  .config-grid label { display: flex; flex-direction: column; gap: 4px; font-size: 11px; font-weight: 600; color: var(--text-secondary); }
  .config-grid input { padding: 6px 8px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: ui-monospace, monospace; font-size: 13px; }
  .tier-label { display: block; }
  .help { font-size: 11px; color: var(--text-muted); margin-top: 6px; line-height: 1.5; }
  .help code { background: var(--bg-primary); padding: 1px 4px; border-radius: 3px; font-family: ui-monospace, monospace; }

  .config-actions { display: flex; gap: 8px; justify-content: flex-end; align-items: center; padding-top: 12px; border-top: 1px solid var(--border-color); }
  .save-msg { font-size: 12px; color: var(--text-secondary); margin-right: auto; }
  .btn-primary { padding: 8px 16px; border-radius: var(--radius); background: var(--accent); color: var(--bg-primary); border: none; font-family: inherit; font-size: 13px; font-weight: 600; cursor: pointer; }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-secondary { padding: 8px 16px; border-radius: var(--radius); background: var(--bg-secondary); color: var(--text-secondary); border: 1px solid var(--border-color); font-family: inherit; font-size: 13px; cursor: pointer; }

  @media (max-width: 768px) {
    .config-grid, .config-grid.grid-3, .config-grid.grid-4 { grid-template-columns: 1fr 1fr; }
  }
</style>
