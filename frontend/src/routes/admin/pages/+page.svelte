<script lang="ts">
  import { api } from '$lib/api/client';

  interface PluginPage {
    id: string;
    slug: string;
    title: string;
    description: string | null;
    template: Record<string, any>;
    is_published: boolean;
    nav_position: number | null;
    nav_label: string | null;
    flow_id?: string | null;
    inserted_at?: string;
    updated_at?: string;
  }

  interface Flow { id: string; name: string }

  let pages = $state<PluginPage[]>([]);
  let flows = $state<Flow[]>([]);
  let loading = $state(true);
  let error = $state('');

  let showForm = $state(false);
  let editing = $state<PluginPage | null>(null);
  let form = $state({
    slug: '',
    title: '',
    description: '',
    flow_id: '',
    is_published: false,
    nav_label: '',
    nav_position: 0,
    template_json: '{}'
  });
  let saving = $state(false);
  let formError = $state('');

  $effect(() => { load(); });

  async function load() {
    loading = true;
    error = '';
    try {
      const [pagesData, flowsData] = await Promise.all([
        api.getAdminPluginPages(),
        api.request('/admin/plugins/flows').catch(() => ({ flows: [] }))
      ]);
      pages = pagesData.pages || [];
      flows = ((flowsData as any).flows || []).map((f: any) => ({ id: f.id, name: f.name }));
    } catch (err: any) {
      error = err?.error || 'Failed to load plugin pages.';
    }
    loading = false;
  }

  function openCreate() {
    editing = null;
    form = { slug: '', title: '', description: '', flow_id: '', is_published: false, nav_label: '', nav_position: 0, template_json: '{}' };
    formError = '';
    showForm = true;
  }

  function openEdit(page: PluginPage) {
    editing = page;
    form = {
      slug: page.slug,
      title: page.title,
      description: page.description || '',
      flow_id: (page as any).flow_id || '',
      is_published: page.is_published,
      nav_label: page.nav_label || '',
      nav_position: page.nav_position ?? 0,
      template_json: JSON.stringify(page.template || {}, null, 2)
    };
    formError = '';
    showForm = true;
  }

  function autoSlug() {
    if (!editing && form.title && !form.slug) {
      form.slug = form.title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
    }
  }

  async function handleSave() {
    formError = '';
    if (!form.title.trim()) { formError = 'Title is required.'; return; }
    if (!form.slug.trim()) { formError = 'Slug is required.'; return; }
    if (!form.flow_id) { formError = 'A linked flow is required. Create one in Plugins → Flows first.'; return; }

    let template: Record<string, any> = {};
    try {
      const parsed = JSON.parse(form.template_json || '{}');
      if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
        formError = 'Template must be a JSON object.';
        return;
      }
      template = parsed;
    } catch (e: any) {
      formError = 'Invalid template JSON: ' + (e?.message || 'parse error');
      return;
    }

    saving = true;
    const payload: Record<string, any> = {
      slug: form.slug.trim(),
      title: form.title.trim(),
      description: form.description || null,
      flow_id: form.flow_id,
      is_published: form.is_published,
      nav_label: form.nav_label || null,
      nav_position: Number(form.nav_position) || 0,
      template
    };

    try {
      if (editing) {
        await api.updatePluginPage(editing.id, payload);
      } else {
        await api.createPluginPage(payload);
      }
      showForm = false;
      editing = null;
      await load();
    } catch (err: any) {
      formError = err?.error ? JSON.stringify(err.error) : 'Failed to save page.';
    }
    saving = false;
  }

  async function handleDelete(page: PluginPage) {
    if (!confirm(`Delete plugin page "${page.title}" (/p/${page.slug})?`)) return;
    try {
      await api.deletePluginPage(page.id);
      await load();
    } catch (err: any) {
      alert('Failed to delete: ' + (err?.error || 'unknown error'));
    }
  }

  async function togglePublished(page: PluginPage) {
    await api.updatePluginPage(page.id, { is_published: !page.is_published });
    await load();
  }

  function flowName(id: string | null | undefined): string {
    if (!id) return '—';
    const f = flows.find((x) => x.id === id);
    return f ? f.name : id.slice(0, 8) + '…';
  }
</script>

