<script lang="ts">
  import { api } from '$lib/api/client';

  interface ForumWebhook {
    id: string;
    name: string;
    url: string;
    secret: string;
    events: string[];
    is_active: boolean;
    last_triggered_at: string | null;
    failure_count: number;
    inserted_at: string;
  }

  interface Delivery {
    id: string;
    event_type: string;
    response_status: number | null;
    latency_ms: number | null;
    attempt: number;
    error: string | null;
    delivered_at: string;
    ok: boolean;
    payload: Record<string, any>;
    response_body_preview: string | null;
  }

  let webhooks = $state<ForumWebhook[]>([]);
  let eventTypes = $state<string[]>([]);
  let loading = $state(true);
  let error = $state('');

  let showForm = $state(false);
  let editing = $state<ForumWebhook | null>(null);
  let form = $state({ name: '', url: '', secret: '', events: [] as string[], is_active: true });
  let saving = $state(false);
  let formError = $state('');

  let viewingDeliveries = $state<ForumWebhook | null>(null);
  let deliveries = $state<Delivery[]>([]);
  let deliveriesLoading = $state(false);
  let expandedDelivery = $state<string | null>(null);
  let testMessage = $state('');

  $effect(() => { load(); });

  async function load() {
    loading = true;
    error = '';
    try {
      const [whs, events] = await Promise.all([
        api.getForumWebhooks(),
        api.getForumWebhookEventTypes()
      ]);
      webhooks = whs.webhooks || [];
      eventTypes = events.events || [];
    } catch (err: any) {
      error = err?.error || 'Failed to load forum webhooks.';
    }
    loading = false;
  }

  function openCreate() {
    editing = null;
    form = { name: '', url: '', secret: generateSecret(), events: [], is_active: true };
    formError = '';
    showForm = true;
  }

  function openEdit(wh: ForumWebhook) {
    editing = wh;
    form = { name: wh.name, url: wh.url, secret: wh.secret, events: [...(wh.events || [])], is_active: wh.is_active };
    formError = '';
    showForm = true;
  }

  function generateSecret(): string {
    const bytes = new Uint8Array(32);
    if (typeof crypto !== 'undefined') crypto.getRandomValues(bytes);
    return Array.from(bytes).map((b) => b.toString(16).padStart(2, '0')).join('');
  }

  function toggleEvent(evt: string) {
    if (form.events.includes(evt)) {
      form.events = form.events.filter((e) => e !== evt);
    } else {
      form.events = [...form.events, evt];
    }
  }

  async function handleSave() {
    formError = '';
    if (!form.name.trim()) { formError = 'Name is required.'; return; }
    if (!form.url.trim()) { formError = 'URL is required.'; return; }
    try { new URL(form.url); } catch { formError = 'URL must be a valid absolute URL.'; return; }
    saving = true;
    try {
      if (editing) {
        await api.updateForumWebhook(editing.id, form);
      } else {
        await api.createForumWebhook(form);
      }
      showForm = false;
      editing = null;
      await load();
    } catch (err: any) {
      formError = err?.error ? JSON.stringify(err.error) : 'Failed to save webhook.';
    }
    saving = false;
  }

  async function handleDelete(wh: ForumWebhook) {
    if (!confirm(`Delete webhook "${wh.name}"? Its delivery history will be deleted too.`)) return;
    try {
      await api.deleteForumWebhook(wh.id);
      await load();
    } catch (err: any) {
      alert('Failed to delete: ' + (err?.error || 'unknown error'));
    }
  }

  async function toggleActive(wh: ForumWebhook) {
    await api.updateForumWebhook(wh.id, { is_active: !wh.is_active });
    await load();
  }

  async function sendTest(wh: ForumWebhook) {
    testMessage = '';
    try {
      await api.testForumWebhook(wh.id);
      testMessage = `Test delivery enqueued for ${wh.name}.`;
      setTimeout(() => { if (viewingDeliveries?.id === wh.id) openDeliveries(wh); }, 1200);
    } catch (err: any) {
      testMessage = 'Failed to enqueue test: ' + (err?.error || 'unknown error');
    }
  }

  async function openDeliveries(wh: ForumWebhook) {
    viewingDeliveries = wh;
    deliveriesLoading = true;
    expandedDelivery = null;
    try {
      const data = await api.getForumWebhookDeliveries(wh.id, 50);
      deliveries = data.deliveries || [];
    } catch (err: any) {
      deliveries = [];
    }
    deliveriesLoading = false;
  }

  function closeDeliveries() {
    viewingDeliveries = null;
    deliveries = [];
    expandedDelivery = null;
  }

  function formatDate(d: string | null) {
    if (!d) return '—';
    return new Date(d).toLocaleString();
  }
