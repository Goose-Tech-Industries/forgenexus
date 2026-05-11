<script lang="ts">
  import { api } from '$lib/api/client';
  let posts = $state<any[]>([]);
  let loading = $state(true);
  let mode = $state('best');

  $effect(() => { load(); });
  async function load() {
    loading = true;
    try { const data = await api.getContentQuality(mode); posts = data.posts || []; } catch {}
    loading = false;
  }
</script>

<div class="admin-page">
  <div class="page-header">
    <h1>Content Quality</h1>
    <div class="mode-toggle">
      <button class:active={mode === 'best'} onclick={() => { mode = 'best'; load(); }}>Best Content</button>
      <button class:active={mode === 'worst'} onclick={() => { mode = 'worst'; load(); }}>Worst Content</button>
    </div>
  </div>

  {#if loading}
    <p class="loading">Loading...</p>
  {:else}
    <div class="post-list">
      {#each posts as p, i}
        <div class="post-card">
          <div class="quality-bar" style:width="{p.quality_score}%" style:background={p.quality_score >= 60 ? '#4ade80' : p.quality_score >= 30 ? '#fbbf24' : '#f87171'}></div>
          <div class="post-header">
            <span class="quality-score">{p.quality_score}</span>
            <span class="post-author">{p.user?.username || 'Unknown'}</span>
            {#if p.thread_title}
              <span class="post-thread">in "{p.thread_title}"</span>
            {/if}
            {#if p.report_count > 0}
              <span class="report-flag">{p.report_count} report{p.report_count > 1 ? 's' : ''}</span>
            {/if}
          </div>
          <div class="post-preview">{p.body_preview}</div>
          <div class="post-meta">
            <span>{p.length} chars</span>
            {#if p.has_formatting}<span>Has formatting</span>{/if}
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .admin-page { max-width: 800px; }
  .page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
  .page-header h1 { font-size: 20px; font-weight: 800; }
  .mode-toggle { display: flex; border: 1px solid var(--border-color); border-radius: var(--radius); overflow: hidden; }
  .mode-toggle button { padding: 6px 14px; border: none; background: var(--bg-secondary); color: var(--text-muted); cursor: pointer; font-family: inherit; font-size: 12px; font-weight: 600; }
  .mode-toggle button.active { background: var(--accent); color: var(--bg-primary); }
  .post-list { display: flex; flex-direction: column; gap: 10px; }
  .post-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 14px 16px; position: relative; overflow: hidden; }
  .quality-bar { position: absolute; top: 0; left: 0; height: 3px; border-radius: 3px 0 0 0; }
  .post-header { display: flex; align-items: baseline; gap: 8px; margin-bottom: 6px; font-size: 12px; }
  .quality-score { font-size: 18px; font-weight: 800; color: var(--text-primary); min-width: 28px; }
  .post-author { font-weight: 600; color: var(--accent); }
  .post-thread { color: var(--text-muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .report-flag { margin-left: auto; font-size: 10px; color: #f87171; font-weight: 600; }
  .post-preview { font-size: 13px; color: var(--text-secondary); line-height: 1.4; margin-bottom: 6px; }
  .post-meta { display: flex; gap: 12px; font-size: 10px; color: var(--text-muted); }
  .loading { text-align: center; color: var(--text-muted); padding: 40px; }
</style>
