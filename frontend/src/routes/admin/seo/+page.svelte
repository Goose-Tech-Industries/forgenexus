<script lang="ts">
  import { api } from '$lib/api/client';
  let seo = $state<any>(null);
  let loading = $state(true);

  $effect(() => { load(); });
  async function load() {
    loading = true;
    try { const data = await api.getSeoHealth(); seo = data.seo; } catch {}
    loading = false;
  }
</script>

<div class="admin-page">
  <h1>SEO Health Monitor</h1>

  {#if loading}
    <p class="loading">Loading...</p>
  {:else if seo}
    <div class="score-card">
      <div class="score-circle" class:good={seo.overall_score >= 70} class:warning={seo.overall_score >= 40 && seo.overall_score < 70} class:bad={seo.overall_score < 40}>
        {seo.overall_score}
      </div>
      <div class="score-label">SEO Health Score</div>
    </div>

    {#if seo.dead_forums.length > 0}
      <div class="section warning-section">
        <h3>Dead Forums ({seo.dead_forums.length})</h3>
        <p class="section-desc">No threads in 30+ days. Consider merging or promoting.</p>
        <div class="tag-list">
          {#each seo.dead_forums as f}
            <span class="dead-tag">{f.name} ({f.thread_count} total threads)</span>
          {/each}
        </div>
      </div>
    {/if}

    {#if seo.underperforming_threads.length > 0}
      <div class="section">
        <h3>Underperforming Threads</h3>
        <p class="section-desc">High-view threads with no replies — opportunity to engage.</p>
        {#each seo.underperforming_threads as t}
          <div class="thread-row">
            <span class="thread-title">{t.title}</span>
            <span class="thread-views">{t.view_count} views</span>
            <span class="thread-forum">{t.forum_name}</span>
            {#if t.suggestion}
              <span class="thread-suggestion">{t.suggestion}</span>
            {/if}
          </div>
        {/each}
      </div>
    {/if}

    <div class="section">
      <h3>Top Threads by Views</h3>
      <table class="admin-table">
        <thead><tr><th>Thread</th><th>Forum</th><th>Views</th><th>Replies</th></tr></thead>
        <tbody>
          {#each seo.top_threads as t}
            <tr>
              <td>{t.title}</td>
              <td>{t.forum_name}</td>
              <td>{t.view_count}</td>
              <td>{t.reply_count}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>

<style>
  .admin-page { max-width: 800px; }
  h1 { font-size: 20px; font-weight: 800; margin-bottom: 16px; }
  h3 { font-size: 14px; font-weight: 700; margin-bottom: 6px; }
  .score-card { text-align: center; margin-bottom: 24px; }
  .score-circle { display: inline-flex; align-items: center; justify-content: center; width: 80px; height: 80px; border-radius: 50%; font-size: 28px; font-weight: 800; border: 4px solid; }
  .score-circle.good { border-color: #4ade80; color: #4ade80; }
  .score-circle.warning { border-color: #fbbf24; color: #fbbf24; }
  .score-circle.bad { border-color: #f87171; color: #f87171; }
  .score-label { font-size: 12px; color: var(--text-muted); margin-top: 6px; }
  .section { margin-bottom: 24px; }
  .section-desc { font-size: 12px; color: var(--text-muted); margin-bottom: 10px; }
  .warning-section { background: rgba(251,191,36,0.05); border: 1px solid rgba(251,191,36,0.15); border-radius: var(--radius-lg); padding: 16px; }
  .tag-list { display: flex; flex-wrap: wrap; gap: 6px; }
  .dead-tag { font-size: 11px; padding: 4px 10px; background: rgba(248,113,113,0.1); color: #f87171; border-radius: 10px; }
  .thread-row { display: flex; align-items: baseline; gap: 10px; padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.03); font-size: 12px; }
  .thread-title { flex: 1; font-weight: 600; color: var(--text-primary); }
  .thread-views { color: var(--text-muted); }
  .thread-forum { color: var(--accent); font-size: 11px; }
  .thread-suggestion { color: #fbbf24; font-size: 11px; font-style: italic; }
  .admin-table { width: 100%; border-collapse: collapse; }
  .admin-table th { text-align: left; padding: 8px 10px; font-size: 11px; text-transform: uppercase; color: var(--text-muted); border-bottom: 1px solid var(--border-color); }
  .admin-table td { padding: 8px 10px; border-bottom: 1px solid rgba(255,255,255,0.03); font-size: 13px; }
  .loading { text-align: center; color: var(--text-muted); padding: 40px; }
</style>