</script>

<div class="admin-page">
  <div class="page-header">
    <div>
      <h1>Forum Event Webhooks</h1>
      <p class="page-sub">Outbound HTTP callbacks fired when forum events occur. HMAC-signed, auto-retried, auto-disabled after 10 consecutive failures.</p>
    </div>
    <button class="btn-primary" onclick={openCreate}>New Webhook</button>
  </div>

  {#if testMessage}<div class="toast">{testMessage}</div>{/if}

  {#if showForm}
    <div class="form-card">
      <h3>{editing ? `Edit: ${editing.name}` : 'New Forum Webhook'}</h3>
      <div class="form-grid">
        <label class="span-2">Name
          <input type="text" bind:value={form.name} placeholder="Discord notifier" />
        </label>
        <label class="span-2">URL
          <input type="text" bind:value={form.url} placeholder="https://example.com/hook" />
        </label>
        <label class="span-2">Secret (HMAC-SHA256 signing key)
          <input type="text" bind:value={form.secret} placeholder="auto-generated" />
        </label>
      </div>

      <div class="events-section">
        <h4>Events {form.events.length === 0 ? '(empty = all events)' : `(${form.events.length} selected)`}</h4>
        <div class="events-grid">
          {#each eventTypes as evt}
            <label class="event-chip" class:selected={form.events.includes(evt)}>
              <input type="checkbox" checked={form.events.includes(evt)} onchange={() => toggleEvent(evt)} />
              <span>{evt}</span>
            </label>
          {/each}
        </div>
      </div>

      <div class="toggles">
        <label class="checkbox"><input type="checkbox" bind:checked={form.is_active} /> Active</label>
      </div>

      {#if formError}<div class="form-error">{formError}</div>{/if}

      <div class="form-actions">
        <button onclick={() => { showForm = false; editing = null; }}>Cancel</button>
        <button class="btn-primary" onclick={handleSave} disabled={saving || !form.name.trim() || !form.url.trim()}>
          {saving ? 'Saving...' : editing ? 'Update' : 'Create'}
        </button>
      </div>
    </div>
  {/if}

  {#if viewingDeliveries}
    <div class="deliveries-card">
      <div class="deliveries-header">
        <h3>Delivery log: {viewingDeliveries.name}</h3>
        <button class="btn-sm" onclick={closeDeliveries}>Close</button>
      </div>
      {#if deliveriesLoading}
        <p class="loading">Loading deliveries...</p>
      {:else if deliveries.length === 0}
        <p class="empty">No deliveries yet. Click "Send test" to enqueue one.</p>
      {:else}
        <table class="deliveries-table">
          <thead>
            <tr>
              <th>When</th>
              <th>Event</th>
              <th>Status</th>
              <th>Latency</th>
              <th>Attempt</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {#each deliveries as d (d.id)}
              <tr class:ok={d.ok} class:fail={!d.ok}>
                <td>{formatDate(d.delivered_at)}</td>
                <td><code>{d.event_type}</code></td>
                <td>
                  {#if d.response_status}
                    <span class="status-code" class:ok={d.ok}>{d.response_status}</span>
                  {:else}
                    <span class="status-code fail">ERR</span>
                  {/if}
                </td>
                <td class="num">{d.latency_ms ?? '—'}{d.latency_ms ? 'ms' : ''}</td>
                <td class="num">{d.attempt}</td>
                <td><button class="btn-sm" onclick={() => (expandedDelivery = expandedDelivery === d.id ? null : d.id)}>
                  {expandedDelivery === d.id ? 'Hide' : 'Details'}
                </button></td>
              </tr>
              {#if expandedDelivery === d.id}
                <tr class="detail-row">
                  <td colspan="6">
                    {#if d.error}
                      <div class="detail-block">
                        <strong>Error:</strong>
                        <pre>{d.error}</pre>
                      </div>
                    {/if}
                    <div class="detail-block">
                      <strong>Payload:</strong>
                      <pre>{JSON.stringify(d.payload, null, 2)}</pre>
                    </div>
                    {#if d.response_body_preview}
                      <div class="detail-block">
                        <strong>Response:</strong>
                        <pre>{d.response_body_preview}</pre>
                      </div>
                    {/if}
                  </td>
                </tr>
              {/if}
            {/each}
          </tbody>
        </table>
      {/if}
    </div>
  {/if}

  {#if loading}
    <p class="loading">Loading webhooks...</p>
  {:else if error}
    <div class="error-banner">{error}</div>
  {:else if webhooks.length === 0}
    <p class="empty">No forum webhooks defined yet.</p>
  {:else}
    <div class="webhooks-list">
      {#each webhooks as wh (wh.id)}
        <div class="webhook-card" class:inactive={!wh.is_active}>
          <div class="webhook-head">
            <div>
              <strong>{wh.name}</strong>
              <span class="status" class:on={wh.is_active} class:off={!wh.is_active}>
                {wh.is_active ? 'Active' : 'Disabled'}
              </span>
              {#if wh.failure_count > 0}<span class="tag fail">{wh.failure_count} recent failures</span>{/if}
            </div>
            <div class="webhook-actions">
              <button class="btn-sm" onclick={() => sendTest(wh)}>Send test</button>
              <button class="btn-sm" onclick={() => openDeliveries(wh)}>Deliveries</button>
              <button class="btn-sm" onclick={() => toggleActive(wh)}>{wh.is_active ? 'Disable' : 'Enable'}</button>
              <button class="btn-sm" onclick={() => openEdit(wh)}>Edit</button>
              <button class="btn-sm danger" onclick={() => handleDelete(wh)}>Delete</button>
            </div>
          </div>
          <div class="webhook-url">{wh.url}</div>
          <div class="webhook-meta">
            <span>Events: {wh.events.length === 0 ? 'all' : wh.events.join(', ')}</span>
            <span>Last fired: {formatDate(wh.last_triggered_at)}</span>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .admin-page { max-width: 1100px; }
  .page-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 16px; gap: 16px; }
  .page-header h1 { font-size: 20px; font-weight: 800; }
  .page-sub { font-size: 12px; color: var(--text-muted); margin-top: 2px; max-width: 640px; }
  .btn-primary { background: var(--accent); color: var(--bg-primary); border: none; padding: 8px 16px; border-radius: var(--radius); font-weight: 600; cursor: pointer; font-family: inherit; font-size: 13px; }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
  .toast { padding: 10px 12px; background: rgba(52,211,153,0.15); border: 1px solid rgba(52,211,153,0.3); border-radius: var(--radius); color: #34d399; margin-bottom: 12px; font-size: 12px; }

  .form-card, .deliveries-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 20px; margin-bottom: 20px; }
  .form-card h3, .deliveries-card h3 { font-size: 15px; font-weight: 700; margin-bottom: 12px; }
  .form-card h4 { font-size: 12px; font-weight: 700; margin: 12px 0 8px; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.05em; }
  .form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  .form-grid .span-2 { grid-column: span 2; }
  .form-grid label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  .form-grid input { padding: 8px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: inherit; font-size: 13px; }
  .events-section { margin-top: 12px; }
  .events-grid { display: flex; flex-wrap: wrap; gap: 6px; }
  .event-chip { display: inline-flex; align-items: center; gap: 6px; padding: 4px 10px; font-size: 11px; border: 1px solid var(--border-color); border-radius: 14px; background: var(--bg-primary); color: var(--text-secondary); cursor: pointer; }
  .event-chip.selected { background: var(--accent-glow); border-color: var(--accent); color: var(--accent); }
  .event-chip input { margin: 0; }
  .toggles { display: flex; gap: 16px; margin-top: 12px; }
  .checkbox { display: flex; flex-direction: row; align-items: center; gap: 6px; font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  .form-error { margin-top: 12px; padding: 10px; background: rgba(248,113,113,0.1); border: 1px solid rgba(248,113,113,0.3); border-radius: var(--radius); color: #f87171; font-size: 12px; }
  .form-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: 12px; }
  .form-actions button { padding: 8px 16px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; font-size: 13px; }
  .form-actions button.btn-primary { border: none; color: var(--bg-primary); background: var(--accent); }

  .deliveries-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }
  .deliveries-table { width: 100%; border-collapse: collapse; font-size: 12px; }
  .deliveries-table th { text-align: left; padding: 8px; background: var(--bg-primary); color: var(--text-muted); font-size: 10px; text-transform: uppercase; letter-spacing: 0.05em; border-bottom: 1px solid var(--border-color); }
  .deliveries-table td { padding: 8px; border-bottom: 1px solid var(--border-color); }
  .deliveries-table tr.ok td { color: var(--text-secondary); }
  .deliveries-table tr.fail td { color: #f87171; }
  .deliveries-table .detail-row td { background: var(--bg-primary); padding: 12px; }
  .detail-block { margin-bottom: 8px; font-size: 11px; }
  .detail-block strong { display: block; color: var(--text-muted); margin-bottom: 4px; text-transform: uppercase; letter-spacing: 0.05em; font-size: 10px; }
  .detail-block pre { font-family: ui-monospace, monospace; font-size: 11px; padding: 8px; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius); overflow: auto; max-height: 240px; color: var(--text-secondary); }
  .status-code { display: inline-block; padding: 2px 8px; font-size: 10px; font-weight: 700; border-radius: 10px; background: rgba(156,163,175,0.15); color: #9ca3af; }
  .status-code.ok { background: rgba(52,211,153,0.15); color: #34d399; }
  .status-code.fail { background: rgba(248,113,113,0.15); color: #f87171; }
  .num { font-variant-numeric: tabular-nums; }

  .webhooks-list { display: flex; flex-direction: column; gap: 10px; }
  .webhook-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 14px; }
  .webhook-card.inactive { opacity: 0.55; }
  .webhook-head { display: flex; justify-content: space-between; align-items: center; gap: 12px; flex-wrap: wrap; }
  .webhook-head strong { font-weight: 700; margin-right: 8px; }
  .webhook-actions { display: flex; gap: 6px; flex-wrap: wrap; }
  .webhook-url { font-family: ui-monospace, monospace; font-size: 11px; color: var(--text-muted); margin-top: 6px; word-break: break-all; }
  .webhook-meta { display: flex; gap: 16px; margin-top: 6px; font-size: 11px; color: var(--text-muted); }
  .status { display: inline-block; padding: 2px 8px; font-size: 10px; font-weight: 700; border-radius: 10px; text-transform: uppercase; letter-spacing: 0.05em; }
  .status.on { background: rgba(52,211,153,0.15); color: #34d399; }
  .status.off { background: rgba(156,163,175,0.15); color: #9ca3af; }
  .tag { display: inline-block; margin-left: 4px; padding: 2px 8px; font-size: 10px; font-weight: 700; border-radius: 10px; text-transform: uppercase; letter-spacing: 0.05em; }
  .tag.fail { background: rgba(248,113,113,0.15); color: #f87171; }

  .btn-sm { padding: 4px 10px; font-size: 11px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; }
  .btn-sm:hover { background: var(--bg-hover); color: var(--text-primary); }
  .btn-sm.danger { color: #f87171; border-color: rgba(248,113,113,0.3); }

  .loading, .empty { text-align: center; color: var(--text-muted); padding: 30px; }
  .error-banner { padding: 12px; background: rgba(248,113,113,0.1); border: 1px solid rgba(248,113,113,0.3); border-radius: var(--radius); color: #f87171; }
</style>
