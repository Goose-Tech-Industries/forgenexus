<script lang="ts">
  import { api } from '$lib/api/client';

  interface ImpersonationLog {
    id: string;
    admin_id: string;
    admin_username: string;
    target_user_id: string;
    target_username: string;
    reason: string | null;
    started_at: string;
    ended_at: string | null;
    duration_seconds: number | null;
    is_active: boolean;
  }

  let logs = $state<ImpersonationLog[]>([]);
  let loading = $state(true);
  let error = $state('');
  let active = $state<ImpersonationLog | null>(null);

  let showStart = $state(false);
  let targetUserId = $state('');
  let reason = $state('');
  let startBusy = $state(false);
  let startError = $state('');

  $effect(() => { load(); });

  async function load() {
    loading = true;
    error = '';
    try {
      const [logsData, activeData] = await Promise.all([
        api.getImpersonationLogs({ limit: 100 }),
        api.getActiveImpersonation()
      ]);
      logs = logsData.logs || [];
      active = activeData.impersonation || null;
    } catch (err: any) {
      error = err?.error || 'Failed to load impersonation logs.';
    }
    loading = false;
  }

  async function handleStart() {
    startError = '';
    if (!targetUserId.trim()) { startError = 'Target user ID is required.'; return; }
    if (!reason.trim()) { startError = 'Reason is required for audit trail.'; return; }
    startBusy = true;
    try {
      await api.startImpersonation(targetUserId.trim(), reason.trim());
      showStart = false;
      targetUserId = '';
      reason = '';
      await load();
    } catch (err: any) {
      startError = err?.error || 'Failed to start impersonation.';
    }
    startBusy = false;
  }

  async function handleEnd() {
    if (!confirm('End the active impersonation session?')) return;
    try {
      await api.endImpersonation();
      await load();
    } catch (err: any) {
      alert('Failed to end session: ' + (err?.error || 'unknown error'));
    }
  }

  function formatDate(d: string | null) {
    if (!d) return '—';
    return new Date(d).toLocaleString();
  }

  function formatDuration(seconds: number | null): string {
    if (seconds === null || seconds === undefined) return '—';
    if (seconds < 60) return `${seconds}s`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    return `${h}h ${m}m`;
  }
</script>

