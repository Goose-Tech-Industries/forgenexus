<script lang="ts">
  import { api } from '$lib/api/client';

  interface SlashCommand {
    id: string;
    name: string;
    description: string | null;
    category: string;
    enabled: boolean;
    cooldown_seconds: number;
    permission_level: string;
    response_type: string;
    usage_count: number;
    is_built_in: boolean;
    flow_id: string | null;
    inserted_at?: string;
    updated_at?: string;
  }

  interface Flow {
    id: string;
    name: string;
  }

  const PERMISSION_LEVELS = ['everyone', 'member', 'moderator', 'admin'];
  const RESPONSE_TYPES = ['channel', 'ephemeral', 'dm'];

  let commands = $state<SlashCommand[]>([]);
  let flows = $state<Flow[]>([]);
  let loading = $state(true);
  let error = $state('');

  let showForm = $state(false);
  let editing = $state<SlashCommand | null>(null);
  let form = $state({
    name: '',
    description: '',
    category: 'general',
    flow_id: '',
    cooldown_seconds: 0,
    permission_level: 'everyone',
    response_type: 'channel',
    enabled: true
  });
  let saving = $state(false);
  let formError = $state('');

  let search = $state('');
  let categoryFilter = $state('');

  $effect(() => { load(); });

  async function load() {
    loading = true;
    error = '';
    try {
      const [cmdData, flowData] = await Promise.all([
        api.getAdminSlashCommands(),
        loadFlows()
      ]);
      commands = cmdData.commands || [];
      flows = flowData;
    } catch (err: any) {
      error = err?.error || 'Failed to load slash commands.';
    }
    loading = false;
  }

  async function loadFlows(): Promise<Flow[]> {
    try {
      const data = await api.request('/admin/plugins/flows');
      return (data.flows || []).map((f: any) => ({ id: f.id, name: f.name }));
    } catch {
      return [];
    }
  }

  const filtered = $derived.by(() => {
    const q = search.trim().toLowerCase();
    return commands.filter((c) => {
      if (q && !c.name.toLowerCase().includes(q) && !(c.description || '').toLowerCase().includes(q)) return false;
      if (categoryFilter && c.category !== categoryFilter) return false;
      return true;
    });
  });

  const categories = $derived(Array.from(new Set(commands.map((c) => c.category))).sort());

  function openCreate() {
    editing = null;
    form = { name: '', description: '', category: 'general', flow_id: '', cooldown_seconds: 0, permission_level: 'everyone', response_type: 'channel', enabled: true };
    formError = '';
    showForm = true;
  }

  function openEdit(cmd: SlashCommand) {
    editing = cmd;
    form = {
      name: cmd.name,
      description: cmd.description || '',
      category: cmd.category,
      flow_id: cmd.flow_id || '',
      cooldown_seconds: cmd.cooldown_seconds,
      permission_level: cmd.permission_level,
      response_type: cmd.response_type,
      enabled: cmd.enabled
    };
    formError = '';
    showForm = true;
  }

  async function handleSave() {
    formError = '';
    if (!form.name.trim()) { formError = 'Command name is required.'; return; }
    if (!/^[a-z][a-z0-9_-]*$/i.test(form.name.trim())) { formError = 'Name must start with a letter and contain only letters, digits, _, -.'; return; }
    saving = true;
    const payload: Record<string, any> = {
      name: form.name.trim().toLowerCase(),
      description: form.description || null,
      category: form.category.trim() || 'general',
      cooldown_seconds: Number(form.cooldown_seconds) || 0,
      permission_level: form.permission_level,
      response_type: form.response_type,
      enabled: form.enabled
    };
    if (form.flow_id) payload.flow_id = form.flow_id;

    try {
      if (editing) {
        await api.updateSlashCommand(editing.id, payload);
      } else {
        await api.createSlashCommand(payload);
      }
      showForm = false;
      editing = null;
      await load();
    } catch (err: any) {
      formError = err?.error ? JSON.stringify(err.error) : 'Failed to save command.';
    }
    saving = false;
  }

  async function handleDelete(cmd: SlashCommand) {
    if (cmd.is_built_in) {
      alert('Built-in commands cannot be deleted.');
      return;
    }
    if (!confirm(`Delete slash command /${cmd.name}?`)) return;
    try {
      await api.deleteSlashCommand(cmd.id);
      await load();
    } catch (err: any) {
      alert('Failed to delete: ' + (err?.error || 'unknown error'));
    }
  }

  async function toggleEnabled(cmd: SlashCommand) {
    await api.updateSlashCommand(cmd.id, { enabled: !cmd.enabled });
    await load();
  }

  function flowName(id: string | null): string {
    if (!id) return '—';
    const f = flows.find((x) => x.id === id);
    return f ? f.name : id.slice(0, 8) + '…';
  }