<div class="admin-page">
  <div class="page-header">
    <div>
      <h1>Plugin Pages</h1>
      <p class="page-sub">Custom pages rendered by a no-code flow. Each page is mounted at <code>/p/:slug</code> and runs its linked flow for data.</p>
    </div>
    <button class="btn-primary" onclick={openCreate}>New Page</button>
  </div>

  {#if showForm}
    <div class="form-card">
      <h3>{editing ? `Edit: ${editing.title}` : 'New Plugin Page'}</h3>
      <div class="form-grid">
        <label>Title
          <input type="text" bind:value={form.title} oninput={autoSlug} placeholder="Community Leaderboard" />
        </label>
        <label>Slug
          <input type="text" bind:value={form.slug} placeholder="leaderboard" disabled={!!editing} />
        </label>
        <label class="span-2">Description
          <input type="text" bind:value={form.description} placeholder="Weekly top posters" />
        </label>
        <label>Linked Flow
          <select bind:value={form.flow_id}>
            <option value="">— Select a flow —</option>
            {#each flows as f}<option value={f.id}>{f.name}</option>{/each}
          </select>
        </label>
        <label>Nav Label <span class="hint">(optional)</span>
          <input type="text" bind:value={form.nav_label} placeholder="Leaderboard" />
        </label>
        <label>Nav Position
          <input type="number" bind:value={form.nav_position} />
        </label>
        <label class="checkbox-span"><input type="checkbox" bind:checked={form.is_published} /> Published</label>
      </div>
      <label class="template-label">
        Template JSON
        <textarea bind:value={form.template_json} rows="8" spellcheck="false"></textarea>
      </label>
      <p class="help">Template is the layout tree rendered on the page. Consult the plugin docs for the expected shape.</p>
      {#if formError}<div class="form-error">{formError}</div>{/if}
      <div class="form-actions">
        <button onclick={() => { showForm = false; editing = null; }}>Cancel</button>
        <button class="btn-primary" onclick={handleSave} disabled={saving || !form.title.trim() || !form.slug.trim() || !form.flow_id}>
          {saving ? 'Saving...' : editing ? 'Update' : 'Create'}
        </button>
      </div>
    </div>
  {/if}

  {#if loading}
    <p class="loading">Loading pages...</p>
  {:else if error}
    <div class="error-banner">{error}</div>
  {:else if pages.length === 0}
    <p class="empty">No plugin pages yet. Create one to publish a flow-backed page.</p>
  {:else}
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Title</th>
            <th>URL</th>
            <th>Flow</th>
            <th>Nav</th>
            <th>Published</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each pages as page (page.id)}
            <tr class:unpublished={!page.is_published}>
              <td>
                <strong>{page.title}</strong>
                {#if page.description}<div class="desc">{page.description}</div>{/if}
              </td>
              <td><code>/p/{page.slug}</code></td>
              <td class="flow-cell">{flowName(page.flow_id)}</td>
              <td>{page.nav_label || '—'}{page.nav_position !== null ? ` (#${page.nav_position})` : ''}</td>
              <td>
                <span class="status" class:on={page.is_published} class:off={!page.is_published}>
                  {page.is_published ? 'Published' : 'Draft'}
                </span>
              </td>
              <td class="actions">
                <button class="btn-sm" onclick={() => togglePublished(page)}>{page.is_published ? 'Unpublish' : 'Publish'}</button>
                <button class="btn-sm" onclick={() => openEdit(page)}>Edit</button>
                <button class="btn-sm danger" onclick={() => handleDelete(page)}>Delete</button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>

<style>
  .admin-page { max-width: 1000px; }
  .page-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 16px; gap: 16px; }
  .page-header h1 { font-size: 20px; font-weight: 800; }
  .page-sub { font-size: 12px; color: var(--text-muted); margin-top: 2px; max-width: 640px; }
  .page-sub code { background: var(--bg-primary); padding: 1px 4px; border-radius: 3px; }
  .btn-primary { background: var(--accent); color: var(--bg-primary); border: none; padding: 8px 16px; border-radius: var(--radius); font-weight: 600; cursor: pointer; font-family: inherit; font-size: 13px; }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }

  .form-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 20px; margin-bottom: 16px; }
  .form-card h3 { font-size: 15px; font-weight: 700; margin-bottom: 12px; }
  .form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  .form-grid .span-2 { grid-column: span 2; }
  .form-grid label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  .form-grid label.checkbox-span { flex-direction: row; align-items: center; gap: 6px; grid-column: span 2; }
  .hint { font-weight: 400; color: var(--text-muted); font-size: 11px; }
  .form-grid input, .form-grid select { padding: 8px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: inherit; font-size: 13px; }
  .template-label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; font-weight: 600; color: var(--text-secondary); margin-top: 12px; }
  .template-label textarea { padding: 8px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: ui-monospace, monospace; font-size: 12px; resize: vertical; }
  .help { font-size: 11px; color: var(--text-muted); margin-top: 6px; }
  .form-error { margin-top: 10px; padding: 10px; background: rgba(248,113,113,0.1); border: 1px solid rgba(248,113,113,0.3); border-radius: var(--radius); color: #f87171; font-size: 12px; }
  .form-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: 12px; }
  .form-actions button { padding: 8px 16px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; font-size: 13px; }
  .form-actions button.btn-primary { border: none; color: var(--bg-primary); background: var(--accent); }

  .table-wrap { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); overflow: auto; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  th { text-align: left; padding: 10px 12px; background: var(--bg-primary); color: var(--text-muted); font-size: 10px; text-transform: uppercase; letter-spacing: 0.05em; border-bottom: 1px solid var(--border-color); font-weight: 700; }
  td { padding: 10px 12px; border-bottom: 1px solid var(--border-color); vertical-align: middle; }
  tr.unpublished { opacity: 0.6; }
  .desc { font-size: 11px; color: var(--text-muted); margin-top: 2px; }
  .flow-cell { font-size: 11px; color: var(--text-secondary); }
  .status { display: inline-block; padding: 2px 8px; font-size: 10px; font-weight: 700; border-radius: 10px; text-transform: uppercase; letter-spacing: 0.05em; }
  .status.on { background: rgba(52,211,153,0.15); color: #34d399; }
  .status.off { background: rgba(156,163,175,0.15); color: #9ca3af; }
  .actions { display: flex; gap: 4px; flex-wrap: wrap; }
  .btn-sm { padding: 4px 10px; font-size: 11px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; }
  .btn-sm:hover { background: var(--bg-hover); color: var(--text-primary); }
  .btn-sm.danger { color: #f87171; border-color: rgba(248,113,113,0.3); }

  .loading, .empty { text-align: center; color: var(--text-muted); padding: 30px; }
  .error-banner { padding: 12px; background: rgba(248,113,113,0.1); border: 1px solid rgba(248,113,113,0.3); border-radius: var(--radius); color: #f87171; }
</style>
