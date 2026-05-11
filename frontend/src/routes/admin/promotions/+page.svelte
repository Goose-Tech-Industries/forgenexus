<script lang="ts">
  import { api } from '$lib/api/client';

  interface Group { id: string; name: string; color?: string | null }

  interface PromotionRule {
    id: string;
    name: string;
    criteria: Record<string, any>;
    is_active: boolean;
    position: number;
    from_group: Group | null;
    to_group: Group | null;
  }

  interface Summary {
    evaluated: number;
    promoted: number;
    per_rule: Array<{ rule_id: string; rule_name: string; candidates: number; promoted: number }>;
  }

  let rules = $state<PromotionRule[]>([]);
  let groups = $state<Group[]>([]);
  let loading = $state(true);
  let error = $state('');

  let showForm = $state(false);
  let editing = $state<PromotionRule | null>(null);
  let form = $state({
    name: '',
    from_group_id: '',
    to_group_id: '',
    is_active: true,
    position: 0,
    post_count: 0,
    thread_count: 0,
    reputation: 0,
    trust_level: 0,
    days_since_join: 0
  });
  let saving = $state(false);
  let formError = $state('');

  let evaluating = $state(false);
  let summary = $state<Summary | null>(null);
  let evalError = $state('');

  $effect(() => { load(); });

  async function load() {
    loading = true;
    error = '';
    try {
      const [rulesData, groupsData] = await Promise.all([
        api.getPromotionRules(),
        api.getAdminGroups()
      ]);
      rules = rulesData.rules || [];
      groups = (groupsData.groups || []).map((g: any) => ({ id: g.id, name: g.name, color: g.color }));
    } catch (err: any) {
      error = err?.error || 'Failed to load promotion rules.';
    }
    loading = false;
  }

  function emptyForm() {
    return {
      name: '',
      from_group_id: '',
      to_group_id: '',
      is_active: true,
      position: rules.length,
      post_count: 0,
      thread_count: 0,
      reputation: 0,
      trust_level: 0,
      days_since_join: 0
    };
  }

  function openCreate() {
    editing = null;
    form = emptyForm();
    formError = '';
    showForm = true;
  }

  function openEdit(rule: PromotionRule) {
    editing = rule;
    const c = rule.criteria || {};
    form = {
      name: rule.name,
      from_group_id: rule.from_group?.id || '',
      to_group_id: rule.to_group?.id || '',
      is_active: rule.is_active,
      position: rule.position,
      post_count: Number(c.post_count || 0),
      thread_count: Number(c.thread_count || 0),
      reputation: Number(c.reputation || 0),
      trust_level: Number(c.trust_level || 0),
      days_since_join: Number(c.days_since_join || 0)
    };
    formError = '';
    showForm = true;
  }

  function buildCriteria(): Record<string, number> {
    const c: Record<string, number> = {};
    if (form.post_count > 0) c.post_count = form.post_count;
    if (form.thread_count > 0) c.thread_count = form.thread_count;
    if (form.reputation > 0) c.reputation = form.reputation;
    if (form.trust_level > 0) c.trust_level = form.trust_level;
    if (form.days_since_join > 0) c.days_since_join = form.days_since_join;
    return c;
  }

  async function handleSave() {
    formError = '';
    if (!form.name.trim()) { formError = 'Name is required.'; return; }
    if (!form.to_group_id) { formError = 'Target group is required.'; return; }
    const criteria = buildCriteria();
    if (Object.keys(criteria).length === 0) {
      formError = 'At least one criterion (post_count, reputation, etc.) must be set above 0.';
      return;
    }
    saving = true;
    const payload: Record<string, any> = {
      name: form.name.trim(),
      to_group_id: form.to_group_id,
      criteria,
      is_active: form.is_active,
      position: Number(form.position) || 0
    };
    if (form.from_group_id) payload.from_group_id = form.from_group_id;

    try {
      if (editing) {
        await api.updatePromotionRule(editing.id, payload);
      } else {
        await api.createPromotionRule(payload);
      }
      showForm = false;
      editing = null;
      await load();
    } catch (err: any) {
      formError = err?.error ? JSON.stringify(err.error) : 'Failed to save rule.';
    }
    saving = false;
  }

  async function handleDelete(rule: PromotionRule) {
    if (!confirm(`Delete promotion rule "${rule.name}"?`)) return;
    try {
      await api.deletePromotionRule(rule.id);
      await load();
    } catch (err: any) {
      alert('Failed to delete: ' + (err?.error || 'unknown error'));
    }
  }

  async function toggleActive(rule: PromotionRule) {
    await api.updatePromotionRule(rule.id, { is_active: !rule.is_active });
    await load();
  }

  async function runEvaluation() {
    if (!confirm('Evaluate all active promotion rules and promote qualifying users right now?')) return;
    evaluating = true;
    evalError = '';
    summary = null;
    try {
      const data = await api.evaluatePromotionRules();
      summary = data.summary;
      await load();
    } catch (err: any) {
      evalError = err?.error || 'Evaluation failed.';
    }
    evaluating = false;
  }

  function criteriaPreview(c: Record<string, any>): string {
    const parts: string[] = [];
    if (c.post_count) parts.push(`posts ≥ ${c.post_count}`);
    if (c.thread_count) parts.push(`threads ≥ ${c.thread_count}`);
    if (c.reputation) parts.push(`rep ≥ ${c.reputation}`);
    if (c.trust_level) parts.push(`trust ≥ ${c.trust_level}`);
    if (c.days_since_join) parts.push(`${c.days_since_join}d since join`);
    return parts.length ? parts.join(' AND ') : 'no criteria';
  }
