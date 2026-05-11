<script lang="ts">
  import { api } from '$lib/api/client';
  import UserHoverCard from '$lib/components/common/UserHoverCard.svelte';

  let members = $state<any[]>([]);
  let loading = $state(true);
  let error = $state('');
  let search = $state('');
  let sort = $state('joined');
  let currentPage = $state(1);
  let totalPages = $state(1);
  let total = $state(0);

  $effect(() => { loadMembers(); });

  async function loadMembers() {
    loading = true;
    try {
      const data = await api.getMembers({ page: currentPage, search: search || undefined, sort });
      members = data.members || [];
      total = data.total || 0;
      totalPages = data.total_pages || 1;
    } catch (err: any) { error = err?.error || 'Failed to load members'; }
    loading = false;
  }

  function doSearch() { currentPage = 1; loadMembers(); }
  function goToPage(pg: number) { currentPage = pg; loadMembers(); }

  function timeAgo(dateStr: string | null): string {
    if (!dateStr) return 'Never';
    const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return new Date(dateStr).toLocaleDateString();
  }
</script>

<div class="members-page">
  <h1 class="page-title">Members ({total})</h1>

  <div class="members-toolbar">
    <form class="search-form" onsubmit={(e) => { e.preventDefault(); doSearch(); }}>
      <input type="text" bind:value={search} placeholder="Search members..." class="search-input" />
      <button type="submit" class="btn">Search</button>
    </form>
    <select bind:value={sort} onchange={() => { currentPage = 1; loadMembers(); }} class="sort-select">
      <option value="joined">Newest</option>
      <option value="posts">Most Posts</option>
      <option value="username">A-Z</option>
    </select>
  </div>

  {#if loading}
    <div class="loading">Loading members...</div>
  {:else if error}
    <div class="error-box">{error}</div>
  {:else}
    <div class="members-grid">
      {#each members as member (member.id)}
        <a href="/profile/{member.slug}" class="member-card">
          <div class="member-avatar">
            {#if member.avatar_url}
              <img src={member.avatar_url} alt={member.username} />
            {:else}
              <span class="avatar-initial">{member.username.charAt(0).toUpperCase()}</span>
            {/if}
            {#if member.is_online}<span class="online-dot"></span>{/if}
          </div>
          <div class="member-info">
            <UserHoverCard
              username={member.username}
              slug={member.slug}
              avatarUrl={member.avatar_url}
              postCount={member.post_count}
              reputation={member.reputation || 0}
              customTitle={member.display_title || member.custom_title}
              isOnline={member.is_online}
            >
              <strong class="member-name">{member.username}</strong>
            </UserHoverCard>
            {#if member.display_title || member.custom_title}<div class="member-title">{member.display_title || member.custom_title}</div>{/if}
            <div class="member-stats">{member.post_count} posts &middot; Joined {timeAgo(member.inserted_at)}</div>
          </div>
        </a>
      {/each}
    </div>

    {#if totalPages > 1}
      <div class="pagination">
        <button class="pg-btn" disabled={currentPage <= 1} onclick={() => goToPage(currentPage - 1)}>&laquo;</button>
        {#each Array.from({length: Math.min(totalPages, 10)}, (_, i) => i + 1) as pg}
          <button class="pg-btn" class:active={pg === currentPage} onclick={() => goToPage(pg)}>{pg}</button>
        {/each}
        <button class="pg-btn" disabled={currentPage >= totalPages} onclick={() => goToPage(currentPage + 1)}>&raquo;</button>
      </div>
    {/if}
  {/if}
</div>

<style>
  .members-page { display: flex; flex-direction: column; gap: 16px; }
  .page-title { font-size: 20px; font-weight: 800; color: var(--text-primary); }
  .members-toolbar { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
  .search-form { display: flex; gap: 6px; flex: 1; }
  .search-input { flex: 1; padding: 6px 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-input); color: var(--text-primary); font-size: 13px; }
  .sort-select { padding: 6px 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-input); color: var(--text-primary); font-size: 12px; }
  .btn { padding: 6px 14px; border-radius: var(--radius); font-size: 12px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-secondary); }

  .members-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 8px; }
  .member-card { display: flex; gap: 10px; padding: 10px 12px; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius); text-decoration: none; transition: all 0.15s; }
  .member-card:hover { border-color: var(--accent); background: var(--bg-hover); }
  .member-avatar { position: relative; width: 40px; height: 40px; border-radius: var(--radius); background: var(--bg-tertiary); display: flex; align-items: center; justify-content: center; flex-shrink: 0; overflow: hidden; }
  .member-avatar img { width: 100%; height: 100%; object-fit: cover; }
  .avatar-initial { font-size: 16px; font-weight: 700; color: var(--text-muted); }
  .online-dot { position: absolute; bottom: -1px; right: -1px; width: 10px; height: 10px; border-radius: 50%; background: var(--online); border: 2px solid var(--bg-card); }
  .member-name { font-size: 13px; color: var(--text-primary); }
  .member-title { font-size: 11px; color: var(--accent); }
  .member-stats { font-size: 11px; color: var(--text-muted); }

  .pagination { display: flex; gap: 4px; justify-content: center; padding: 8px 0; }
  .pg-btn { padding: 4px 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-card); color: var(--text-secondary); font-size: 12px; cursor: pointer; }
  .pg-btn.active { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); }
  .pg-btn:disabled { opacity: 0.4; cursor: default; }
  .loading { text-align: center; padding: 40px 0; color: var(--text-muted); }
</style>
