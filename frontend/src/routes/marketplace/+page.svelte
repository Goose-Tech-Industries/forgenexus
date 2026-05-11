<script lang="ts">
  import { api } from '$lib/api/client';

  let templates = $state<any[]>([]);
  let plugins = $state<any[]>([]);
  let tab = $state<'templates' | 'plugins'>('templates');
  let loading = $state(true);

  $effect(() => { loadAll(); });

  async function loadAll() {
    const [t, p] = await Promise.allSettled([
      api.request('/marketplace/templates'),
      api.request('/marketplace/plugins')
    ]);
    if (t.status === 'fulfilled') templates = t.value.templates || [];
    if (p.status === 'fulfilled') plugins = p.value.plugins || [];
    loading = false;
  }

  function formatPrice(cents: number): string {
    if (!cents || cents === 0) return 'Free';
    return `$${(cents / 100).toFixed(2)}`;
  }
</script>

<svelte:head>
  <title>Marketplace — ForgeNexus</title>
</svelte:head>

<div class="marketplace">
  <div class="marketplace-header">
    <h1 class="text-glow">Marketplace</h1>
    <p>Templates, plugins, and tools to supercharge your community.</p>
  </div>

  <div class="tab-bar glass">
    <button class="tab" class:active={tab === 'templates'} onclick={() => tab = 'templates'}>
      🎨 Templates
    </button>
    <button class="tab" class:active={tab === 'plugins'} onclick={() => tab = 'plugins'}>
      🔌 Plugins
    </button>
  </div>

  <div class="items-grid stagger">
    {#if tab === 'templates'}
      {#each templates as t (t.id)}
        <div class="item-card card-elevated card-glow">
          {#if t.preview_url}
            <img src={t.preview_url} alt={t.name} class="item-preview" />
          {:else}
            <div class="item-preview-placeholder">🎨</div>
          {/if}
          <div class="item-info">
            <h3>{t.name}</h3>
            <p>{t.description?.slice(0, 100) || ''}</p>
            <div class="item-footer">
              <span class="item-price" class:free={!t.price_cents}>{formatPrice(t.price_cents)}</span>
              <span class="item-installs">📥 {t.install_count}</span>
            </div>
          </div>
        </div>
      {:else}
        <div class="empty glass">No templates yet. Be the first to create one!</div>
      {/each}
    {:else}
      {#each plugins as p (p.id)}
        <div class="item-card card-elevated card-glow">
          <div class="item-preview-placeholder">🔌</div>
          <div class="item-info">
            <h3>{p.name}</h3>
            <p>{p.description?.slice(0, 100) || ''}</p>
            <div class="item-footer">
              <span class="item-price" class:free={!p.price_cents}>{formatPrice(p.price_cents)}</span>
              <span class="item-installs">📥 {p.install_count}</span>
            </div>
          </div>
        </div>
      {:else}
        <div class="empty glass">No plugins yet. Build one with the plugin SDK!</div>
      {/each}
    {/if}
  </div>
</div>

<style>
  .marketplace { max-width: 1000px; margin: 0 auto; padding: 24px 16px; }
  .marketplace-header { text-align: center; margin-bottom: 24px; }
  .marketplace-header h1 { font-size: 28px; font-weight: 800; }
  .marketplace-header p { color: var(--text-secondary); }

  .tab-bar { display: flex; gap: 4px; padding: 4px; margin-bottom: 20px; width: fit-content; }
  .tab {
    padding: 8px 20px; border: none; background: transparent;
    color: var(--text-muted); font-size: 14px; font-weight: 600;
    border-radius: var(--radius-md); cursor: pointer;
    transition: all var(--transition-fast);
  }
  .tab:hover { background: var(--bg-hover); color: var(--text-primary); }
  .tab.active { background: var(--accent-gradient); color: var(--bg-primary); }

  .items-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 16px; }

  .item-card { overflow: hidden; }
  .item-preview { width: 100%; height: 140px; object-fit: cover; }
  .item-preview-placeholder {
    width: 100%; height: 100px; display: flex; align-items: center;
    justify-content: center; font-size: 40px; background: var(--bg-elevated);
  }
  .item-info { padding: 14px; }
  .item-info h3 { font-size: 15px; font-weight: 700; margin-bottom: 4px; }
  .item-info p { font-size: 13px; color: var(--text-secondary); margin-bottom: 10px; }
  .item-footer { display: flex; justify-content: space-between; align-items: center; }
  .item-price { font-weight: 700; color: var(--accent); }
  .item-price.free { color: var(--success); }
  .item-installs { font-size: 12px; color: var(--text-muted); }

  .empty { padding: 40px; text-align: center; color: var(--text-muted); grid-column: 1 / -1; }
</style>
