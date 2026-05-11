<script lang="ts">
  import { api } from '$lib/api/client';

  interface LoginEvent {
    id: string;
    email: string | null;
    ip_address: string | null;
    user_agent: string | null;
    success: boolean;
    failure_reason: string | null;
    user_id: string | null;
    username: string | null;
    occurred_at: string | null;
    inserted_at: string;
  }

  let events = $state<LoginEvent[]>([]);
  let loading = $state(true);
  let error = $state('');

  let emailFilter = $state('');
  let ipFilter = $state('');
  let userIdFilter = $state('');
  let successFilter = $state<'all' | 'success' | 'fail'>('all');
  let hoursFilter = $state<'' | '1' | '24' | '168' | '720'>('');
  let limit = $state(100);

  async function load() {
    loading = true;
    error = '';
    try {
      const params: any = { limit };
      if (emailFilter) params.email = emailFilter;
      if (ipFilter) params.ip = ipFilter;
      if (userIdFilter) params.user_id = userIdFilter;
      if (successFilter === 'success') params.success = true;
      if (successFilter === 'fail') params.success = false;
      if (hoursFilter) params.since = hoursFilter;
      const data = await api.getLoginEvents(params);
      events = data.events || [];
    } catch (err: any) {
      error = err?.error || 'Failed to load login events.';
    }
    loading = false;
  }

  $effect(() => { load(); });

  function applyFilters() {
    load();
  }

  function clearFilters() {
    emailFilter = '';
    ipFilter = '';
    userIdFilter = '';
    successFilter = 'all';
    hoursFilter = '';
    load();
  }

  function formatDate(d: string | null) {
    if (!d) return '—';
    return new Date(d).toLocaleString();
  }

  function shortUa(ua: string | null): string {
    if (!ua) return '—';
    const m = ua.match(/(Chrome|Firefox|Safari|Edge|Brave)\/[\d.]+/i);
    return m ? m[0] : ua.slice(0, 40);
  }

  const stats = $derived.by(() => {
    const total = events.length;
    const successes = events.filter((e) => e.success).length;
    const failures = total - successes;
    return { total, successes, failures };
  });
</script>

<div class="admin-page">
  <div class="page-header">
    <div>
      <h1>Login Events</h1>
      <p class="page-sub">Security timeline of every login attempt. Used for audit trails and incident investigation.</p>
    </div>
    <div class="stats">
      <div class="stat"><strong>{stats.total}</strong><span>total</span></div>
      <div class="stat ok"><strong>{stats.successes}</strong><span>success</span></div>
      <div class="stat fail"><strong>{stats.failures}</strong><span>failed</span></div>
    </div>
  </div>

  <div class="filters">
    <input type="text" placeholder="Email contains..." bind:value={emailFilter} />
    <input type="text" placeholder="IP address" bind:value={ipFilter} />
    <input type="text" placeholder="User ID" bind:value={userIdFilter} />
    <select bind:value={successFilter}>
      <option value="all">All outcomes</option>
      <option value="success">Success only</option>
      <option value="fail">Failures only</option>
    </select>
    <select bind:value={hoursFilter}>
      <option value="">All time</option>
      <option value="1">Last hour</option>
      <option value="24">Last 24 hours</option>
      <option value="168">Last 7 days</option>
      <option value="720">Last 30 days</option>
    </select>
    <select bind:value={limit}>
      <option value={50}>50 rows</option>
      <option value={100}>100 rows</option>
      <option value={250}>250 rows</option>
      <option value={500}>500 rows</option>
    </select>
    <button class="btn-primary" onclick={applyFilters}>Apply</button>
    <button class="btn-secondary" onclick={clearFilters}>Clear</button>
  </div>

  {#if loading}
    <p class="loading">Loading events...</p>
  {:else if error}
    <div class="error-banner">{error}</div>
  {:else if events.length === 0}
    <p class="empty">No login events match your filters.</p>
  {:else}
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>When</th>
            <th>Outcome</th>
            <th>Email</th>
            <th>User</th>
            <th>IP</th>
            <th>Browser</th>
            <th>Failure</th>
          </tr>
        </thead>
        <tbody>
          {#each events as e (e.id)}
            <tr class:ok={e.success} class:fail={!e.success}>
              <td>{formatDate(e.occurred_at || e.inserted_at)}</td>
              <td>
                <span class="pill" class:ok={e.success} class:fail={!e.success}>
                  {e.success ? 'OK' : 'FAIL'}
                </span>
              </td>
              <td>{e.email || '—'}</td>
              <td>{e.username || (e.user_id ? e.user_id.slice(0, 8) + '…' : '—')}</td>
              <td><code>{e.ip_address || '—'}</code></td>
              <td title={e.user_agent || ''}>{shortUa(e.user_agent)}</td>
              <td class="reason">{e.failure_reason || '—'}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>

<style>
  .admin-page { max-width: 1200px; }
  .page-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 16px; gap: 16px; flex-wrap: wrap; }
  .page-header h1 { font-size: 20px; font-weight: 800; }
  .page-sub { font-size: 12px; color: var(--text-muted); margin-top: 2px; max-width: 640px; }
  .stats { display: flex; gap: 12px; }
  .stat { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 10px 16px; text-align: center; min-width: 70px; }
  .stat strong { display: block; font-size: 18px; font-weight: 800; }
  .stat span { font-size: 10px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; }
  .stat.ok strong { color: #34d399; }
  .stat.fail strong { color: #f87171; }

  .filters { display: flex; gap: 8px; margin-bottom: 12px; flex-wrap: wrap; }
  .filters input, .filters select { padding: 8px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: inherit; font-size: 13px; }
  .filters input { flex: 1; min-width: 140px; }
  .filters button { padding: 8px 16px; border-radius: var(--radius); font-family: inherit; font-size: 13px; cursor: pointer; border: 1px solid var(--border-color); }
  .btn-primary { background: var(--accent); color: var(--bg-primary); border: none; font-weight: 600; }
  .btn-secondary { background: var(--bg-secondary); color: var(--text-secondary); }

  .table-wrap { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); overflow: auto; }
  table { width: 100%; border-collapse: collapse; font-size: 12px; }
  th { text-align: left; padding: 8px 12px; background: var(--bg-primary); color: var(--text-muted); font-size: 10px; text-transform: uppercase; letter-spacing: 0.05em; border-bottom: 1px solid var(--border-color); font-weight: 700; }
  td { padding: 8px 12px; border-bottom: 1px solid var(--border-color); vertical-align: middle; }
  tr.fail td { color: #f87171; }
  tr.ok td { color: var(--text-secondary); }
  .pill { display: inline-block; padding: 2px 8px; font-size: 10px; font-weight: 800; border-radius: 10px; letter-spacing: 0.05em; }
  .pill.ok { background: rgba(52,211,153,0.15); color: #34d399; }
  .pill.fail { background: rgba(248,113,113,0.15); color: #f87171; }
  .reason { font-size: 11px; max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

  .loading, .empty { text-align: center; color: var(--text-muted); padding: 30px; }
  .error-banner { padding: 12px; background: rgba(248,113,113,0.1); border: 1px solid rgba(248,113,113,0.3); border-radius: var(--radius); color: #f87171; }
</style>
