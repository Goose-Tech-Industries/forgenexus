<script lang="ts">
  import { plugins } from '$lib/stores/plugins.svelte';
  import { goto } from '$app/navigation';

  let name = $state('');
  let description = $state('');
  let code = $state(`// ForgeNexus JS Plugin
// Available: ForgeNexus.trigger, ForgeNexus.settings, ForgeNexus.log(), ForgeNexus.output(), ForgeNexus.api.*

ForgeNexus.log("Plugin executed!");
ForgeNexus.output({ message: "Hello from my plugin!" });
`);

  // Manifest
  let hooks = $state<string[]>(['on_post_created']);
  let permissions = $state<string[]>([]);
  let allowedDomains = $state('');

  // Settings schema
  let settingsSchema = $state<{ key: string; type: string; label: string; default: string }[]>([]);

  let saving = $state(false);
  let error = $state('');

  const availableHooks = [
    'on_post_created', 'on_thread_created', 'on_user_joined', 'on_user_left',
    'on_reaction_added', 'on_chat_message', 'on_custom_event', 'manual'
  ];

  const availablePermissions = [
    'create_post', 'send_dm', 'send_notification', 'read_data', 'write_data',
    'read_data_tables', 'write_data_tables', 'emit_events', 'manage_users', 'http_request'
  ];

  function toggleHook(hook: string) {
    if (hooks.includes(hook)) hooks = hooks.filter(h => h !== hook);
    else hooks = [...hooks, hook];
  }

  function togglePermission(perm: string) {
    if (permissions.includes(perm)) permissions = permissions.filter(p => p !== perm);
    else permissions = [...permissions, perm];
  }

  function addSettingsField() {
    settingsSchema = [...settingsSchema, { key: '', type: 'string', label: '', default: '' }];
  }

  function removeSettingsField(i: number) {
    settingsSchema = settingsSchema.filter((_, idx) => idx !== i);
  }

  async function handleCreate() {
    if (!name.trim()) { error = 'Name is required'; return; }
    if (hooks.length === 0) { error = 'Select at least one hook'; return; }
    saving = true;
    error = '';
    try {
      const manifest = {
        hooks,
        permissions,
        settings_schema: settingsSchema.filter(s => s.key),
        allowed_domains: allowedDomains.split(',').map(d => d.trim()).filter(Boolean),
      };
      const plugin = await plugins.createJsPlugin({ name, description, code, manifest });
      goto(`/admin/plugins/js-plugins/${plugin.id}`);
    } catch (e: any) {
      error = e.error || 'Failed to create plugin';
    } finally {
      saving = false;
    }
  }
</script>

<div class="page-header">
  <h1>New JS Plugin</h1>
</div>

