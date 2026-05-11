<script lang="ts">
  import type { FlowNode, FlowEdge, NodeTypeSchema } from '$lib/stores/plugins.svelte';
  import { categoryColor } from './category-colors';
  import { edgePath, getPortIndexByName, getInputPortPosition, getOutputPortPosition } from './canvas-math';

  let {
    edge,
    sourceNode,
    targetNode,
    sourceSchema,
    targetSchema,
    selected = false,
    onSelect,
  }: {
    edge: FlowEdge;
    sourceNode: FlowNode;
    targetNode: FlowNode;
    sourceSchema: NodeTypeSchema | null;
    targetSchema: NodeTypeSchema | null;
    selected: boolean;
    onSelect: (id: string) => void;
  } = $props();

  const sourcePortIdx = $derived(
    sourceSchema ? getPortIndexByName(sourceSchema, 'output', edge.source_port) : 0
  );
  const targetPortIdx = $derived(
    targetSchema ? getPortIndexByName(targetSchema, 'input', edge.target_port) : 0
  );

  const sourcePos = $derived(getOutputPortPosition(sourceNode, sourcePortIdx));
  const targetPos = $derived(getInputPortPosition(targetNode, targetPortIdx));
  const path = $derived(edgePath(sourcePos.x, sourcePos.y, targetPos.x, targetPos.y));
  const color = $derived(categoryColor(sourceNode.category));
</script>

<g class="edge" role="button" tabindex="-1" onclick={(e: MouseEvent) => { e.stopPropagation(); onSelect(edge.id); }} onkeydown={(e: KeyboardEvent) => { if (e.key === 'Enter') onSelect(edge.id); }}>
  <!-- Invisible fat hitbox -->
  <path
    d={path}
    fill="none"
    stroke="transparent"
    stroke-width="14"
    style="cursor: pointer; pointer-events: stroke;"
  />
  <!-- Visible edge -->
  <path
    d={path}
    fill="none"
    stroke={selected ? '#fff' : color}
    stroke-width={selected ? 2.5 : 1.5}
    opacity={selected ? 1 : 0.7}
  />
  <!-- Condition label -->
  {#if edge.condition}
    {@const midX = (sourcePos.x + targetPos.x) / 2}
    {@const midY = (sourcePos.y + targetPos.y) / 2}
    <rect
      x={midX - 20} y={midY - 8}
      width="40" height="16"
      rx="4" fill="#1a2235"
      stroke={color} stroke-width="1"
    />
    <text
      x={midX} y={midY + 4}
      text-anchor="middle"
      fill={color}
      font-size="9"
      font-family="Inter, sans-serif"
    >
      {edge.condition}
    </text>
  {/if}
</g>
