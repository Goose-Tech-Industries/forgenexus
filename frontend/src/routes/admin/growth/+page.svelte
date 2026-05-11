<script lang="ts">
  import { api } from '$lib/api/client';
  let forecast = $state<any>(null);
  let loading = $state(true);

  $effect(() => { load(); });
  async function load() {
    loading = true;
    try { const data = await api.getGrowthForecast(); forecast = data.forecast; } catch {}
    loading = false;
  }

  const trendIcons: Record<string, string> = { growing: '\u{1F4C8}', declining: '\u{1F4C9}', stable: '\u{2796}' };
</script>

<div class="admin-page">
  <h1>Growth Forecasting</h1>

  {#if loading}
    <p class="loading">Loading...</p>
  {:else if forecast}
    <div class="forecast-cards">
      <div class="fc-card">
        <div class="fc-label">Total Users</div>
        <div class="fc-value">{forecast.total_users}</div>
        <div class="fc-trend">{trendIcons[forecast.trend]} {forecast.trend}</div>
      </div>
      <div class="fc-card">
        <div class="fc-label">Total Posts</div>
        <div class="fc-value">{forecast.total_posts}</div>
      </div>
      <div class="fc-card accent">
        <div class="fc-label">Projected Users (90d)</div>
        <div class="fc-value">+{forecast.projections.registrations_90d}</div>
      </div>
      <div class="fc-card accent">
        <div class="fc-label">Projected Posts (90d)</div>
        <div class="fc-value">+{forecast.projections.posts_90d}</div>
      </div>
    </div>

    <h3>Projections</h3>
    <table class="admin-table">
      <thead><tr><th></th><th>30 Days</th><th>60 Days</th><th>90 Days</th></tr></thead>
      <tbody>
        <tr><td>New Users</td><td>+{forecast.projections.registrations_30d}</td><td>+{forecast.projections.registrations_60d}</td><td>+{forecast.projections.registrations_90d}</td></tr>
        <tr><td>New Posts</td><td>+{forecast.projections.posts_30d}</td><td>+{forecast.projections.posts_60d}</td><td>+{forecast.projections.posts_90d}</td></tr>
      </tbody>
    </table>

    <h3>Weekly Activity (12 weeks)</h3>
    <div class="weekly-chart">
      {#each forecast.weekly_data as week}
        <div class="week-bar">
          <div class="bar-fill" style:height="{Math.min(week.posts / (Math.max(...forecast.weekly_data.map((w: any) => w.posts), 1)) * 100, 100)}%"></div>
          <span class="week-label">W{week.week}</span>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .admin-page { max-width: 800px; }
  h1 { font-size: 20px; font-weight: 800; margin-bottom: 16px; }
  h3 { font-size: 14px; font-weight: 700; margin: 24px 0 12px; }
  .forecast-cards { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 20px; }
  .fc-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; text-align: center; }
  .fc-card.accent { border-color: var(--accent); }
  .fc-label { font-size: 11px; color: var(--text-muted); text-transform: uppercase; font-weight: 600; margin-bottom: 4px; }
  .fc-value { font-size: 24px; font-weight: 800; }
  .fc-card.accent .fc-value { color: var(--accent); }
  .fc-trend { font-size: 12px; color: var(--text-muted); margin-top: 4px; text-transform: capitalize; }
  .admin-table { width: 100%; border-collapse: collapse; }
  .admin-table th, .admin-table td { padding: 8px 12px; text-align: left; border-bottom: 1px solid var(--border-color); font-size: 13px; }
  .admin-table th { font-size: 11px; text-transform: uppercase; color: var(--text-muted); }
  .weekly-chart { display: flex; gap: 4px; align-items: flex-end; height: 120px; padding: 12px; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); }
  .week-bar { flex: 1; display: flex; flex-direction: column; align-items: center; height: 100%; justify-content: flex-end; }
  .bar-fill { width: 100%; background: var(--accent); border-radius: 3px 3px 0 0; min-height: 2px; transition: height 0.3s; }
  .week-label { font-size: 9px; color: var(--text-muted); margin-top: 4px; }
  .loading { text-align: center; color: var(--text-muted); padding: 40px; }
</style>
