<script lang="ts">
  import { api } from '$lib/api/client';

  interface UserSummary { id: string; username: string }

  interface QuarantineRecord {
    id: string;
    user_id: string;
    user: UserSummary | null;
    quarantined_by_id: string | null;
    quarantined_by: UserSummary | null;
    original_group_ids: string[];
    reason: string | null;
    quarantined_at: string;
    released_at: string | null;
    is_active: boolean;
  }

  let records = $state<QuarantineRecord[]>([]);
  let loading = $state(true);
  let error = $state('');
  let activeOnly = $state(true);

  let showQuarantine = $state(false);
  let quarantineUserId = $state('');
  let quarantineReason = $state('');
  let quarantining = $state(false);
  let formError = $state('');

  $effect(() => { load(); });

  async function load() {
    loading = true;
    error = '';
    try {
      const data = await api.getQuarantineRecords(activeOnly);
      records = data.records || [];
    } catch (err: any) {
      error = err?.error || 'Failed to load quarantine records.';
    }
    loading = false;
  }

  async function handleQuarantine() {
    formError = '';
    if (!quarantineUserId.trim()) { formError = 'User ID is required.'; return; }
    quarantining = true;
    try {
      await api.quarantineUser(quarantineUserId.trim(), quarantineReason);
      showQuarantine = false;
      quarantineUserId = '';
      quarantineReason = '';
      await load();
    } catch (err: any) {
      formError = err?.error || 'Failed to quarantine user.';
    }
    quarantining = false;
  }

  async function handleRelease(r: QuarantineRecord) {
    if (!confirm(`Release ${r.user?.username || r.user_id} from quarantine?`)) return;
    try {
      await api.releaseQuarantine(r.user_id);
      await load();
    } catch (err: any) {
      alert('Failed to release: ' + (err?.error || 'unknown error'));
    }
  }

  function formatDate(d: string | null) {
    if (!d) return '—';
    return new Date(d).toLocaleString();
  }
</script>

<div class="admin-page">
  <div class="page-header">
    <div>
      <h1>Quarantine</h1>
      <p class="page-sub">Restrict a user's account pending moderator review. Original group memberships are captured and restored on release.</p>
    </div>
    <button class="btn-primary" onclick={() => { showQuarantine = true; formError = ''; }}>Quarantine User</button>
  </div>

  <div class="filters">
    <label class="checkbox">
      <input type="checkbox" bind:checked={activeOnly} onchange={load} /> Show active only
    </label>
    <span class="count">{records.length} record{records.length === 1 ? '' : 's'}</span>
  </div>

  {#if showQuarantine}
    <div class="form-card">
      <h3>Quarantine User</h3>
      <label>User ID
        <input type="text" bind:value={quarantineUserId} placeholder="UUID of the user to quarantine" />
      </label>
      <label>Reason
        <textarea bind:value={quarantineReason} rows="3" placeholder="Why is this user being quarantined?"></textarea>
      </label>
      {#if formError}<div class="form-error">{formError}</div>{/if}
      <div class="form-actions">
        <button onclick={() => { showQuarantine = false; }}>Cancel</button>
        <button class="btn-primary" onclick={handleQuarantine} disabled={quarantining || !quarantineUserId.trim()}>
          {quarantining ? 'Quarantining...' : 'Quarantine'}
        </button>
      </div>
    </div>
  {/if}

  {#if loading}
    <p class="loading">Loading...</p>
  {:else if error}
    <div class="error-banner">{error}</div>
  {:else if records.length === 0}
    <p class="empty">{activeOnly ? 'No active quarantines.' : 'No quarantine history.'}</p>
  {:else}
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>User</th>
            <th>Quarantined At</th>
            <th>By</th>
            <th>Reason</th>
            <th>Status</th>
            <th>Released</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each records as r (r.id)}
            <tr class:released={!r.is_active}>
              <td>
                {#if r.user}
                  <a href="/admin/users/{r.user.id}">{r.user.username}</a>
                {:else}
                  <code class="muted">{r.user_id.slice(0, 8)}…</code>
                {/if}
              </td>
              <td>{formatDate(r.quarantined_at)}</td>
              <td>{r.quarantined_by?.username ?? 'system'}</td>
              <td class="reason-cell">{r.reason || '—'}</td>
              <td>
                <span class="status" class:active={r.is_active} class:released={!r.is_active}>
                  {r.is_active ? 'Active' : 'Released'}
                </span>
              </td>
              <td>{formatDate(r.released_at)}</td>
              <td>
                {#if r.is_active}
                  <button class="btn-sm" onclick={() => handleRelease(r)}>Release</button>
                {:else}
                  —
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
  .filters { display: flex; align-items: center; gap: 16px; margin-bottom: 12px; }
  .checkbox { display: flex; align-items: center; gap: 6px; font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  .count { font-size: 11px; color: var(--text-muted); }

  .form-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 20px; margin-bottom: 16px; }
  .form-card h3 { font-size: 15px; font-weight: 700; margin-bottom: 12px; }
  .form-card label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; font-weight: 600; color: var(--text-secondary); margin-bottom: 10px; }
  .form-card input, .form-card textarea { padding: 8px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: inherit; font-size: 13px; resize: vertical; }
  .form-error { padding: 10px; background: rgba(248,113,113,0.1); border: 1px solid rgba(248,113,113,0.3); border-radius: var(--radius); color: #f87171; font-size: 12px; margin-bottom: 10px; }
  .form-actions { display: flex; gap: 8px; justify-content: flex-end; }
  .form-actions button { padding: 8px 16px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; font-size: 13px; }
  .form-actions button.btn-primary { border: none; color: var(--bg-primary); background: var(--accent); }

  .table-wrap { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); overflow: auto; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  th { text-align: left; padding: 10px 12px; background: var(--bg-primary); color: var(--text-muted); font-size: 11px; text-transform: uppercase; letter-spacing: 0.05em; border-bottom: 1px solid var(--border-color); font-weight: 700; }
  td { padding: 10px 12px; border-bottom: 1px solid var(--border-color); vertical-align: middle; }
  tr.released td { color: var(--text-muted); }
  .reason-cell { max-width: 300px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .status { display: inline-block; padding: 2px 8px; font-size: 10px; font-weight: 700; border-radius: 10px; text-transform: uppercase; letter-spacing: 0.05em; }
  .status.active { background: rgba(248,113,113,0.15); color: #f87171; }
  .status.released { background: rgba(52,211,153,0.15); color: #34d399; }
  .muted { color: var(--text-muted); }
  a { color: var(--accent); }
  .btn-sm { padding: 4px 10px; font-size: 11px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; }
  .btn-sm:hover { background: var(--bg-hover); color: var(--text-primary); }

  .loading, .empty { text-align: center; color: var(--text-muted); padding: 30px; }
  .error-banner { padding: 12px; background: rgba(248,113,113,0.1); border: 1px solid rgba(248,113,113,0.3); border-radius: var(--radius); color: #f87171; }
</style>
