<script lang="ts">
  import { admin } from '$lib/stores/admin.svelte';
  import DecayCard from '$lib/components/admin/DecayCard.svelte';

  let loading = $state(true);

  $effect(() => { load(); });

  async function load() {
    loading = true;
    await admin.loadContentDecay();
    loading = false;
  }
</script>

<div class="page">
  <div class="page-header">
    <div>
      <h1>Content Decay Detection</h1>
      <p class="subtitle">Forums with significant activity decline in the last 30 days, with AI-powered revival suggestions</p>
    </div>
  </div>

  {#if loading}
    <p class="loading">Analyzing forum activity...</p>
  {:else if admin.contentDecay.length === 0}
    <div class="empty-state">
      <span class="empty-icon">🎉</span>
      <p>All forums are healthy! No significant activity decline detected.</p>
    </div>
  {:else}
    <p class="decay-count">{admin.contentDecay.length} forum{admin.contentDecay.length > 1 ? 's' : ''} showing decline</p>
    <div class="decay-list">
      {#each admin.contentDecay as forum (forum.forum_id)}
        <DecayCard {forum} />
      {/each}
    </div>
  {/if}
</div>

<style>
  .page h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); }
  .subtitle { font-size: 12px; color: var(--text-muted); margin-top: 2px; }
  .page-header { margin-bottom: 20px; }
  .loading { color: var(--text-muted); text-align: center; padding: 32px 0; }
  .empty-state { text-align: center; padding: 48px 0; color: var(--text-secondary); }
  .empty-icon { font-size: 32px; display: block; margin-bottom: 8px; }
  .decay-count { font-size: 12px; color: var(--text-muted); margin-bottom: 12px; }
  .decay-list { display: flex; flex-direction: column; gap: 10px; }
</style>
