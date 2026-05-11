<script lang="ts">
  import { api } from '$lib/api/client';
  let staff = $state<any[]>([]);
  let loading = $state(true);
  let days = $state(30);

  $effect(() => { load(); });

  async function load() {
    loading = true;
    try { const data = await api.getStaffPerformance(days); staff = data.staff || []; } catch {}
    loading = false;
  }
</script>

<div class="admin-page">
  <div class="page-header">
    <h1>Staff Performance</h1>
    <select bind:value={days} onchange={load}>
      <option value={7}>Last 7 days</option>
      <option value={30}>Last 30 days</option>
      <option value={90}>Last 90 days</option>
    </select>
  </div>

  {#if loading}
    <p class="loading">Loading...</p>
  {:else if staff.length === 0}
    <p class="empty">No staff activity found.</p>
  {:else}
    <div class="staff-grid">
      {#each staff as s, i}
        <div class="staff-card" class:top={i === 0}>
          <div class="staff-rank">#{i + 1}</div>
          <div class="staff-info">
            <div class="staff-name">{s.username}</div>
            <div class="staff-score">Score: {s.efficiency_score}</div>
          </div>
          <div class="staff-stats">
            <div class="stat"><span class="stat-val">{s.reports_resolved}</span><span class="stat-label">Reports</span></div>
            <div class="stat"><span class="stat-val">{s.mod_actions}</span><span class="stat-label">Actions</span></div>
            <div class="stat"><span class="stat-val">{s.bans_issued}</span><span class="stat-label">Bans</span></div>
            <div class="stat"><span class="stat-val">{s.avg_response_minutes ? s.avg_response_minutes + 'm' : '—'}</span><span class="stat-label">Avg Response</span></div>
          </div>
          {#if s.active_hours.length > 0}
            <div class="active-hours">Most active: {s.active_hours.map((h: any) => `${h.hour}:00`).join(', ')}</div>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .admin-page { max-width: 900px; }
  .page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
  .page-header h1 { font-size: 20px; font-weight: 800; }
  .page-header select { padding: 6px 10px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: inherit; }
  .staff-grid { display: flex; flex-direction: column; gap: 10px; }
  .staff-card { display: flex; align-items: center; gap: 16px; padding: 16px; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); }
  .staff-card.top { border-color: var(--accent); background: rgba(0,212,170,0.03); }
  .staff-rank { font-size: 20px; font-weight: 800; color: var(--text-muted); width: 36px; text-align: center; }
  .staff-card.top .staff-rank { color: var(--accent); }
  .staff-info { min-width: 120px; }
  .staff-name { font-weight: 700; font-size: 14px; }
  .staff-score { font-size: 11px; color: var(--text-muted); }
  .staff-stats { display: flex; gap: 16px; flex: 1; }
  .stat { text-align: center; }
  .stat-val { display: block; font-size: 18px; font-weight: 700; color: var(--text-primary); }
  .stat-label { font-size: 10px; color: var(--text-muted); text-transform: uppercase; }
  .active-hours { font-size: 11px; color: var(--text-muted); }
  .loading, .empty { text-align: center; color: var(--text-muted); padding: 40px; }
</style>
