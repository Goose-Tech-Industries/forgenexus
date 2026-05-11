<script lang="ts">
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { api } from '$lib/api/client';

  let query = $state('');
  let searchType = $state<'threads' | 'posts'>('threads');
  let authorFilter = $state('');
  let results = $state<any[]>([]);
  let total = $state(0);
  let currentPage = $state(1);
  let totalPages = $state(1);
  const perPage = 20;
  let loading = $state(false);
  let searched = $state(false);
  let error = $state('');

  // Load from URL params on mount
  $effect(() => {
    const params = $page.url.searchParams;
    const q = params.get('q');
    if (q && q !== query) {
      query = q;
      searchType = (params.get('type') as any) || 'threads';
      authorFilter = params.get('author') || '';
      doSearch();
    }
  });

  async function doSearch() {
    if (query.length < 2) return;
    loading = true;
    searched = true;
    try {
      const data = await api.search(query, {
        type: searchType,
        page: currentPage,
        author: authorFilter || undefined
      });
      results = data.results || [];
      total = data.total || 0;
      totalPages = data.total_pages || Math.ceil(total / perPage) || 1;
    } catch (err: any) {
      error = err?.error || 'Search failed. Please try again.';
      results = [];
    }
    loading = false;
  }

  function goToPage(pg: number) {
    currentPage = pg;
    doSearch();
  }

  function handleSubmit() {
    currentPage = 1;
    const params = new URLSearchParams({ q: query, type: searchType });
    if (authorFilter) params.set('author', authorFilter);
    goto(`/search?${params.toString()}`, { replaceState: true });
    doSearch();
  }

  function timeAgo(dateStr: string | null): string {
    if (!dateStr) return '';
    const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return new Date(dateStr).toLocaleDateString();
  }
</script>

<div class="search-page">
  <h1 class="page-title">Search</h1>

  <form class="search-form" onsubmit={(e) => { e.preventDefault(); handleSubmit(); }}>
    <div class="search-bar">
      <input
        type="text"
        bind:value={query}
        placeholder="Search threads, posts..."
        class="search-input"
        minlength="2"
      />
      <button type="submit" class="btn btn-primary" disabled={loading || query.length < 2}>
        {loading ? 'Searching...' : 'Search'}
      </button>
    </div>
    <div class="search-filters">
      <div class="filter-group">
        <label class="filter-label">Type:</label>
        <select bind:value={searchType} class="filter-select">
          <option value="threads">Threads</option>
          <option value="posts">Posts</option>
        </select>
      </div>
      <div class="filter-group">
        <label class="filter-label">Author:</label>
        <input type="text" bind:value={authorFilter} placeholder="username" class="filter-input" />
      </div>
    </div>
  </form>

  {#if loading}
    <div class="loading">Searching...</div>
  {:else if error}
    <div class="error-box">{error}</div>
  {:else if searched && results.length === 0}
    <div class="no-results">No results found for "{query}"</div>
  {:else if results.length > 0}
    <div class="results-header">
      <span class="results-count">{total} result{total !== 1 ? 's' : ''}</span>
    </div>

    <div class="results-list">
      {#each results as result (result.id)}
        <div class="result-item">
          <a href="/threads/{result.slug}" class="result-title">{result.title}</a>
          <div class="result-meta">
            {#if result.forum}
              in <a href="/forums/{result.forum.slug}" class="result-forum">{result.forum.name}</a>
            {/if}
            {#if result.user}
              &middot; by <a href="/profile/{result.user.slug}" class="result-author">{result.user.username}</a>
            {/if}
            &middot; {result.reply_count} replies &middot; {result.view_count} views
            &middot; {timeAgo(result.inserted_at)}
          </div>
        </div>
      {/each}
    </div>

    {#if totalPages > 1}
      <div class="pagination">
        <button class="pg-btn" disabled={currentPage <= 1} onclick={() => goToPage(currentPage - 1)}>&laquo; Prev</button>
        {#each Array.from({length: Math.min(totalPages, 10)}, (_, i) => {
          if (totalPages <= 10) return i + 1;
          const start = Math.max(1, Math.min(currentPage - 4, totalPages - 9));
          return start + i;
        }) as pg}
          <button class="pg-btn" class:active={pg === currentPage} onclick={() => goToPage(pg)}>{pg}</button>
        {/each}
        <button class="pg-btn" disabled={currentPage >= totalPages} onclick={() => goToPage(currentPage + 1)}>Next &raquo;</button>
      </div>
    {/if}
  {/if}
</div>

<style>
  .search-page { display: flex; flex-direction: column; gap: 16px; }
  .page-title { font-size: 20px; font-weight: 800; color: var(--text-primary); }

  .search-form { display: flex; flex-direction: column; gap: 10px; }
  .search-bar { display: flex; gap: 8px; }
  .search-input {
    flex: 1; padding: 10px 14px; border: 1px solid var(--border-color);
    border-radius: var(--radius); background: var(--bg-input); color: var(--text-primary);
    font-size: 14px;
  }
  .search-input:focus { border-color: var(--accent); outline: none; }

  .search-filters { display: flex; gap: 16px; align-items: center; }
  .filter-group { display: flex; align-items: center; gap: 6px; }
  .filter-label { font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  .filter-select, .filter-input {
    padding: 4px 8px; border: 1px solid var(--border-color); border-radius: var(--radius);
    background: var(--bg-input); color: var(--text-primary); font-size: 12px;
  }
  .filter-input { width: 120px; }

  .btn { padding: 8px 20px; border-radius: var(--radius); font-size: 13px; font-weight: 600; cursor: pointer; border: none; }
  .btn-primary { background: var(--accent); color: var(--bg-primary); }
  .btn-primary:hover:not(:disabled) { background: var(--accent-hover); }
  .btn:disabled { opacity: 0.5; cursor: default; }

  .results-header { font-size: 13px; color: var(--text-secondary); }
  .results-count { font-weight: 600; }

  .results-list { display: flex; flex-direction: column; gap: 4px; }
  .result-item {
    padding: 10px 14px; background: var(--bg-card);
    border: 1px solid var(--border-color); border-radius: var(--radius);
  }
  .result-title { font-size: 14px; font-weight: 700; color: var(--text-link); display: block; }
  .result-meta { font-size: 12px; color: var(--text-muted); margin-top: 4px; }
  .result-forum { color: var(--text-secondary); }
  .result-author { color: var(--text-secondary); }

  .no-results, .loading { text-align: center; padding: 40px 0; color: var(--text-muted); font-size: 14px; }

  .pagination { display: flex; gap: 4px; justify-content: center; padding: 12px 0; }
  .pg-btn { padding: 6px 12px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-card); color: var(--text-secondary); font-size: 12px; cursor: pointer; }
  .pg-btn.active { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); }
  .pg-btn:disabled { opacity: 0.4; cursor: default; }
  .pg-btn:hover:not(:disabled):not(.active) { background: var(--bg-hover); }
</style>
