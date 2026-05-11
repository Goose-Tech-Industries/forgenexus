<script lang="ts">
  import { themeStore } from '$lib/stores/theme.svelte';

  let {
    value = $bindable<string | null>(null)
  }: {
    value: string | null;
  } = $props();

  function selectTheme(themeId: string | null) {
    value = themeId;
    themeStore.applyTheme(themeId);
  }
</script>

<div class="theme-picker">
  <label class="picker-label">Site Theme</label>
  <div class="theme-grid">
    <!-- Default / None -->
    <button
      type="button"
      class="theme-card"
      class:active={!value}
      onclick={() => selectTheme(null)}
    >
      <div class="theme-swatches">
        <div class="swatch" style:background="#0a0e17"></div>
        <div class="swatch" style:background="#111827"></div>
        <div class="swatch" style:background="#00d4aa"></div>
        <div class="swatch" style:background="#e2e8f0"></div>
      </div>
      <span class="theme-name">Default</span>
    </button>

    {#each themeStore.themes as theme}
      <button
        type="button"
        class="theme-card"
        class:active={value === theme.id}
        onclick={() => selectTheme(theme.id)}
      >
        <div class="theme-swatches">
          <div class="swatch" style:background={theme.variables.bg_primary || '#0a0e17'}></div>
          <div class="swatch" style:background={theme.variables.bg_secondary || '#111827'}></div>
          <div class="swatch" style:background={theme.variables.accent || '#00d4aa'}></div>
          <div class="swatch" style:background={theme.variables.text_primary || '#e2e8f0'}></div>
        </div>
        <span class="theme-name">{theme.name}</span>
      </button>
    {/each}
  </div>
</div>

<style>
  .theme-picker {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .picker-label {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary);
  }

  .theme-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
    gap: 8px;
  }

  .theme-card {
    background: var(--bg-secondary);
    border: 2px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 10px;
    cursor: pointer;
    transition: all 0.15s;
    text-align: center;
  }
  .theme-card:hover {
    border-color: var(--border-accent);
  }
  .theme-card.active {
    border-color: var(--accent);
    box-shadow: 0 0 8px var(--accent-glow);
  }

  .theme-swatches {
    display: flex;
    gap: 4px;
    margin-bottom: 6px;
    justify-content: center;
  }

  .swatch {
    width: 24px;
    height: 24px;
    border-radius: var(--radius);
    border: 1px solid rgba(255, 255, 255, 0.1);
  }

  .theme-name {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-primary);
  }
</style>
