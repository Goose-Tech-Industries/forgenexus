<script lang="ts">
  import { goto } from '$app/navigation';
  import { plugins } from '$lib/stores/plugins.svelte';

  const triggerTypes = [
    { value: 'manual', label: 'Manual', description: 'Run this flow manually from the admin panel' },
    { value: 'on_post_created', label: 'Post Created', description: 'Triggers when a new post is made' },
    { value: 'on_thread_created', label: 'Thread Created', description: 'Triggers when a new thread is created' },
    { value: 'on_user_joined', label: 'User Joined', description: 'Triggers when a new user registers' },
    { value: 'on_user_left', label: 'User Left', description: 'Triggers when a user leaves' },
    { value: 'on_reaction_added', label: 'Reaction Added', description: 'Triggers when someone reacts to a post' },
    { value: 'on_chat_message', label: 'Chat Message', description: 'Triggers when a chat message is sent' },
    { value: 'on_custom_event', label: 'Custom Event', description: 'Triggers when another flow emits a named event' },
    { value: 'on_slash_command', label: 'Slash Command', description: 'Triggers when a user types a slash command' },
    { value: 'scheduled', label: 'Scheduled', description: 'Runs on a recurring schedule' },
    { value: 'webhook_received', label: 'Webhook Received', description: 'Triggers when an external webhook is received' },
  ];

  // Presets for the scheduled trigger cron builder
  const cronPresets = [
    { label: 'Every hour', value: '0 * * * *' },
    { label: 'Every day at midnight', value: '0 0 * * *' },
    { label: 'Every day at 9 AM', value: '0 9 * * *' },
    { label: 'Every Monday', value: '0 0 * * 1' },
    { label: 'Every 15 minutes', value: '*/15 * * * *' },
    { label: 'Every 5 minutes', value: '*/5 * * * *' },
    { label: 'Custom', value: '' },
  ];

  let name = $state('');
  let description = $state('');
  let triggerType = $state('manual');
  let submitting = $state(false);
  let error = $state('');

  // Trigger-specific fields
  let cronPreset = $state('0 * * * *');
  let cronCustom = $state('');
  let eventName = $state('');
  let commandName = $state('');
  let commandDescription = $state('');
  let webhookPath = $state('');
  let showAdvanced = $state(false);
  let advancedJson = $state('{}');

  function buildTriggerConfig(): Record<string, any> {
    if (showAdvanced) {
      try { return JSON.parse(advancedJson); }
      catch { error = 'Invalid JSON in advanced config'; return {}; }
    }

    switch (triggerType) {
      case 'scheduled':
        return { cron_expression: cronPreset === '' ? cronCustom : cronPreset };
      case 'on_custom_event':
        return { event_name: eventName };
      case 'on_slash_command':
        return { command_name: commandName, description: commandDescription };
      case 'webhook_received':
        return { path: webhookPath };
      default:
        return {};
    }
  }

  function describeCron(expr: string): string {
    if (!expr) return '';
    const preset = cronPresets.find(p => p.value === expr);
    if (preset && preset.label !== 'Custom') return preset.label;
    return `Custom: ${expr}`;
  }

  const needsConfig = $derived(
    ['scheduled', 'on_custom_event', 'on_slash_command', 'webhook_received'].includes(triggerType)
  );

  async function handleCreate() {
    if (!name.trim()) { error = 'Name is required'; return; }
    if (triggerType === 'scheduled') {
      const cron = cronPreset === '' ? cronCustom : cronPreset;
      if (!cron.trim()) { error = 'Cron expression is required for scheduled flows'; return; }
    }
    if (triggerType === 'on_custom_event' && !eventName.trim()) { error = 'Event name is required'; return; }
    if (triggerType === 'on_slash_command' && !commandName.trim()) { error = 'Command name is required'; return; }

    submitting = true; error = '';
    try {
      const config = buildTriggerConfig();
      if (error) { submitting = false; return; }
      const slug = name.toLowerCase().replace(/[^\w\s-]/g, '').replace(/[\s_]+/g, '-').replace(/-+/g, '-').trim();
      const flow = await plugins.createFlow({ name, description, slug, trigger_type: triggerType, trigger_config: config });
      goto(`/admin/plugins/flows/${flow.id}`);
    } catch (e: any) { error = e.error || 'Failed to create flow'; }
    finally { submitting = false; }
  }
</script>

