<script lang="ts">
  import { plugins } from '$lib/stores/plugins.svelte';
  import { api } from '$lib/api/client';
  import { goto } from '$app/navigation';

  let loaded = $state(false);

  $effect(() => { if (!loaded) { plugins.loadFlows(); loaded = true; } });

  async function toggleFlow(id: string, status: string) {
    if (status === 'active') await plugins.deactivateFlow(id);
    else await plugins.activateFlow(id);
    plugins.loadFlows();
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this flow?')) return;
    await plugins.deleteFlow(id);
  }

  // --- AI Flow Generator ---
  let showGenerator = $state(false);
  let description = $state('');
  let generating = $state(false);
  let genError = $state<string | null>(null);
  let genWarning = $state<string | null>(null);

  const examples = [
    'When a new user joins, wait 7 days, then send them a DM welcoming them to the community and add them to the Members group.',
    'Every Monday at 9am, post a weekly summary thread in the Announcements forum with the top 5 most-reacted posts from the past week.',
    "When someone posts in the #support channel, run sentiment analysis. If it's negative, alert the mod team and set the thread prefix to 'Needs Help'.",
    'When a user hits 100 posts, grant them the Veteran achievement and promote them from Member to Regular.',
    "When a post gets reported twice by different users, hide the post and DM the moderators with the post content and the reporters' usernames."
  ];

  async function generate() {
    if (!description.trim()) return;
    generating = true;
    genError = null;
    genWarning = null;
    try {
      const data = await api.generateFlowFromDescription(description.trim(), true);
      if (data.flow?.id) {
        showGenerator = false;
        description = '';
        await plugins.loadFlows();
        // Navigate to the new flow's editor
        goto(`/admin/plugins/flows/${data.flow.id}`);
      } else if (data.spec) {
        genWarning = 'Flow spec generated but not saved — see console for details.';
        console.log('Generated spec:', data.spec);
      }
    } catch (err: any) {
      genError = err?.error || err?.reason || 'Generation failed';
      if (err?.spec) console.log('Partial spec:', err.spec);
    }
    generating = false;
  }

  function useExample(ex: string) {
    description = ex;
  }
</script>

<div class="flows-page">
  <div class="page-header">
    <h1>Flows</h1>
    <a href="/admin/plugins/flows/new" class="btn btn-primary">New Flow</a>
  </div>

  {#if plugins.loading}
    <p class="empty">Loading...</p>
  {:else if plugins.flows.length === 0}
    <p class="empty">No flows created yet</p>
  {:else}
    <div class="flows-list">
      {#each plugins.flows as flow (flow.id)}
        <div class="flow-card">
          <div class="flow-header">
            <a href="/admin/plugins/flows/{flow.id}" class="flow-name">{flow.name}</a>
            <span class="badge badge-{flow.status}">{flow.status}</span>
            <span class="trigger-type">{flow.trigger_type}</span>
          </div>
          <div class="flow-meta">
            <span>{flow.execution_count} executions</span>
            {#if flow.last_executed_at}
              <span>Last: {new Date(flow.last_executed_at).toLocaleDateString()}</span>
            {/if}
            <span>{flow.node_count ?? 0} nodes</span>
          </div>
          <div class="flow-actions">
            <button class="btn-sm" onclick={() => toggleFlow(flow.id, flow.status)}>
              {flow.status === 'active' ? 'Deactivate' : 'Activate'}
            </button>
            <button class="btn-sm btn-danger" onclick={() => handleDelete(flow.id)}>Delete</button>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .flows-page h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); }
  .page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
  .btn { padding: 8px 18px; border-radius: var(--radius); font-size: 13px; font-weight: 600; cursor: pointer; border: none; text-decoration: none; }
  .btn-primary { background: var(--accent); color: #fff; }
  .flows-list { display: flex; flex-direction: column; gap: 10px; }
  .flow-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 14px 16px; }
  .flow-header { display: flex; align-items: center; gap: 8px; margin-bottom: 6px; }
  .flow-name { font-size: 14px; font-weight: 700; color: var(--accent); text-decoration: none; }
  .badge { padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; background: var(--bg-tertiary); color: var(--text-secondary); }
  .badge-active { background: #22c55e33; color: #4ade80; }
  .badge-draft { background: #eab30833; color: #fbbf24; }
  .badge-disabled { background: var(--bg-tertiary); color: var(--text-muted); }
  .badge-error { background: #dc262633; color: #f87171; }
  .trigger-type { font-size: 11px; color: var(--text-muted); margin-left: auto; }
  .flow-meta { display: flex; gap: 16px; font-size: 12px; color: var(--text-muted); margin-bottom: 8px; }
  .flow-actions { display: flex; gap: 6px; }
  .btn-sm { padding: 4px 12px; border-radius: var(--radius); font-size: 11px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); background: var(--bg-card); color: var(--text-secondary); }
  .btn-sm:hover { background: var(--bg-hover); }
  .btn-danger { color: #f87171; border-color: #dc262640; }
  .empty { color: var(--text-muted); font-size: 13px; text-align: center; padding: 24px 0; }
</style>
