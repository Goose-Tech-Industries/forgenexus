<script lang="ts">
  import type { FlowNode, NodeTypeSchema } from '$lib/stores/plugins.svelte';
  import { categoryColor } from './category-colors';
  import { NODE_WIDTH, HEADER_HEIGHT, PORT_OFFSET_Y, PORT_SPACING, getNodeHeight, truncateText } from './canvas-math';
  import Port from './Port.svelte';

  let {
    node,
    schema,
    selected = false,
    onStartDraft,
    onCompleteDraft,
  }: {
    node: FlowNode;
    schema: NodeTypeSchema | null;
    selected: boolean;
    onStartDraft: (nodeId: string, port: string, absX: number, absY: number) => void;
    onCompleteDraft: (nodeId: string, port: string) => void;
  } = $props();

  const color = $derived(categoryColor(node.category));
  const height = $derived(getNodeHeight(schema));
  const inputs = $derived(schema?.inputs ?? []);
  const outputs = $derived(schema?.outputs ?? []);
  const label = $derived(node.label || schema?.label || node.type);
</script>

<g transform="translate({node.position_x} {node.position_y})">
  <!-- Selection glow -->
  {#if selected}
    <rect
      x="-3" y="-3"
      width={NODE_WIDTH + 6} height={height + 6}
      rx="10" ry="10"
      fill="none"
      stroke={color}
      stroke-width="2"
      opacity="0.5"
    />
  {/if}

  <!-- Body -->
  <rect
    x="0" y="0"
    width={NODE_WIDTH} height={height}
    rx="8" ry="8"
    fill="#141c2b"
    stroke={selected ? color : '#1e293b'}
    stroke-width={selected ? 2 : 1}
  />

  <!-- Header background -->
  <clipPath id="header-clip-{node.id}">
    <rect x="0" y="0" width={NODE_WIDTH} height={HEADER_HEIGHT} rx="8" ry="8" />
  </clipPath>
  <rect
    x="0" y="0"
    width={NODE_WIDTH} height={HEADER_HEIGHT}
    clip-path="url(#header-clip-{node.id})"
    fill={color}
    opacity="0.15"
  />

  <!-- Header bottom line -->
  <line x1="0" y1={HEADER_HEIGHT} x2={NODE_WIDTH} y2={HEADER_HEIGHT} stroke={color} stroke-width="1" opacity="0.4" />

  <!-- Category dot -->
  <circle cx="14" cy={HEADER_HEIGHT / 2} r="4" fill={color} />

  <!-- Node label -->
  <text
    x="26" y={HEADER_HEIGHT / 2 + 4}
    fill="#e2e8f0"
    font-size="12"
    font-weight="600"
    font-family="Inter, sans-serif"
  >
    {truncateText(label, 20)}
  </text>

  <!-- Type subtitle -->
  <text
    x={NODE_WIDTH - 8} y={HEADER_HEIGHT / 2 + 3}
    text-anchor="end"
    fill="#64748b"
    font-size="9"
    font-family="Inter, sans-serif"
  >
    {node.type.split('/')[1]?.replace(/_/g, ' ') ?? ''}
  </text>

  <!-- Input ports (left side) -->
  {#each inputs as input, i (input.name)}
    {@const localY = PORT_OFFSET_Y + i * PORT_SPACING}
    <Port
      localX={0}
      {localY}
      absX={node.position_x}
      absY={node.position_y + localY}
      name={input.name}
      side="input"
      category={node.category}
      nodeId={node.id}
      {onStartDraft}
      {onCompleteDraft}
    />
  {/each}

  <!-- Output ports (right side) -->
  {#each outputs as output, i (output.name)}
    {@const localY = PORT_OFFSET_Y + i * PORT_SPACING}
    <Port
      localX={NODE_WIDTH}
      {localY}
      absX={node.position_x + NODE_WIDTH}
      absY={node.position_y + localY}
      name={output.name}
      side="output"
      category={node.category}
      nodeId={node.id}
      {onStartDraft}
      {onCompleteDraft}
    />
  {/each}
</g>
