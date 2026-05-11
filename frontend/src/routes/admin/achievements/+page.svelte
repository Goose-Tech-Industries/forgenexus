<script lang="ts">
  import { api } from '$lib/api/client';

  interface Achievement {
    id: string;
    name: string;
    slug: string;
    description: string | null;
    icon: string | null;
    category: string | null;
    points: number;
    criteria: Record<string, any>;
    is_hidden: boolean;
    is_active: boolean;
    sort_order: number;
    unlock_count?: number;
    inserted_at?: string;
    updated_at?: string;
  }

  type CriteriaPreset = 'custom' | 'post_count' | 'thread_count' | 'reputation' | 'streak' | 'level' | 'collection' | 'json';

  interface FormState {
    name: string;
    slug: string;
    description: string;
    icon: string;
    category: string;
    points: number;
    preset: CriteriaPreset;
    stat_key: string;
    threshold: number;
    target: number;
    criteria_json: string;
    is_hidden: boolean;
    is_active: boolean;
    sort_order: number;
  }

  const emptyForm = (): FormState => ({
    name: '',
    slug: '',
    description: '',
    icon: '🏆',
    category: '',
    points: 0,
    preset: 'custom',
    stat_key: '',
    threshold: 0,
    target: 0,
    criteria_json: '{}',
    is_hidden: false,
    is_active: true,
    sort_order: 0
  });

  let achievements = $state<Achievement[]>([]);
  let loading = $state(true);
  let error = $state('');
  let showForm = $state(false);
  let editing = $state<Achievement | null>(null);
  let form = $state<FormState>(emptyForm());
  let saving = $state(false);
  let formError = $state('');
  let search = $state('');
  let categoryFilter = $state('');
  let statusFilter = $state<'all' | 'active' | 'inactive'>('all');

  // Grant-to-user modal state
  let grantingAchievement = $state<Achievement | null>(null);
  let grantUserId = $state('');
  let grantMessage = $state('');
  let grantTab = $state<'single' | 'bulk'>('single');
  let bulkTargets = $state('');
  let bulkResults = $state<Array<{ target: string; status: string; reason?: string }>>([]);
  let bulkSummary = $state<{ total: number; ok: number; skipped: number; not_found: number; errors: number } | null>(null);
  let bulkBusy = $state(false);

  $effect(() => { loadAchievements(); });

  async function loadAchievements() {
    loading = true;
    error = '';
    try {
      const data = await api.getAdminAchievements();
      achievements = data.achievements || [];
    } catch (err: any) {
      error = err?.error || 'Failed to load achievements.';
    }
    loading = false;
  }

  const filtered = $derived.by(() => {
    const q = search.trim().toLowerCase();
    return achievements.filter((a) => {
      if (q && !a.name.toLowerCase().includes(q) && !a.slug.toLowerCase().includes(q)) return false;
      if (categoryFilter && a.category !== categoryFilter) return false;
      if (statusFilter === 'active' && !a.is_active) return false;
      if (statusFilter === 'inactive' && a.is_active) return false;
      return true;
    });
  });

  const categories = $derived(
    Array.from(new Set(achievements.map((a) => a.category).filter((c): c is string => !!c))).sort()
  );

  function openCreate() {
    editing = null;
    form = emptyForm();
    formError = '';
    showForm = true;
  }

  function openEdit(a: Achievement) {
    editing = a;
    formError = '';
    const c = a.criteria || {};
    const type = c.type;
    let preset: CriteriaPreset = 'custom';
    let stat_key = '';
    let threshold = 0;
    let target = 0;
    let criteria_json = JSON.stringify(c, null, 2);

    if (type === 'stat_threshold' && typeof c.stat_key === 'string') {
      if (['post_count', 'thread_count', 'reputation', 'streak', 'level'].includes(c.stat_key)) {
        preset = c.stat_key as CriteriaPreset;
      } else {
        preset = 'json';
      }
      stat_key = c.stat_key;
      threshold = Number(c.threshold ?? 0);
    } else if (type === 'count' && c.stat_key === 'collection') {
      preset = 'collection';
      target = Number(c.target ?? 0);
    } else if (type === 'custom' || !type) {
      preset = 'custom';
    } else {
      preset = 'json';
    }

    form = {
      name: a.name,
      slug: a.slug,
      description: a.description || '',
      icon: a.icon || '🏆',
      category: a.category || '',
      points: a.points,
      preset,
      stat_key,
      threshold,
      target,
      criteria_json,
      is_hidden: a.is_hidden,
      is_active: a.is_active,
      sort_order: a.sort_order
    };
    showForm = true;
  }

  function autoSlug() {
    if (!editing && form.name && !form.slug) {
      form.slug = form.name
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '');
    }
  }

  function buildCriteria(): { ok: true; value: Record<string, any> } | { ok: false; error: string } {
    switch (form.preset) {
      case 'custom':
        return { ok: true, value: { type: 'custom' } };
      case 'post_count':
      case 'thread_count':
      case 'reputation':
      case 'streak':
      case 'level':
        return {
          ok: true,
          value: { type: 'stat_threshold', stat_key: form.preset, threshold: Number(form.threshold) || 0 }
        };
      case 'collection':
        return {
          ok: true,
          value: { type: 'count', stat_key: 'collection', target: Number(form.target) || 0 }
        };
      case 'json':
        try {
          const parsed = JSON.parse(form.criteria_json || '{}');
          if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
            return { ok: false, error: 'Criteria JSON must be an object.' };
          }
          return { ok: true, value: parsed };
        } catch (e: any) {
          return { ok: false, error: 'Invalid JSON: ' + (e?.message || 'parse error') };
        }
    }
  }

  async function handleSave() {
    formError = '';
    if (!form.name.trim()) {
      formError = 'Name is required.';
      return;
    }
    const crit = buildCriteria();
    if (!crit.ok) {
      formError = crit.error;
      return;
    }
    saving = true;
    const payload: Record<string, any> = {
      name: form.name.trim(),
      description: form.description || null,
      icon: form.icon || null,
      category: form.category || null,
      points: Number(form.points) || 0,
      criteria: crit.value,
      is_hidden: form.is_hidden,
      is_active: form.is_active,
      sort_order: Number(form.sort_order) || 0
    };
    if (form.slug.trim()) payload.slug = form.slug.trim();

    try {
      if (editing) {
        await api.updateAchievement(editing.id, payload);
      } else {
        await api.createAchievement(payload);
      }
      showForm = false;
      editing = null;
      form = emptyForm();
      await loadAchievements();
    } catch (err: any) {
      formError = err?.error ? JSON.stringify(err.error) : 'Failed to save achievement.';
    }
    saving = false;
  }

  async function handleDelete(a: Achievement) {
    const count = a.unlock_count ?? 0;
    const msg =
      count > 0
        ? `Delete achievement "${a.name}"? ${count} user${count === 1 ? '' : 's'} will lose it. This cannot be undone.`
        : `Delete achievement "${a.name}"? This cannot be undone.`;
    if (!confirm(msg)) return;
    try {
      await api.deleteAchievement(a.id);
      await loadAchievements();
    } catch (err: any) {
      alert('Failed to delete: ' + (err?.error || 'unknown error'));
    }
  }

  async function toggleActive(a: Achievement) {
    try {
      await api.updateAchievement(a.id, { is_active: !a.is_active });
      await loadAchievements();
    } catch { /* silent */ }
  }

  function openGrant(a: Achievement) {
    grantingAchievement = a;
    grantUserId = '';
    grantMessage = '';
    grantTab = 'single';
    bulkTargets = '';
    bulkResults = [];
    bulkSummary = null;
  }

  function parseBulkTargets(): string[] {
    return bulkTargets
      .split(/[\n,;\s]+/)
      .map((t) => t.trim())
      .filter((t) => t.length > 0);
  }

  async function runBulk(action: 'grant' | 'revoke') {
    if (!grantingAchievement) return;
    const targets = parseBulkTargets();
    if (targets.length === 0) {
      bulkSummary = null;
      bulkResults = [];
      return;
    }
    bulkBusy = true;
    bulkResults = [];
    bulkSummary = null;
    try {
      const data = await api.bulkAchievement(grantingAchievement.id, action, targets);
      bulkResults = data.results || [];
      bulkSummary = data.summary || null;
      await loadAchievements();
    } catch (err: any) {
      bulkSummary = { total: targets.length, ok: 0, skipped: 0, not_found: 0, errors: targets.length };
    }
    bulkBusy = false;
  }

  async function submitGrant() {
    if (!grantingAchievement || !grantUserId.trim()) return;
    grantMessage = '';
    try {
      await api.grantAchievement(grantingAchievement.id, grantUserId.trim());
      grantMessage = 'Granted.';
      await loadAchievements();
    } catch (err: any) {
      grantMessage = err?.error || 'Failed to grant.';
    }
  }

  async function submitRevoke() {
    if (!grantingAchievement || !grantUserId.trim()) return;
    grantMessage = '';
    try {
      await api.revokeAchievement(grantingAchievement.id, grantUserId.trim());
      grantMessage = 'Revoked.';
      await loadAchievements();
    } catch (err: any) {
      grantMessage = err?.error || 'Failed to revoke.';
    }
  }