{#if error}<div class="error-box">{error}</div>{/if}

<div class="form-layout">
  <div class="form-section">
    <h2>Plugin Info</h2>
    <div class="field">
      <label>Name</label>
      <input type="text" bind:value={name} placeholder="My Plugin" />
    </div>
    <div class="field">
      <label>Description</label>
      <textarea bind:value={description} rows="2" placeholder="What does this plugin do?"></textarea>
    </div>
  </div>

  <div class="form-section">
    <h2>Hooks</h2>
    <p class="hint">Which events should trigger this plugin?</p>
    <div class="checkbox-grid">
      {#each availableHooks as hook}
        <label class="checkbox-label">
          <input type="checkbox" checked={hooks.includes(hook)} onchange={() => toggleHook(hook)} />
          <span>{hook.replace(/_/g, ' ')}</span>
        </label>
      {/each}
    </div>
  </div>

  <div class="form-section">
    <h2>Permissions</h2>
    <p class="hint">What API capabilities does this plugin need?</p>
    <div class="checkbox-grid">
      {#each availablePermissions as perm}
        <label class="checkbox-label">
          <input type="checkbox" checked={permissions.includes(perm)} onchange={() => togglePermission(perm)} />
          <span>{perm.replace(/_/g, ' ')}</span>
        </label>
      {/each}
    </div>
  </div>

  <div class="form-section">
    <h2>Allowed Domains</h2>
    <p class="hint">Comma-separated domains the plugin can make HTTP requests to (leave empty for no network access)</p>
    <input type="text" bind:value={allowedDomains} placeholder="api.example.com, hooks.slack.com" />
  </div>

  <div class="form-section">
    <h2>Settings Schema</h2>
    <p class="hint">Define configurable settings for this plugin</p>
    {#each settingsSchema as field, i}
      <div class="settings-row">
        <input type="text" bind:value={field.key} placeholder="key" />
        <select bind:value={field.type}>
          <option value="string">String</option>
          <option value="number">Number</option>
          <option value="boolean">Boolean</option>
        </select>
        <input type="text" bind:value={field.label} placeholder="Label" />
        <input type="text" bind:value={field.default} placeholder="Default" />
        <button class="btn-tiny" onclick={() => removeSettingsField(i)}>x</button>
      </div>
    {/each}
    <button class="btn-sm" onclick={addSettingsField}>Add Field</button>
  </div>

  <div class="form-section">
    <h2>Plugin Code</h2>
    <p class="hint">TypeScript code executed in sandboxed Deno runtime</p>
    <textarea class="code-editor" bind:value={code} rows="16" spellcheck="false"></textarea>
  </div>

  <div class="form-actions">
    <button class="btn" onclick={() => goto('/admin/plugins/js-plugins')}>Cancel</button>
    <button class="btn btn-primary" onclick={handleCreate} disabled={saving}>
      {saving ? 'Creating...' : 'Create Plugin'}
    </button>
  </div>
</div>

<style>
  .page-header h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); margin-bottom: 16px; }
  .error-box { padding: 10px; background: #dc262620; border: 1px solid #dc262640; border-radius: var(--radius); color: #f87171; font-size: 13px; margin-bottom: 12px; }
  .form-layout { display: flex; flex-direction: column; gap: 16px; }
  .form-section { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; }
  .form-section h2 { font-size: 13px; font-weight: 700; color: var(--text-primary); margin-bottom: 8px; text-transform: uppercase; letter-spacing: 0.03em; }
  .hint { font-size: 11px; color: var(--text-muted); margin-bottom: 8px; }
  .field { display: flex; flex-direction: column; gap: 4px; margin-bottom: 10px; }
  .field label { font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  input, textarea, select { padding: 8px 12px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-input); color: var(--text-primary); font-size: 13px; font-family: inherit; width: 100%; }
  input:focus, textarea:focus, select:focus { outline: none; border-color: var(--accent); }
  .checkbox-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 6px; }
  .checkbox-label { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--text-secondary); cursor: pointer; text-transform: capitalize; }
  .checkbox-label input[type="checkbox"] { width: auto; }
  .settings-row { display: flex; gap: 6px; margin-bottom: 6px; align-items: center; }
  .settings-row input, .settings-row select { flex: 1; }
  .btn-tiny { padding: 2px 6px; font-size: 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-tertiary); color: var(--text-muted); cursor: pointer; flex-shrink: 0; }
  .btn-sm { padding: 4px 12px; font-size: 11px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-tertiary); color: var(--text-secondary); font-family: inherit; }
  .code-editor { font-family: var(--font-mono); font-size: 12px; line-height: 1.5; resize: vertical; min-height: 200px; tab-size: 2; }
  .form-actions { display: flex; gap: 8px; justify-content: flex-end; }
  .btn { padding: 8px 20px; border-radius: var(--radius); font-size: 13px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); background: var(--bg-card); color: var(--text-secondary); font-family: inherit; }
  .btn-primary { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); }
  .btn-primary:hover { background: var(--accent-hover); }
  .btn:disabled { opacity: 0.5; cursor: default; }
</style>