</script>

<div class="admin-page">
  <div class="page-header">
    <div>
      <h1>Slash Commands</h1>
      <p class="page-sub">Chat commands like <code>/warn</code> and <code>/poll</code>. Link each command to a no-code flow that runs when invoked.</p>
    </div>
    <button class="btn-primary" onclick={openCreate}>New Command</button>
  </div>

  <div class="filters">
    <input type="text" bind:value={search} placeholder="Search by name or description..." />
    <select bind:value={categoryFilter}>
      <option value="">All categories</option>
      {#each categories as cat}<option value={cat}>{cat}</option>{/each}
    </select>
  </div>

  {#if showForm}
    <div class="form-card">
      <h3>{editing ? `Edit: /${editing.name}` : 'New Slash Command'}</h3>
      <div class="form-grid">
        <label>Name <span class="hint">(no slash)</span>
          <input type="text" bind:value={form.name} placeholder="warn" disabled={!!editing && editing.is_built_in} />
        </label>
        <label>Category
          <input type="text" bind:value={form.category} placeholder="moderation" />
        </label>
        <label class="span-2">Description
          <input type="text" bind:value={form.description} placeholder="Warn a user for rule violations" />
        </label>
        <label>Linked Flow
          <select bind:value={form.flow_id}>
            <option value="">— No flow (inert) —</option>
            {#each flows as f}<option value={f.id}>{f.name}</option>{/each}
          </select>
        </label>
        <label>Cooldown (seconds)
          <input type="number" bind:value={form.cooldown_seconds} min="0" />
        </label>
        <label>Permission
          <select bind:value={form.permission_level}>
            {#each PERMISSION_LEVELS as lvl}<option value={lvl}>{lvl}</option>{/each}
          </select>
        </label>
        <label>Response Type
          <select bind:value={form.response_type}>
            {#each RESPONSE_TYPES as t}<option value={t}>{t}</option>{/each}
          </select>
        </label>
      </div>
      <div class="toggles">
        <label class="checkbox"><input type="checkbox" bind:checked={form.enabled} /> Enabled</label>
      </div>
      {#if formError}<div class="form-error">{formError}</div>{/if}
      <div class="form-actions">
        <button onclick={() => { showForm = false; editing = null; }}>Cancel</button>
        <button class="btn-primary" onclick={handleSave} disabled={saving || !form.name.trim()}>
          {saving ? 'Saving...' : editing ? 'Update' : 'Create'}
        </button>
      </div>
    </div>
  {/if}

  {#if loading}
    <p class="loading">Loading commands...</p>
  {:else if error}
    <div class="error-banner">{error}</div>
  {:else if filtered.length === 0}
    <p class="empty">{commands.length === 0 ? 'No slash commands yet.' : 'No commands match your filters.'}</p>
  {:else}
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Command</th>
            <th>Category</th>
            <th>Flow</th>
            <th>Permission</th>
            <th>Cooldown</th>
            <th>Used</th>
            <th>Status</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each filtered as cmd (cmd.id)}
            <tr class:inactive={!cmd.enabled}>
              <td>
                <code class="cmd-name">/{cmd.name}</code>
                {#if cmd.is_built_in}<span class="tag built-in">built-in</span>{/if}
                {#if cmd.description}<div class="cmd-desc">{cmd.description}</div>{/if}
              </td>
              <td>{cmd.category}</td>
              <td class="flow-cell">{flowName(cmd.flow_id)}</td>
              <td><span class="perm perm-{cmd.permission_level}">{cmd.permission_level}</span></td>
              <td class="num">{cmd.cooldown_seconds}s</td>
              <td class="num">{cmd.usage_count}</td>
              <td>
                <span class="status" class:on={cmd.enabled} class:off={!cmd.enabled}>
                  {cmd.enabled ? 'On' : 'Off'}
                </span>
              </td>
              <td class="actions">
                <button class="btn-sm" onclick={() => toggleEnabled(cmd)}>{cmd.enabled ? 'Disable' : 'Enable'}</button>
                <button class="btn-sm" onclick={() => openEdit(cmd)}>Edit</button>
                {#if !cmd.is_built_in}
                  <button class="btn-sm danger" onclick={() => handleDelete(cmd)}>Delete</button>
                {/if}
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
  .page-sub { font-size: 12px; color: var(--text-muted); margin-top: 2px; max-width: 640px; }
  .page-sub code { background: var(--bg-primary); padding: 1px 4px; border-radius: 3px; }
  .btn-primary { background: var(--accent); color: var(--bg-primary); border: none; padding: 8px 16px; border-radius: var(--radius); font-weight: 600; cursor: pointer; font-family: inherit; font-size: 13px; }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }

  .filters { display: flex; gap: 8px; margin-bottom: 12px; flex-wrap: wrap; }
  .filters input, .filters select { padding: 8px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: inherit; font-size: 13px; }
  .filters input { flex: 1; min-width: 200px; }

  .form-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 20px; margin-bottom: 16px; }
  .form-card h3 { font-size: 15px; font-weight: 700; margin-bottom: 12px; }
  .form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  .form-grid .span-2 { grid-column: span 2; }
  .form-grid label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  .hint { font-weight: 400; color: var(--text-muted); font-size: 11px; }
  .form-grid input, .form-grid select { padding: 8px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: inherit; font-size: 13px; }
  .toggles { display: flex; gap: 16px; margin-top: 12px; }
  .checkbox { display: flex; align-items: center; gap: 6px; font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  .form-error { margin-top: 10px; padding: 10px; background: rgba(248,113,113,0.1); border: 1px solid rgba(248,113,113,0.3); border-radius: var(--radius); color: #f87171; font-size: 12px; }
  .form-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: 12px; }
  .form-actions button { padding: 8px 16px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; font-size: 13px; }
  .form-actions button.btn-primary { border: none; color: var(--bg-primary); background: var(--accent); }

  .table-wrap { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); overflow: auto; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  th { text-align: left; padding: 10px 12px; background: var(--bg-primary); color: var(--text-muted); font-size: 10px; text-transform: uppercase; letter-spacing: 0.05em; border-bottom: 1px solid var(--border-color); font-weight: 700; }
  td { padding: 10px 12px; border-bottom: 1px solid var(--border-color); vertical-align: middle; }
  tr.inactive { opacity: 0.55; }
  .cmd-name { font-family: ui-monospace, monospace; color: var(--accent); font-weight: 700; }
  .cmd-desc { font-size: 11px; color: var(--text-muted); margin-top: 2px; }
  .flow-cell { font-size: 11px; color: var(--text-secondary); }
  .num { font-variant-numeric: tabular-nums; color: var(--text-secondary); }
  .status { display: inline-block; padding: 2px 8px; font-size: 10px; font-weight: 700; border-radius: 10px; text-transform: uppercase; letter-spacing: 0.05em; }
  .status.on { background: rgba(52,211,153,0.15); color: #34d399; }
  .status.off { background: rgba(156,163,175,0.15); color: #9ca3af; }
  .perm { display: inline-block; padding: 2px 8px; font-size: 10px; font-weight: 700; border-radius: 10px; text-transform: capitalize; }
  .perm-everyone { background: rgba(156,163,175,0.15); color: #9ca3af; }
  .perm-member { background: rgba(96,165,250,0.15); color: #60a5fa; }
  .perm-moderator { background: rgba(250,204,21,0.15); color: #facc15; }
  .perm-admin { background: rgba(248,113,113,0.15); color: #f87171; }
  .tag.built-in { display: inline-block; margin-left: 6px; padding: 1px 6px; font-size: 9px; font-weight: 700; border-radius: 8px; background: rgba(168,85,247,0.15); color: #a855f7; text-transform: uppercase; letter-spacing: 0.05em; }
  .actions { display: flex; gap: 4px; flex-wrap: wrap; }
  .btn-sm { padding: 4px 10px; font-size: 11px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; }
  .btn-sm:hover { background: var(--bg-hover); color: var(--text-primary); }
  .btn-sm.danger { color: #f87171; border-color: rgba(248,113,113,0.3); }

  .loading, .empty { text-align: center; color: var(--text-muted); padding: 30px; }
  .error-banner { padding: 12px; background: rgba(248,113,113,0.1); border: 1px solid rgba(248,113,113,0.3); border-radius: var(--radius); color: #f87171; }
</style>