</script>

<div class="admin-page">
  <div class="page-header">
    <div>
      <h1>Achievements</h1>
      <p class="page-sub">Define unlockable milestones with criteria, points, and categories.</p>
    </div>
    <button class="btn-primary" onclick={openCreate}>New Achievement</button>
  </div>

  <div class="filters">
    <input type="text" bind:value={search} placeholder="Search by name or slug..." />
    <select bind:value={categoryFilter}>
      <option value="">All categories</option>
      {#each categories as cat}<option value={cat}>{cat}</option>{/each}
    </select>
    <select bind:value={statusFilter}>
      <option value="all">All</option>
      <option value="active">Active only</option>
      <option value="inactive">Inactive only</option>
    </select>
  </div>

  {#if showForm}
    <div class="form-card">
      <h3>{editing ? `Edit: ${editing.name}` : 'New Achievement'}</h3>
      <div class="form-grid">
        <label>Name
          <input type="text" bind:value={form.name} oninput={autoSlug} placeholder="First Post" />
        </label>
        <label>Slug
          <input type="text" bind:value={form.slug} placeholder="first-post" disabled={!!editing} />
        </label>
        <label class="span-2">Description
          <input type="text" bind:value={form.description} placeholder="Make your first post on the forum." />
        </label>
        <label>Icon
          <input type="text" bind:value={form.icon} placeholder="🏆" />
        </label>
        <label>Category
          <input type="text" bind:value={form.category} placeholder="starter" />
        </label>
        <label>Points
          <input type="number" bind:value={form.points} min="0" />
        </label>
        <label>Sort Order
          <input type="number" bind:value={form.sort_order} />
        </label>
      </div>

      <div class="criteria-section">
        <h4>Criteria</h4>
        <label>Type
          <select bind:value={form.preset}>
            <option value="custom">Custom (manual grant only)</option>
            <option value="post_count">Post count</option>
            <option value="thread_count">Thread count</option>
            <option value="reputation">Reputation</option>
            <option value="streak">Daily streak</option>
            <option value="level">User level</option>
            <option value="collection">Collection count</option>
            <option value="json">Advanced (raw JSON)</option>
          </select>
        </label>

        {#if form.preset === 'post_count' || form.preset === 'thread_count' || form.preset === 'reputation' || form.preset === 'streak' || form.preset === 'level'}
          <label>Threshold
            <input type="number" bind:value={form.threshold} min="0" />
          </label>
          <p class="criteria-help">Unlocks when the user's <code>{form.preset}</code> stat reaches this value.</p>
        {:else if form.preset === 'collection'}
          <label>Target count
            <input type="number" bind:value={form.target} min="0" />
          </label>
          <p class="criteria-help">Unlocks when the user's collection reaches this count.</p>
        {:else if form.preset === 'json'}
          <label>Criteria JSON
            <textarea bind:value={form.criteria_json} rows="5" spellcheck="false"></textarea>
          </label>
          <p class="criteria-help">Must be a JSON object. Example: <code>{'{"type":"stat_threshold","stat_key":"post_count","threshold":100}'}</code></p>
        {:else}
          <p class="criteria-help">Custom achievements have no automatic unlock logic — grant them manually from this admin page or via the no-code engine.</p>
        {/if}
      </div>

      <div class="toggles">
        <label class="checkbox"><input type="checkbox" bind:checked={form.is_active} /> Active</label>
        <label class="checkbox"><input type="checkbox" bind:checked={form.is_hidden} /> Hidden until unlocked</label>
      </div>

      {#if formError}<div class="form-error">{formError}</div>{/if}

      <div class="form-actions">
        <button onclick={() => { showForm = false; editing = null; formError = ''; }}>Cancel</button>
        <button class="btn-primary" onclick={handleSave} disabled={saving || !form.name.trim()}>
          {saving ? 'Saving...' : editing ? 'Update' : 'Create'}
        </button>
      </div>
    </div>
  {/if}

  {#if grantingAchievement}
    <div class="modal-backdrop" onclick={() => { grantingAchievement = null; }} role="presentation">
      <div class="modal modal-wide" onclick={(e) => e.stopPropagation()} role="dialog" aria-modal="true">
        <h3>Grant / Revoke: {grantingAchievement.name}</h3>

        <div class="grant-tabs">
          <button class="grant-tab" class:active={grantTab === 'single'} onclick={() => (grantTab = 'single')}>Single User</button>
          <button class="grant-tab" class:active={grantTab === 'bulk'} onclick={() => (grantTab = 'bulk')}>Bulk</button>
        </div>

        {#if grantTab === 'single'}
          <label>User ID
            <input type="text" bind:value={grantUserId} placeholder="UUID" />
          </label>
          <div class="modal-actions">
            <button onclick={() => { grantingAchievement = null; }}>Close</button>
            <button class="btn-secondary" onclick={submitRevoke} disabled={!grantUserId.trim()}>Revoke</button>
            <button class="btn-primary" onclick={submitGrant} disabled={!grantUserId.trim()}>Grant</button>
          </div>
          {#if grantMessage}<div class="modal-message">{grantMessage}</div>{/if}
        {:else}
          <label>Usernames or User IDs
            <textarea
              bind:value={bulkTargets}
              rows="6"
              placeholder="One per line. You can mix usernames and UUIDs. Commas and spaces also work as separators."
              spellcheck="false"
            ></textarea>
          </label>
          <p class="bulk-hint">{parseBulkTargets().length} target{parseBulkTargets().length === 1 ? '' : 's'}</p>
          <div class="modal-actions">
            <button onclick={() => { grantingAchievement = null; }}>Close</button>
            <button class="btn-secondary" onclick={() => runBulk('revoke')} disabled={bulkBusy || parseBulkTargets().length === 0}>
              {bulkBusy ? 'Working...' : 'Revoke All'}
            </button>
            <button class="btn-primary" onclick={() => runBulk('grant')} disabled={bulkBusy || parseBulkTargets().length === 0}>
              {bulkBusy ? 'Working...' : 'Grant All'}
            </button>
          </div>

          {#if bulkSummary}
            <div class="bulk-summary">
              <strong>{bulkSummary.ok}</strong> ok ·
              <strong>{bulkSummary.skipped}</strong> skipped ·
              <strong>{bulkSummary.not_found}</strong> not found ·
              <strong>{bulkSummary.errors}</strong> errors ·
              <span class="muted">({bulkSummary.total} total)</span>
            </div>
          {/if}

          {#if bulkResults.length > 0}
            <div class="bulk-results">
              {#each bulkResults as r (r.target + (r.status || ''))}
                <div class="bulk-row bulk-{r.status}">
                  <code>{r.target}</code>
                  <span class="bulk-status">{r.status}{#if r.reason} · {r.reason}{/if}</span>
                </div>
              {/each}
            </div>
          {/if}
        {/if}
      </div>
    </div>
  {/if}

  {#if loading}
    <p class="loading">Loading achievements...</p>
  {:else if error}
    <div class="error-banner">{error}</div>
  {:else if filtered.length === 0}
    <p class="empty">
      {achievements.length === 0 ? 'No achievements defined yet. Create your first one.' : 'No achievements match your filters.'}
    </p>
  {:else}
    <div class="achievement-table-wrap">
      <table class="achievement-table">
        <thead>
          <tr>
            <th></th>
            <th>Name</th>
            <th>Category</th>
            <th>Points</th>
            <th>Criteria</th>
            <th>Unlocks</th>
            <th>Status</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each filtered as a (a.id)}
            <tr class:inactive={!a.is_active}>
              <td class="icon-cell">{a.icon || '🏆'}</td>
              <td>
                <div class="name-cell">
                  <strong>{a.name}</strong>
                  <code class="slug">{a.slug}</code>
                </div>
              </td>
              <td>{a.category || '—'}</td>
              <td class="num">{a.points}</td>
              <td class="criteria-cell">
                <code>{a.criteria?.type || 'custom'}</code>
                {#if a.criteria?.stat_key}<span class="muted"> · {a.criteria.stat_key}</span>{/if}
                {#if a.criteria?.threshold !== undefined}<span class="muted"> ≥ {a.criteria.threshold}</span>{/if}
                {#if a.criteria?.target !== undefined}<span class="muted"> · {a.criteria.target}</span>{/if}
              </td>
              <td class="num">{a.unlock_count ?? 0}</td>
              <td>
                <span class="status" class:on={a.is_active} class:off={!a.is_active}>
                  {a.is_active ? 'Active' : 'Inactive'}
                </span>
                {#if a.is_hidden}<span class="tag">Hidden</span>{/if}
              </td>
              <td class="actions">
                <button class="btn-sm" onclick={() => toggleActive(a)}>{a.is_active ? 'Disable' : 'Enable'}</button>
                <button class="btn-sm" onclick={() => openGrant(a)}>Grant</button>
                <button class="btn-sm" onclick={() => openEdit(a)}>Edit</button>
                <button class="btn-sm danger" onclick={() => handleDelete(a)}>Delete</button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>

<style>
  .admin-page { max-width: 1100px; }
  .page-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 16px; gap: 16px; }
  .page-header h1 { font-size: 20px; font-weight: 800; }
  .page-sub { font-size: 12px; color: var(--text-muted); margin-top: 2px; }
  .btn-primary { background: var(--accent); color: var(--bg-primary); border: none; padding: 8px 16px; border-radius: var(--radius); font-weight: 600; cursor: pointer; font-family: inherit; font-size: 13px; }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-secondary { background: var(--bg-secondary); color: var(--text-primary); border: 1px solid var(--border-color); padding: 8px 16px; border-radius: var(--radius); font-family: inherit; font-size: 13px; cursor: pointer; }

  .filters { display: flex; gap: 8px; margin-bottom: 16px; flex-wrap: wrap; }
  .filters input, .filters select { padding: 8px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: inherit; font-size: 13px; }
  .filters input { flex: 1; min-width: 200px; }

  .form-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 20px; margin-bottom: 20px; }
  .form-card h3 { font-size: 15px; font-weight: 700; margin-bottom: 12px; }
  .form-card h4 { font-size: 13px; font-weight: 700; margin: 16px 0 8px 0; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.05em; }
  .form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  .form-grid label, .criteria-section label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  .form-grid .span-2 { grid-column: span 2; }
  .form-grid input, .criteria-section input, .criteria-section select, .criteria-section textarea { padding: 8px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: inherit; font-size: 13px; }
  .criteria-section textarea { font-family: ui-monospace, monospace; font-size: 12px; resize: vertical; }
  .criteria-section { margin-top: 8px; }
  .criteria-help { font-size: 11px; color: var(--text-muted); margin-top: 6px; }
  .criteria-help code { background: var(--bg-primary); padding: 1px 4px; border-radius: 3px; }
  .toggles { display: flex; gap: 16px; margin-top: 16px; }
  .checkbox { display: flex; flex-direction: row; align-items: center; gap: 6px; font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  .form-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: 16px; }
  .form-actions button { padding: 8px 16px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; font-size: 13px; }
  .form-actions button.btn-primary { border: none; color: var(--bg-primary); background: var(--accent); }
  .form-error { margin-top: 12px; padding: 10px 12px; background: rgba(248,113,113,0.1); border: 1px solid rgba(248,113,113,0.3); border-radius: var(--radius); color: #f87171; font-size: 12px; }

  .achievement-table-wrap { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); overflow: auto; }
  .achievement-table { width: 100%; border-collapse: collapse; font-size: 13px; }
  .achievement-table th { text-align: left; padding: 10px 12px; font-size: 11px; text-transform: uppercase; letter-spacing: 0.05em; color: var(--text-muted); background: var(--bg-primary); border-bottom: 1px solid var(--border-color); font-weight: 700; }
  .achievement-table td { padding: 10px 12px; border-bottom: 1px solid var(--border-color); vertical-align: middle; }
  .achievement-table tr.inactive { opacity: 0.55; }
  .icon-cell { font-size: 22px; width: 32px; text-align: center; }
  .name-cell { display: flex; flex-direction: column; gap: 2px; }
  .name-cell strong { font-weight: 700; }
  .slug { font-size: 11px; color: var(--text-muted); }
  .num { font-variant-numeric: tabular-nums; color: var(--text-secondary); }
  .criteria-cell { font-family: ui-monospace, monospace; font-size: 11px; color: var(--text-secondary); }
  .criteria-cell .muted { color: var(--text-muted); }
  .status { display: inline-block; padding: 2px 8px; font-size: 10px; font-weight: 700; border-radius: 10px; text-transform: uppercase; letter-spacing: 0.05em; }
  .status.on { background: rgba(52,211,153,0.15); color: #34d399; }
  .status.off { background: rgba(156,163,175,0.15); color: #9ca3af; }
  .tag { display: inline-block; margin-left: 4px; padding: 2px 8px; font-size: 10px; font-weight: 700; border-radius: 10px; background: rgba(250,204,21,0.15); color: #facc15; text-transform: uppercase; letter-spacing: 0.05em; }
  .actions { display: flex; gap: 4px; flex-wrap: wrap; }
  .btn-sm { padding: 4px 10px; font-size: 11px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; }
  .btn-sm:hover { background: var(--bg-hover); color: var(--text-primary); }
  .btn-sm.danger { color: #f87171; border-color: rgba(248,113,113,0.3); }

  .loading, .empty { text-align: center; color: var(--text-muted); padding: 40px; }
  .error-banner { padding: 12px; background: rgba(248,113,113,0.1); border: 1px solid rgba(248,113,113,0.3); border-radius: var(--radius); color: #f87171; }

  .modal-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; z-index: 1000; }
  .modal { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 20px; width: 100%; max-width: 420px; max-height: 85vh; overflow: auto; }
  .modal.modal-wide { max-width: 560px; }
  .grant-tabs { display: flex; gap: 4px; margin-bottom: 12px; border-bottom: 1px solid var(--border-color); }
  .grant-tab { padding: 6px 14px; border: none; background: transparent; color: var(--text-muted); font-family: inherit; font-size: 12px; font-weight: 700; cursor: pointer; border-bottom: 2px solid transparent; }
  .grant-tab.active { color: var(--accent); border-bottom-color: var(--accent); }
  .modal textarea { padding: 8px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: ui-monospace, monospace; font-size: 12px; resize: vertical; width: 100%; }
  .bulk-hint { font-size: 11px; color: var(--text-muted); margin: 4px 0 8px; }
  .bulk-summary { margin-top: 12px; padding: 10px; background: var(--bg-primary); border-radius: var(--radius); font-size: 12px; color: var(--text-secondary); }
  .bulk-summary strong { color: var(--text-primary); font-variant-numeric: tabular-nums; }
  .bulk-summary .muted { color: var(--text-muted); }
  .bulk-results { margin-top: 10px; max-height: 200px; overflow: auto; border: 1px solid var(--border-color); border-radius: var(--radius); }
  .bulk-row { display: flex; justify-content: space-between; gap: 8px; padding: 6px 10px; font-size: 11px; border-bottom: 1px solid var(--border-color); }
  .bulk-row:last-child { border-bottom: none; }
  .bulk-row code { font-family: ui-monospace, monospace; color: var(--text-primary); }
  .bulk-status { font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; font-size: 10px; }
  .bulk-ok { background: rgba(52,211,153,0.08); }
  .bulk-ok .bulk-status { color: #34d399; }
  .bulk-skipped { background: rgba(250,204,21,0.08); }
  .bulk-skipped .bulk-status { color: #facc15; }
  .bulk-not_found, .bulk-error { background: rgba(248,113,113,0.08); }
  .bulk-not_found .bulk-status, .bulk-error .bulk-status { color: #f87171; }
  .modal h3 { font-size: 15px; font-weight: 700; margin-bottom: 12px; }
  .modal label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; font-weight: 600; color: var(--text-secondary); margin-bottom: 12px; }
  .modal input { padding: 8px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: inherit; font-size: 13px; }
  .modal-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: 12px; }
  .modal-actions button { padding: 8px 16px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; font-size: 13px; }
  .modal-actions button.btn-primary { border: none; color: var(--bg-primary); background: var(--accent); }
  .modal-actions button.btn-secondary { color: #f87171; border-color: rgba(248,113,113,0.3); }
  .modal-actions button:disabled { opacity: 0.5; cursor: not-allowed; }
  .modal-message { margin-top: 10px; padding: 8px; font-size: 12px; background: var(--bg-primary); border-radius: var(--radius); color: var(--text-secondary); }

  @media (max-width: 768px) { .form-grid { grid-template-columns: 1fr; } .form-grid .span-2 { grid-column: span 1; } }
</style>
