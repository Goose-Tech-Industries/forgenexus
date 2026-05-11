<script lang="ts">
  import { canvasState } from './canvas-state.svelte';
  import { categoryColor } from './category-colors';
  import { NODE_WIDTH, getNodeHeight } from './canvas-math';

  const MAP_W = 180;
  const MAP_H = 120;
  const PADDING = 40;

  // Compute bounds of all nodes
  const bounds = $derived(() => {
    const ns = canvasState.nodes;
    if (ns.length === 0) return { minX: 0, minY: 0, maxX: 800, maxY: 600 };
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (const n of ns) {
      const schema = canvasState.nodeTypeMap.get(n.type) ?? null;
      const h = getNodeHeight(schema);
      minX = Math.min(minX, n.position_x);
      minY = Math.min(minY, n.position_y);
      maxX = Math.max(maxX, n.position_x + NODE_WIDTH);
      maxY = Math.max(maxY, n.position_y + h);
    }
    return {
      minX: minX - PADDING,
      minY: minY - PADDING,
      maxX: maxX + PADDING,
      maxY: maxY + PADDING,
    };
  });

  const scale = $derived(() => {
    const b = bounds();
    const rangeX = b.maxX - b.minX || 1;
    const rangeY = b.maxY - b.minY || 1;
    return Math.min(MAP_W / rangeX, MAP_H / rangeY);
  });

  function toMapX(x: number) { return (x - bounds().minX) * scale(); }
  function toMapY(y: number) { return (y - bounds().minY) * scale(); }

  function handleClick(e: MouseEvent) {
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
    const mx = e.clientX - rect.left;
    const my = e.clientY - rect.top;
    const canvasX = mx / scale() + bounds().minX;
    const canvasY = my / scale() + bounds().minY;
    // Center viewport on this point
    const vp = canvasState.viewport;
    canvasState.pan(
      -canvasX * vp.zoom - vp.panX + window.innerWidth / 2,
      -canvasY * vp.zoom - vp.panY + window.innerHeight / 2
    );
  }
</script>

<div class="minimap" role="button" tabindex="-1" onclick={handleClick} onkeydown={(e: KeyboardEvent) => { if (e.key === 'Enter') handleClick(e as any); }}>
  <svg width={MAP_W} height={MAP_H}>
    <rect width={MAP_W} height={MAP_H} fill="#0a0e17" rx="4" />

    <!-- Nodes as small rects -->
    {#each canvasState.nodes as node (node.id)}
      {@const schema = canvasState.nodeTypeMap.get(node.type) ?? null}
      <rect
        x={toMapX(node.position_x)}
        y={toMapY(node.position_y)}
        width={NODE_WIDTH * scale()}
        height={getNodeHeight(schema) * scale()}
        rx="1"
        fill={categoryColor(node.category)}
        opacity={canvasState.selectedNodeId === node.id ? 1 : 0.6}
      />
    {/each}

    <!-- Viewport rect -->
    {#if true}
      {@const vp = canvasState.viewport}
      {@const vx = toMapX(-vp.panX / vp.zoom)}
      {@const vy = toMapY(-vp.panY / vp.zoom)}
      {@const vw = (window.innerWidth - 520) / vp.zoom * scale()}
      {@const vh = window.innerHeight / vp.zoom * scale()}
      <rect
        x={vx} y={vy}
        width={vw} height={vh}
        fill="none"
        stroke="#fff"
        stroke-width="1"
        opacity="0.4"
        rx="1"
      />
    {/if}
  </svg>
</div>

<style>
  .minimap {
    position: absolute;
    bottom: 12px;
    right: 12px;
    width: 180px;
    height: 120px;
    border: 1px solid var(--border-color);
    border-radius: 6px;
    overflow: hidden;
    cursor: pointer;
    opacity: 0.8;
    transition: opacity 0.15s;
  }

  .minimap:hover {
    opacity: 1;
  }
</style>
