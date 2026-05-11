<script lang="ts">
  import { admin } from '$lib/stores/admin.svelte';
  import { goto } from '$app/navigation';

  let search = $state('');
  let ipSearch = $state('');
  let statusFilter = $state('');
  let sortBy = $state('newest');
  let loading = $state(true);
  let page = $state(1);
  let pageSize = $state(25);

  $effect(() => { loadUsers(); });

  async function loadUsers() {
    loading = true;
    const params: Record<string, string> = {
      sort: sortBy,
      limit: String(pageSize),
      offset: String((page - 1) * pageSize)
    };
    if (search) params.search = search;
    if (statusFilter) params.status = statusFilter;
    await admin.loadUsers(params);
    loading = false;
  }

  function handleSearch() { page = 1; loadUsers(); }

  const totalPages = $derived(Math.max(1, Math.ceil(admin.usersTotal / pageSize)));
  const pageStart = $derived((page - 1) * pageSize + 1);
  const pageEnd = $derived(Math.min(admin.usersTotal, page * pageSize));

  function goPage(p: number) {
    if (p < 1 || p > totalPages) return;
    page = p;
    loadUsers();
  }

  async function handleIpSearch() {
    if (!ipSearch.trim()) return;
    loading = true;
    await admin.searchUsersByIp(ipSearch.trim());
    loading = false;
  }

  async function handleDelete(id: string, username: string) {
    if (!confirm(`Delete user "${username}"? This cannot be undone.`)) return;
    await admin.deleteUser(id);
  }

  function formatDate(d: string | null) { return d ? new Date(d).toLocaleDateString() : '-'; }
</script>

