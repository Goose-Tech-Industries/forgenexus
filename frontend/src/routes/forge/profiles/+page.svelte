<script lang="ts">
  import { onMount } from 'svelte';
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';
  import { toast } from '$lib/stores/toast.svelte';
  import { goto } from '$app/navigation';

  type Tab = 'featured' | 'trending' | 'new' | 'mine';

  let activeTab = $state<Tab>('featured');
  let activeVibe = $state<string | null>(null);
  let vocab = $state<{ vibes: string[]; fonts: string[] } | null>(null);
  let codes = $state<any[]>([]);
  let loading = $state(true);
  let applyLoadingCode = $state<string | null>(null);
  let pasteInput = $state('');

  // Save-as dialog
  let showSaveAs = $state(false);
  let saveName = $state('');
  let saveDescription = $state('');
  let saveVibe = $state('default');
  let savePublic = $state(true);
  let saveRemixable = $state(true);
  let saving = $state(false);

  async function load() {
    loading = true;
    try {
      if (!vocab) vocab = await api.getForgeVocabulary();
      if (activeTab === 'mine') {
        if (!auth.isLoggedIn) {
          codes = [];
          return;
        }
        const res = await api.getMyForgeCodes();
        codes = res.codes || [];
      } else {
        const res = await api.getForgeGallery(activeTab, activeVibe || undefined, 24, 0);
        codes = res.codes || [];
      }
    } catch (e: any) {
      toast.error(e?.error || 'Failed to load Forge Codes');
      codes = [];
    }
    loading = false;
  }

  onMount(load);

  $effect(() => {
    void activeTab;
    void activeVibe;
    load();
  });

  async function applyCode(code: string) {
    if (!auth.isLoggedIn) {
      toast.error('Sign in to apply Forge Codes');
      return;
    }
    applyLoadingCode = code;
    try {
      await api.applyForgeCode(code);
      toast.success(`Applied Forge Code ${code}`);
      if (auth.user?.slug) goto(`/profile/${auth.user.slug}`);
    } catch (e: any) {
      toast.error(e?.error || 'Could not apply Forge Code');
    }
    applyLoadingCode = null;
  }

  async function applyFromPaste() {
    const raw = pasteInput.trim().toLowerCase().replace(/^forge[- ]*/i, '').replace(/[^a-z0-9-]/g, '');
    if (!raw) { toast.error('Paste a Forge Code first'); return; }
    await applyCode(raw);
  }

  async function saveMyProfile() {
    if (!saveName.trim()) { toast.error('Name is required'); return; }
    saving = true;
    try {
      const res = await api.createForgeCode({
        name: saveName.trim(),
        description: saveDescription.trim() || null,
        vibe_tag: saveVibe,
        is_public: savePublic,
        is_remixable: saveRemixable
      });
      toast.success(`Saved as ${res.code.code}`);
      showSaveAs = false;
      saveName = '';
      saveDescription = '';
      activeTab = 'mine';
      await load();
    } catch (e: any) {
      toast.error(e?.error || 'Failed to save Forge Code');
    }
    saving = false;
  }

  async function deleteCode(code: string) {
    if (!confirm(`Delete Forge Code ${code}? This can't be undone.`)) return;
    try {
      await api.deleteForgeCode(code);
      toast.success('Deleted');
      await load();
    } catch (e: any) {
      toast.error(e?.error || 'Delete failed');
    }
  }

  function previewSwatches(config: any): string[] {
    const bg = config?.background;
    const bgColor = bg?.type === 'color' ? bg.color : bg?.type === 'gradient' ? bg.start : '#1a2030';
    const bgColor2 = bg?.type === 'gradient' ? bg.end : (bg?.type === 'color' ? bg.color : '#0a0e17');
    const accent = config?.accent || config?.color_overrides?.accent || '#00d4aa';
    return [bgColor, bgColor2, accent];
  }
</script>

