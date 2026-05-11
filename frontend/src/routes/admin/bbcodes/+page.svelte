<script lang="ts">
  import { api } from '$lib/api/client';

  interface CustomBBCode {
    id: string;
    tag_name: string;
    replacement_html: string;
    description: string | null;
    is_active: boolean;
    inserted_at?: string;
    updated_at?: string;
  }

  let bbcodes = $state<CustomBBCode[]>([]);
  let loading = $state(true);
  let error = $state('');

  let showForm = $state(false);
  let editing = $state<CustomBBCode | null>(null);
  let form = $state({ tag_name: '', replacement_html: '', description: '', is_active: true });
  let saving = $state(false);
  let formError = $state('');

  $effect(() => { load(); });

  async function load() {
    loading = true;
    error = '';
    try {
      const data = await api.getCustomBBCodes();
      bbcodes = data.bbcodes || [];
    } catch (err: any) {
      error = err?.error || 'Failed to load custom BBCodes.';
    }
    loading = false;
  }

  function openCreate() {
    editing = null;
    form = { tag_name: '', replacement_html: '', description: '', is_active: true };
    formError = '';
    showForm = true;
  }

  function openEdit(bb: CustomBBCode) {
    editing = bb;
    form = { tag_name: bb.tag_name, replacement_html: bb.replacement_html, description: bb.description || '', is_active: bb.is_active };
    formError = '';
    showForm = true;
  }

  async function handleSave() {
    formError = '';
    if (!form.tag_name.trim()) { formError = 'Tag name is required.'; return; }
    if (!form.replacement_html.trim()) { formError = 'Replacement HTML is required.'; return; }
    if (!/^[a-z0-9_-]+$/i.test(form.tag_name.trim())) { formError = 'Tag name must be alphanumeric (letters, digits, _, -).'; return; }
    saving = true;
    try {
      if (editing) {
        await api.updateCustomBBCode(editing.id, form);
      } else {
        await api.createCustomBBCode(form);
      }
      showForm = false;
      editing = null;
      await load();
    } catch (err: any) {
      formError = err?.error ? JSON.stringify(err.error) : 'Failed to save BBCode.';
    }
    saving = false;
  }

  async function handleDelete(bb: CustomBBCode) {
    if (!confirm(`Delete custom BBCode [${bb.tag_name}]?`)) return;
    try {
      await api.deleteCustomBBCode(bb.id);
      await load();
    } catch (err: any) {
      alert('Failed to delete: ' + (err?.error || 'unknown error'));
    }
  }

  async function toggleActive(bb: CustomBBCode) {
    await api.updateCustomBBCode(bb.id, { is_active: !bb.is_active });
    await load();
  }

  const previewExample = $derived.by(() => {
    if (!form.tag_name) return '';
    const tag = form.tag_name.toLowerCase();
    return `[${tag}]sample content[/${tag}]`;
  });
</script>

