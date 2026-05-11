<script lang="ts">
  import { api } from '$lib/api/client';

  interface CustomEmoji {
    id: string; name: string; shortcode: string; image_url: string; category: string; is_animated: boolean; is_active: boolean;
  }

  let emojis = $state<CustomEmoji[]>([]);
  let loading = $state(true);
  let showCreate = $state(false);
  let editingEmoji = $state<CustomEmoji | null>(null);
  let form = $state({ name: '', shortcode: '', image_url: '', category: 'custom', is_animated: false });
  let saving = $state(false);

  $effect(() => { loadEmojis(); });

  async function loadEmojis() {
    loading = true;
    try {
      const data = await api.getAdminEmojis();
      emojis = data.emojis || [];
    } catch { /* silent */ }
    loading = false;
  }

  async function handleSave() {
    saving = true;
    try {
      if (editingEmoji) {
        await api.updateEmoji(editingEmoji.id, form);
      } else {
        await api.createEmoji(form);
      }
      showCreate = false;
      editingEmoji = null;
      form = { name: '', shortcode: '', image_url: '', category: 'custom', is_animated: false };
      await loadEmojis();
    } catch { /* silent */ }
    saving = false;
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this emoji?')) return;
    await api.deleteEmoji(id);
    await loadEmojis();
  }

  async function toggleActive(emoji: CustomEmoji) {
    await api.updateEmoji(emoji.id, { is_active: !emoji.is_active });
    await loadEmojis();
  }

  function startEdit(emoji: CustomEmoji) {
    editingEmoji = emoji;
    form = { name: emoji.name, shortcode: emoji.shortcode, image_url: emoji.image_url, category: emoji.category, is_animated: emoji.is_animated };
    showCreate = true;
  }

  function autoShortcode() {
    if (!editingEmoji && form.name && !form.shortcode) {
      form.shortcode = form.name.toLowerCase().replace(/[^a-z0-9]/g, '_').replace(/_+/g, '_');
    }
  }
</script>

<div class="admin-page">
  <div class="page-header">
    <h1>Custom Emojis</h1>
    <button class="btn-primary" onclick={() => { showCreate = true; editingEmoji = null; form = { name: '', shortcode: '', image_url: '', category: 'custom', is_animated: false }; }}>Add Emoji</button>
  </div>

  {#if showCreate}
    <div class="form-card">
      <h3>{editingEmoji ? 'Edit Emoji' : 'New Custom Emoji'}</h3>
      <div class="form-grid">
        <label>Name <input type="text" bind:value={form.name} oninput={autoShortcode} placeholder="Party Parrot" /></label>
        <label>Shortcode <input type="text" bind:value={form.shortcode} placeholder="party_parrot" /></label>
        <label>Image URL <input type="text" bind:value={form.image_url} placeholder="https://..." /></label>
        <label>Category <input type="text" bind:value={form.category} placeholder="custom" /></label>
        <label class="checkbox"><input type="checkbox" bind:checked={form.is_animated} /> Animated</label>
      </div>
      {#if form.image_url}
        <div class="emoji-preview">
          <span>Preview:</span>
          <img src={form.image_url} alt="preview" class="preview-img" />
          <code>:{form.shortcode || 'shortcode'}:</code>
        </div>
      {/if}
      <div class="form-actions">
        <button onclick={() => { showCreate = false; editingEmoji = null; }}>Cancel</button>
        <button class="btn-primary" onclick={handleSave} disabled={saving || !form.name.trim() || !form.shortcode.trim() || !form.image_url.trim()}>
          {saving ? 'Saving...' : 'Save'}
        </button>
      </div>
    </div>
  {/if}

  {#if loading}
    <p class="loading">Loading...</p>
  {:else if emojis.length === 0}
    <p class="empty">No custom emojis yet.</p>
  {:else}
    <div class="emoji-grid">
      {#each emojis as emoji}
        <div class="emoji-card" class:inactive={!emoji.is_active}>
          <img src={emoji.image_url} alt={emoji.name} class="emoji-img" />
          <div class="emoji-info">
            <div class="emoji-name">{emoji.name}</div>
            <code class="emoji-code">:{emoji.shortcode}:</code>
          </div>
          <div class="emoji-actions">
            <button class="btn-sm" onclick={() => toggleActive(emoji)}>{emoji.is_active ? 'Disable' : 'Enable'}</button>
            <button class="btn-sm" onclick={() => startEdit(emoji)}>Edit</button>
            <button class="btn-sm danger" onclick={() => handleDelete(emoji.id)}>Delete</button>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .admin-page { max-width: 900px; }
  .page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
  .page-header h1 { font-size: 20px; font-weight: 800; }
  .btn-primary { background: var(--accent); color: var(--bg-primary); border: none; padding: 8px 16px; border-radius: var(--radius); font-weight: 600; cursor: pointer; font-family: inherit; font-size: 13px; }
  .form-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 20px; margin-bottom: 20px; }
  .form-card h3 { font-size: 15px; font-weight: 700; margin-bottom: 12px; }
  .form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 16px; }
  .form-grid label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  .form-grid input[type="text"] { padding: 8px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: inherit; font-size: 13px; }
  .form-grid .checkbox { flex-direction: row; align-items: center; gap: 8px; }
  .emoji-preview { display: flex; align-items: center; gap: 10px; padding: 10px; background: var(--bg-primary); border-radius: var(--radius); margin-bottom: 12px; font-size: 12px; color: var(--text-muted); }
  .preview-img { width: 32px; height: 32px; object-fit: contain; }
  .form-actions { display: flex; gap: 8px; justify-content: flex-end; }
  .form-actions button { padding: 8px 16px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; font-size: 13px; }
  .emoji-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 12px; }
  .emoji-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 14px; display: flex; flex-direction: column; align-items: center; gap: 8px; text-align: center; }
  .emoji-card.inactive { opacity: 0.4; }
  .emoji-img { width: 48px; height: 48px; object-fit: contain; }
  .emoji-name { font-weight: 600; font-size: 13px; }
  .emoji-code { font-size: 11px; color: var(--text-muted); }
  .emoji-actions { display: flex; gap: 6px; }
  .btn-sm { padding: 4px 10px; font-size: 11px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; }
  .btn-sm.danger { color: #f87171; border-color: rgba(248,113,113,0.3); }
  .loading, .empty { text-align: center; color: var(--text-muted); padding: 40px; }
</style>
