<script lang="ts">
  import { moderation } from '$lib/stores/moderation.svelte';
  import { auth } from '$lib/stores/auth.svelte';

  let loaded = $state(false);
  let statusFilter = $state('open');
  let actionReportId = $state<string | null>(null);
  let resolutionNote = $state('');

  $effect(() => {
    if (!loaded) {
      moderation.loadReports({ status: statusFilter });
      loaded = true;
    }
  });

  async function filterByStatus(status: string) {
    statusFilter = status;
    await moderation.loadReports({ status });
  }

  async function claimReport(id: string) {
    await moderation.assignReport(id);
  }

  async function resolveReport(id: string) {
    await moderation.resolveReport(id, resolutionNote);
    actionReportId = null;
    resolutionNote = '';
  }

  async function dismissReport(id: string) {
    await moderation.dismissReport(id, resolutionNote);
    actionReportId = null;
    resolutionNote = '';
  }
</script>

<div class="reports-page">
  <h1>Report Queue</h1>

  <div class="filter-bar">
    {#each ['open', 'assigned', 'resolved', 'dismissed'] as status}
      <button
        class="filter-btn"
        class:active={statusFilter === status}
        onclick={() => filterByStatus(status)}
      >
        {status}
        {#if moderation.reportCounts[status]}
          <span class="count">{moderation.reportCounts[status]}</span>
        {/if}
      </button>
    {/each}
  </div>

  {#if moderation.loading}
    <p class="loading">Loading reports...</p>
  {:else if moderation.reports.length === 0}
    <p class="empty">No {statusFilter} reports</p>
  {:else}
    <div class="report-list">
      {#each moderation.reports as report}
        <div class="report-card">
          <div class="report-header">
            <span class="badge badge-{report.reason}">{report.reason}</span>
            <span class="report-type">{report.reportable_type} report</span>
            {#if report.priority > 0}
              <span class="priority">P{report.priority}</span>
            {/if}
            <span class="report-time">{new Date(report.inserted_at).toLocaleString()}</span>
          </div>

          {#if report.description}
            <p class="report-description">{report.description}</p>
          {/if}

          <div class="report-meta">
            <span>Reported by <strong>{report.reporter.username}</strong></span>
            {#if report.assigned_to}
              <span>Assigned to <strong>{report.assigned_to.username}</strong></span>
            {/if}
            {#if report.resolver}
              <span>{report.status} by <strong>{report.resolver.username}</strong></span>
            {/if}
          </div>

          {#if report.status === 'open' || report.status === 'assigned'}
            <div class="report-actions">
              {#if !report.assigned_to}
                <button class="btn btn-sm" onclick={() => claimReport(report.id)}>Claim</button>
              {/if}

              {#if actionReportId === report.id}
                <div class="action-form">
                  <textarea
                    bind:value={resolutionNote}
                    placeholder="Resolution note (optional)"
                    rows="2"
                  ></textarea>
                  <div class="action-buttons">
                    <button class="btn btn-sm btn-success" onclick={() => resolveReport(report.id)}>Resolve</button>
                    <button class="btn btn-sm btn-danger" onclick={() => dismissReport(report.id)}>Dismiss</button>
                    <button class="btn btn-sm" onclick={() => { actionReportId = null; }}>Cancel</button>
                  </div>
                </div>
              {:else}
                <button class="btn btn-sm btn-primary" onclick={() => { actionReportId = report.id; }}>Take Action</button>
              {/if}
            </div>
          {/if}

          {#if report.resolution_note}
            <div class="resolution-note">
              <strong>Resolution:</strong> {report.resolution_note}
            </div>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .reports-page h1 {
    font-size: 20px;
    font-weight: 700;
    color: var(--text-primary);
    margin-bottom: 16px;
  }

  .filter-bar {
    display: flex;
    gap: 4px;
    margin-bottom: 16px;
  }

  .filter-btn {
    padding: 6px 14px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-card);
    color: var(--text-secondary);
    font-size: 13px;
    cursor: pointer;
    text-transform: capitalize;
  }
  .filter-btn:hover { background: var(--bg-hover); }
  .filter-btn.active {
    background: var(--accent);
    color: white;
    border-color: var(--accent);
  }
  .count {
    display: inline-block;
    background: rgba(255,255,255,0.2);
    padding: 0 6px;
    border-radius: 8px;
    font-size: 11px;
    margin-left: 4px;
  }

  .report-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .report-card {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 14px;
  }

  .report-header {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 8px;
  }

  .badge {
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
  .badge-off_topic { background: #2563eb33; color: #60a5fa; }
  .badge-other { background: var(--bg-tertiary); color: var(--text-muted); }

  .report-type { font-size: 13px; color: var(--text-secondary); }
  .priority { font-size: 11px; font-weight: 700; color: #f87171; }
  .report-time { font-size: 11px; color: var(--text-muted); margin-left: auto; }

  .report-description {
    font-size: 13px;
    color: var(--text-secondary);
    margin-bottom: 8px;
    line-height: 1.4;
  }

  .report-meta {
    display: flex;
    gap: 16px;
    font-size: 12px;
    color: var(--text-muted);
    margin-bottom: 8px;
  }
  .report-meta strong { color: var(--text-secondary); }

  .report-actions {
    display: flex;
    align-items: flex-start;
    gap: 8px;
    padding-top: 8px;
    border-top: 1px solid var(--border-color);
  }

  .action-form {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .action-form textarea {
    width: 100%;
    padding: 8px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-input);
    color: var(--text-primary);
    font-size: 13px;
    resize: vertical;
  }

  .action-buttons {
    display: flex;
    gap: 6px;
  }

  .btn {
    padding: 6px 12px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-card);
    color: var(--text-secondary);
    font-size: 12px;
    cursor: pointer;
  }
  .btn:hover { background: var(--bg-hover); }
  .btn-sm { padding: 4px 10px; font-size: 11px; }
  .btn-primary { background: var(--accent); color: white; border-color: var(--accent); }
  .btn-success { background: #16a34a; color: white; border-color: #16a34a; }
  .btn-danger { background: #dc2626; color: white; border-color: #dc2626; }

  .resolution-note {
    margin-top: 8px;
    padding: 8px;
    background: var(--bg-tertiary);
    border-radius: var(--radius);
    font-size: 12px;
    color: var(--text-secondary);
  }

  .loading, .empty {
    color: var(--text-muted);
    font-size: 13px;
    padding: 24px 0;
    text-align: center;
  }
</style>
