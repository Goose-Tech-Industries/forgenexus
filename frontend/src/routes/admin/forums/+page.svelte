<script lang="ts">
  import { admin } from '$lib/stores/admin.svelte';
  import { api } from '$lib/api/client';
  import DraggableList from '$lib/components/admin/DraggableList.svelte';

  let loading = $state(true);
  let categories = $state<any[]>([]);
  let saving = $state(false);
  let saveMessage = $state('');

  // Create/Edit modals
  let showCategoryForm = $state(false);
  let showForumForm = $state(false);
  let editingCategory = $state<any>(null);
  let editingForum = $state<any>(null);
  let formCategoryId = $state('');

  // Form fields
  let formName = $state('');
  let formDescription = $state('');
  let formColor = $state('#00d4aa');
  let formIcon = $state('');
  let formIsVisible = $state(true);
  let formIsLocked = $state(false);
  let formIsPrivate = $state(false);
  let formRequireApproval = $state(false);
  let formAllowRatings = $state(false);
  let formMinPostLength = $state(1);
  let formRules = $state('');
  let formParentId = $state('');

  $effect(() => { load(); });

  async function load() {
    loading = true;
    try {
      const d = await api.getAdminForums();
      categories = d.categories || [];
    } catch {
      const d = await api.getForums();
      categories = d.categories || [];
    } finally { loading = false; }
  }

  function openCategoryForm(cat?: any) {
    editingCategory = cat || null;
    formName = cat?.name || '';
    formDescription = cat?.description || '';
    formColor = cat?.color || '#00d4aa';
    formIcon = cat?.icon || '';
    formIsVisible = cat?.is_visible ?? true;
    showCategoryForm = true;
    showForumForm = false;
  }

  function openForumForm(categoryId: string, forum?: any) {
    editingForum = forum || null;
    formCategoryId = categoryId;
    formName = forum?.name || '';
    formDescription = forum?.description || '';
    formColor = forum?.color || '#3b82f6';
    formIcon = forum?.icon || '';
    formIsVisible = forum?.is_visible ?? true;
    formIsLocked = forum?.is_locked ?? false;
    formIsPrivate = forum?.is_private ?? false;
    formRequireApproval = forum?.require_post_approval ?? false;
    formAllowRatings = forum?.allow_thread_ratings ?? false;
    formMinPostLength = forum?.min_post_length ?? 1;
    formRules = forum?.rules || '';
    formParentId = forum?.parent_id || '';
    showForumForm = true;
    showCategoryForm = false;
  }

  async function saveCategory() {
    saving = true;
    try {
      const data = { name: formName, description: formDescription, color: formColor, icon: formIcon, is_visible: formIsVisible };
      if (editingCategory) {
        await api.updateAdminCategory(editingCategory.id, data);
      } else {
        await api.createAdminCategory(data);
      }
      showCategoryForm = false;
      saveMessage = editingCategory ? 'Category updated!' : 'Category created!';
      await load();
    } catch { saveMessage = 'Failed to save category'; }
    finally { saving = false; }
  }

  async function saveForum() {
    saving = true;
    try {
      const data: any = { name: formName, description: formDescription, color: formColor, icon: formIcon, is_visible: formIsVisible, is_locked: formIsLocked, is_private: formIsPrivate, require_post_approval: formRequireApproval, allow_thread_ratings: formAllowRatings, min_post_length: formMinPostLength, rules: formRules, category_id: formCategoryId, parent_id: formParentId || null };
      if (editingForum) {
        await api.updateAdminForum(editingForum.id, data);
      } else {
        await api.createAdminForum(data);
      }
      showForumForm = false;
      saveMessage = editingForum ? 'Forum updated!' : 'Forum created!';
      await load();
    } catch { saveMessage = 'Failed to save forum'; }
    finally { saving = false; }
  }

  async function deleteCategory(id: string, name: string) {
    if (!confirm(`Delete category "${name}" and all its forums?`)) return;
    await api.deleteAdminCategory(id);
    saveMessage = 'Category deleted';
    await load();
  }

  async function deleteForum(id: string, name: string) {
    if (!confirm(`Delete forum "${name}" and all its content?`)) return;
    await api.deleteAdminForum(id);
    saveMessage = 'Forum deleted';
    await load();
  }

  async function handleCategoryReorder(orderedIds: string[]) {
    saving = true; saveMessage = '';
    try { await admin.reorderCategories(orderedIds); saveMessage = 'Categories reordered!'; await load(); }
    catch { saveMessage = 'Failed to reorder'; } finally { saving = false; }
  }

  async function handleForumReorder(categoryId: string, orderedIds: string[]) {
    saving = true; saveMessage = '';
    try { await admin.reorderForums(categoryId, orderedIds); saveMessage = 'Forums reordered!'; await load(); }
    catch { saveMessage = 'Failed to reorder'; } finally { saving = false; }
  }
