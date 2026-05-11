<script lang="ts">
  import { STICKER_PACKS, searchStickers, type StickerPack, type Sticker } from '$lib/chat/stickers';

  let { onSelect }: { onSelect: (sticker: string) => void } = $props();
  let activePack = $state<string>(STICKER_PACKS[0]?.id || '');
  let searchQuery = $state('');

  let displayStickers = $derived.by(() => {
    if (searchQuery.trim()) return searchStickers(searchQuery);
    return STICKER_PACKS.find(p => p.id === activePack)?.stickers || [];
  });
</script>

<div class="sticker-picker">
  <input type="text" placeholder="Search stickers..." bind:value={searchQuery} class="sticker-search" />
  <div class="pack-tabs">
    {#each STICKER_PACKS as pack (pack.id)}
      <button
        class="pack-tab"
        class:active={activePack === pack.id && !searchQuery}
        onclick={() => { activePack = pack.id; searchQuery = ''; }}
        title={pack.name}
      >{pack.icon}</button>
    {/each}
  </div>
  <div class="sticker-grid">
    {#each displayStickers as sticker (sticker.id)}
      <button class="sticker-item" onclick={() => onSelect(sticker.emoji)} title={sticker.label}>
        <span class="sticker-emoji">{sticker.emoji}</span>
      </button>
    {/each}
    {#if displayStickers.length === 0}
      <div class="sticker-empty">No stickers found</div>
    {/if}
  </div>
</div>

<style>
  .sticker-picker { width: 260px; max-height: 300px; display: flex; flex-direction: column; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); box-shadow: 0 8px 24px rgba(0,0,0,0.4); overflow: hidden; }
  .sticker-search { padding: 6px 10px; border: none; border-bottom: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-primary); font-size: 12px; outline: none; }
  .pack-tabs { display: flex; gap: 2px; padding: 4px; border-bottom: 1px solid var(--border-color); overflow-x: auto; }
  .pack-tab { padding: 4px 8px; border: none; background: none; cursor: pointer; font-size: 16px; border-radius: 4px; }
  .pack-tab:hover, .pack-tab.active { background: var(--bg-hover); }
  .sticker-grid { flex: 1; overflow-y: auto; display: grid; grid-template-columns: repeat(4, 1fr); gap: 2px; padding: 4px; }
  .sticker-item { padding: 6px; border: none; background: none; cursor: pointer; border-radius: 4px; text-align: center; }
  .sticker-item:hover { background: var(--bg-hover); }
  .sticker-emoji { font-size: 20px; white-space: pre-wrap; line-height: 1.2; }
  .sticker-empty { grid-column: 1/-1; text-align: center; padding: 20px; color: var(--text-muted); font-size: 12px; }
</style>