</script>

<div class="admin-page">
  <div class="page-header">
    <div>
      <h1>Promotion Rules</h1>
      <p class="page-sub">Automatically move users between groups when they meet criteria (post count, reputation, account age, etc.).</p>
    </div>
    <div class="header-actions">
      <button class="btn-secondary" onclick={runEvaluation} disabled={evaluating || rules.length === 0}>
        {evaluating ? 'Evaluating...' : 'Run Evaluation Now'}
      </button>
      <button class="btn-primary" onclick={openCreate}>New Rule</button>
    </div>
  </div>

  {#if summary}
    <div class="summary-card">
      <div class="summary-head">
        <strong>{summary.promoted}</strong> users promoted across <strong>{summary.per_rule.length}</strong> rules
        ({summary.evaluated} candidates evaluated)
      </div>
      {#if summary.per_rule.length > 0}
        <div class="summary-rules">
          {#each summary.per_rule as r (r.rule_id)}
            <div class="summary-row">
              <span class="summary-name">{r.rule_name}</span>
              <span class="summary-stats">{r.promoted} / {r.candidates} promoted</span>
            </div>
          {/each}
        </div>
      {/if}
    </div>
  {/if}

  {#if evalError}<div class="error-banner">{evalError}</div>{/if}

  {#if showForm}
    <div class="form-card">
      <h3>{editing ? `Edit: ${editing.name}` : 'New Promotion Rule'}</h3>
      <div class="form-grid">
        <label class="span-2">Name
          <input type="text" bind:value={form.name} placeholder="Veteran Member promotion" />
        </label>
        <label>From Group <span class="hint">(optional)</span>
          <select bind:value={form.from_group_id}>
            <option value="">— Any user —</option>
            {#each groups as g}<option value={g.id}>{g.name}</option>{/each}
          </select>
        </label>
        <label>To Group
          <select bind:value={form.to_group_id}>
            <option value="">— Select a target group —</option>
            {#each groups as g}<option value={g.id}>{g.name}</option>{/each}
          </select>
        </label>
      </div>

      <div class="criteria-section">
        <h4>Criteria (all must be met — set 0 to ignore)</h4>
        <div class="criteria-grid">
          <label>Minimum post count<input type="number" bind:value={form.post_count} min="0" /></label>
          <label>Minimum thread count<input type="number" bind:value={form.thread_count} min="0" /></label>
          <label>Minimum reputation<input type="number" bind:value={form.reputation} min="0" /></label>
          <label>Minimum trust level<input type="number" bind:value={form.trust_level} min="0" max="4" /></label>
          <label>Days since joined<input type="number" bind:value={form.days_since_join} min="0" /></label>
          <label>Position (priority)<input type="number" bind:value={form.position} /></label>
        </div>
      </div>

      <div class="toggles">
        <label class="checkbox"><input type="checkbox" bind:checked={form.is_active} /> Active</label>
      </div>

      {#if formError}<div class="form-error">{formError}</div>{/if}

      <div class="form-actions">
        <button onclick={() => { showForm = false; editing = null; }}>Cancel</button>
        <button class="btn-primary" onclick={handleSave} disabled={saving || !form.name.trim() || !form.to_group_id}>
          {saving ? 'Saving...' : editing ? 'Update' : 'Create'}
        </button>
      </div>
    </div>
  {/if}

  {#if loading}
    <p class="loading">Loading promotion rules...</p>
  {:else if error}
    <div class="error-banner">{error}</div>
  {:else if rules.length === 0}
    <p class="empty">No promotion rules defined yet. Create one to auto-promote users based on activity.</p>
  {:else}
    <div class="rules-list">
      {#each rules as rule (rule.id)}
        <div class="rule-card" class:inactive={!rule.is_active}>
          <div class="rule-head">
            <div class="rule-head-left">
              <strong>{rule.name}</strong>
              <span class="status" class:on={rule.is_active} class:off={!rule.is_active}>
                {rule.is_active ? 'Active' : 'Disabled'}
              </span>
              <span class="position">#{rule.position}</span>
            </div>
            <div class="rule-actions">
              <button class="btn-sm" onclick={() => toggleActive(rule)}>{rule.is_active ? 'Disable' : 'Enable'}</button>
              <button class="btn-sm" onclick={() => openEdit(rule)}>Edit</button>
              <button class="btn-sm danger" onclick={() => handleDelete(rule)}>Delete</button>
            </div>
          </div>
          <div class="rule-flow">
            <span class="group-chip">{rule.from_group?.name || 'Any user'}</span>
            <span class="arrow">→</span>
            <span class="group-chip to">{rule.to_group?.name || '(no target)'}</span>
          </div>
          <div class="rule-criteria">
            <code>{criteriaPreview(rule.criteria)}</code>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .admin-page { max-width: 1000px; }
  .page-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 16px; gap: 16px; flex-wrap: wrap; }
  .page-header h1 { font-size: 20px; font-weight: 800; }
  .page-sub { font-size: 12px; color: var(--text-muted); margin-top: 2px; max-width: 640px; }
  .header-actions { display: flex; gap: 8px; }
  .btn-primary { background: var(--accent); color: var(--bg-primary); border: none; padding: 8px 16px; border-radius: var(--radius); font-weight: 600; cursor: pointer; font-family: inherit; font-size: 13px; }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-secondary { background: var(--bg-secondary); color: var(--text-primary); border: 1px solid var(--border-color); padding: 8px 16px; border-radius: var(--radius); font-family: inherit; font-size: 13px; cursor: pointer; }
  .btn-secondary:disabled { opacity: 0.5; cursor: not-allowed; }

  .summary-card { background: rgba(52,211,153,0.08); border: 1px solid rgba(52,211,153,0.2); border-radius: var(--radius-lg); padding: 12px 16px; margin-bottom: 16px; font-size: 12px; color: var(--text-secondary); }
  .summary-card strong { color: #34d399; font-variant-numeric: tabular-nums; }
  .summary-head { margin-bottom: 8px; }
  .summary-rules { display: flex; flex-direction: column; gap: 4px; }
  .summary-row { display: flex; justify-content: space-between; padding: 4px 8px; background: var(--bg-primary); border-radius: var(--radius); }
  .summary-name { font-weight: 600; color: var(--text-primary); }
  .summary-stats { color: var(--text-muted); font-variant-numeric: tabular-nums; }

  .form-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 20px; margin-bottom: 16px; }
  .form-card h3 { font-size: 15px; font-weight: 700; margin-bottom: 12px; }
  .form-card h4 { font-size: 12px; font-weight: 700; margin: 16px 0 8px; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.05em; }
  .form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  .form-grid .span-2 { grid-column: span 2; }
  .form-grid label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  .hint { font-weight: 400; color: var(--text-muted); font-size: 11px; }
  .form-grid input, .form-grid select, .criteria-grid input { padding: 8px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: inherit; font-size: 13px; }
  .criteria-section { margin-top: 12px; }
  .criteria-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; }
  .criteria-grid label { display: flex; flex-direction: column; gap: 4px; font-size: 11px; font-weight: 600; color: var(--text-secondary); }
  .toggles { display: flex; gap: 16px; margin-top: 14px; }
  .checkbox { display: flex; align-items: center; gap: 6px; font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  .form-error { margin-top: 12px; padding: 10px; background: rgba(248,113,113,0.1); border: 1px solid rgba(248,113,113,0.3); border-radius: var(--radius); color: #f87171; font-size: 12px; }
  .form-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: 14px; }
  .form-actions button { padding: 8px 16px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; font-size: 13px; }
  .form-actions button.btn-primary { border: none; color: var(--bg-primary); background: var(--accent); }

  .rules-list { display: flex; flex-direction: column; gap: 10px; }
  .rule-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 14px; }
  .rule-card.inactive { opacity: 0.55; }
  .rule-head { display: flex; justify-content: space-between; align-items: center; gap: 12px; flex-wrap: wrap; margin-bottom: 8px; }
  .rule-head-left { display: flex; align-items: center; gap: 10px; }
  .rule-head-left strong { font-weight: 700; }
  .rule-actions { display: flex; gap: 6px; }
  .status { display: inline-block; padding: 2px 8px; font-size: 10px; font-weight: 700; border-radius: 10px; text-transform: uppercase; letter-spacing: 0.05em; }
  .status.on { background: rgba(52,211,153,0.15); color: #34d399; }
  .status.off { background: rgba(156,163,175,0.15); color: #9ca3af; }
  .position { font-size: 11px; color: var(--text-muted); font-variant-numeric: tabular-nums; }
  .rule-flow { display: flex; align-items: center; gap: 8px; margin: 8px 0; font-size: 12px; }
  .group-chip { padding: 4px 10px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: 12px; color: var(--text-secondary); }
  .group-chip.to { background: var(--accent-glow); color: var(--accent); border-color: var(--accent); }
  .arrow { color: var(--text-muted); font-weight: 700; }
  .rule-criteria { font-family: ui-monospace, monospace; font-size: 11px; color: var(--text-muted); }
  .btn-sm { padding: 4px 10px; font-size: 11px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; }
  .btn-sm:hover { background: var(--bg-hover); color: var(--text-primary); }
  .btn-sm.danger { color: #f87171; border-color: rgba(248,113,113,0.3); }

  .loading, .empty { text-align: center; color: var(--text-muted); padding: 30px; }
  .error-banner { padding: 12px; background: rgba(248,113,113,0.1); border: 1px solid rgba(248,113,113,0.3); border-radius: var(--radius); color: #f87171; margin-bottom: 12px; }

  @media (max-width: 768px) {
    .criteria-grid { grid-template-columns: 1fr 1fr; }
    .form-grid { grid-template-columns: 1fr; }
    .form-grid .span-2 { grid-column: span 1; }
  }
</style>