</script>

<div class="page">
  <div class="page-header">
    <div>
      <h1>Forum Management</h1>
      <p class="subtitle">Create, edit, reorder categories and forums</p>
    </div>
    <div class="header-actions">
      {#if saveMessage}<span class="save-msg" class:error={saveMessage.includes('Failed') || saveMessage.includes('deleted')}>{saveMessage}</span>{/if}
      <button class="btn btn-primary" onclick={() => openCategoryForm()}>New Category</button>
    </div>
  </div>

  <!-- Category/Forum Create/Edit Form -->
  {#if showCategoryForm}
    <div class="form-modal">
      <h3>{editingCategory ? 'Edit' : 'New'} Category</h3>
      <div class="form-grid">
        <div class="field"><label>Name</label><input type="text" bind:value={formName} /></div>
        <div class="field"><label>Description</label><input type="text" bind:value={formDescription} /></div>
        <div class="field"><label>Color</label><input type="color" bind:value={formColor} /></div>
        <div class="field"><label>Icon</label><input type="text" bind:value={formIcon} placeholder="e.g. folder" /></div>
        <label class="toggle"><input type="checkbox" bind:checked={formIsVisible} /> Visible</label>
      </div>
      <div class="form-actions">
        <button class="btn" onclick={() => { showCategoryForm = false; }}>Cancel</button>
        <button class="btn btn-primary" onclick={saveCategory} disabled={saving}>{saving ? 'Saving...' : 'Save'}</button>
      </div>
    </div>
  {/if}

  {#if showForumForm}
    <div class="form-modal">
      <h3>{editingForum ? 'Edit' : 'New'} Forum</h3>
      <div class="form-grid">
        <div class="field"><label>Name</label><input type="text" bind:value={formName} /></div>
        <div class="field"><label>Description</label><input type="text" bind:value={formDescription} /></div>
        <div class="field"><label>Color</label><input type="color" bind:value={formColor} /></div>
        <div class="field"><label>Icon</label><input type="text" bind:value={formIcon} /></div>
        <div class="field">
          <label>Parent Forum (sub-forum of)</label>
          <select bind:value={formParentId} class="form-select">
            <option value="">None (top-level)</option>
            {#each categories as cat}
              {#each (cat.forums || []) as f}
                {#if f.id !== editingForum?.id}
                  <option value={f.id}>{cat.name} &rsaquo; {f.name}</option>
                {/if}
              {/each}
            {/each}
          </select>
        </div>
        <label class="toggle"><input type="checkbox" bind:checked={formIsVisible} /> Visible</label>
        <label class="toggle"><input type="checkbox" bind:checked={formIsLocked} /> Locked</label>
        <label class="toggle"><input type="checkbox" bind:checked={formIsPrivate} /> Private (hidden from public)</label>
        <label class="toggle"><input type="checkbox" bind:checked={formRequireApproval} /> Require Post Approval</label>
        <label class="toggle"><input type="checkbox" bind:checked={formAllowRatings} /> Allow Thread Ratings</label>
        <div class="field"><label>Min Post Length</label><input type="number" bind:value={formMinPostLength} min="1" max="1000" /></div>
        <div class="field full-width"><label>Forum Rules</label><textarea bind:value={formRules} rows="4" placeholder="Optional rules displayed at the top of the forum..."></textarea></div>
      </div>
      <div class="form-actions">
        <button class="btn" onclick={() => { showForumForm = false; }}>Cancel</button>
        <button class="btn btn-primary" onclick={saveForum} disabled={saving}>{saving ? 'Saving...' : 'Save'}</button>
      </div>
    </div>
  {/if}

  {#if loading}
    <p class="loading">Loading forums...</p>
  {:else}
    <section class="section">
      <h2>Category Order</h2>
      <DraggableList
        items={categories.map(c => ({ id: c.id, label: c.name, sublabel: `${c.forums?.length ?? 0} forums` }))}
        onReorder={handleCategoryReorder}
      />
    </section>

    {#each categories as category (category.id)}
      <section class="section">
        <div class="section-header">
          <h2>{category.name}</h2>
          <div class="section-actions">
            <button class="btn-sm" onclick={() => openForumForm(category.id)}>Add Forum</button>
            <button class="btn-sm" onclick={() => openCategoryForm(category)}>Edit</button>
            <button class="btn-sm btn-danger" onclick={() => deleteCategory(category.id, category.name)}>Delete</button>
          </div>
        </div>
        {#if category.forums?.length > 0}
          <DraggableList
            items={category.forums.map((f: any) => ({ id: f.id, label: f.name, sublabel: `${f.thread_count ?? 0} threads` }))}
            onReorder={(ids: string[]) => handleForumReorder(category.id, ids)}
          />
          <div class="forum-actions-row">
            {#each category.forums as forum (forum.id)}
              <div class="forum-action-item">
                <span class="forum-action-name">{forum.name}</span>
                <button class="btn-tiny" onclick={() => openForumForm(category.id, forum)}>Edit</button>
                <button class="btn-tiny btn-danger" onclick={() => deleteForum(forum.id, forum.name)}>Del</button>
              </div>
              {#if forum.children?.length > 0}
                {#each forum.children as child (child.id)}
                  <div class="forum-action-item subforum-item">
                    <span class="subforum-indent">&#8627;</span>
                    <span class="forum-action-name">{child.name}</span>
                    <button class="btn-tiny" onclick={() => openForumForm(category.id, child)}>Edit</button>
                    <button class="btn-tiny btn-danger" onclick={() => deleteForum(child.id, child.name)}>Del</button>
                  </div>
                {/each}
              {/if}
            {/each}
          </div>
        {:else}
          <p class="empty">No forums in this category</p>
        {/if}
      </section>
    {/each}
  {/if}
</div>

<style>
  .page h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); }
  .subtitle { font-size: 12px; color: var(--text-muted); margin-top: 2px; }
  .page-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 20px; }
  .header-actions { display: flex; align-items: center; gap: 10px; }
  .section { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; margin-bottom: 12px; }
  .section h2 { font-size: 13px; font-weight: 700; color: var(--text-primary); text-transform: uppercase; letter-spacing: 0.03em; }
  .section-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; }
  .section-actions { display: flex; gap: 4px; }
  .loading, .empty { color: var(--text-muted); text-align: center; padding: 24px 0; font-size: 13px; }
  .save-msg { font-size: 12px; font-weight: 600; color: #4ade80; }
  .save-msg.error { color: #f87171; }

  .form-modal { background: var(--bg-tertiary); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; margin-bottom: 16px; }
  .form-modal h3 { font-size: 14px; font-weight: 700; color: var(--text-primary); margin-bottom: 12px; }
  .form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 12px; }
  .full-width { grid-column: 1 / -1; }
  .field { display: flex; flex-direction: column; gap: 4px; }
  .field label { font-size: 11px; font-weight: 600; color: var(--text-secondary); }
  input[type="text"], input[type="color"], textarea { padding: 6px 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-input); color: var(--text-primary); font-size: 12px; font-family: inherit; }
  textarea { resize: vertical; width: 100%; }
  input:focus { outline: none; border-color: var(--accent); }
  input[type="color"] { height: 32px; cursor: pointer; }
  .toggle { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--text-secondary); cursor: pointer; }
  .toggle input[type="checkbox"] { width: auto; }
  .form-actions { display: flex; gap: 8px; justify-content: flex-end; }

  .btn { padding: 6px 14px; border-radius: var(--radius); font-size: 12px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); background: var(--bg-card); color: var(--text-secondary); font-family: inherit; }
  .btn-primary { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); }
  .btn:disabled { opacity: 0.5; }
  .btn-sm { padding: 3px 8px; font-size: 10px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-tertiary); color: var(--text-secondary); font-family: inherit; }
  .btn-sm:hover { background: var(--bg-hover); }
  .btn-danger { color: #f87171; border-color: #dc262640; }
  .btn-tiny { padding: 2px 6px; font-size: 9px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-tertiary); color: var(--text-muted); cursor: pointer; font-family: inherit; }

  .forum-actions-row { margin-top: 8px; border-top: 1px solid var(--border-color); padding-top: 8px; }
  .forum-action-item { display: flex; align-items: center; gap: 6px; padding: 3px 0; font-size: 12px; }
  .forum-action-name { flex: 1; color: var(--text-secondary); }
  .subforum-item { padding-left: 20px; }
  .subforum-indent { color: var(--text-muted); font-size: 14px; flex-shrink: 0; }
  .form-select { padding: 6px 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-input); color: var(--text-primary); font-size: 12px; font-family: inherit; width: 100%; }
  .form-select:focus { outline: none; border-color: var(--accent); }
</style>