<div class="admin-page">
  <div class="page-header">
    <div>
      <h1>Impersonation Audit</h1>
      <p class="page-sub">Historical log of every admin impersonation session. Use sparingly — always leave a reason for the audit trail.</p>
    </div>
    <button class="btn-primary" onclick={() => { showStart = true; startError = ''; }}>Start Session</button>
  </div>

  {#if active}
    <div class="active-banner">
      <div>
        <strong>⚠ Active Session:</strong>
        You are currently impersonating <strong>{active.target_username}</strong>
        {#if active.reason}— "{active.reason}"{/if}
        <span class="since">started {formatDate(active.started_at)}</span>
      </div>
      <button class="btn-danger" onclick={handleEnd}>End Session</button>
    </div>
  {/if}

  {#if showStart}
    <div class="form-card">
      <h3>Start Impersonation Session</h3>
      <label>Target User ID
        <input type="text" bind:value={targetUserId} placeholder="UUID of the user to impersonate" />
      </label>
      <label>Reason (required for audit)
        <textarea bind:value={reason} rows="3" placeholder="Investigating a bug report on their account, with user permission..."></textarea>
      </label>
      {#if startError}<div class="form-error">{startError}</div>{/if}
      <div class="form-actions">
        <button onclick={() => { showStart = false; }}>Cancel</button>
        <button class="btn-primary" onclick={handleStart} disabled={startBusy || !targetUserId.trim() || !reason.trim()}>
          {startBusy ? 'Starting...' : 'Start Session'}
        </button>
      </div>
    </div>
  {/if}

  {#if loading}
    <p class="loading">Loading impersonation logs...</p>
  {:else if error}
    <div class="error-banner">{error}</div>
  {:else if logs.length === 0}
    <p class="empty">No impersonation history.</p>
  {:else}
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Admin</th>
            <th>Impersonated</th>
            <th>Reason</th>
            <th>Started</th>
            <th>Ended</th>
            <th>Duration</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {#each logs as log (log.id)}
            <tr class:active-row={log.is_active}>
              <td>{log.admin_username}</td>
              <td><a href="/admin/users/{log.target_user_id}">{log.target_username}</a></td>
              <td class="reason-cell" title={log.reason || ''}>{log.reason || '—'}</td>
              <td>{formatDate(log.started_at)}</td>
              <td>{formatDate(log.ended_at)}</td>
              <td class="num">{formatDuration(log.duration_seconds)}</td>
              <td>
                {#if log.is_active}
                  <span class="pill active">Active</span>
                {:else}
                  <span class="pill ended">Ended</span>
                {/if}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>

<style>
  .admin-page { max-width: 1100px; }
  .page-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 16px; gap: 16px; }
  .page-header h1 { font-size: 20px; font-weight: 800; }
  .page-sub { font-size: 12px; color: var(--text-muted); margin-top: 2px; max-width: 640px; }
  .btn-primary { background: var(--accent); color: var(--bg-primary); border: none; padding: 8px 16px; border-radius: var(--radius); font-weight: 600; cursor: pointer; font-family: inherit; font-size: 13px; }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-danger { background: rgba(248,113,113,0.15); color: #f87171; border: 1px solid rgba(248,113,113,0.3); padding: 8px 16px; border-radius: var(--radius); font-weight: 600; cursor: pointer; font-family: inherit; font-size: 13px; }

  .active-banner { display: flex; justify-content: space-between; align-items: center; gap: 16px; background: rgba(250,204,21,0.1); border: 1px solid rgba(250,204,21,0.3); border-radius: var(--radius-lg); padding: 12px 16px; margin-bottom: 16px; color: var(--text-primary); font-size: 13px; }
  .active-banner strong { color: #facc15; }
  .since { color: var(--text-muted); font-size: 11px; margin-left: 8px; }

  .form-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 20px; margin-bottom: 16px; }
  .form-card h3 { font-size: 15px; font-weight: 700; margin-bottom: 12px; }
  .form-card label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; font-weight: 600; color: var(--text-secondary); margin-bottom: 10px; }
  .form-card input, .form-card textarea { padding: 8px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: inherit; font-size: 13px; resize: vertical; }
  .form-error { padding: 10px; background: rgba(248,113,113,0.1); border: 1px solid rgba(248,113,113,0.3); border-radius: var(--radius); color: #f87171; font-size: 12px; margin-bottom: 10px; }
  .form-actions { display: flex; gap: 8px; justify-content: flex-end; }
  .form-actions button { padding: 8px 16px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; font-size: 13px; }
  .form-actions button.btn-primary { border: none; color: var(--bg-primary); background: var(--accent); }

  .table-wrap { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); overflow: auto; }
  table { width: 100%; border-collapse: collapse; font-size: 12px; }
  th { text-align: left; padding: 10px 12px; background: var(--bg-primary); color: var(--text-muted); font-size: 10px; text-transform: uppercase; letter-spacing: 0.05em; border-bottom: 1px solid var(--border-color); font-weight: 700; }
  td { padding: 10px 12px; border-bottom: 1px solid var(--border-color); vertical-align: middle; }
  tr.active-row { background: rgba(250,204,21,0.05); }
  .reason-cell { max-width: 280px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: var(--text-secondary); }
  .num { font-variant-numeric: tabular-nums; }
  .pill { display: inline-block; padding: 2px 8px; font-size: 10px; font-weight: 700; border-radius: 10px; text-transform: uppercase; letter-spacing: 0.05em; }
  .pill.active { background: rgba(250,204,21,0.15); color: #facc15; }
  .pill.ended { background: rgba(156,163,175,0.15); color: #9ca3af; }
  a { color: var(--accent); }

  .loading, .empty { text-align: center; color: var(--text-muted); padding: 30px; }
  .error-banner { padding: 12px; background: rgba(248,113,113,0.1); border: 1px solid rgba(248,113,113,0.3); border-radius: var(--radius); color: #f87171; }
</style>
