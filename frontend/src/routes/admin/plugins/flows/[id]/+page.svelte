<script lang="ts">
  import { page } from '$app/stores';
  import { plugins, type Flow, type FlowNode, type FlowEdge } from '$lib/stores/plugins.svelte';
  import { api } from '$lib/api/client';
  import FlowEditor from '$lib/components/flow-editor/FlowEditor.svelte';

  let flowId = $derived(($page.params as Record<string, string>).id);
  let flow = $state<Flow | null>(null);
  let loading = $state(true);
  let tab = $state('overview');
  let editorOpen = $state(false);

  // Node form
  let showNodeForm = $state(false);
  let nodeType = $state('action/create_post');
  let nodeLabel = $state('');
  let nodeConfig = $state('{}');

  // Executions
  let executions = $state<any[]>([]);

  $effect(() => { loadFlow(); });

  async function loadFlow() {
    loading = true;
    try {
      flow = await plugins.loadFlow(flowId);
      const exData = await api.getExecutions({ flow_id: flowId, limit: '10' });
      executions = exData.executions;
    } finally { loading = false; }
  }

  async function addNode() {
    let config = {};
    try { config = JSON.parse(nodeConfig); } catch { alert('Invalid JSON'); return; }
    const category = nodeType.split('/')[0];
    await api.updateFlow(flowId, {
      nodes: [...(flow?.nodes || []).map(n => ({ id: n.id, type: n.type, category: n.category, label: n.label, config: n.config })), { type: nodeType, category, label: nodeLabel || nodeType, config }]
    }).catch(() => {});
    showNodeForm = false;
    nodeLabel = '';
    nodeConfig = '{}';
    await loadFlow();
  }

  async function deleteNode(nodeId: string) {
    if (!flow) return;
    const nodes = flow.nodes?.filter(n => n.id !== nodeId) || [];
    const edges = flow.edges?.filter(e => e.source_node_id !== nodeId && e.target_node_id !== nodeId) || [];
    await api.updateFlow(flowId, { nodes: nodes.map(n => ({ type: n.type, category: n.category, label: n.label, config: n.config })), edges: edges.map(e => ({ source_node_id: e.source_node_id, target_node_id: e.target_node_id, source_port: e.source_port, target_port: e.target_port })) });
    await loadFlow();
  }

  async function handleActivate() { await plugins.activateFlow(flowId); await loadFlow(); }
  async function handleDeactivate() { await plugins.deactivateFlow(flowId); await loadFlow(); }
  async function handleExecute() {
    try { await plugins.executeFlow(flowId); alert('Flow executed!'); await loadFlow(); }
    catch (e: any) { alert(e.error || 'Execution failed'); }
  }

  function categoryColor(cat: string) {
    const colors: Record<string, string> = { trigger: '#f97316', logic: '#3b82f6', math: '#a855f7', data: '#22c55e', action: '#ef4444', text: '#06b6d4', ui: '#ec4899' };
    return colors[cat] || '#6b7280';
  }

  function handleEditorClose() {
    editorOpen = false;
    loadFlow(); // Refresh data after editor closes
  }
</script>