<div class="page">
  <div class="page-header">
    <h1>User Management</h1>
    <span class="user-count">
      {#if admin.usersTotal > 0}
        Showing {pageStart}–{pageEnd} of {admin.usersTotal}
      {:else}
        {admin.users.length} users
      {/if}
    </span>
  </div>

  <div class="filters">
    <input type="text" bind:value={search} placeholder="Search username, email..." onkeydown={(e: KeyboardEvent) => { if (e.key === 'Enter') handleSearch(); }} />
    <select bind:value={statusFilter} onchange={handleSearch}>
      <option value="">All statuses</option>
      <option value="active">Active</option>
      <option value="banned">Banned</option>
      <option value="suspended">Suspended</option>
    </select>
    <select bind:value={sortBy} onchange={handleSearch}>
      <option value="newest">Newest</option>
      <option value="oldest">Oldest</option>
      <option value="username">Username</option>
      <option value="posts">Most Posts</option>
    </select>
    <button class="btn" onclick={handleSearch}>Search</button>
  </div>

  <div class="filters ip-search-row">
    <input type="text" bind:value={ipSearch} placeholder="Search by IP address (e.g. 192.168.1.1)" onkeydown={(e: KeyboardEvent) => { if (e.key === 'Enter') handleIpSearch(); }} />
    <button class="btn" onclick={handleIpSearch}>Search IP</button>
    {#if ipSearch}<button class="btn btn-clear" onclick={() => { ipSearch = ''; loadUsers(); }}>Clear</button>{/if}
  </div>

  {#if loading}
    <p class="loading">Loading users...</p>
  {:else}
    <div class="user-table-wrap">
      <table class="user-table">
        <thead>
          <tr>
            <th>User</th>
            <th>Email</th>
            <th>Status</th>
            <th>Posts</th>
            <th>Last Seen</th>
            <th>Joined</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each admin.users as user (user.id)}
            <tr>
              <td class="user-cell">
                <span class="online-dot" class:online={user.is_online}></span>
                <a href="/admin/users/{user.id}" class="username">{user.username}</a>
                {#if user.primary_group}<span class="group-badge" style="color: {user.primary_group.color || 'var(--text-muted)'};">{user.primary_group.name}</span>{/if}
              </td>
              <td class="email">{user.email}</td>
              <td><span class="badge badge-{user.status}">{user.status}</span></td>
              <td class="num">{user.post_count}</td>
              <td class="date">{formatDate(user.last_seen_at)}</td>
              <td class="date">{formatDate(user.inserted_at)}</td>
              <td>
                <button class="btn-tiny" onclick={() => goto(`/admin/users/${user.id}`)}>View</button>
                <button class="btn-tiny btn-danger" onclick={() => handleDelete(user.id, user.username)}>Del</button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    {#if admin.usersTotal > pageSize}
      <div class="pagination">
        <button class="btn-tiny" disabled={page <= 1} onclick={() => goPage(1)}>« First</button>
        <button class="btn-tiny" disabled={page <= 1} onclick={() => goPage(page - 1)}>‹ Prev</button>
        <span class="page-indicator">Page {page} of {totalPages}</span>
        <button class="btn-tiny" disabled={page >= totalPages} onclick={() => goPage(page + 1)}>Next ›</button>
        <button class="btn-tiny" disabled={page >= totalPages} onclick={() => goPage(totalPages)}>Last »</button>
        <select bind:value={pageSize} onchange={() => { page = 1; loadUsers(); }}>
          <option value={25}>25 / page</option>
          <option value={50}>50 / page</option>
          <option value={100}>100 / page</option>
        </select>
      </div>
    {/if}
  {/if}
</div>

<style>
  .page h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); }
  .page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
  .user-count { font-size: 12px; color: var(--text-muted); }
  .filters { display: flex; gap: 8px; margin-bottom: 16px; }
  .filters input, .filters select { padding: 6px 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-input); color: var(--text-primary); font-size: 12px; font-family: inherit; }
  .filters input { flex: 1; max-width: 300px; }
  .filters input:focus, .filters select:focus { outline: none; border-color: var(--accent); }
  .btn { padding: 6px 14px; border-radius: var(--radius); font-size: 12px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); background: var(--bg-card); color: var(--text-secondary); font-family: inherit; }
  .user-table-wrap { overflow-x: auto; }
  .user-table { width: 100%; border-collapse: collapse; font-size: 12px; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); overflow: hidden; }
  .user-table th { text-align: left; padding: 8px 10px; font-size: 10px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; background: var(--bg-tertiary); border-bottom: 1px solid var(--border-color); }
  .user-table td { padding: 8px 10px; border-bottom: 1px solid rgba(30, 41, 59, 0.4); color: var(--text-secondary); }
  .user-table tr:last-child td { border-bottom: none; }
  .user-table tr:hover { background: var(--bg-hover); }
  .user-cell { display: flex; align-items: center; gap: 6px; }
  .online-dot { width: 6px; height: 6px; border-radius: 50%; background: var(--text-muted); flex-shrink: 0; }
  .online-dot.online { background: #4ade80; box-shadow: 0 0 4px #4ade80; }
  .username { font-weight: 600; color: var(--text-primary); text-decoration: none; }
  .username:hover { color: var(--accent); }
  .group-badge { font-size: 9px; font-weight: 600; }
  .email { font-size: 11px; color: var(--text-muted); }
  .num { font-variant-numeric: tabular-nums; }
  .date { font-size: 11px; color: var(--text-muted); }
  .badge { padding: 2px 6px; border-radius: 8px; font-size: 10px; font-weight: 600; background: var(--bg-tertiary); color: var(--text-secondary); }
  .badge-active { background: #22c55e20; color: #4ade80; }
  .badge-banned { background: #dc262620; color: #f87171; }
  .btn-tiny { padding: 2px 6px; font-size: 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-tertiary); color: var(--text-muted); cursor: pointer; font-family: inherit; }
  .btn-danger { color: #f87171; border-color: #dc262640; }
  .ip-search-row input { flex: 1; max-width: 350px; }
  .btn-clear { color: var(--text-muted); }
  .loading { color: var(--text-muted); text-align: center; padding: 32px 0; }
  .pagination { display: flex; gap: 6px; align-items: center; justify-content: center; margin-top: 16px; flex-wrap: wrap; }
  .pagination .btn-tiny { padding: 6px 12px; font-size: 11px; }
  .pagination .btn-tiny:disabled { opacity: 0.4; cursor: not-allowed; }
  .pagination .page-indicator { font-size: 11px; color: var(--text-secondary); padding: 0 10px; font-weight: 600; }
  .pagination select { padding: 4px 8px; font-size: 11px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-input); color: var(--text-primary); font-family: inherit; margin-left: 8px; }
</style>
