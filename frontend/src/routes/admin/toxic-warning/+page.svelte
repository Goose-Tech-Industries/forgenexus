<script lang="ts">
  import { api } from '$lib/api/client';
  let users = $state<any[]>([]);
  let loading = $state(true);

  $effect(() => { load(); });
  async function load() {
    loading = true;
    try { const data = await api.getToxicWarning(); users = data.users || []; } catch {}
    loading = false;
  }

  const riskColors: Record<string, string> = { critical: '#ef4444', high: '#f97316', medium: '#fbbf24', low: '#94a3b8' };
</script>

<div class="admin-page">
  <h1>Toxic User Early Warning</h1>
  <p class="subtitle">Users trending toward disciplinary action based on report frequency and warning velocity.</p>

  {#if loading}
    <p class="loading">Loading...</p>
  {:else if users.length === 0}
    <div class="all-clear">
      <div class="clear-icon">&#9989;</div>
      <h3>All Clear</h3>
      <p>No users flagged in the last 30 days.</p>
    </div>
  {:else}
    <div class="warning-list">
      {#each users as u}
        <div class="warning-card" style:border-left-color={riskColors[u.risk_level]}>
          <div class="warning-header">
            <span class="risk-badge" style:background="{riskColors[u.risk_level]}20" style:color={riskColors[u.risk_level]}>
              {u.risk_level.toUpperCase()}
            </span>
            <a href="/admin/users/{u.user_id}" class="warning-user">{u.username}</a>
            {#if u.has_active_ban}
              <span class="ban-badge">BANNED</span>
            {/if}
            <span class="toxicity-score">Score: {u.toxicity_score}</span>
          </div>
          <div class="warning-stats">
            <span>{u.report_count} reports (30d)</span>
            <span>{u.warning_count} warnings (30d)</span>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .admin-page { max-width: 800px; }
  h1 { font-size: 20px; font-weight: 800; margin-bottom: 4px; }
  .subtitle { font-size: 12px; color: var(--text-muted); margin-bottom: 20px; }
  .all-clear { text-align: center; padding: 60px; color: var(--text-muted); }
  .clear-icon { font-size: 48px; margin-bottom: 12px; }
  .all-clear h3 { font-size: 16px; color: var(--text-primary); margin-bottom: 4px; }
  .warning-list { display: flex; flex-direction: column; gap: 10px; }
  .warning-card { background: var(--bg-card); border: 1px solid var(--border-color); border-left: 4px solid; border-radius: var(--radius-lg); padding: 14px 16px; }
  .warning-header { display: flex; align-items: center; gap: 10px; margin-bottom: 6px; }
  .risk-badge { font-size: 10px; font-weight: 700; padding: 2px 8px; border-radius: 3px; letter-spacing: 0.03em; }
  .warning-user { font-weight: 700; font-size: 14px; color: var(--accent); text-decoration: none; }
  .ban-badge { font-size: 9px; font-weight: 700; padding: 2px 6px; border-radius: 3px; background: rgba(239,68,68,0.15); color: #ef4444; }
  .toxicity-score { margin-left: auto; font-size: 12px; color: var(--text-muted); }
  .warning-stats { display: flex; gap: 16px; font-size: 12px; color: var(--text-muted); }
  .loading { text-align: center; color: var(--text-muted); padding: 40px; }
</style>
