<script lang="ts">
  /** GIF search via Tenor API (free tier, no key needed for basic search) */
  let { onSelect }: { onSelect: (url: string, preview: string) => void } = $props();

  let query = $state('');
  let results = $state<Array<{ url: string; preview: string; width: number; height: number }>>([]);
  let loading = $state(false);
  let debounceTimer: ReturnType<typeof setTimeout> | null = null;

  // Trending GIFs on open
  $effect(() => { searchTrending(); });

  async function searchTrending() {
    loading = true;
    try {
      const res = await fetch('https://tenor.googleapis.com/v2/featured?key=AIzaSyAyimkuYQYF_FXVALexPuGQctUWRURdCYQ&limit=20&media_filter=tinygif,gif');
      const data = await res.json();
      results = (data.results || []).map(mapResult);
    } catch { results = []; }
    loading = false;
  }

  async function search() {
    if (!query.trim()) { searchTrending(); return; }
    loading = true;
    try {
      const res = await fetch(`https://tenor.googleapis.com/v2/search?key=AIzaSyAyimkuYQYF_FXVALexPuGQctUWRURdCYQ&q=${encodeURIComponent(query)}&limit=20&media_filter=tinygif,gif`);
      const data = await res.json();
      results = (data.results || []).map(mapResult);
    } catch { results = []; }
    loading = false;
  }

  function mapResult(r: any) {
    const gif = r.media_formats?.gif || r.media_formats?.tinygif;
    const tiny = r.media_formats?.tinygif || gif;
    return {
      url: gif?.url || '',
      preview: tiny?.url || gif?.url || '',
      width: tiny?.dims?.[0] || 200,
      height: tiny?.dims?.[1] || 150,
    };
  }

  function handleInput() {
    if (debounceTimer) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(search, 400);
  }
</script>

<div class="gif-picker">
  <input type="text" placeholder="Search GIFs..." bind:value={query} oninput={handleInput} class="gif-search" />
  <div class="gif-grid">
    {#if loading}
      <div class="gif-loading">Loading...</div>
    {:else}
      {#each results as gif}
        <button class="gif-item" onclick={() => onSelect(gif.url, gif.preview)}>
          <img src={gif.preview} alt="GIF" loading="lazy" />
        </button>
      {/each}
    {/if}
  </div>
  <div class="gif-powered">Powered by Tenor</div>
</div>

<style>
  .gif-picker { width: 280px; max-height: 320px; display: flex; flex-direction: column; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); box-shadow: 0 8px 24px rgba(0,0,0,0.4); overflow: hidden; }
  .gif-search { padding: 8px 10px; border: none; border-bottom: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-primary); font-size: 12px; outline: none; }
  .gif-grid { flex: 1; overflow-y: auto; display: grid; grid-template-columns: repeat(2, 1fr); gap: 2px; padding: 4px; }
  .gif-item { padding: 0; border: none; background: none; cursor: pointer; border-radius: 4px; overflow: hidden; }
  .gif-item:hover { outline: 2px solid var(--accent); }
  .gif-item img { width: 100%; height: 80px; object-fit: cover; display: block; }
  .gif-loading { grid-column: 1/-1; text-align: center; padding: 20px; color: var(--text-muted); font-size: 12px; }
  .gif-powered { text-align: center; padding: 3px; font-size: 9px; color: var(--text-muted); border-top: 1px solid var(--border-color); }
</style>
