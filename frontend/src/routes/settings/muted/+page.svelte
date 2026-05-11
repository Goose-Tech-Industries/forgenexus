<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';

  let ignores = $state<any[]>([]);
  let loading = $state(true);
  let error = $state('');

  $effect(() => {
    if (auth.isLoggedIn) loadIgnores();
  });

  async function loadIgnores() {
    loading = true;
    try {
      const data = await api.getIgnores();
      ignores = data.ignores || [];
    } catch (err: any) {
      error = err?.error || 'Failed to load muted content';
    }
    loading = false;
  }

  async function unmute(ignore: any) {
    try {
      if (ignore.forum) {
        await api.unignoreForum(ignore.forum.id);
      } else if (ignore.thread) {
        await api.unignoreThread(ignore.thread.id);
      }
      ignores = ignores.filter(i => i.id !== ignore.id);
    } catch (err) {
      console.error('Failed to unmute:', err);
    }
  }
</script>

<div class="muted-page">
  <h1 class="page-title">Muted Content</h1>
  <p class="page-desc">Forums and threads you've muted won't appear in your feed.</p>

  {#if loading}
    <div class="loading">Loading...</div>
  {:else if error}
    <div class="error-box">{error}</div>
  {:else if ignores.length === 0}
    <div class="empty-state">
      <p>You haven't muted any forums or threads.</p>
    </div>
  {:else}
    <div class="ignore-list">
      {#each ignores as ignore (ignore.id)}
        <div class="ignore-item">
          <div class="ignore-info">
            {#if ignore.forum}
              <span class="ignore-type">Forum</span>
              <a href="/forums/{ignore.forum.slug}" class="ignore-name">{ignore.forum.name}</a>
            {:else if ignore.thread}
              <span class="ignore-type">Thread</span>
              <a href="/threads/{ignore.thread.slug}" class="ignore-name">{ignore.thread.title}</a>
            {/if}
          </div>
          <button class="btn-unmute" onclick={() => unmute(ignore)}>Unmute</button>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .muted-page { display: flex; flex-direction: column; gap: 12px; }
  .page-title { font-size: 20px; font-weight: 800; color: var(--text-primary); }
  .page-desc { font-size: 13px; color: var(--text-secondary); }

  .ignore-list { display: flex; flex-direction: column; gap: 4px; }
  .ignore-item {
    display: flex; justify-content: space-between; align-items: center;
    padding: 10px 12px; background: var(--bg-card);
    border: 1px solid var(--border-color); border-radius: var(--radius);
  }
  .ignore-info { display: flex; align-items: center; gap: 8px; }
  .ignore-type {
    font-size: 10px; text-transform: uppercase; font-weight: 700;
    color: var(--text-muted); background: var(--bg-tertiary);
    padding: 2px 6px; border-radius: 3px;
  }
  .ignore-name { font-size: 13px; font-weight: 600; color: var(--text-link); }

  .btn-unmute {
    font-size: 12px; padding: 4px 12px; border-radius: var(--radius);
    background: var(--bg-tertiary); color: var(--text-secondary);
    border: 1px solid var(--border-color); cursor: pointer;
  }
  .btn-unmute:hover { background: var(--danger); color: white; border-color: var(--danger); }

  .empty-state, .loading { text-align: center; padding: 40px 0; color: var(--text-muted); font-size: 13px; }
</style>