<div class="new-flow">
  <h1>Create Flow</h1>

  {#if error}<div class="alert-error">{error}</div>{/if}

  <div class="form-card">
    <div class="form-group">
      <label>Name</label>
      <input type="text" bind:value={name} placeholder="My Awesome Flow" />
    </div>
    <div class="form-group">
      <label>Description</label>
      <textarea bind:value={description} rows="2" placeholder="What does this flow do?"></textarea>
    </div>
    <div class="form-group">
      <label>Trigger Type</label>
      <select bind:value={triggerType}>
        {#each triggerTypes as t}
          <option value={t.value}>{t.label}</option>
        {/each}
      </select>
      <span class="hint">{triggerTypes.find(t => t.value === triggerType)?.description}</span>
    </div>

    <!-- Trigger-specific configuration -->
    {#if triggerType === 'scheduled'}
      <div class="form-group">
        <label>Schedule</label>
        <select bind:value={cronPreset}>
          {#each cronPresets as p}
            <option value={p.value}>{p.label}</option>
          {/each}
        </select>
      </div>
      {#if cronPreset === ''}
        <div class="form-group">
          <label>Cron Expression</label>
          <input type="text" bind:value={cronCustom} placeholder="0 * * * *" />
          <span class="hint">Format: minute hour day-of-month month day-of-week</span>
        </div>
      {:else}
        <span class="hint schedule-preview">Runs: {describeCron(cronPreset)}</span>
      {/if}

    {:else if triggerType === 'on_custom_event'}
      <div class="form-group">
        <label>Event Name</label>
        <input type="text" bind:value={eventName} placeholder="my_custom_event" />
        <span class="hint">Used when another flow emits this event via the "Emit Custom Event" node</span>
      </div>

    {:else if triggerType === 'on_slash_command'}
      <div class="form-group">
        <label>Command Name</label>
        <div class="input-prefix">
          <span class="prefix">/</span>
          <input type="text" bind:value={commandName} placeholder="daily" />
        </div>
        <span class="hint">Users will type /{commandName || '...'} to trigger this flow</span>
      </div>
      <div class="form-group">
        <label>Command Description</label>
        <input type="text" bind:value={commandDescription} placeholder="Claim your daily reward" />
      </div>

    {:else if triggerType === 'webhook_received'}
      <div class="form-group">
        <label>Webhook Path</label>
        <div class="input-prefix">
          <span class="prefix">/webhooks/</span>
          <input type="text" bind:value={webhookPath} placeholder="my-hook" />
        </div>
        <span class="hint">External services will POST to this URL to trigger the flow</span>
      </div>
    {/if}

    <!-- Advanced JSON toggle -->
    {#if needsConfig}
      <button class="btn-link" onclick={() => showAdvanced = !showAdvanced}>
        {showAdvanced ? 'Hide' : 'Show'} advanced config (JSON)
      </button>
      {#if showAdvanced}
        <div class="form-group">
          <label>Raw Trigger Config JSON</label>
          <textarea bind:value={advancedJson} rows="3" placeholder={'{}'}></textarea>
          <span class="hint">Overrides the fields above when enabled</span>
        </div>
      {/if}
    {/if}

    <button class="btn btn-primary" onclick={handleCreate} disabled={submitting}>
      {submitting ? 'Creating...' : 'Create Flow'}
    </button>
  </div>
</div>

<style>
  .new-flow h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); margin-bottom: 16px; }
  .form-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 20px; max-width: 600px; }
  .form-group { margin-bottom: 12px; }
  .form-group label { display: block; font-size: 12px; font-weight: 600; color: var(--text-secondary); margin-bottom: 4px; }
  .form-group input, .form-group select, .form-group textarea { width: 100%; padding: 8px 12px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-primary); color: var(--text-primary); font-size: 13px; font-family: inherit; }
  .btn { padding: 8px 18px; border-radius: var(--radius); font-size: 13px; font-weight: 600; cursor: pointer; border: none; margin-top: 8px; }
  .btn:disabled { opacity: 0.5; }
  .btn-primary { background: var(--accent); color: #fff; }
  .btn-link { background: none; border: none; color: var(--accent); font-size: 12px; cursor: pointer; padding: 4px 0; margin-bottom: 8px; }
  .btn-link:hover { text-decoration: underline; }
  .hint { display: block; font-size: 11px; color: var(--text-muted); margin-top: 4px; }
  .schedule-preview { margin-bottom: 12px; }
  .alert-error { padding: 10px 14px; border-radius: var(--radius); font-size: 13px; margin-bottom: 12px; background: #dc262620; color: #f87171; border: 1px solid #dc262640; }
  .input-prefix { display: flex; align-items: center; gap: 0; }
  .input-prefix .prefix { padding: 8px 8px 8px 12px; background: var(--bg-secondary); border: 1px solid var(--border-color); border-right: none; border-radius: var(--radius) 0 0 var(--radius); font-size: 13px; color: var(--text-muted); white-space: nowrap; }
  .input-prefix input { border-radius: 0 var(--radius) var(--radius) 0; }
</style>
