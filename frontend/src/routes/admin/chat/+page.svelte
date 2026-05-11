<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';

  interface Category {
    id: string; name: string; slug: string; position: number;
  }
  interface Channel {
    id: string; name: string; slug: string; description: string | null; topic: string | null;
    type: string; icon: string | null; color: string | null; position: number;
    category_id: string | null; is_private: boolean; is_read_only: boolean; is_archived: boolean;
    is_nsfw: boolean; slowmode_seconds: number; message_count: number;
    allowed_group_ids: string[];
  }

  let categories = $state<Category[]>([]);
  let channels = $state<Channel[]>([]);
  let loading = $state(true);
  let error = $state('');

  // Modal state
  let showModal = $state(false);
  let modalType = $state<'category' | 'channel'>('channel');
  let editing = $state<any>(null);
  let form = $state<Record<string, any>>({});
  let saving = $state(false);

  $effect(() => { loadAll(); });

  async function loadAll() {
    loading = true;
    try {
      const [catData, chData] = await Promise.all([
        api.getAdminChatCategories(),
        api.getAdminChatChannels()
      ]);
      categories = catData.categories || [];
      channels = chData.channels || [];
    } catch (e: any) {
      error = e.error || 'Failed to load';
    }
    loading = false;
  }

  function channelsForCategory(catId: string): Channel[] {
    return channels.filter(c => c.category_id === catId).sort((a, b) => a.position - b.position);
  }

  function uncategorizedChannels(): Channel[] {
    return channels.filter(c => !c.category_id).sort((a, b) => a.position - b.position);
  }

  // Category CRUD
  function openCreateCategory() {
    modalType = 'category';
    editing = null;
    form = { name: '', slug: '', position: categories.length };
    showModal = true;
  }

  function openEditCategory(cat: Category) {
    modalType = 'category';
    editing = cat;
    form = { ...cat };
    showModal = true;
  }

  async function saveCategory() {
    saving = true;
    error = '';
    try {
      if (editing) {
        await api.updateChatCategory(editing.id, form);
      } else {
        await api.createChatCategory(form);
      }
      showModal = false;
      await loadAll();
    } catch (e: any) { error = e.error || 'Failed to save'; }
    saving = false;
  }

  async function deleteCategory(cat: Category) {
    if (!confirm(`Delete category "${cat.name}"? Channels will become uncategorized.`)) return;
    try { await api.deleteChatCategory(cat.id); await loadAll(); } catch (e: any) { error = e.error || 'Failed'; }
  }

  // Channel CRUD
  function openCreateChannel(categoryId?: string) {
    modalType = 'channel';
    editing = null;
    form = {
      name: '', slug: '', description: '', topic: '', type: 'text', icon: '', color: '',
      position: 0, category_id: categoryId || '', is_private: false, is_read_only: false,
      is_archived: false, is_nsfw: false, slowmode_seconds: 0, allowed_group_ids: []
    };
    showModal = true;
  }

  function openEditChannel(ch: Channel) {
    modalType = 'channel';
    editing = ch;
    form = { ...ch, category_id: ch.category_id || '' };
    showModal = true;
  }

  async function saveChannel() {
    saving = true;
    error = '';
    try {
      const data = { ...form, category_id: form.category_id || null };
      if (editing) {
        await api.updateChatChannel(editing.id, data);
      } else {
        await api.createChatChannel(data);
      }
      showModal = false;
      await loadAll();
    } catch (e: any) { error = e.error || 'Failed to save'; }
    saving = false;
  }

  async function deleteChannel(ch: Channel) {
    if (!confirm(`Delete #${ch.name}? All messages will be lost.`)) return;
    try { await api.deleteChatChannel(ch.id); await loadAll(); } catch (e: any) { error = e.error || 'Failed'; }
  }

  async function toggleArchive(ch: Channel) {
    try {
      if (ch.is_archived) await api.unarchiveChatChannel(ch.id);
      else await api.archiveChatChannel(ch.id);
      await loadAll();
    } catch (e: any) { error = e.error || 'Failed'; }
  }

  function autoSlug() {
    if (form.name && !editing) {
      form.slug = form.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
    }
  }
