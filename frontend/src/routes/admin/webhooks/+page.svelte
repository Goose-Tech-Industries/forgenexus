<script lang="ts">
  import { api } from '$lib/api/client';
  import { channelStore } from '$lib/stores/channels.svelte';

  interface Webhook {
    id: string; name: string; avatar_url: string | null; token: string; channel_id: string;
    channel_name: string | null; is_active: boolean; url: string; inserted_at: string;
  }

  let webhooks = $state<Webhook[]>([]);
  let loading = $state(true);
  let showCreate = $state(false);
  let form = $state({ name: '', avatar_url: '', channel_id: '' });
  let saving = $state(false);

  $effect(() => { loadWebhooks(); channelStore.loadChannels(); });

  async function loadWebhooks() {
    loading = true;
    try {
      const data = await api.getWebhooks('');
      webhooks = data.webhooks || [];
    } catch { /* silent */ }
    loading = false;
  }

  async function handleCreate() {
    saving = true;
    try {
      await api.createWebhook(form);
      showCreate = false;
      form = { name: '', avatar_url: '', channel_id: '' };
      await loadWebhooks();
    } catch { /* silent */ }
    saving = false;
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this webhook?')) return;
    await api.deleteWebhook(id);
    await loadWebhooks();
  }

  async function handleRegenerate(id: string) {
    if (!confirm('Regenerate token? The old URL will stop working.')) return;
    await api.regenerateWebhookToken(id);
    await loadWebhooks();
  }

  let allChannels = $derived(channelStore.categories.flatMap(c => c.channels));
  let copied = $state<string | null>(null);

  function copyUrl(webhook: Webhook) {
    const url = `${window.location.origin}/api/webhooks/${webhook.token}`;
    navigator.clipboard.writeText(url);
    copied = webhook.id;
    setTimeout(() => { copied = null; }, 2000);
  }
</script>

<div class="admin-page">
  <div class="page-header">
    <h1>Webhooks</h1>
    <button class="btn-primary" onclick={() => { showCreate = true; }}>Create Webhook</button>
  </div>

  <p class="subtitle">External services can post messages to channels via webhook URLs. Send a POST with <code>{`{"content": "message"}`}</code>.</p>

  {#if showCreate}
    <div class="form-card">
      <h3>New Webhook</h3>
      <div class="form-grid">
        <label>Name <input type="text" bind:value={form.name} placeholder="GitHub Bot" /></label>
        <label>Avatar URL (optional) <input type="text" bind:value={form.avatar_url} placeholder="https://..." /></label>
        <label>Channel
          <select bind:value={form.channel_id}>
            <option value="">Select channel...</option>
            {#each allChannels as ch}
              <option value={ch.id}>{ch.name}</option>
            {/each}
          </select>
        </label>
      </div>
      <div class="form-actions">
        <button onclick={() => showCreate = false}>Cancel</button>
        <button class="btn-primary" onclick={handleCreate} disabled={saving || !form.name.trim() || !form.channel_id}>{saving ? 'Creating...' : 'Create'}</button>
      </div>
    </div>
  {/if}

  {#if loading}
    <p class="loading">Loading...</p>
  {:else if webhooks.length === 0}
    <p class="empty">No webhooks configured.</p>
  {:else}
    <div class="webhook-list">
      {#each webhooks as wh}
        <div class="webhook-card">
          <div class="wh-header">
            <div class="wh-name">{wh.name}</div>
            <span class="wh-channel">#{wh.channel_name || 'unknown'}</span>
          </div>
          <div class="wh-url">
            <code>{window.location.origin}/api/webhooks/{wh.token}</code>
            <button class="btn-sm" onclick={() => copyUrl(wh)}>{copied === wh.id ? 'Copied!' : 'Copy'}</button>
          </div>
          <div class="wh-actions">
            <button class="btn-sm" onclick={() => handleRegenerate(wh.id)}>Regenerate Token</button>
            <button class="btn-sm danger" onclick={() => handleDelete(wh.id)}>Delete</button>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .admin-page { max-width: 900px; }
  .page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
  .page-header h1 { font-size: 20px; font-weight: 800; }
  .subtitle { font-size: 12px; color: var(--text-muted); margin-bottom: 20px; }
  .subtitle code { background: var(--bg-primary); padding: 2px 6px; border-radius: 3px; font-size: 11px; }
  .btn-primary { background: var(--accent); color: var(--bg-primary); border: none; padding: 8px 16px; border-radius: var(--radius); font-weight: 600; cursor: pointer; font-family: inherit; font-size: 13px; }
  .form-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 20px; margin-bottom: 20px; }
  .form-card h3 { font-size: 15px; font-weight: 700; margin-bottom: 12px; }
  .form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 16px; }
  .form-grid label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  .form-grid input, .form-grid select { padding: 8px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: inherit; font-size: 13px; }
  .form-actions { display: flex; gap: 8px; justify-content: flex-end; }
  .form-actions button { padding: 8px 16px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; font-size: 13px; }
  .webhook-list { display: flex; flex-direction: column; gap: 12px; }
  .webhook-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; }
  .wh-header { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; }
  .wh-name { font-weight: 700; font-size: 14px; }
  .wh-channel { font-size: 11px; color: var(--accent); background: rgba(0,212,170,0.08); padding: 2px 8px; border-radius: 10px; }
  .wh-url { display: flex; align-items: center; gap: 8px; margin-bottom: 10px; padding: 8px; background: var(--bg-primary); border-radius: var(--radius); overflow: hidden; }
  .wh-url code { font-size: 11px; color: var(--text-muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; flex: 1; }
  .wh-actions { display: flex; gap: 8px; }
  .btn-sm { padding: 4px 10px; font-size: 11px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; }
  .btn-sm.danger { color: #f87171; border-color: rgba(248,113,113,0.3); }
  .loading, .empty { text-align: center; color: var(--text-muted); padding: 40px; }
</style>
