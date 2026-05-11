<script lang="ts">
  import { api } from '$lib/api/client';

  let clips = $state<any[]>([]);
  let loading = $state(true);

  $effect(() => { loadClips(); });

  async function loadClips() {
    try {
      const data = await api.request('/voice/clips/recent');
      clips = data.clips || [];
    } catch (e) { console.error(e); }
    loading = false;
  }

  function duration(start: number, end: number): string {
    const secs = Math.round((end - start) / 1000);
    return secs < 60 ? `${secs}s` : `${Math.floor(secs/60)}m ${secs%60}s`;
  }
</script>

<svelte:head><title>Clips — ForgeNexus</title></svelte:head>

<div class="clips-page">
  <h1 class="text-glow">Clips</h1>
  <p class="subtitle">Highlights from voice room sessions</p>

  <div class="clips-grid stagger">
    {#if loading}
      {#each Array(6) as _}<div class="skeleton clip-skeleton"></div>{/each}
    {:else if clips.length === 0}
      <div class="empty glass">No clips yet. Join a voice room and create one!</div>
    {:else}
      {#each clips as clip (clip.id)}
        <div class="clip-card card-elevated card-glow">
          <div class="clip-preview">
            <span class="clip-play">▶</span>
            <span class="clip-duration">{duration(clip.start_ms, clip.end_ms)}</span>
          </div>
          <div class="clip-info">
            <h3>{clip.title || 'Untitled Clip'}</h3>
            <div class="clip-meta">
              <span>👁 {clip.view_count || 0} views</span>
            </div>
          </div>
        </div>
      {/each}
    {/if}
  </div>
</div>

<style>
  .clips-page { max-width: 1000px; margin: 0 auto; padding: 24px 16px; }
  h1 { font-size: 28px; font-weight: 800; margin-bottom: 4px; }
  .subtitle { color: var(--text-secondary); margin-bottom: 24px; }
  .clips-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 14px; }
  .clip-skeleton { height: 180px; border-radius: var(--radius-lg); }
  .clip-card { overflow: hidden; }
  .clip-preview {
    height: 120px; background: var(--bg-elevated);
    display: flex; align-items: center; justify-content: center;
    position: relative;
  }
  .clip-play { font-size: 36px; opacity: 0.7; }
  .clip-duration {
    position: absolute; bottom: 6px; right: 8px;
    background: rgba(0,0,0,0.7); padding: 2px 6px;
    border-radius: 4px; font-size: 11px; font-weight: 600;
  }
  .clip-info { padding: 10px 14px; }
  .clip-info h3 { font-size: 14px; font-weight: 700; margin-bottom: 4px; }
  .clip-meta { font-size: 12px; color: var(--text-muted); }
  .empty { padding: 40px; text-align: center; color: var(--text-muted); grid-column: 1/-1; }
</style>
