<script lang="ts">
  import { canvasState } from './canvas-state.svelte';
  import { categoryColor } from './category-colors';

  const node = $derived(canvasState.selectedNode);
  const schema = $derived(node ? canvasState.nodeTypeMap.get(node.type) ?? null : null);
  const color = $derived(node ? categoryColor(node.category) : '#6b7280');

  let editLabel = $state('');

  $effect(() => {
    if (node) editLabel = node.label ?? '';
  });

  function updateLabel() {
    if (node) canvasState.updateNodeLabel(node.id, editLabel);
  }

  function updateConfigField(fieldName: string, value: any) {
    if (!node) return;
    canvasState.updateNodeConfig(node.id, { ...node.config, [fieldName]: value });
  }

  function handleDelete() {
    if (node) canvasState.deleteNode(node.id);
  }
</script>

{#if node && schema}
  <div class="config-panel">
    <div class="panel-header" style="border-left: 3px solid {color};">
      <span class="panel-category" style="color: {color};">{node.category}</span>
      <span class="panel-type">{schema.label}</span>
    </div>

    <div class="panel-body">
      <!-- Label -->
      <div class="field">
        <label class="field-label">Label</label>
        <input
          type="text"
          bind:value={editLabel}
          onblur={updateLabel}
          onkeydown={(e: KeyboardEvent) => { if (e.key === 'Enter') updateLabel(); }}
        />
      </div>

      <!-- Description -->
      <p class="node-desc">{schema.description}</p>

      <!-- Ports info -->
      <div class="ports-info">
        {#if schema.inputs.length > 0}
          <div class="port-group">
            <span class="port-group-label">Inputs</span>
            {#each schema.inputs as input}
              <span class="port-tag">{input.name} <span class="port-type">({input.type})</span></span>
            {/each}
          </div>
        {/if}
        {#if schema.outputs.length > 0}
          <div class="port-group">
            <span class="port-group-label">Outputs</span>
            {#each schema.outputs as output}
              <span class="port-tag">{output.name} <span class="port-type">({output.type})</span></span>
            {/each}
          </div>
        {/if}
      </div>

      <!-- Config fields -->
      {#if schema.config_fields.length > 0}
        <div class="config-section">
          <span class="config-section-title">Configuration</span>
          {#each schema.config_fields as field (field.name)}
            <div class="field">
              <label class="field-label">
                {field.name.replace(/_/g, ' ')}
                {#if field.description}
                  <span class="field-hint">{field.description}</span>
                {/if}
              </label>

              {#if field.type === 'select' && field.options}
                <select
                  value={node.config[field.name] ?? field.default ?? ''}
                  onchange={(e: Event) => updateConfigField(field.name, (e.target as HTMLSelectElement).value)}
                >
                  {#each field.options as opt}
                    <option value={opt}>{opt}</option>
                  {/each}
                </select>

              {:else if field.type === 'number'}
                <input
                  type="number"
                  value={node.config[field.name] ?? field.default ?? 0}
                  onchange={(e: Event) => updateConfigField(field.name, Number((e.target as HTMLInputElement).value))}
                />

              {:else if field.type === 'boolean'}
                <label class="toggle-label">
                  <input
                    type="checkbox"
                    checked={node.config[field.name] ?? field.default ?? false}
                    onchange={(e: Event) => updateConfigField(field.name, (e.target as HTMLInputElement).checked)}
                  />
                  <span class="toggle-text">{node.config[field.name] ? 'Enabled' : 'Disabled'}</span>
                </label>

              {:else if field.type === 'text' || field.type === 'json'}
                <textarea
                  rows="3"
                  value={typeof node.config[field.name] === 'object' ? JSON.stringify(node.config[field.name], null, 2) : (node.config[field.name] ?? field.default ?? '')}
                  onblur={(e: FocusEvent) => {
                    const val = (e.target as HTMLTextAreaElement).value;
                    if (field.type === 'json') {
                      try { updateConfigField(field.name, JSON.parse(val)); } catch { /* ignore invalid json */ }
                    } else {
                      updateConfigField(field.name, val);
                    }
                  }}
                ></textarea>

              {:else}
                <input
                  type="text"
                  value={node.config[field.name] ?? field.default ?? ''}
                  onchange={(e: Event) => updateConfigField(field.name, (e.target as HTMLInputElement).value)}
                />
              {/if}
            </div>
          {/each}
        </div>
      {/if}

      <!-- Delete -->
      <button class="delete-btn" onclick={handleDelete}>Delete Node</button>
    </div>
  </div>
{/if}

<style>
  .config-panel {
    width: 280px;
    height: 100%;
    background: var(--bg-secondary);
    border-left: 1px solid var(--border-color);
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .panel-header {
    padding: 12px 14px;
    border-bottom: 1px solid var(--border-color);
    background: var(--bg-tertiary);
  }

  .panel-category {
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    display: block;
  }

  .panel-type {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
    display: block;
    margin-top: 2px;
  }

  .panel-body {
    flex: 1;
    overflow-y: auto;
    padding: 12px 14px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .node-desc {
    font-size: 11px;
    color: var(--text-muted);
    line-height: 1.4;
  }

  .field {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .field-label {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-secondary);
    text-transform: capitalize;
  }

  .field-hint {
    font-weight: 400;
    color: var(--text-muted);
    font-size: 10px;
    display: block;
    text-transform: none;
  }

  input, select, textarea {
    padding: 6px 10px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-input);
    color: var(--text-primary);
    font-size: 12px;
    font-family: inherit;
    width: 100%;
  }

  input:focus, select:focus, textarea:focus {
    outline: none;
    border-color: var(--accent);
  }

  textarea {
    font-family: var(--font-mono);
    font-size: 11px;
    resize: vertical;
  }

  .toggle-label {
    display: flex;
    align-items: center;
    gap: 8px;
    cursor: pointer;
    font-size: 12px;
  }

  .toggle-label input[type="checkbox"] {
    width: auto;
  }

  .toggle-text {
    font-size: 12px;
    color: var(--text-secondary);
  }

  .ports-info {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .port-group {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    align-items: center;
  }

  .port-group-label {
    font-size: 10px;
    font-weight: 700;
    color: var(--text-secondary);
    text-transform: uppercase;
    margin-right: 4px;
  }

  .port-tag {
    font-size: 10px;
    padding: 1px 6px;
    border-radius: 6px;
    background: var(--bg-tertiary);
    color: var(--text-primary);
  }

  .port-type {
    color: var(--text-muted);
  }

  .config-section {
    display: flex;
    flex-direction: column;
    gap: 10px;
    border-top: 1px solid var(--border-color);
    padding-top: 10px;
  }

  .config-section-title {
    font-size: 11px;
    font-weight: 700;
    color: var(--text-secondary);
    text-transform: uppercase;
    letter-spacing: 0.03em;
  }

  .delete-btn {
    padding: 6px 12px;
    border: 1px solid #dc2626;
    border-radius: var(--radius);
    background: #dc262620;
    color: #f87171;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    margin-top: auto;
    font-family: inherit;
  }

  .delete-btn:hover {
    background: #dc262640;
  }
</style>
