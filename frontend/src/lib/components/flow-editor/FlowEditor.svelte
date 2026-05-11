<script lang="ts">
  import { plugins } from '$lib/stores/plugins.svelte';
  import { canvasState } from './canvas-state.svelte';
  import Canvas from './Canvas.svelte';
  import NodePalette from './NodePalette.svelte';
  import NodeConfigPanel from './NodeConfigPanel.svelte';
  import Minimap from './Minimap.svelte';

  let {
    flowId,
    onClose,
  }: {
    flowId: string;
    onClose: () => void;
  } = $props();

  let loading = $state(true);
  let saveStatus = $state<'saved' | 'unsaved' | 'saving' | 'error'>('saved');
  let saveTimer: ReturnType<typeof setTimeout> | null = null;

  $effect(() => {
    loadEditor();
  });

  async function loadEditor() {
    loading = true;
    try {
      const [flow, types] = await Promise.all([
        plugins.loadFlow(flowId),
        plugins.loadNodeTypes(),
      ]);
      canvasState.init(flow, types);
    } finally {
      loading = false;
    }
  }

  // Auto-save on dirty
  $effect(() => {
    if (canvasState.dirty) {
      saveStatus = 'unsaved';
      if (saveTimer) clearTimeout(saveTimer);
      saveTimer = setTimeout(save, 2000);
    }
  });

  async function save() {
    if (!canvasState.dirty) return;
    saveStatus = 'saving';
    try {
      const payload = canvasState.toSavePayload();
      const saved = await plugins.updateFlow(flowId, payload);
      canvasState.remapIds(saved);
      saveStatus = 'saved';
    } catch {
      saveStatus = 'error';
    }
  }

  async function handleSaveNow() {
    if (saveTimer) clearTimeout(saveTimer);
    await save();
  }

  async function handleActivate() {
    await handleSaveNow();
    await plugins.activateFlow(flowId);
    canvasState.init(await plugins.loadFlow(flowId), canvasState.nodeTypes);
  }

  async function handleDeactivate() {
    await plugins.deactivateFlow(flowId);
    canvasState.init(await plugins.loadFlow(flowId), canvasState.nodeTypes);
  }

  async function handleExecute() {
    await handleSaveNow();
    try {
      await plugins.executeFlow(flowId);
    } catch { /* execution errors shown elsewhere */ }
  }

  function handleClose() {
    if (canvasState.dirty) {
      handleSaveNow().then(onClose);
    } else {
      onClose();
    }
  }

  // Save before unload
  function handleBeforeUnload(e: BeforeUnloadEvent) {
    if (canvasState.dirty) {
      e.preventDefault();
    }
  }
</script>

<svelte:window onbeforeunload={handleBeforeUnload} />

{#if loading}
  <div class="editor-loading">
    <span>Loading editor...</span>
  </div>
{:else}
  <div class="flow-editor">
    <!-- Toolbar -->
    <div class="toolbar">
      <button class="toolbar-btn back-btn" onclick={handleClose}>
        <span class="back-arrow">&larr;</span> Back
      </button>

      <div class="toolbar-center">
        <span class="flow-name">{canvasState.flowName}</span>
        <span class="status-badge" class:active={canvasState.flowStatus === 'active'} class:draft={canvasState.flowStatus === 'draft'}>
          {canvasState.flowStatus}
        </span>
        <span class="save-indicator" class:saved={saveStatus === 'saved'} class:unsaved={saveStatus === 'unsaved'} class:saving={saveStatus === 'saving'} class:error={saveStatus === 'error'}>
          {#if saveStatus === 'saved'}Saved
          {:else if saveStatus === 'unsaved'}Unsaved changes
          {:else if saveStatus === 'saving'}Saving...
          {:else}Save error
          {/if}
        </span>
      </div>

      <div class="toolbar-actions">
        <button class="toolbar-btn" onclick={handleSaveNow} disabled={!canvasState.dirty}>Save</button>
        <button class="toolbar-btn" onclick={handleExecute}>Run</button>
        {#if canvasState.flowStatus !== 'active'}
          <button class="toolbar-btn primary" onclick={handleActivate}>Activate</button>
        {:else}
          <button class="toolbar-btn" onclick={handleDeactivate}>Deactivate</button>
        {/if}
      </div>
    </div>

    <!-- Main content -->
    <div class="editor-body">
      <NodePalette />

      <div class="canvas-area">
        <Canvas />
        <Minimap />
      </div>

      <NodeConfigPanel />
    </div>
  </div>
{/if}

<style>
  .editor-loading {
    position: fixed;
    inset: 0;
    z-index: 200;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--bg-primary);
    color: var(--text-muted);
    font-size: 14px;
  }

  .flow-editor {
    position: fixed;
    inset: 0;
    z-index: 200;
    display: flex;
    flex-direction: column;
    background: var(--bg-primary);
  }

  /* Toolbar */
  .toolbar {
    height: 44px;
    background: var(--bg-secondary);
    border-bottom: 1px solid var(--border-color);
    display: flex;
    align-items: center;
    padding: 0 12px;
    gap: 12px;
    flex-shrink: 0;
  }

  .toolbar-center {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 10px;
    justify-content: center;
  }

  .flow-name {
    font-size: 14px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .status-badge {
    font-size: 10px;
    font-weight: 600;
    padding: 2px 8px;
    border-radius: 10px;
    background: var(--bg-tertiary);
    color: var(--text-secondary);
    text-transform: capitalize;
  }

  .status-badge.active {
    background: #22c55e33;
    color: #4ade80;
  }

  .status-badge.draft {
    background: #eab30833;
    color: #fbbf24;
  }

  .save-indicator {
    font-size: 11px;
    font-weight: 500;
  }

  .save-indicator.saved { color: #4ade80; }
  .save-indicator.unsaved { color: #fbbf24; }
  .save-indicator.saving { color: var(--text-muted); }
  .save-indicator.error { color: #f87171; }

  .toolbar-actions {
    display: flex;
    gap: 6px;
  }

  .toolbar-btn {
    padding: 5px 12px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-tertiary);
    color: var(--text-secondary);
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    font-family: inherit;
    transition: all 0.15s;
  }

  .toolbar-btn:hover {
    background: var(--bg-hover);
    border-color: var(--border-accent);
    color: var(--text-primary);
  }

  .toolbar-btn:disabled {
    opacity: 0.4;
    cursor: default;
  }

  .toolbar-btn.primary {
    background: var(--accent);
    color: var(--bg-primary);
    border-color: var(--accent);
  }

  .toolbar-btn.primary:hover {
    background: var(--accent-hover);
  }

  .back-btn {
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .back-arrow {
    font-size: 16px;
  }

  /* Body */
  .editor-body {
    flex: 1;
    display: flex;
    overflow: hidden;
  }

  .canvas-area {
    flex: 1;
    position: relative;
    overflow: hidden;
  }
</style>
