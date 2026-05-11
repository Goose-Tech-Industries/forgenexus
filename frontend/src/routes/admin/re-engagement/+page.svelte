<script lang="ts">
  import { api } from '$lib/api/client';
  let users = $state<any[]>([]);
  let loading = $state(true);

  $effect(() => { load(); });
  async function load() {
    loading = true;
    try { const data = await api.getLapsedUsers(); users = data.users || []; } catch {}
    loading = false;
  }

  function formatDate(ts: string) { return new Date(ts).toLocaleDateString(undefined, { month: 'short', day: 'numeric' }); }

  let notifying = $state<string | null>(null);
  let notified = $state<Set<string>>(new Set());

  async function notify(user: any) {
    if (notifying) return;
    notifying = user.id;
    try {
      await api.request('/admin/mass-email', {
        method: 'POST',
        body: JSON.stringify({
          user_ids: [user.id],
          subject: 'We miss you!',
          body: `Hey ${user.username}, we noticed you haven't been around in a while. Come back and check what's new!`
        })
      });
      notified = new Set([...notified, user.id]);
    } catch { /* silent */ }
    notifying = null;
  }
</script>

<div class="admin-page">
  <h1>Re-engagement Campaigns</h1>
  <p class="subtitle">Users who were active but haven't been seen in 14+ days. {users.length} lapsed user{users.length !== 1 ? 's' : ''} found.</p>

  {#if loading}
    <p class="loading">Loading...</p>
  {:else if users.length === 0}
    <div class="all-clear">
      <h3>No lapsed users</h3>
      <p>All active users are still engaged.</p>
    </div>
  {:else}
    <table class="admin-table">
      <thead><tr><th>User</th><th>Posts</th><th>Rep</th><th>Last Seen</th><th>Days Gone</th><th>Actions</th></tr></thead>
      <tbody>
        {#each users as u}
          <tr>
            <td class="name-cell"><a href="/admin/users/{u.id}">{u.username}</a></td>
            <td>{u.post_count}</td>
            <td>{u.reputation}</td>
            <td>{u.last_seen_at ? formatDate(u.last_seen_at) : '—'}</td>
            <td><span class="days-badge" class:critical={u.days_inactive > 60}>{u.days_inactive}d</span></td>
            <td>
              {#if notified.has(u.id)}
                <span class="btn-sm" style="color: var(--accent);">Sent</span>
              {:else}
                <button class="btn-sm" title="Send re-engagement notification" disabled={notifying === u.id} onclick={() => notify(u)}>
                  {notifying === u.id ? '...' : 'Notify'}
                </button>
              {/if}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}
</div>

<style>
  .admin-page { max-width: 800px; }
  h1 { font-size: 20px; font-weight: 800; margin-bottom: 4px; }
  .subtitle { font-size: 12px; color: var(--text-muted); margin-bottom: 20px; }
  .all-clear { text-align: center; padding: 60px; color: var(--text-muted); }
  .admin-table { width: 100%; border-collapse: collapse; }
  .admin-table th { text-align: left; padding: 8px 10px; font-size: 11px; text-transform: uppercase; color: var(--text-muted); border-bottom: 1px solid var(--border-color); }
  .admin-table td { padding: 8px 10px; border-bottom: 1px solid rgba(255,255,255,0.03); font-size: 13px; }
  .name-cell a { color: var(--accent); text-decoration: none; font-weight: 600; }
  .days-badge { font-weight: 700; }
  .days-badge.critical { color: #f87171; }
  .btn-sm { padding: 4px 10px; font-size: 11px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; }
  .loading { text-align: center; color: var(--text-muted); padding: 40px; }
</style>
