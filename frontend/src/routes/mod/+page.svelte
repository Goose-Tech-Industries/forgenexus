<script lang="ts">
  import { moderation } from '$lib/stores/moderation.svelte';

  let loaded = $state(false);

  $effect(() => {
    if (!loaded) {
      moderation.loadReports({ status: 'open' });
      moderation.loadBans({ active_only: 'true' });
      moderation.loadModLogs();
      moderation.loadWorkload();
      moderation.loadQueueStats();
      loaded = true;
    }
  });

  function formatWait(seconds: number): string {
    if (seconds < 3600) return `${Math.round(seconds / 60)}m`;
    if (seconds < 86400) return `${Math.round(seconds / 3600)}h`;
    return `${Math.round(seconds / 86400)}d`;
  }

  function timeAgo(dateStr: string | null): string {
    if (!dateStr) return 'N/A';
    const diff = Date.now() - new Date(dateStr).getTime();
    const hours = Math.round(diff / 3600000);
    if (hours < 1) return 'just now';
    if (hours < 24) return `${hours}h ago`;
    return `${Math.round(hours / 24)}d ago`;
  }
</script>

<div class="mod-dashboard">
  <h1>Moderation Dashboard</h1>

  <div class="stats-grid">
    <div class="stat-card">
      <div class="stat-value">{moderation.reportCounts['open'] ?? 0}</div>
      <div class="stat-label">Open Reports</div>
    </div>
    <div class="stat-card">
      <div class="stat-value">{moderation.reportCounts['assigned'] ?? 0}</div>
      <div class="stat-label">Assigned</div>
    </div>
    <div class="stat-card">
      <div class="stat-value">{moderation.reportCounts['resolved'] ?? 0}</div>
      <div class="stat-label">Resolved</div>
    </div>
    <div class="stat-card">
      <div class="stat-value">{moderation.bans.filter(b => b.is_active).length}</div>
      <div class="stat-label">Active Bans</div>
    </div>
  </div>

  {#if moderation.queueStats || moderation.workload}
    <div class="health-grid">
      {#if moderation.queueStats}
        <section class="dashboard-section">
          <h2>Queue Health</h2>
          <div class="health-stats">
            <div class="health-item">
              <span class="health-label">Open reports</span>
              <span class="health-value">{moderation.queueStats.open_count}</span>
            </div>
            <div class="health-item">
              <span class="health-label">Avg wait</span>
              <span class="health-value">{formatWait(moderation.queueStats.avg_wait_seconds)}</span>
            </div>
            <div class="health-item">
              <span class="health-label">Oldest report</span>
              <span class="health-value">{timeAgo(moderation.queueStats.oldest_report_at)}</span>
            </div>
            <div class="health-item">
              <span class="health-label">Pending appeals</span>
              <span class="health-value">{moderation.queueStats.pending_appeals}</span>
            </div>
          </div>
        </section>
      {/if}

      {#if moderation.workload}
        <section class="dashboard-section">
          <h2>Your Workload</h2>
          <div class="health-stats">
            <div class="health-item">
              <span class="health-label">Assigned to you</span>
              <span class="health-value">{moderation.workload.assigned_reports}</span>
            </div>
            <div class="health-item">
              <span class="health-label">Actions (30d)</span>
              <span class="health-value">{moderation.workload.actions_30d}</span>
            </div>
            <div class="health-item">
              <span class="health-label">Resolved (30d)</span>
              <span class="health-value">{moderation.workload.resolved_30d}</span>
            </div>
          </div>
        </section>
      {/if}
    </div>
  {/if}

  <div class="dashboard-grid">
    <section class="dashboard-section">
      <h2>Recent Reports</h2>
      {#if moderation.reports.length === 0}
        <p class="empty">No open reports</p>
      {:else}
        {#each moderation.reports.slice(0, 5) as report}
          <div class="item-row">
            <span class="badge badge-{report.reason}">{report.reason}</span>
            <span class="item-type">{report.reportable_type}</span>
            <span class="item-meta">by {report.reporter.username}</span>
            <a href="/mod/reports" class="item-link">View</a>
          </div>
        {/each}
      {/if}
    </section>

    <section class="dashboard-section">
      <h2>Recent Activity</h2>
      {#if moderation.modLogs.length === 0}
        <p class="empty">No recent activity</p>
      {:else}
        {#each moderation.modLogs.slice(0, 5) as log}
          <div class="item-row">
            <span class="badge">{log.action}</span>
            <span class="item-type">{log.target_type}</span>
            <span class="item-meta">by {log.moderator.username}</span>
            <span class="item-time">{new Date(log.inserted_at).toLocaleDateString()}</span>
          </div>
        {/each}
      {/if}
    </section>
  </div>
</div>

<style>
  .mod-dashboard h1 {
    font-size: 20px;
    font-weight: 700;
    color: var(--text-primary);
    margin-bottom: 16px;
  }

  .stats-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 12px;
    margin-bottom: 16px;
  }

  .stat-card {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 16px;
    text-align: center;
  }

  .stat-value {
    font-size: 28px;
    font-weight: 800;
    color: var(--accent);
  }

  .stat-label {
    font-size: 12px;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
    margin-top: 4px;
  }

  .health-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
    margin-bottom: 16px;
  }

  .health-stats {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .health-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 6px 0;
    border-bottom: 1px solid var(--border-color);
    font-size: 13px;
  }
  .health-item:last-child { border-bottom: none; }

  .health-label { color: var(--text-secondary); }
  .health-value { color: var(--text-primary); font-weight: 600; }

  .dashboard-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
  }

  .dashboard-section {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 16px;
  }

  .dashboard-section h2 {
    font-size: 14px;
    font-weight: 700;
    color: var(--text-primary);
    margin-bottom: 12px;
    padding-bottom: 8px;
    border-bottom: 1px solid var(--border-color);
  }

  .item-row {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 0;
    font-size: 13px;
    border-bottom: 1px solid var(--border-color);
  }
  .item-row:last-child { border-bottom: none; }

  .badge {
    display: inline-block;
    padding: 2px 8px;
    border-radius: 10px;
    font-size: 11px;
    font-weight: 600;
    background: var(--bg-tertiary);
    color: var(--text-secondary);
  }
  .badge-spam { background: #dc262633; color: #f87171; }
  .badge-harassment { background: #ea580c33; color: #fb923c; }
  .badge-inappropriate { background: #d9770633; color: #fbbf24; }

  .item-type { color: var(--text-secondary); }
  .item-meta { color: var(--text-muted); margin-left: auto; }
  .item-link { color: var(--accent); text-decoration: none; font-weight: 600; }
  .item-time { color: var(--text-muted); font-size: 11px; }
  .empty { color: var(--text-muted); font-size: 13px; padding: 12px 0; }

  @media (max-width: 768px) {
    .stats-grid { grid-template-columns: repeat(2, 1fr); }
    .health-grid { grid-template-columns: 1fr; }
    .dashboard-grid { grid-template-columns: 1fr; }
  }
</style>
