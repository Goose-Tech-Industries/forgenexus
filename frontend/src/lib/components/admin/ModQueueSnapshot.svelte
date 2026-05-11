<script lang="ts">
  let { queue }: {
    queue: {
      open_reports: number;
      pending_appeals: number;
      oldest_report_age_minutes: number | null;
      assigned_unresolved: number;
    } | null;
  } = $props();

  function formatAge(minutes: number | null): string {
    if (minutes == null) return 'None';
    if (minutes < 60) return `${minutes}m`;
    if (minutes < 1440) return `${Math.floor(minutes / 60)}h ${minutes % 60}m`;
    return `${Math.floor(minutes / 1440)}d ${Math.floor((minutes % 1440) / 60)}h`;
  }

  let urgency = $derived.by(() => {
    if (!queue) return 'none';
    if (queue.open_reports > 10 || (queue.oldest_report_age_minutes ?? 0) > 480) return 'critical';
    if (queue.open_reports > 5 || (queue.oldest_report_age_minutes ?? 0) > 240) return 'warning';
    return 'ok';
  });
</script>

{#if queue}
  <div class="mod-queue" class:critical={urgency === 'critical'} class:warning={urgency === 'warning'}>
    <div class="mq-header">
      <h3>Mod Queue</h3>
      {#if urgency === 'critical'}
        <span class="urgency-badge critical-badge">NEEDS ATTENTION</span>
      {:else if urgency === 'warning'}
        <span class="urgency-badge warning-badge">BUILDING UP</span>
      {:else}
        <span class="urgency-badge ok-badge">CLEAR</span>
      {/if}
    </div>
    <div class="mq-grid">
      <div class="mq-stat">
        <span class="mq-value" class:highlight={queue.open_reports > 0}>{queue.open_reports}</span>
        <span class="mq-label">Open Reports</span>
      </div>
      <div class="mq-stat">
        <span class="mq-value" class:highlight={queue.pending_appeals > 0}>{queue.pending_appeals}</span>
        <span class="mq-label">Pending Appeals</span>
      </div>
      <div class="mq-stat">
        <span class="mq-value">{formatAge(queue.oldest_report_age_minutes)}</span>
        <span class="mq-label">Oldest Waiting</span>
      </div>
      <div class="mq-stat">
        <span class="mq-value">{queue.assigned_unresolved}</span>
        <span class="mq-label">Assigned / Open</span>
      </div>
    </div>
    <a href="/mod" class="mq-link">Open Mod Panel \u2192</a>
  </div>
{/if}

<style>
  .mod-queue {
    background: var(--bg-card, var(--bg-secondary));
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 16px;
  }
  .mod-queue.warning { border-color: rgba(251, 191, 36, 0.4); }
  .mod-queue.critical { border-color: rgba(248, 113, 113, 0.4); background: rgba(248, 113, 113, 0.03); }

  .mq-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 12px;
  }
  .mq-header h3 {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-secondary);
    text-transform: uppercase;
    letter-spacing: 0.04em;
    margin: 0;
  }

  .urgency-badge {
    font-size: 9px;
    font-weight: 800;
    padding: 2px 8px;
    border-radius: 10px;
    letter-spacing: 0.05em;
  }
  .ok-badge { background: rgba(74, 222, 128, 0.15); color: #4ade80; }
  .warning-badge { background: rgba(251, 191, 36, 0.15); color: #fbbf24; }
  .critical-badge { background: rgba(248, 113, 113, 0.15); color: #f87171; animation: urgent-pulse 1.5s ease-in-out infinite; }
  @keyframes urgent-pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.6; } }

  .mq-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 8px;
    margin-bottom: 10px;
  }

  .mq-stat { text-align: center; }
  .mq-value {
    display: block;
    font-size: 20px;
    font-weight: 800;
    color: var(--text-primary);
    font-variant-numeric: tabular-nums;
  }
  .mq-value.highlight { color: #fbbf24; }
  .mq-label {
    font-size: 10px;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.03em;
  }

  .mq-link {
    display: block;
    text-align: center;
    font-size: 11px;
    font-weight: 600;
    color: var(--accent);
    text-decoration: none;
    padding: 6px;
    border-top: 1px solid var(--border-color);
    margin-top: 4px;
  }
  .mq-link:hover { opacity: 0.8; }

  @media (max-width: 640px) {
    .mq-grid { grid-template-columns: repeat(2, 1fr); }
  }
</style>
