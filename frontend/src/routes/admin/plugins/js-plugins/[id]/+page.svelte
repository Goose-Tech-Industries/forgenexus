<script lang="ts">
  import { page } from '$app/stores';
  import { plugins, type JsPlugin, type JsPluginExecution } from '$lib/stores/plugins.svelte';

  let pluginId = $derived(($page.params as Record<string, string>).id);
  let plugin = $state<JsPlugin | null>(null);
  let loading = $state(true);
  let tab = $state('overview');
  let saving = $state(false);
  let executions = $state<JsPluginExecution[]>([]);

  // Editable fields
  let editCode = $state('');
  let editName = $state('');
  let editDescription = $state('');
  let editSettings = $state<Record<string, any>>({});

  $effect(() => { loadPlugin(); });

  async function loadPlugin() {
    loading = true;
    try {
      plugin = await plugins.loadJsPlugin(pluginId);
      editCode = plugin.code;
      editName = plugin.name;
      editDescription = plugin.description || '';
      editSettings = { ...plugin.settings };
      const exData = await plugins.loadJsPluginExecutions(pluginId, { limit: '20' });
      executions = plugins.jsPluginExecutions;
    } finally { loading = false; }
  }

  async function saveCode() {
    saving = true;
    try {
      plugin = await plugins.updateJsPlugin(pluginId, { code: editCode });
    } finally { saving = false; }
  }

  async function saveInfo() {
    saving = true;
    try {
      plugin = await plugins.updateJsPlugin(pluginId, { name: editName, description: editDescription });
    } finally { saving = false; }
  }

  async function saveSettings() {
    saving = true;
    try {
      plugin = await plugins.updateJsPlugin(pluginId, { settings: editSettings });
    } finally { saving = false; }
  }

  async function handleActivate() {
    await plugins.activateJsPlugin(pluginId);
    await loadPlugin();
  }

  async function handleDeactivate() {
    await plugins.deactivateJsPlugin(pluginId);
    await loadPlugin();
  }

  async function handleExecute() {
    try {
      await plugins.executeJsPlugin(pluginId);
      await loadPlugin();
    } catch (e: any) {
      alert(e.error || 'Execution failed');
    }
  }

  function formatDate(d: string | null) {
    return d ? new Date(d).toLocaleString() : 'Never';
  }
</script>

