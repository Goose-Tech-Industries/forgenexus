<script lang="ts">
  import type { DecayForum } from '$lib/stores/admin.svelte';

  let { forum }: { forum: DecayForum } = $props();
</script>

<div class="decay-card">
  <div class="decay-header">
    <div>
      <span class="forum-name">{forum.forum_name}</span>
      <span class="category-name">{forum.category_name}</span>
    </div>
    <span class="decline-badge">-{forum.decline_pct}%</span>
  </div>
  <div class="decay-stats">
    <span>Now: {forum.current_threads_30d} threads/30d</span>
    <span>Was: {forum.previous_threads_30d} threads/30d</span>
    <span>{forum.total_posts} total posts</span>
  </div>
  <div class="suggestions">
    <span class="suggestions-label">Revival ideas:</span>
    <div class="suggestion-pills">
      {#each forum.suggestions as suggestion}
        <span class="pill">{suggestion}</span>
      {/each}
    </div>
  </div>
</div>

<style>
  .decay-card {
    background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg);
    padding: 14px; border-left: 3px solid #f97316;
  }
  .decay-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 8px; }
  .forum-name { font-size: 14px; font-weight: 700; color: var(--text-primary); display: block; }
  .category-name { font-size: 11px; color: var(--text-muted); }
  .decline-badge { font-size: 16px; font-weight: 800; color: #f87171; background: #dc262620; padding: 2px 10px; border-radius: 8px; }
  .decay-stats { display: flex; gap: 16px; font-size: 11px; color: var(--text-muted); margin-bottom: 10px; }
  .suggestions { border-top: 1px solid var(--border-color); padding-top: 8px; }
  .suggestions-label { font-size: 10px; font-weight: 700; color: var(--accent); text-transform: uppercase; letter-spacing: 0.03em; display: block; margin-bottom: 6px; }
  .suggestion-pills { display: flex; flex-wrap: wrap; gap: 4px; }
  .pill {
    font-size: 11px; padding: 3px 10px; border-radius: 12px;
    background: var(--bg-tertiary); color: var(--text-primary); border: 1px solid var(--border-color);
    cursor: default;
  }
</style>
