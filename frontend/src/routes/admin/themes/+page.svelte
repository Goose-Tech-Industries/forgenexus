<script lang="ts">
  import { admin } from '$lib/stores/admin.svelte';
  let loading = $state(true);
  let showForm = $state(false);
  let newName = $state('');

  $effect(() => { load(); });
  async function load() { loading = true; await admin.loadThemes(); loading = false; }
  async function create() { if (!newName.trim()) return; await admin.createTheme({ name: newName, slug: newName.toLowerCase().replace(/\s+/g, '-') }); showForm = false; newName = ''; await load(); }
  async function setDefault(id: string) { await admin.setDefaultTheme(id); await load(); }
  async function del(id: string, n: string) { if (!confirm(`Delete theme "${n}"?`)) return; await admin.deleteTheme(id); await load(); }
</script>
<div class="page">
  <div class="hdr"><h1>Themes</h1><button class="btn bp" onclick={() => { showForm = !showForm; }}>New Theme</button></div>
  {#if showForm}<div class="form-box">
    <div class="fr"><input type="text" bind:value={newName} placeholder="Theme name" /><button class="btn bp" onclick={create}>Create</button></div>
  </div>{/if}
  {#if loading}<p class="ld">Loading...</p>
  {:else}{#each admin.themes as theme (theme.id)}
    <div class="theme-card">
      <div class="tc-hdr">
        <span class="tc-name">{theme.name}</span>
        {#if theme.is_default}<span class="badge">Default</span>{/if}
        {#if !theme.is_active}<span class="badge bd">Inactive</span>{/if}
        <div class="tc-actions">
          {#if !theme.is_default}<button class="btn-sm" onclick={() => setDefault(theme.id)}>Set Default</button>{/if}
          {#if !theme.is_default}<button class="btn-sm btn-danger" onclick={() => del(theme.id, theme.name)}>Delete</button>{/if}
        </div>
      </div>
      {#if theme.colors}
        <div class="color-grid">
          {#each Object.entries(theme.colors).filter(([k]) => !['__meta__', 'inserted_at', 'updated_at'].includes(k)) as [key, value]}
            {#if value && typeof value === 'string' && value.startsWith('#')}
              <div class="color-swatch">
                <div class="swatch" style="background: {value};"></div>
                <span class="swatch-label">{key.replace(/_/g, ' ')}</span>
              </div>
            {/if}
          {/each}
        </div>
      {/if}
    </div>
  {/each}{/if}
</div>
<style>
  .page h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); }
  .hdr { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
  .form-box { background: var(--bg-tertiary); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 12px; margin-bottom: 16px; }
  .fr { display: flex; gap: 8px; }
  .fr input { flex: 1; padding: 6px 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-input); color: var(--text-primary); font-size: 12px; font-family: inherit; }
  .theme-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 14px; margin-bottom: 10px; }
  .tc-hdr { display: flex; align-items: center; gap: 8px; margin-bottom: 10px; }
  .tc-name { font-size: 14px; font-weight: 700; color: var(--text-primary); }
  .tc-actions { display: flex; gap: 4px; margin-left: auto; }
  .badge { font-size: 9px; padding: 1px 6px; border-radius: 6px; background: var(--accent); color: var(--bg-primary); font-weight: 700; }
  .badge.bd { background: var(--bg-tertiary); color: var(--text-muted); }
  .color-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(100px, 1fr)); gap: 6px; }
  .color-swatch { display: flex; align-items: center; gap: 6px; }
  .swatch { width: 20px; height: 20px; border-radius: 4px; border: 1px solid var(--border-color); }
  .swatch-label { font-size: 10px; color: var(--text-muted); }
  .btn { padding: 6px 14px; border-radius: var(--radius); font-size: 12px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); background: var(--bg-card); color: var(--text-secondary); font-family: inherit; }
  .bp { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); }
  .btn-sm { padding: 3px 8px; font-size: 10px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-tertiary); color: var(--text-secondary); font-family: inherit; }
  .btn-danger { color: #f87171; border-color: #dc262640; }
  .ld { color: var(--text-muted); text-align: center; padding: 32px 0; }
</style>