{#if loading}
  <p class="loading">Loading plugin...</p>
{:else if plugin}
  <div class="plugin-detail">
    <div class="detail-header">
      <div>
        <h1>{plugin.name}</h1>
        <p class="desc">{plugin.description || 'No description'}</p>
      </div>
      <div class="header-right">
        <span class="badge badge-{plugin.status}">{plugin.status}</span>
        <span class="version">v{plugin.version}</span>
      </div>
    </div>

    <div class="tabs">
      {#each ['overview', 'code', 'settings', 'manifest', 'executions'] as t}
        <button class="tab" class:active={tab === t} onclick={() => { tab = t; }}>{t}</button>
      {/each}
    </div>

    {#if tab === 'overview'}
      <div class="section">
        <div class="meta-grid">
          <div><span class="label">Status</span><span class="value">{plugin.status}</span></div>
          <div><span class="label">Executions</span><span class="value">{plugin.execution_count}</span></div>
          <div><span class="label">Last Run</span><span class="value">{formatDate(plugin.last_executed_at)}</span></div>
          <div><span class="label">Hooks</span><span class="value">{plugin.manifest?.hooks?.length ?? 0}</span></div>
          <div><span class="label">Permissions</span><span class="value">{plugin.manifest?.permissions?.length ?? 0}</span></div>
          <div><span class="label">Version</span><span class="value">{plugin.version}</span></div>
        </div>
        {#if plugin.error_message}<div class="error-box">{plugin.error_message}</div>{/if}
        <div class="action-bar">
          {#if plugin.status !== 'active'}
            <button class="btn btn-primary" onclick={handleActivate}>Activate</button>
          {:else}
            <button class="btn" onclick={handleDeactivate}>Deactivate</button>
          {/if}
          <button class="btn" onclick={handleExecute}>Test Run</button>
        </div>
      </div>

    {:else if tab === 'code'}
      <div class="section">
        <div class="section-header">
          <h2>Plugin Code</h2>
          <button class="btn btn-primary" onclick={saveCode} disabled={saving}>{saving ? 'Saving...' : 'Save Code'}</button>
        </div>
        <textarea class="code-editor" bind:value={editCode} rows="24" spellcheck="false"></textarea>
        <div class="sdk-ref">
          <h3>SDK Reference</h3>
          <div class="ref-grid">
            <code>ForgeNexus.trigger.type</code><span>Event type (string)</span>
            <code>ForgeNexus.trigger.data</code><span>Event payload (object)</span>
            <code>ForgeNexus.settings</code><span>Admin-configured settings</span>
            <code>ForgeNexus.log(msg)</code><span>Log a message</span>
            <code>ForgeNexus.output(data)</code><span>Set plugin output</span>
            <code>ForgeNexus.api.createPost(forumId, threadId, body)</code><span>Create a post</span>
            <code>ForgeNexus.api.sendDm(userId, subject, body)</code><span>Send a DM</span>
            <code>ForgeNexus.api.setUserData(key, value)</code><span>Store user data</span>
            <code>ForgeNexus.api.emitEvent(name, payload)</code><span>Emit custom event</span>
            <code>ForgeNexus.api.httpRequest(url, opts?)</code><span>HTTP request (allowed domains only)</span>
          </div>
        </div>
      </div>

    {:else if tab === 'settings'}
      <div class="section">
        <div class="section-header">
          <h2>Plugin Settings</h2>
          <button class="btn btn-primary" onclick={saveSettings} disabled={saving}>{saving ? 'Saving...' : 'Save Settings'}</button>
        </div>
        {#if plugin.manifest?.settings_schema?.length > 0}
          {#each plugin.manifest.settings_schema as field (field.key)}
            <div class="field">
              <label>{field.label || field.key}</label>
              {#if field.type === 'boolean'}
                <label class="toggle-label">
                  <input type="checkbox" checked={editSettings[field.key] ?? field.default === 'true'} onchange={(e: Event) => { editSettings = { ...editSettings, [field.key]: (e.target as HTMLInputElement).checked }; }} />
                  <span>{editSettings[field.key] ? 'Enabled' : 'Disabled'}</span>
                </label>
              {:else if field.type === 'number'}
                <input type="number" value={editSettings[field.key] ?? field.default ?? ''} onchange={(e: Event) => { editSettings = { ...editSettings, [field.key]: Number((e.target as HTMLInputElement).value) }; }} />
              {:else}
                <input type="text" value={editSettings[field.key] ?? field.default ?? ''} onchange={(e: Event) => { editSettings = { ...editSettings, [field.key]: (e.target as HTMLInputElement).value }; }} />
              {/if}
            </div>
          {/each}
        {:else}
          <p class="empty">No settings schema defined. Add settings in the Manifest tab.</p>
        {/if}
      </div>

    {:else if tab === 'manifest'}
      <div class="section">
        <h2>Manifest</h2>
        <div class="manifest-block">
          <h3>Hooks</h3>
          <div class="tag-list">
            {#each plugin.manifest?.hooks ?? [] as hook}
              <span class="tag">{hook.replace(/_/g, ' ')}</span>
            {/each}
          </div>
        </div>
        <div class="manifest-block">
          <h3>Permissions</h3>
          <div class="tag-list">
            {#each plugin.manifest?.permissions ?? [] as perm}
              <span class="tag">{perm.replace(/_/g, ' ')}</span>
            {/each}
            {#if (plugin.manifest?.permissions ?? []).length === 0}
              <span class="empty">None</span>
            {/if}
          </div>
        </div>
        <div class="manifest-block">
          <h3>Allowed Domains</h3>
          <div class="tag-list">
            {#each plugin.manifest?.allowed_domains ?? [] as domain}
              <span class="tag">{domain}</span>
            {/each}
            {#if (plugin.manifest?.allowed_domains ?? []).length === 0}
              <span class="empty">No network access</span>
            {/if}
          </div>
        </div>
        <div class="manifest-block">
          <h3>Settings Schema</h3>
          {#each plugin.manifest?.settings_schema ?? [] as field}
            <div class="schema-row">
              <code>{field.key}</code>
              <span class="schema-type">{field.type}</span>
              <span>{field.label}</span>
              {#if field.default}<span class="schema-default">= {field.default}</span>{/if}
            </div>
          {/each}
          {#if (plugin.manifest?.settings_schema ?? []).length === 0}
            <span class="empty">No settings defined</span>
          {/if}
        </div>
      </div>

    {:else if tab === 'executions'}
      <div class="section">
        <h2>Recent Executions</h2>
        {#each executions as exec (exec.id)}
          <div class="exec-card">
            <div class="exec-header">
              <span class="badge badge-{exec.status}">{exec.status}</span>
              <span class="exec-trigger">{exec.trigger_type || 'manual'}</span>
              <span class="exec-duration">{exec.duration_ms ?? '?'}ms</span>
              <span class="exec-date">{formatDate(exec.started_at)}</span>
            </div>
            {#if exec.logs.length > 0}
              <div class="exec-logs">
                {#each exec.logs as log}
                  <div class="log-line">{log}</div>
                {/each}
              </div>
            {/if}
            {#if exec.result}
              <details class="exec-result">
                <summary>Result</summary>
                <pre>{JSON.stringify(exec.result, null, 2)}</pre>
              </details>
            {/if}
          </div>
        {/each}
        {#if executions.length === 0}<p class="empty">No executions yet</p>{/if}
      </div>
    {/if}
  </div>
{/if}

<style>
  .plugin-detail h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); }
  .desc { font-size: 13px; color: var(--text-muted); margin-top: 2px; }
  .detail-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 16px; }
  .header-right { display: flex; gap: 8px; align-items: center; }
  .version { font-size: 11px; color: var(--text-muted); }

  .tabs { display: flex; gap: 4px; margin-bottom: 16px; }
  .tab { padding: 6px 14px; border-radius: 16px; border: 1px solid var(--border-color); background: var(--bg-card); color: var(--text-secondary); font-size: 12px; font-weight: 600; cursor: pointer; text-transform: capitalize; font-family: inherit; }
  .tab.active { background: var(--accent); color: #fff; border-color: var(--accent); }

  .section { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; }
  .section h2 { font-size: 13px; font-weight: 700; color: var(--text-primary); margin-bottom: 12px; text-transform: uppercase; letter-spacing: 0.03em; }
  .section-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }

  .meta-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-bottom: 16px; }
  .meta-grid div { display: flex; flex-direction: column; gap: 2px; }
  .meta-grid .label { font-size: 11px; color: var(--text-muted); text-transform: uppercase; }
  .meta-grid .value { font-size: 14px; font-weight: 600; color: var(--text-primary); }

  .error-box { padding: 10px; background: #dc262620; border: 1px solid #dc262640; border-radius: var(--radius); color: #f87171; font-size: 13px; margin-bottom: 12px; }
  .action-bar { display: flex; gap: 8px; }
  .btn { padding: 6px 16px; border-radius: var(--radius); font-size: 12px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); background: var(--bg-card); color: var(--text-secondary); font-family: inherit; }
  .btn-primary { background: var(--accent); color: #fff; border-color: var(--accent); }
  .btn:disabled { opacity: 0.5; }

  .code-editor { width: 100%; font-family: var(--font-mono); font-size: 12px; line-height: 1.5; padding: 12px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-input); color: var(--text-primary); resize: vertical; min-height: 300px; tab-size: 2; }
  .code-editor:focus { outline: none; border-color: var(--accent); }

  .sdk-ref { margin-top: 16px; padding: 12px; background: var(--bg-tertiary); border-radius: var(--radius); }
  .sdk-ref h3 { font-size: 11px; font-weight: 700; color: var(--text-secondary); text-transform: uppercase; margin-bottom: 8px; }
  .ref-grid { display: grid; grid-template-columns: auto 1fr; gap: 4px 12px; font-size: 11px; }
  .ref-grid code { color: var(--accent); font-family: var(--font-mono); font-size: 10px; }
  .ref-grid span { color: var(--text-muted); }

  .field { display: flex; flex-direction: column; gap: 4px; margin-bottom: 10px; }
  .field label { font-size: 12px; font-weight: 600; color: var(--text-secondary); text-transform: capitalize; }
  input, select { padding: 8px 12px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-input); color: var(--text-primary); font-size: 13px; font-family: inherit; width: 100%; }
  input:focus { outline: none; border-color: var(--accent); }
  .toggle-label { display: flex; align-items: center; gap: 8px; cursor: pointer; font-size: 12px; color: var(--text-secondary); }
  .toggle-label input[type="checkbox"] { width: auto; }

  .manifest-block { margin-bottom: 14px; }
  .manifest-block h3 { font-size: 11px; font-weight: 700; color: var(--text-secondary); text-transform: uppercase; margin-bottom: 6px; }
  .tag-list { display: flex; flex-wrap: wrap; gap: 4px; }
  .tag { font-size: 10px; padding: 2px 8px; border-radius: 6px; background: var(--bg-tertiary); color: var(--text-primary); text-transform: capitalize; }
  .schema-row { display: flex; align-items: center; gap: 8px; font-size: 12px; padding: 4px 0; border-bottom: 1px solid var(--border-color); }
  .schema-row:last-child { border-bottom: none; }
  .schema-row code { font-family: var(--font-mono); font-size: 11px; color: var(--accent); }
  .schema-type { font-size: 10px; padding: 1px 5px; border-radius: 4px; background: var(--bg-tertiary); color: var(--text-muted); }
  .schema-default { color: var(--text-muted); font-size: 11px; }

  .exec-card { border: 1px solid var(--border-color); border-radius: var(--radius); padding: 10px; margin-bottom: 8px; }
  .exec-header { display: flex; align-items: center; gap: 8px; font-size: 12px; }
  .exec-trigger { color: var(--text-secondary); text-transform: capitalize; }
  .exec-duration { color: var(--text-muted); }
  .exec-date { color: var(--text-muted); font-size: 11px; margin-left: auto; }
  .exec-logs { margin-top: 8px; padding: 8px; background: var(--bg-primary); border-radius: var(--radius); font-family: var(--font-mono); font-size: 11px; }
  .log-line { color: var(--text-secondary); padding: 1px 0; }
  .exec-result { margin-top: 6px; font-size: 11px; }
  .exec-result summary { cursor: pointer; color: var(--text-muted); }
  .exec-result pre { margin-top: 4px; padding: 8px; background: var(--bg-primary); border-radius: var(--radius); font-family: var(--font-mono); font-size: 10px; color: var(--text-secondary); overflow-x: auto; }

  .badge { padding: 2px 8px; border-radius: 10px; font-size: 10px; font-weight: 600; background: var(--bg-tertiary); color: var(--text-secondary); }
  .badge-active, .badge-completed { background: #22c55e33; color: #4ade80; }
  .badge-draft { background: #eab30833; color: #fbbf24; }
  .badge-error, .badge-failed { background: #dc262633; color: #f87171; }
  .badge-running { background: #3b82f633; color: #60a5fa; }
  .badge-disabled { background: var(--bg-tertiary); color: var(--text-muted); }

  .empty { color: var(--text-muted); font-size: 12px; }
  .loading { color: var(--text-muted); font-size: 13px; text-align: center; padding: 24px 0; }
</style>
