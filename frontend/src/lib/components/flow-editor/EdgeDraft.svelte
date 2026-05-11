<script lang="ts">
  import type { DraftEdge } from './canvas-state.svelte';
  import { edgePath } from './canvas-math';

  let {
    draft,
    sourceAbsX,
    sourceAbsY,
  }: {
    draft: DraftEdge;
    sourceAbsX: number;
    sourceAbsY: number;
  } = $props();

  const path = $derived(edgePath(sourceAbsX, sourceAbsY, draft.mouseX, draft.mouseY));
</script>

<path
  d={path}
  fill="none"
  stroke="#fff"
  stroke-width="1.5"
  stroke-dasharray="6 4"
  opacity="0.5"
  pointer-events="none"
/>