<!-- Visual Editor Overlay -->
{#if editorOpen}
  <FlowEditor {flowId} onClose={handleEditorClose} />
{/if}

{#if loading}
  <p class="loading">Loading flow...</p>
{:else if flow}
  <div class="flow-detail">
    <div class="flow-header">
      <div>
        <h1>{flow.name}</h1>
        <p class="flow-desc">{flow.description || 'No description'}</p>
      </div>
      <div class="flow-header-right">
        <button class="btn btn-editor" onclick={() => { editorOpen = true; }}>
          <span class="editor-icon">&#9998;</span> Open Visual Editor
        </button>
        <div class="flow-badges">
          <span class="badge badge-{flow.status}">{flow.status}</span>
          <span class="badge">{flow.trigger_type.replace(/_/g, ' ')}</span>
        </div>
      </div>
    </div>

    <div class="tabs">
      {#each ['overview', 'nodes', 'edges', 'executions'] as t}
        <button class="tab" class:active={tab === t} onclick={() => { tab = t; }}>{t}</button>
      {/each}
    </div>

    {#if tab === 'overview'}
      <div class="section">
        <div class="meta-grid">
          <div><span class="label">Status</span><span class="value">{flow.status}</span></div>
          <div><span class="label">Executions</span><span class="value">{flow.execution_count}</span></div>
          <div><span class="label">Nodes</span><span class="value">{flow.nodes?.length ?? 0}</span></div>
          <div><span class="label">Edges</span><span class="value">{flow.edges?.length ?? 0}</span></div>
          <div><span class="label">Last Run</span><span class="value">{flow.last_executed_at ? new Date(flow.last_executed_at).toLocaleString() : 'Never'}</span></div>
        </div>
        {#if flow.error_message}<div class="error-box">{flow.error_message}</div>{/if}
        <div class="action-bar">
          {#if flow.status !== 'active'}<button class="btn btn-primary" onclick={handleActivate}>Activate</button>{/if}
          {#if flow.status === 'active'}<button class="btn" onclick={handleDeactivate}>Deactivate</button>{/if}
          <button class="btn" onclick={handleExecute}>Execute Now</button>
        </div>
      </div>

    {:else if tab === 'nodes'}
      <div class="section">
        <div class="section-header">
          <h2>Nodes ({flow.nodes?.length ?? 0})</h2>
          <button class="btn-sm" onclick={() => { showNodeForm = !showNodeForm; }}>Add Node</button>
        </div>

        {#if showNodeForm}
          <div class="inline-form">
            <div class="form-row">
              <input type="text" bind:value={nodeLabel} placeholder="Label" />
              <input type="text" bind:value={nodeType} placeholder="e.g. action/create_post" />
            </div>
            <textarea bind:value={nodeConfig} rows="3" placeholder={'{"key": "value"}'}></textarea>
            <button class="btn btn-primary" onclick={addNode}>Add</button>
          </div>
        {/if}

        {#each flow.nodes ?? [] as node (node.id)}
          <div class="node-card">
            <span class="cat-dot" style="background: {categoryColor(node.category)}"></span>
            <span class="node-type">{node.type}</span>
            <span class="node-label">{node.label || ''}</span>
            <code class="node-config">{JSON.stringify(node.config).slice(0, 80)}</code>
            <button class="btn-tiny" onclick={() => deleteNode(node.id)}>x</button>
          </div>
        {/each}
      </div>

    {:else if tab === 'edges'}
      <div class="section">
        <h2>Edges ({flow.edges?.length ?? 0})</h2>
        {#each flow.edges ?? [] as edge (edge.id)}
          {@const src = flow.nodes?.find(n => n.id === edge.source_node_id)}
          {@const tgt = flow.nodes?.find(n => n.id === edge.target_node_id)}
          <div class="edge-row">
            <span>{src?.label || src?.type || '?'}</span>
            <span class="port">[{edge.source_port}]</span>
            <span class="arrow">&rarr;</span>
            <span>{tgt?.label || tgt?.type || '?'}</span>
            <span class="port">[{edge.target_port}]</span>
          </div>
        {/each}
      </div>

    {:else if tab === 'executions'}
      <div class="section">
        <h2>Recent Executions</h2>
        {#each executions as exec}
          <div class="exec-row">
            <span class="badge badge-{exec.status}">{exec.status}</span>
            <span>{exec.nodes_executed} nodes</span>
            <span>{exec.duration_ms ?? '?'}ms</span>
            <span class="meta">{new Date(exec.started_at).toLocaleString()}</span>
          </div>
        {/each}
        {#if executions.length === 0}<p class="empty">No executions yet</p>{/if}
      </div>
    {/if}
  </div>
{/if}

<style>
  .flow-detail h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); }
  .flow-desc { font-size: 13px; color: var(--text-muted); margin-top: 2px; }
  .flow-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 16px; }
  .flow-header-right { display: flex; flex-direction: column; align-items: flex-end; gap: 8px; }
  .flow-badges { display: flex; gap: 6px; }

  .btn-editor {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 8px 16px;
    border: 1px solid var(--accent);
    border-radius: var(--radius);
    background: var(--accent);
    color: var(--bg-primary);
    font-size: 13px;
    font-weight: 700;
    cursor: pointer;
    font-family: inherit;
    transition: all 0.15s;
  }
  .btn-editor:hover {
    background: var(--accent-hover);
    box-shadow: 0 0 16px var(--accent-glow);
  }
  .editor-icon { font-size: 15px; }

  .badge { padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; background: var(--bg-tertiary); color: var(--text-secondary); }
  .badge-active { background: #22c55e33; color: #4ade80; }
  .badge-draft { background: #eab30833; color: #fbbf24; }
  .badge-error { background: #dc262633; color: #f87171; }
  .badge-completed { background: #22c55e33; color: #4ade80; }
  .badge-failed { background: #dc262633; color: #f87171; }
  .tabs { display: flex; gap: 4px; margin-bottom: 16px; }
  .tab { padding: 6px 14px; border-radius: 16px; border: 1px solid var(--border-color); background: var(--bg-card); color: var(--text-secondary); font-size: 12px; font-weight: 600; cursor: pointer; text-transform: capitalize; }
  .tab.active { background: var(--accent); color: #fff; border-color: var(--accent); }
  .section { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; }
  .section h2 { font-size: 14px; font-weight: 700; color: var(--text-primary); margin-bottom: 12px; }
  .section-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }
  .meta-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-bottom: 16px; }
  .meta-grid div { display: flex; flex-direction: column; gap: 2px; }
  .meta-grid .label { font-size: 11px; color: var(--text-muted); text-transform: uppercase; }
  .meta-grid .value { font-size: 14px; font-weight: 600; color: var(--text-primary); }
  .error-box { padding: 10px; background: #dc262620; border: 1px solid #dc262640; border-radius: var(--radius); color: #f87171; font-size: 13px; margin-bottom: 12px; }
  .action-bar { display: flex; gap: 8px; }
  .btn { padding: 6px 16px; border-radius: var(--radius); font-size: 12px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); background: var(--bg-card); color: var(--text-secondary); }
  .btn-primary { background: var(--accent); color: #fff; border-color: var(--accent); }
  .btn-sm { padding: 4px 12px; font-size: 11px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-card); color: var(--text-secondary); }
  .inline-form { background: var(--bg-tertiary); padding: 12px; border-radius: var(--radius); margin-bottom: 12px; display: flex; flex-direction: column; gap: 8px; }
  .form-row { display: flex; gap: 8px; }
  input, textarea { padding: 8px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-primary); color: var(--text-primary); font-size: 13px; font-family: inherit; flex: 1; }
  .node-card { display: flex; align-items: center; gap: 8px; padding: 8px 0; border-bottom: 1px solid var(--border-color); font-size: 13px; }
  .node-card:last-child { border-bottom: none; }
  .cat-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
  .node-type { font-weight: 600; color: var(--text-primary); }
  .node-label { color: var(--text-secondary); }
  .node-config { font-size: 11px; color: var(--text-muted); margin-left: auto; max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .btn-tiny { padding: 2px 6px; font-size: 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-tertiary); color: var(--text-muted); cursor: pointer; }
  .edge-row { display: flex; align-items: center; gap: 6px; padding: 6px 0; font-size: 13px; border-bottom: 1px solid var(--border-color); }
  .edge-row:last-child { border-bottom: none; }
  .port { font-size: 11px; color: var(--text-muted); }
  .arrow { color: var(--accent); }
  .exec-row { display: flex; align-items: center; gap: 8px; padding: 6px 0; font-size: 13px; border-bottom: 1px solid var(--border-color); }
  .exec-row:last-child { border-bottom: none; }
  .meta { color: var(--text-muted); font-size: 12px; margin-left: auto; }
  .loading, .empty { color: var(--text-muted); font-size: 13px; text-align: center; padding: 24px 0; }
</style>