</script>

<div class="page-header">
  <div>
    <h1>Chat Channel Management</h1>
    <p class="subtitle">Create and manage chat channels, categories, and permissions. Admins can edit everything.</p>
  </div>
  <div class="header-actions">
    <button class="btn-secondary" onclick={openCreateCategory}>+ Category</button>
    <button class="btn-primary" onclick={() => openCreateChannel()}>+ Channel</button>
  </div>
</div>

{#if error}
  <div class="error-banner">{error} <button onclick={() => error = ''}>dismiss</button></div>
{/if}

{#if loading}
  <div class="loading">Loading channels...</div>
{:else}
  <!-- Categories with their channels -->
  {#each categories.sort((a, b) => a.position - b.position) as cat (cat.id)}
    <div class="category-block">
      <div class="cat-header">
        <h2>{cat.name}</h2>
        <div class="cat-actions">
          <button class="btn-tiny" onclick={() => openCreateChannel(cat.id)}>+ Channel</button>
          <button class="btn-tiny" onclick={() => openEditCategory(cat)}>Edit</button>
          <button class="btn-tiny danger" onclick={() => deleteCategory(cat)}>Delete</button>
        </div>
      </div>
      <div class="channels-list">
        {#each channelsForCategory(cat.id) as ch (ch.id)}
          <div class="channel-row" class:archived={ch.is_archived}>
            <div class="ch-icon">{ch.icon || '#'}</div>
            <div class="ch-info">
              <span class="ch-name">{ch.name}</span>
              {#if ch.description}<span class="ch-desc">{ch.description}</span>{/if}
              <div class="ch-badges">
                {#if ch.is_private}<span class="badge private">Private</span>{/if}
                {#if ch.is_read_only}<span class="badge readonly">Read-Only</span>{/if}
                {#if ch.is_archived}<span class="badge archived">Archived</span>{/if}
                {#if ch.slowmode_seconds > 0}<span class="badge slow">Slow {ch.slowmode_seconds}s</span>{/if}
                <span class="badge count">{ch.message_count} msgs</span>
              </div>
            </div>
            <div class="ch-actions">
              <button class="btn-tiny" onclick={() => toggleArchive(ch)}>{ch.is_archived ? 'Unarchive' : 'Archive'}</button>
              <button class="btn-tiny" onclick={() => openEditChannel(ch)}>Edit</button>
              <button class="btn-tiny danger" onclick={() => deleteChannel(ch)}>Delete</button>
            </div>
          </div>
        {/each}
        {#if channelsForCategory(cat.id).length === 0}
          <div class="empty-cat">No channels in this category</div>
        {/if}
      </div>
    </div>
  {/each}

  <!-- Uncategorized channels -->
  {#if uncategorizedChannels().length > 0}
    <div class="category-block">
      <div class="cat-header"><h2>Uncategorized</h2></div>
      <div class="channels-list">
        {#each uncategorizedChannels() as ch (ch.id)}
          <div class="channel-row" class:archived={ch.is_archived}>
            <div class="ch-icon">{ch.icon || '#'}</div>
            <div class="ch-info">
              <span class="ch-name">{ch.name}</span>
              {#if ch.description}<span class="ch-desc">{ch.description}</span>{/if}
            </div>
            <div class="ch-actions">
              <button class="btn-tiny" onclick={() => openEditChannel(ch)}>Edit</button>
              <button class="btn-tiny danger" onclick={() => deleteChannel(ch)}>Delete</button>
            </div>
          </div>
        {/each}
      </div>
    </div>
  {/if}
{/if}

<!-- Modal -->
{#if showModal}
  <div class="modal-overlay" onclick={() => showModal = false}>
    <div class="modal" onclick={(e) => e.stopPropagation()}>
      <h2>{editing ? 'Edit' : 'Create'} {modalType === 'category' ? 'Category' : 'Channel'}</h2>

      {#if modalType === 'category'}
        <div class="form-grid">
          <div class="form-group"><label>Name</label><input type="text" bind:value={form.name} oninput={autoSlug} /></div>
          <div class="form-group"><label>Slug</label><input type="text" bind:value={form.slug} /></div>
          <div class="form-group"><label>Position</label><input type="number" bind:value={form.position} /></div>
        </div>
        <div class="modal-actions">
          <button class="btn-secondary" onclick={() => showModal = false}>Cancel</button>
          <button class="btn-primary" onclick={saveCategory} disabled={saving}>{saving ? 'Saving...' : 'Save'}</button>
        </div>
      {:else}
        <div class="form-grid">
          <div class="form-group"><label>Name</label><input type="text" bind:value={form.name} oninput={autoSlug} placeholder="general" /></div>
          <div class="form-group"><label>Slug</label><input type="text" bind:value={form.slug} /></div>
          <div class="form-group full-width"><label>Description</label><input type="text" bind:value={form.description} placeholder="What's this channel for?" /></div>
          <div class="form-group full-width"><label>Topic</label><input type="text" bind:value={form.topic} placeholder="Current topic (shown in header)" /></div>
          <div class="form-group">
            <label>Type</label>
            <select bind:value={form.type}>
              <option value="text">Text</option>
              <option value="voice">Voice</option>
              <option value="announcements">Announcements</option>
            </select>
          </div>
          <div class="form-group">
            <label>Category</label>
            <select bind:value={form.category_id}>
              <option value="">None</option>
              {#each categories as cat}<option value={cat.id}>{cat.name}</option>{/each}
            </select>
          </div>
          <div class="form-group"><label>Icon (emoji)</label><input type="text" bind:value={form.icon} placeholder="#" /></div>
          <div class="form-group"><label>Color</label><input type="color" bind:value={form.color} /></div>
          <div class="form-group"><label>Slowmode (seconds)</label><input type="number" bind:value={form.slowmode_seconds} min="0" max="3600" /></div>
          <div class="form-group"><label>Position</label><input type="number" bind:value={form.position} /></div>
        </div>

        <h3 class="section-label">Permissions</h3>
        <div class="perks-grid">
          <label class="toggle-row"><input type="checkbox" bind:checked={form.is_private} /><span>Private (visible only to allowed groups)</span></label>
          <label class="toggle-row"><input type="checkbox" bind:checked={form.is_read_only} /><span>Read-only (only staff can post)</span></label>
          <label class="toggle-row"><input type="checkbox" bind:checked={form.is_nsfw} /><span>NSFW (age-gated)</span></label>
          <label class="toggle-row"><input type="checkbox" bind:checked={form.is_archived} /><span>Archived (read-only + dimmed)</span></label>
        </div>

        <div class="modal-actions">
          <button class="btn-secondary" onclick={() => showModal = false}>Cancel</button>
          <button class="btn-primary" onclick={saveChannel} disabled={saving}>{saving ? 'Saving...' : 'Save'}</button>
        </div>
      {/if}
    </div>
  </div>
{/if}

<style>
  .page-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 20px; }
  .page-header h1 { font-size: 20px; font-weight: 800; margin: 0; }
  .subtitle { font-size: 12px; color: var(--text-secondary); margin-top: 4px; }
  .header-actions { display: flex; gap: 8px; }

  .btn-primary { background: var(--accent); color: var(--bg-primary); border: none; padding: 8px 16px; border-radius: var(--radius); font-weight: 700; font-size: 13px; cursor: pointer; }
  .btn-primary:hover { opacity: 0.9; }
  .btn-primary:disabled { opacity: 0.5; }
  .btn-secondary { background: var(--bg-tertiary); color: var(--text-primary); border: 1px solid var(--border-color); padding: 8px 16px; border-radius: var(--radius); font-weight: 600; font-size: 13px; cursor: pointer; }
  .btn-tiny { padding: 3px 8px; font-size: 11px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-secondary); cursor: pointer; font-weight: 600; }
  .btn-tiny:hover { background: var(--bg-hover, rgba(255,255,255,0.05)); }
  .btn-tiny.danger { color: #ef4444; }
  .btn-tiny.danger:hover { background: rgba(239, 68, 68, 0.1); }

  .error-banner { background: rgba(239,68,68,0.1); border: 1px solid rgba(239,68,68,0.3); color: #ef4444; padding: 10px 14px; border-radius: var(--radius); font-size: 13px; margin-bottom: 16px; display: flex; justify-content: space-between; align-items: center; }
  .error-banner button { background: none; border: none; color: #ef4444; cursor: pointer; font-size: 12px; }
  .loading { text-align: center; padding: 40px; color: var(--text-muted); }

  .category-block { margin-bottom: 16px; background: var(--bg-card, var(--bg-secondary)); border: 1px solid var(--border-color); border-radius: var(--radius-lg); overflow: hidden; }
  .cat-header { display: flex; align-items: center; justify-content: space-between; padding: 12px 16px; border-bottom: 1px solid var(--border-color); }
  .cat-header h2 { font-size: 14px; font-weight: 700; margin: 0; text-transform: uppercase; letter-spacing: 0.03em; color: var(--text-secondary); }
  .cat-actions { display: flex; gap: 4px; }

  .channels-list { padding: 4px 0; }
  .channel-row { display: flex; align-items: center; gap: 12px; padding: 10px 16px; transition: background 0.1s; }
  .channel-row:hover { background: rgba(255,255,255,0.02); }
  .channel-row.archived { opacity: 0.5; }
  .ch-icon { font-size: 18px; width: 24px; text-align: center; color: var(--text-muted); font-weight: 800; }
  .ch-info { flex: 1; min-width: 0; }
  .ch-name { font-size: 14px; font-weight: 600; display: block; }
  .ch-desc { font-size: 11px; color: var(--text-muted); display: block; margin-top: 1px; }
  .ch-badges { display: flex; gap: 4px; margin-top: 4px; }
  .badge { font-size: 9px; font-weight: 700; padding: 1px 5px; border-radius: 3px; text-transform: uppercase; }
  .badge.private { background: rgba(168,85,247,0.15); color: #a855f7; }
  .badge.readonly { background: rgba(100,116,139,0.15); color: #94a3b8; }
  .badge.archived { background: rgba(251,191,36,0.15); color: #fbbf24; }
  .badge.slow { background: rgba(6,182,212,0.15); color: #06b6d4; }
  .badge.count { background: rgba(255,255,255,0.05); color: var(--text-muted); }
  .ch-actions { display: flex; gap: 4px; flex-shrink: 0; }
  .empty-cat { padding: 16px; text-align: center; font-size: 12px; color: var(--text-muted); }

  /* Modal */
  .modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.6); display: flex; align-items: flex-start; justify-content: center; padding: 40px 16px; z-index: 1000; overflow-y: auto; }
  .modal { background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 24px; max-width: 600px; width: 100%; }
  .modal h2 { font-size: 18px; font-weight: 800; margin: 0 0 16px; }
  .form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  .form-group { display: flex; flex-direction: column; gap: 4px; }
  .form-group.full-width { grid-column: 1 / -1; }
  .form-group label { font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-muted); letter-spacing: 0.03em; }
  .form-group input, .form-group select { background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); padding: 8px 10px; font-size: 13px; color: var(--text-primary); font-family: inherit; }
  .form-group input:focus, .form-group select:focus { outline: none; border-color: var(--accent); }
  .section-label { font-size: 13px; font-weight: 700; margin: 16px 0 10px; padding-top: 12px; border-top: 1px solid var(--border-color); }
  .perks-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
  .toggle-row { display: flex; align-items: center; gap: 8px; font-size: 12px; color: var(--text-secondary); cursor: pointer; }
  .toggle-row input[type="checkbox"] { accent-color: var(--accent); width: 16px; height: 16px; }
  .modal-actions { display: flex; justify-content: flex-end; gap: 8px; margin-top: 20px; padding-top: 16px; border-top: 1px solid var(--border-color); }
</style>
