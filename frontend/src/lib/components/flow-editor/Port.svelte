<script lang="ts">
  import { categoryColor } from './category-colors';

  let {
    localX,
    localY,
    absX,
    absY,
    name,
    side,
    category,
    nodeId,
    onStartDraft,
    onCompleteDraft,
  }: {
    localX: number;
    localY: number;
    absX: number;
    absY: number;
    name: string;
    side: 'input' | 'output';
    category: string;
    nodeId: string;
    onStartDraft: (nodeId: string, port: string, absX: number, absY: number) => void;
    onCompleteDraft: (nodeId: string, port: string) => void;
  } = $props();

  let hovered = $state(false);
  const r = 6;
  const color = $derived(categoryColor(category));

  function handleMouseDown(e: MouseEvent) {
    if (side === 'output') {
      e.stopPropagation();
      onStartDraft(nodeId, name, absX, absY);
    }
  }

  function handleMouseUp(e: MouseEvent) {
    if (side === 'input') {
      e.stopPropagation();
      onCompleteDraft(nodeId, name);
    }
  }
</script>

<g
  class="port"
  role="button"
  tabindex="-1"
  onmousedown={handleMouseDown}
  onmouseup={handleMouseUp}
  onmouseenter={() => { hovered = true; }}
  onmouseleave={() => { hovered = false; }}
  style="cursor: pointer;"
>
  {#if hovered}
    <circle cx={localX} cy={localY} r={r + 4} fill={color} opacity="0.2" />
  {/if}
  <circle
    cx={localX}
    cy={localY}
    r={r}
    fill={hovered ? color : '#1e293b'}
    stroke={color}
    stroke-width="2"
  />
  <text
    x={side === 'input' ? localX + 12 : localX - 12}
    y={localY + 4}
    text-anchor={side === 'input' ? 'start' : 'end'}
    fill="#94a3b8"
    font-size="10"
    font-family="Inter, sans-serif"
  >
    {name}
  </text>
</g>