<div class="admin-page">
  <div class="page-header">
    <div>
      <h1>Custom BBCodes</h1>
      <p class="page-sub">Define custom BBCode tags that render to HTML. Use <code>{'{content}'}</code> as a placeholder for the inner text.</p>
    </div>
    <button class="btn-primary" onclick={openCreate}>New BBCode</button>
  </div>

  {#if showForm}
    <div class="form-card">
      <h3>{editing ? `Edit: [${editing.tag_name}]` : 'New Custom BBCode'}</h3>
      <div class="form-grid">
        <label>Tag Name
          <input type="text" bind:value={form.tag_name} placeholder="highlight" disabled={!!editing} />
        </label>
        <label>Description
          <input type="text" bind:value={form.description} placeholder="Highlights text in accent color" />
        </label>
        <label class="span-2">Replacement HTML
          <textarea bind:value={form.replacement_html} rows="4" placeholder={'<span class="highlight">{content}</span>'} spellcheck="false"></textarea>
        </label>
      </div>
      {#if previewExample}
        <div class="example">
          Example usage: <code>{previewExample}</code>
        </div>
      {/if}
      <div class="toggles">
        <label class="checkbox"><input type="checkbox" bind:checked={form.is_active} /> Active</label>
      </div>
      {#if formError}<div class="form-error">{formError}</div>{/if}
      <div class="form-actions">
        <button onclick={() => { showForm = false; editing = null; }}>Cancel</button>
        <button class="btn-primary" onclick={handleSave} disabled={saving || !form.tag_name.trim() || !form.replacement_html.trim()}>
          {saving ? 'Saving...' : editing ? 'Update' : 'Create'}
        </button>
      </div>
    </div>
  {/if}

  {#if loading}
    <p class="loading">Loading...</p>
  {:else if error}
    <div class="error-banner">{error}</div>
  {:else if bbcodes.length === 0}
    <p class="empty">No custom BBCodes defined yet.</p>
  {:else}
    <div class="list">
      {#each bbcodes as bb (bb.id)}
        <div class="bb-card" class:inactive={!bb.is_active}>
          <div class="bb-head">
            <div class="bb-head-left">
              <code class="tag">[{bb.tag_name}]</code>
              {#if bb.description}<span class="desc">{bb.description}</span>{/if}
              <span class="status" class:on={bb.is_active} class:off={!bb.is_active}>
                {bb.is_active ? 'Active' : 'Disabled'}
              </span>
            </div>
            <div class="bb-actions">
              <button class="btn-sm" onclick={() => toggleActive(bb)}>{bb.is_active ? 'Disable' : 'Enable'}</button>
              <button class="btn-sm" onclick={() => openEdit(bb)}>Edit</button>
              <button class="btn-sm danger" onclick={() => handleDelete(bb)}>Delete</button>
            </div>
          </div>
          <pre class="bb-html">{bb.replacement_html}</pre>
        </div>
      {/each}
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

  .form-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 20px; margin-bottom: 20px; }
  .form-card h3 { font-size: 15px; font-weight: 700; margin-bottom: 12px; }
  .form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  .form-grid .span-2 { grid-column: span 2; }
  .form-grid label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  .form-grid input, .form-grid textarea { padding: 8px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: inherit; font-size: 13px; }
  .form-grid textarea { font-family: ui-monospace, monospace; resize: vertical; }
  .example { margin-top: 10px; padding: 8px; background: var(--bg-primary); border-radius: var(--radius); font-size: 11px; color: var(--text-muted); }
  .example code { font-family: ui-monospace, monospace; color: var(--text-secondary); }
  .toggles { display: flex; gap: 16px; margin-top: 12px; }
  .checkbox { display: flex; flex-direction: row; align-items: center; gap: 6px; font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  .form-error { margin-top: 10px; padding: 10px; background: rgba(248,113,113,0.1); border: 1px solid rgba(248,113,113,0.3); border-radius: var(--radius); color: #f87171; font-size: 12px; }
  .form-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: 12px; }
  .form-actions button { padding: 8px 16px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; font-size: 13px; }
  .form-actions button.btn-primary { border: none; color: var(--bg-primary); background: var(--accent); }

  .list { display: flex; flex-direction: column; gap: 10px; }
  .bb-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 14px; }
  .bb-card.inactive { opacity: 0.55; }
  .bb-head { display: flex; justify-content: space-between; align-items: center; gap: 12px; flex-wrap: wrap; margin-bottom: 8px; }
  .bb-head-left { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
  .tag { font-family: ui-monospace, monospace; font-size: 13px; color: var(--accent); background: var(--bg-primary); padding: 2px 8px; border-radius: var(--radius); }
  .desc { font-size: 12px; color: var(--text-secondary); }
  .status { display: inline-block; padding: 2px 8px; font-size: 10px; font-weight: 700; border-radius: 10px; text-transform: uppercase; letter-spacing: 0.05em; }
  .status.on { background: rgba(52,211,153,0.15); color: #34d399; }
  .status.off { background: rgba(156,163,175,0.15); color: #9ca3af; }
  .bb-actions { display: flex; gap: 6px; }
  .bb-html { font-family: ui-monospace, monospace; font-size: 11px; padding: 10px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-secondary); margin: 0; white-space: pre-wrap; word-break: break-all; }
  .btn-sm { padding: 4px 10px; font-size: 11px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; }
  .btn-sm:hover { background: var(--bg-hover); color: var(--text-primary); }
  .btn-sm.danger { color: #f87171; border-color: rgba(248,113,113,0.3); }

  .loading, .empty { text-align: center; color: var(--text-muted); padding: 30px; }
  .error-banner { padding: 12px; background: rgba(248,113,113,0.1); border: 1px solid rgba(248,113,113,0.3); border-radius: var(--radius); color: #f87171; }
</style>