<div class="forge-gallery">
  <header class="forge-header">
    <div>
      <h1>✦ Forge Codes</h1>
      <p class="tagline">Shareable profile themes. No CSS, no risk, pure style.</p>
    </div>
    {#if auth.isLoggedIn}
      <button class="btn-primary" onclick={() => (showSaveAs = true)}>Save My Profile as a Forge Code</button>
    {/if}
  </header>

  <!-- Apply-by-code paste bar -->
  <div class="paste-bar">
    <input
      type="text"
      bind:value={pasteInput}
      placeholder="Paste a Forge Code (e.g. a7k9-m2xq)"
      class="paste-input"
      onkeydown={(e) => e.key === 'Enter' && applyFromPaste()}
    />
    <button class="btn-primary" onclick={applyFromPaste} disabled={!pasteInput.trim()}>Apply</button>
  </div>

  <!-- Tabs + filters -->
  <div class="tab-row">
    {#each ['featured','trending','new','mine'] as t}
      <button class="tab" class:active={activeTab === t} onclick={() => (activeTab = t as Tab)}>
        {t.charAt(0).toUpperCase() + t.slice(1)}
      </button>
    {/each}
  </div>

  {#if activeTab !== 'mine'}
    <div class="vibe-filters">
      <button class="vibe-chip" class:active={!activeVibe} onclick={() => (activeVibe = null)}>all</button>
      {#each (vocab?.vibes || []) as v}
        <button class="vibe-chip vibe-{v}" class:active={activeVibe === v} onclick={() => (activeVibe = v === activeVibe ? null : v)}>{v}</button>
      {/each}
    </div>
  {/if}

  <!-- Grid -->
  {#if loading}
    <div class="loading">Loading…</div>
  {:else if codes.length === 0}
    <div class="empty">
      {#if activeTab === 'mine'}
        You haven't saved any Forge Codes yet. Customize your profile in <a href="/settings/profile">settings</a>, then click "Save My Profile as a Forge Code".
      {:else}
        No Forge Codes in this tab yet. Be first — save your profile as one!
      {/if}
    </div>
  {:else}
    <div class="grid">
      {#each codes as fc (fc.code)}
        {@const swatches = previewSwatches(fc.config)}
        <div class="card" style:background={`linear-gradient(135deg, ${swatches[0]}, ${swatches[1]})`}>
          <div class="card-inner">
            <div class="card-head">
              <span class="card-vibe vibe-{fc.vibe_tag || 'default'}">{fc.vibe_tag || 'default'}</span>
              {#if fc.is_official}<span class="badge-official">★ Official</span>{/if}
              {#if !fc.is_public}<span class="badge-private">🔒 Private</span>{/if}
            </div>
            <h3 class="card-name" style:color={swatches[2]}>{fc.name}</h3>
            {#if fc.description}
              <p class="card-desc">{fc.description}</p>
            {/if}
            <div class="card-swatches">
              {#each swatches as swatch}
                <span class="swatch" style:background={swatch}></span>
              {/each}
            </div>
            <div class="card-meta">
              {#if fc.owner}
                <a href="/profile/{fc.owner.slug}" class="card-owner">@{fc.owner.username}</a>
              {/if}
              <span class="card-applies">↻ {fc.applies_count}</span>
            </div>
            <code class="card-code">forge-{fc.code}</code>
            <div class="card-actions">
              <button
                class="btn-primary btn-small"
                onclick={() => applyCode(fc.code)}
                disabled={applyLoadingCode === fc.code}
                style:background={swatches[2]}
              >
                {applyLoadingCode === fc.code ? 'Applying…' : 'Apply'}
              </button>
              {#if activeTab === 'mine'}
                <button class="btn-ghost btn-small" onclick={() => deleteCode(fc.code)}>Delete</button>
              {/if}
            </div>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<!-- Save-as dialog -->
{#if showSaveAs}
  <div class="modal-backdrop" onclick={() => (showSaveAs = false)} role="presentation">
    <div class="modal" onclick={(e) => e.stopPropagation()} role="dialog" aria-label="Save profile as Forge Code">
      <h2>Save Profile as a Forge Code</h2>
      <label>
        Name
        <input type="text" bind:value={saveName} placeholder="My Neon Night" maxlength="80" />
      </label>
      <label>
        Description (optional)
        <textarea bind:value={saveDescription} rows="2" maxlength="500" placeholder="What's the vibe?"></textarea>
      </label>
      <label>
        Vibe
        <select bind:value={saveVibe}>
          {#each (vocab?.vibes || []) as v}<option value={v}>{v}</option>{/each}
        </select>
      </label>
      <label class="checkbox">
        <input type="checkbox" bind:checked={savePublic} />
        Show in public gallery
      </label>
      <label class="checkbox">
        <input type="checkbox" bind:checked={saveRemixable} />
        Allow others to apply this theme
      </label>
      <div class="modal-actions">
        <button class="btn-ghost" onclick={() => (showSaveAs = false)}>Cancel</button>
        <button class="btn-primary" onclick={saveMyProfile} disabled={saving}>
          {saving ? 'Saving…' : 'Save Forge Code'}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .forge-gallery { display: flex; flex-direction: column; gap: 20px; }

  .forge-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    flex-wrap: wrap;
    gap: 16px;
  }
  .forge-header h1 { margin: 0; font-size: 2rem; }
  .tagline { margin: 4px 0 0; color: var(--text-secondary, #8a94a6); }

  .paste-bar {
    display: flex;
    gap: 8px;
    padding: 12px;
    background: var(--bg-secondary, #121826);
    border: 1px solid var(--border, #2a3040);
    border-radius: 8px;
  }
  .paste-input {
    flex: 1;
    padding: 8px 12px;
    background: var(--bg-primary, #0a0e17);
    border: 1px solid var(--border, #2a3040);
    border-radius: 4px;
    color: var(--text-primary, #e8eaed);
    font-family: "JetBrains Mono", monospace;
  }

  .tab-row {
    display: flex;
    gap: 4px;
    border-bottom: 1px solid var(--border, #2a3040);
  }
  .tab {
    padding: 8px 16px;
    background: transparent;
    border: none;
    border-bottom: 2px solid transparent;
    color: var(--text-secondary, #8a94a6);
    cursor: pointer;
    font-size: 0.95rem;
  }
  .tab.active { color: var(--accent, #00d4aa); border-bottom-color: var(--accent, #00d4aa); }

  .vibe-filters { display: flex; flex-wrap: wrap; gap: 6px; }
  .vibe-chip {
    padding: 4px 10px;
    border-radius: 999px;
    background: var(--bg-tertiary, #1a2030);
    border: 1px solid var(--border, #2a3040);
    color: var(--text-primary, #e8eaed);
    font-size: 0.82rem;
    cursor: pointer;
    text-transform: lowercase;
  }
  .vibe-chip.active { background: var(--accent, #00d4aa); color: #000; border-color: var(--accent, #00d4aa); }

  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
    gap: 16px;
  }

  .card {
    border-radius: 12px;
    padding: 3px;
    box-shadow: 0 6px 20px rgba(0, 0, 0, 0.4);
    transition: transform 0.15s;
  }
  .card:hover { transform: translateY(-3px); }

  .card-inner {
    background: rgba(10, 14, 23, 0.86);
    backdrop-filter: blur(4px);
    border-radius: 10px;
    padding: 14px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .card-head { display: flex; gap: 6px; flex-wrap: wrap; }
  .card-vibe {
    font-size: 0.7rem;
    text-transform: uppercase;
    padding: 2px 6px;
    border-radius: 3px;
    background: rgba(255,255,255,0.1);
    color: var(--text-primary, #e8eaed);
    letter-spacing: 0.08em;
  }
  .badge-official {
    font-size: 0.7rem;
    padding: 2px 6px;
    background: #ffcc33;
    color: #000;
    border-radius: 3px;
    font-weight: 700;
  }
  .badge-private {
    font-size: 0.7rem;
    padding: 2px 6px;
    background: var(--bg-tertiary, #1a2030);
    color: var(--text-secondary, #8a94a6);
    border-radius: 3px;
  }

  .card-name { margin: 0; font-size: 1.15rem; font-weight: 700; }
  .card-desc { margin: 0; font-size: 0.85rem; color: var(--text-secondary, #8a94a6); line-height: 1.4; }

  .card-swatches { display: flex; gap: 6px; }
  .swatch { width: 22px; height: 22px; border-radius: 50%; border: 1px solid rgba(255,255,255,0.1); }

  .card-meta {
    display: flex;
    justify-content: space-between;
    font-size: 0.8rem;
    color: var(--text-tertiary, #6a748a);
  }
  .card-owner { text-decoration: none; color: inherit; }
  .card-owner:hover { color: var(--accent, #00d4aa); }

  .card-code {
    font-family: "JetBrains Mono", monospace;
    font-size: 0.78rem;
    color: var(--text-secondary, #8a94a6);
    letter-spacing: 0.1em;
  }

  .card-actions { display: flex; gap: 6px; margin-top: 4px; }

  .btn-primary {
    padding: 8px 16px;
    border-radius: 6px;
    border: none;
    background: var(--accent, #00d4aa);
    color: #000;
    font-weight: 700;
    cursor: pointer;
  }
  .btn-primary:disabled { opacity: 0.6; cursor: not-allowed; }
  .btn-small { padding: 5px 12px; font-size: 0.85rem; }
  .btn-ghost {
    padding: 8px 16px;
    border-radius: 6px;
    border: 1px solid var(--border, #2a3040);
    background: transparent;
    color: var(--text-primary, #e8eaed);
    cursor: pointer;
  }

  .loading, .empty {
    text-align: center;
    padding: 48px 20px;
    color: var(--text-secondary, #8a94a6);
  }
  .empty a { color: var(--accent, #00d4aa); }

  .modal-backdrop {
    position: fixed; inset: 0;
    background: rgba(0,0,0,0.75);
    display: flex; align-items: center; justify-content: center;
    z-index: 100;
  }
  .modal {
    width: min(90vw, 500px);
    background: var(--bg-secondary, #121826);
    border: 1px solid var(--border, #2a3040);
    border-radius: 12px;
    padding: 24px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .modal h2 { margin: 0 0 8px; }
  .modal label { display: flex; flex-direction: column; gap: 4px; font-size: 0.9rem; color: var(--text-secondary, #8a94a6); }
  .modal label.checkbox { flex-direction: row; align-items: center; gap: 8px; color: var(--text-primary, #e8eaed); }
  .modal input[type=text], .modal textarea, .modal select {
    padding: 8px 10px;
    background: var(--bg-primary, #0a0e17);
    border: 1px solid var(--border, #2a3040);
    border-radius: 4px;
    color: var(--text-primary, #e8eaed);
    font-family: inherit;
    resize: vertical;
  }
  .modal-actions { display: flex; justify-content: flex-end; gap: 8px; margin-top: 8px; }
</style>
