<script lang="ts">
  let {
    items,
    onReorder,
  }: {
    items: { id: string; label: string; sublabel?: string }[];
    onReorder: (orderedIds: string[]) => void;
  } = $props();

  let dragIdx = $state<number | null>(null);
  let overIdx = $state<number | null>(null);

  function handleDragStart(e: DragEvent, idx: number) {
    dragIdx = idx;
    if (e.dataTransfer) {
      e.dataTransfer.effectAllowed = 'move';
      e.dataTransfer.setData('text/plain', String(idx));
    }
  }

  function handleDragOver(e: DragEvent, idx: number) {
    e.preventDefault();
    if (e.dataTransfer) e.dataTransfer.dropEffect = 'move';
    overIdx = idx;
  }

  function handleDrop(e: DragEvent, idx: number) {
    e.preventDefault();
    if (dragIdx === null || dragIdx === idx) return;
    const newItems = [...items];
    const [moved] = newItems.splice(dragIdx, 1);
    newItems.splice(idx, 0, moved);
    onReorder(newItems.map(i => i.id));
    dragIdx = null;
    overIdx = null;
  }

  function handleDragEnd() {
    dragIdx = null;
    overIdx = null;
  }
</script>

<div class="drag-list">
  {#each items as item, i (item.id)}
    <div
      class="drag-item"
      class:dragging={dragIdx === i}
      class:over={overIdx === i && dragIdx !== i}
      draggable="true"
      ondragstart={(e: DragEvent) => handleDragStart(e, i)}
      ondragover={(e: DragEvent) => handleDragOver(e, i)}
      ondrop={(e: DragEvent) => handleDrop(e, i)}
      ondragend={handleDragEnd}
      role="listitem"
    >
      <span class="drag-handle">⠿</span>
      <span class="drag-label">{item.label}</span>
      {#if item.sublabel}
        <span class="drag-sublabel">{item.sublabel}</span>
      {/if}
    </div>
  {/each}
</div>

<style>
  .drag-list { display: flex; flex-direction: column; gap: 2px; }
  .drag-item {
    display: flex; align-items: center; gap: 10px; padding: 10px 12px;
    background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius);
    cursor: grab; user-select: none; transition: all 0.15s;
  }
  .drag-item:hover { border-color: var(--border-accent); }
  .drag-item.dragging { opacity: 0.4; }
  .drag-item.over { border-color: var(--accent); box-shadow: 0 0 8px var(--accent-glow); }
  .drag-handle { color: var(--text-muted); font-size: 16px; cursor: grab; }
  .drag-label { font-size: 13px; font-weight: 600; color: var(--text-primary); }
  .drag-sublabel { font-size: 11px; color: var(--text-muted); margin-left: auto; }
</style>
